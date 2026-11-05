import "server-only";
import { consultar, consultarUna, ejecutar } from "@/lib/db";
import { falla } from "@/lib/validar";

export const MASCOTAS_POR_PAGINA = 12;

/** Perfil de la mascota con su estado de vacunación.
 *
 *  El estado se calcula desde v_vacunas_pendientes y no desde las columnas
 *  proximo_refuerzo / estado_vacunacion de v_mascota_perfil: esa vista toma el
 *  refuerzo más antiguo de TODAS las aplicaciones, de modo que una mascota que ya
 *  recibió el refuerzo seguiría apareciendo como vencida.
 *
 *  NO_APLICA significa que el catálogo no tiene ninguna vacuna compatible con la
 *  especie. SIN_DATOS significa que sí las hay, pero la mascota no tiene aplicaciones. */
const PERFIL = `
  SELECT p.*, r.vence AS vacuna_vence,
         CASE WHEN r.vence IS NULL AND NOT EXISTS (
                SELECT 1 FROM vacuna v WHERE v.activo AND (
                       EXISTS (SELECT 1 FROM vacuna_especie ve WHERE ve.vacuna_id = v.id AND ve.especie_id = p.especie_id)
                    OR NOT EXISTS (SELECT 1 FROM vacuna_especie ve WHERE ve.vacuna_id = v.id))) THEN 'NO_APLICA'
              WHEN r.vence IS NULL THEN 'SIN_DATOS'
              WHEN r.vence < CURRENT_DATE THEN 'VENCIDA'
              WHEN r.vence <= CURRENT_DATE + 30 THEN 'PROXIMA'
              ELSE 'VIGENTE' END AS vacuna_estado
    FROM v_mascota_perfil p
    LEFT JOIN LATERAL (SELECT min(vp.vence) AS vence FROM v_vacunas_pendientes vp
                        WHERE vp.mascota_id = p.id) r ON TRUE`;

export async function listarMascotas(q: string, especie: string, vacuna: string, estado: string, pagina: number) {
  const filas = await consultar(
    `SELECT t.*, count(*) OVER()::int AS total FROM (${PERFIL}) t
      WHERE ($1 = '' OR f_normalizar(t.nombre) LIKE '%' || f_normalizar($1) || '%'
             OR f_normalizar(t.tutor) LIKE '%' || f_normalizar($1) || '%' OR t.microchip = $1)
        AND ($2 = '' OR t.especie_id::text = $2)
        AND ($3 = '' OR t.vacuna_estado = $3)
        AND ($4 = 'todas' OR t.activo)
      ORDER BY t.nombre
      LIMIT ${MASCOTAS_POR_PAGINA} OFFSET $5`,
    [q, especie, vacuna, estado, (pagina - 1) * MASCOTAS_POR_PAGINA],
  );
  return { filas, total: filas[0]?.total ?? 0 };
}

export const obtenerPerfil = (id: number) =>
  consultarUna(`SELECT t.* FROM (${PERFIL}) t WHERE t.id = $1`, [id]);

export const obtenerMascota = (id: number) =>
  consultarUna(`SELECT * FROM mascota WHERE id = $1`, [id]);

export const opcionesMascotas = () =>
  consultar(`SELECT m.id AS valor, m.nombre || ' — ' || c.nombres || ' ' || c.apellidos AS texto
               FROM mascota m JOIN cliente c ON c.id = m.cliente_id
              WHERE m.activo AND m.fecha_fallecimiento IS NULL ORDER BY m.nombre`) as Promise<{ valor: number; texto: string }[]>;

/** Una mascota de baja o fallecida conserva su historial, pero no recibe atenciones nuevas. */
export async function exigirMascotaAtendible(id: number) {
  const f = await consultarUna(`SELECT 1 FROM mascota WHERE id = $1 AND activo AND fecha_fallecimiento IS NULL`, [id]);
  if (!f) falla("Esta mascota está dada de baja o falleció, así que no se le pueden registrar atenciones nuevas.");
}

export async function citasAbiertasDeMascota(id: number): Promise<number> {
  const f = await consultarUna<{ n: number }>(
    `SELECT count(*)::int AS n FROM cita WHERE mascota_id = $1 AND estado IN ('programada','confirmada')`, [id],
  );
  return f?.n ?? 0;
}

export const especies = () =>
  consultar(`SELECT id AS valor, nombre AS texto FROM especie ORDER BY nombre`) as Promise<{ valor: number; texto: string }[]>;

export const razas = () =>
  consultar(`SELECT id, especie_id, nombre FROM raza ORDER BY nombre`) as Promise<{ id: number; especie_id: number; nombre: string }[]>;

export type DatosMascota = {
  cliente_id: number;
  especie_id: number;
  raza_id: number | null;
  nombre: string;
  sexo: string;
  fecha_nacimiento: string | null;
  color: string | null;
  microchip: string | null;
  esterilizado: boolean;
  observaciones: string | null;
  fecha_fallecimiento: string | null;
};

/** La foto solo se reemplaza si se subió una nueva. */
export async function guardarMascota(d: DatosMascota, foto: string | null, id: number | null): Promise<number> {
  const v = [d.cliente_id, d.especie_id, d.raza_id, d.nombre, d.sexo, d.fecha_nacimiento, d.color,
    d.microchip, d.esterilizado, d.observaciones, d.fecha_fallecimiento, foto];
  if (id) {
    await ejecutar(
      `UPDATE mascota SET cliente_id=$1, especie_id=$2, raza_id=$3, nombre=$4, sexo=$5, fecha_nacimiento=$6,
              color=$7, microchip=$8, esterilizado=$9, observaciones=$10, fecha_fallecimiento=$11,
              foto_url=COALESCE($12, foto_url)
        WHERE id=$13`,
      [...v, id],
    );
    return id;
  }
  const f = await consultarUna<{ id: number }>(
    `INSERT INTO mascota (cliente_id, especie_id, raza_id, nombre, sexo, fecha_nacimiento, color,
                          microchip, esterilizado, observaciones, fecha_fallecimiento, foto_url)
     VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12) RETURNING id`,
    v,
  );
  return f!.id;
}

/** Baja lógica: un DELETE lo impediría la base porque destruiría el historial. */
export const cambiarActivoMascota = (id: number, activo: boolean) =>
  ejecutar(`UPDATE mascota SET activo = $1 WHERE id = $2`, [activo, id]);

// ── Condiciones médicas (N:M) ───────────────────────────────────────────────
export const condicionesDeMascota = (id: number) =>
  consultar(`SELECT mc.condicion_medica_id AS id, cm.nombre, cm.tipo, mc.severidad, mc.fecha_deteccion, mc.notas
               FROM mascota_condicion mc JOIN condicion_medica cm ON cm.id = mc.condicion_medica_id
              WHERE mc.mascota_id = $1
              ORDER BY CASE mc.severidad WHEN 'GRAVE' THEN 1 WHEN 'MEDIA' THEN 2 ELSE 3 END, cm.nombre`, [id]);

export const opcionesCondiciones = () =>
  consultar(`SELECT id AS valor, nombre AS texto FROM condicion_medica ORDER BY nombre`) as Promise<{ valor: number; texto: string }[]>;

export const agregarCondicion = (mascota: number, condicion: number, severidad: string, fecha: string | null, notas: string | null) =>
  ejecutar(`INSERT INTO mascota_condicion (mascota_id, condicion_medica_id, severidad, fecha_deteccion, notas)
            VALUES ($1,$2,$3,$4,$5)`, [mascota, condicion, severidad, fecha, notas]);

export const quitarCondicion = (mascota: number, condicion: number) =>
  ejecutar(`DELETE FROM mascota_condicion WHERE mascota_id = $1 AND condicion_medica_id = $2`, [mascota, condicion]);

// ── Peso ────────────────────────────────────────────────────────────────────
export const pesosDeMascota = (id: number) =>
  consultar(`SELECT id, fecha_registro, peso_kg, observacion, consulta_id FROM registro_peso
              WHERE mascota_id = $1 ORDER BY fecha_registro`, [id]);

export const registrarPeso = (mascota: number, fecha: string, peso: string, observacion: string | null) =>
  ejecutar(`INSERT INTO registro_peso (mascota_id, fecha_registro, peso_kg, observacion) VALUES ($1,$2,$3,$4)`,
    [mascota, fecha, peso, observacion]);

// ── Pestañas de la ficha ────────────────────────────────────────────────────
/** Línea de tiempo: consultas, vacunas, pesos y citas no atendidas ya pasadas.
 *  Las citas atendidas se omiten porque ya aparecen como su consulta. */
export const historialDeMascota = (id: number) =>
  consultar(`SELECT * FROM v_historial_clinico
              WHERE mascota_id = $1
                AND NOT (tipo = 'CITA' AND (momento > now() OR titulo = 'Atendida'))
              ORDER BY momento DESC, tipo`, [id]);

export const diagnosticosDeMascota = (id: number) =>
  consultar(`SELECT cd.consulta_id, d.nombre, cd.tipo, cd.es_principal
               FROM consulta_diagnostico cd
               JOIN diagnostico d ON d.id = cd.diagnostico_id
               JOIN consulta c ON c.id = cd.consulta_id
              WHERE c.mascota_id = $1 ORDER BY cd.es_principal DESC`, [id]);

export const tratamientosDeMascota = (id: number) =>
  consultar(`SELECT t.*, c.fecha_hora AS consulta_fecha FROM tratamiento t
               JOIN consulta c ON c.id = t.consulta_id
              WHERE c.mascota_id = $1 ORDER BY t.fecha_inicio DESC`, [id]);

export const recetasDeMascota = (id: number) =>
  consultar(`SELECT r.id, r.folio, r.fecha_emision, r.consulta_id,
                    (SELECT string_agg(me.nombre, ', ' ORDER BY me.nombre) FROM receta_detalle rd
                       JOIN medicamento me ON me.id = rd.medicamento_id WHERE rd.receta_id = r.id) AS medicamentos
               FROM receta r JOIN consulta c ON c.id = r.consulta_id
              WHERE c.mascota_id = $1 ORDER BY r.fecha_emision DESC`, [id]);

export const consultasDeMascota = (id: number) =>
  consultar(`SELECT c.id, c.fecha_hora, c.tipo, c.motivo, v.nombres || ' ' || v.apellidos AS veterinario
               FROM consulta c JOIN veterinario v ON v.id = c.veterinario_id
              WHERE c.mascota_id = $1 ORDER BY c.fecha_hora DESC`, [id]);

export const vacunasDeMascota = (id: number) =>
  consultar(`SELECT av.id, vac.nombre AS vacuna, av.fecha_aplicacion, av.fecha_proximo_refuerzo, av.lote,
                    av.dosis_numero, v.nombres || ' ' || v.apellidos AS veterinario,
                    (av.fecha_aplicacion = (SELECT max(a2.fecha_aplicacion) FROM aplicacion_vacuna a2
                                             WHERE a2.mascota_id = av.mascota_id AND a2.vacuna_id = av.vacuna_id)) AS ultima
               FROM aplicacion_vacuna av
               JOIN vacuna vac ON vac.id = av.vacuna_id
               JOIN veterinario v ON v.id = av.veterinario_id
              WHERE av.mascota_id = $1 ORDER BY av.fecha_aplicacion DESC`, [id]);

export const citasDeMascota = (id: number) =>
  consultar(`SELECT * FROM v_agenda WHERE mascota_id = $1 ORDER BY fecha_hora_inicio DESC`, [id]);

export const facturasDeMascota = (id: number) =>
  consultar(`SELECT DISTINCT r.id, r.numero, r.fecha_emision, r.total, r.saldo, r.estado
               FROM factura_detalle d JOIN v_factura_resumen r ON r.id = d.factura_id
              WHERE d.mascota_id = $1 ORDER BY r.fecha_emision DESC`, [id]);
