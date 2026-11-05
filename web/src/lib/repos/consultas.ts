import "server-only";
import { consultar, consultarUna, ejecutar, enTransaccion } from "@/lib/db";
import { falla } from "@/lib/validar";
import { POR_PAGINA } from "@/components/ui";

type Opcion = { valor: number; texto: string };

export async function listarConsultas(q: string, tipo: string, vet: string, pagina: number) {
  const filas = await consultar(
    `SELECT c.id, c.fecha_hora, c.tipo, c.motivo, m.id AS mascota_id, m.nombre AS mascota,
            v.nombres || ' ' || v.apellidos AS veterinario,
            cl.nombres || ' ' || cl.apellidos AS tutor,
            (SELECT d.nombre FROM consulta_diagnostico cd JOIN diagnostico d ON d.id = cd.diagnostico_id
              WHERE cd.consulta_id = c.id ORDER BY cd.es_principal DESC LIMIT 1) AS diagnostico,
            count(*) OVER()::int AS total
       FROM consulta c
       JOIN mascota m ON m.id = c.mascota_id
       JOIN cliente cl ON cl.id = m.cliente_id
       JOIN veterinario v ON v.id = c.veterinario_id
      WHERE ($1 = '' OR f_normalizar(m.nombre || ' ' || c.motivo) LIKE '%' || f_normalizar($1) || '%')
        AND ($2 = '' OR c.tipo = $2)
        AND ($3 = '' OR c.veterinario_id::text = $3)
      ORDER BY c.fecha_hora DESC
      LIMIT ${POR_PAGINA} OFFSET $4`,
    [q, tipo, vet, (pagina - 1) * POR_PAGINA],
  );
  return { filas, total: filas[0]?.total ?? 0 };
}

export const obtenerConsulta = (id: number) =>
  consultarUna(
    `SELECT c.*, m.nombre AS mascota, m.foto_url, e.nombre AS especie, e.icono AS especie_icono, m.cliente_id,
            cl.nombres || ' ' || cl.apellidos AS tutor, cl.telefono AS tutor_telefono,
            v.nombres || ' ' || v.apellidos AS veterinario, v.matricula,
            (SELECT rp.peso_kg FROM registro_peso rp WHERE rp.consulta_id = c.id LIMIT 1) AS peso_kg
       FROM consulta c
       JOIN mascota m ON m.id = c.mascota_id
       JOIN especie e ON e.id = m.especie_id
       JOIN cliente cl ON cl.id = m.cliente_id
       JOIN veterinario v ON v.id = c.veterinario_id
      WHERE c.id = $1`,
    [id],
  );

// Quién firmó cada registro clínico. El tratamiento y la receta dependen de su consulta.
const veterinarioDe = async (sql: string, id: number): Promise<number | null> =>
  (await consultarUna<{ veterinario_id: number }>(sql, [id]))?.veterinario_id ?? null;

export const veterinarioDeConsulta = (id: number) =>
  veterinarioDe(`SELECT veterinario_id FROM consulta WHERE id = $1`, id);

export const veterinarioDeTratamiento = (id: number) =>
  veterinarioDe(`SELECT c.veterinario_id FROM tratamiento t JOIN consulta c ON c.id = t.consulta_id WHERE t.id = $1`, id);

export const veterinarioDeReceta = (id: number) =>
  veterinarioDe(`SELECT c.veterinario_id FROM receta r JOIN consulta c ON c.id = r.consulta_id WHERE r.id = $1`, id);

export const alergiasDeMascota = (id: number) =>
  consultar(
    `SELECT cm.nombre, mc.severidad FROM mascota_condicion mc JOIN condicion_medica cm ON cm.id = mc.condicion_medica_id
      WHERE mc.mascota_id = $1 AND cm.tipo = 'ALERGIA' ORDER BY cm.nombre`,
    [id],
  );

export const diagnosticosDeConsulta = (id: number) =>
  consultar(`SELECT * FROM v_consulta_diagnosticos WHERE consulta_id = $1 ORDER BY es_principal DESC, nombre`, [id]);

export const tratamientosDeConsulta = (id: number) =>
  consultar(`SELECT * FROM tratamiento WHERE consulta_id = $1 ORDER BY fecha_inicio, id`, [id]);

export const recetaDeConsulta = (id: number) =>
  consultarUna(`SELECT id, folio, fecha_emision FROM receta WHERE consulta_id = $1`, [id]);

export const opcionesDiagnosticos = () =>
  consultar(`SELECT id AS valor, nombre || ' (' || codigo || ')' AS texto FROM diagnostico ORDER BY nombre`) as Promise<Opcion[]>;

export const opcionesMedicamentos = () =>
  consultar(`SELECT id AS valor, nombre || CASE WHEN concentracion IS NULL OR nombre LIKE '%' || concentracion || '%' THEN '' ELSE ' ' || concentracion END AS texto FROM medicamento
              WHERE activo ORDER BY nombre`) as Promise<Opcion[]>;

export type DatosConsulta = {
  tipo: string;
  motivo: string;
  anamnesis: string | null;
  temperatura_c: string | null;
  frecuencia_cardiaca: number | null;
  frecuencia_respiratoria: number | null;
  examen_fisico: string | null;
  observaciones: string | null;
  proxima_revision: string | null;
};

/** Crea la consulta, registra el peso del día y cierra la cita que la originó.
 *  Va en una transacción: si algo falla no queda una consulta a medias. */
export async function crearConsulta(
  d: DatosConsulta & { mascota_id: number; veterinario_id: number; cita_id: number | null; peso_kg: string | null },
): Promise<number> {
  return enTransaccion(async (cx) => {
    if (d.cita_id) {
      const { rows } = await cx.query(
        `SELECT estado, mascota_id, veterinario_id, fecha_hora_inicio::date <= CURRENT_DATE AS llego FROM cita WHERE id = $1 FOR UPDATE`, [d.cita_id],
      );
      if (!rows[0]) falla("La cita indicada no existe.");
      if (rows[0].mascota_id !== d.mascota_id) falla("Esa cita es de otra mascota.");
      if (rows[0].veterinario_id !== d.veterinario_id) falla("Esa cita está asignada a otro veterinario. Solo esa persona puede atenderla.");
      if (rows[0].estado !== "programada" && rows[0].estado !== "confirmada") falla("Esa cita ya fue cerrada.");
      if (!rows[0].llego) falla("No se puede atender una cita de un día futuro.");
    }
    const { rows } = await cx.query<{ id: number }>(
      `INSERT INTO consulta (mascota_id, veterinario_id, cita_id, tipo, motivo, anamnesis, temperatura_c,
                             frecuencia_cardiaca, frecuencia_respiratoria, examen_fisico, observaciones, proxima_revision)
       VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12) RETURNING id`,
      [d.mascota_id, d.veterinario_id, d.cita_id, d.tipo, d.motivo, d.anamnesis, d.temperatura_c,
        d.frecuencia_cardiaca, d.frecuencia_respiratoria, d.examen_fisico, d.observaciones, d.proxima_revision],
    );
    const id = rows[0].id;
    if (d.peso_kg) {
      // Solo puede haber un peso por mascota y por día: si ya existe, se actualiza.
      await cx.query(
        `INSERT INTO registro_peso (mascota_id, consulta_id, fecha_registro, peso_kg) VALUES ($1,$2,CURRENT_DATE,$3)
         ON CONFLICT ON CONSTRAINT uq_registro_peso_dia DO UPDATE SET peso_kg = EXCLUDED.peso_kg, consulta_id = EXCLUDED.consulta_id`,
        [d.mascota_id, id, d.peso_kg],
      );
    }
    if (d.cita_id) await cx.query(`UPDATE cita SET estado = 'atendida' WHERE id = $1`, [d.cita_id]);
    return id;
  });
}

export const actualizarConsulta = (id: number, d: DatosConsulta) =>
  ejecutar(
    `UPDATE consulta SET tipo=$2, motivo=$3, anamnesis=$4, temperatura_c=$5, frecuencia_cardiaca=$6,
            frecuencia_respiratoria=$7, examen_fisico=$8, observaciones=$9, proxima_revision=$10
      WHERE id=$1`,
    [id, d.tipo, d.motivo, d.anamnesis, d.temperatura_c, d.frecuencia_cardiaca, d.frecuencia_respiratoria,
      d.examen_fisico, d.observaciones, d.proxima_revision],
  );

// ── Diagnósticos (N:M con el catálogo) ──────────────────────────────────────
export const agregarDiagnostico = (consulta: number, diagnostico: number, tipo: string, principal: boolean, notas: string | null) =>
  ejecutar(`INSERT INTO consulta_diagnostico (consulta_id, diagnostico_id, tipo, es_principal, notas) VALUES ($1,$2,$3,$4,$5)`,
    [consulta, diagnostico, tipo, principal, notas]);

export const cambiarTipoDiagnostico = (consulta: number, diagnostico: number, tipo: string) =>
  ejecutar(`UPDATE consulta_diagnostico SET tipo = $3 WHERE consulta_id = $1 AND diagnostico_id = $2`, [consulta, diagnostico, tipo]);

export const quitarDiagnostico = (consulta: number, diagnostico: number) =>
  ejecutar(`DELETE FROM consulta_diagnostico WHERE consulta_id = $1 AND diagnostico_id = $2`, [consulta, diagnostico]);

// ── Tratamientos ────────────────────────────────────────────────────────────
export async function listarTratamientos(estado: string, q: string, pagina: number) {
  const filas = await consultar(
    `SELECT t.*, c.veterinario_id, m.id AS mascota_id, m.nombre AS mascota, count(*) OVER()::int AS total
       FROM tratamiento t JOIN consulta c ON c.id = t.consulta_id JOIN mascota m ON m.id = c.mascota_id
      WHERE ($1 = '' OR t.estado = $1)
        AND ($2 = '' OR f_normalizar(m.nombre || ' ' || t.descripcion) LIKE '%' || f_normalizar($2) || '%')
      ORDER BY CASE t.estado WHEN 'activo' THEN 1 ELSE 2 END, t.fecha_inicio DESC
      LIMIT ${POR_PAGINA} OFFSET $3`,
    [estado, q, (pagina - 1) * POR_PAGINA],
  );
  return { filas, total: filas[0]?.total ?? 0 };
}

export const agregarTratamiento = (consulta: number, descripcion: string, indicaciones: string | null, inicio: string, fin: string | null) =>
  ejecutar(`INSERT INTO tratamiento (consulta_id, descripcion, indicaciones, fecha_inicio, fecha_fin_estimada) VALUES ($1,$2,$3,$4,$5)`,
    [consulta, descripcion, indicaciones, inicio, fin]);

export const cambiarEstadoTratamiento = (id: number, estado: string) =>
  ejecutar(`UPDATE tratamiento SET estado = $2 WHERE id = $1`, [id, estado]);

// ── Recetas ─────────────────────────────────────────────────────────────────
export type LineaReceta = {
  medicamento_id: number;
  dosis: string;
  frecuencia: string;
  duracion_dias: number;
  via_administracion: string;
  cantidad: string;
  instrucciones: string | null;
};

const INSERTAR_LINEA = `INSERT INTO receta_detalle (receta_id, medicamento_id, dosis, frecuencia, duracion_dias, via_administracion, cantidad, instrucciones)
                        VALUES ($1,$2,$3,$4,$5,$6,$7,$8)`;
const valoresLinea = (receta: number, l: LineaReceta) =>
  [receta, l.medicamento_id, l.dosis, l.frecuencia, l.duracion_dias, l.via_administracion, l.cantidad, l.instrucciones];

/** Una receta nace con su primer medicamento: nunca queda una receta vacía. El folio lo pone un trigger. */
export async function emitirReceta(consulta: number, indicaciones: string | null, vigencia: number, l: LineaReceta): Promise<number> {
  return enTransaccion(async (cx) => {
    const { rows } = await cx.query<{ id: number }>(
      `INSERT INTO receta (consulta_id, indicaciones_generales, vigencia_dias) VALUES ($1,$2,$3) RETURNING id`,
      [consulta, indicaciones, vigencia],
    );
    await cx.query(INSERTAR_LINEA, valoresLinea(rows[0].id, l));
    return rows[0].id;
  });
}

export const agregarLineaReceta = (receta: number, l: LineaReceta) => ejecutar(INSERTAR_LINEA, valoresLinea(receta, l));

export async function quitarLineaReceta(receta: number, medicamento: number) {
  await enTransaccion(async (cx) => {
    const { rows } = await cx.query(`SELECT count(*)::int AS n FROM receta_detalle WHERE receta_id = $1`, [receta]);
    if (rows[0].n <= 1) falla("La receta debe conservar al menos un medicamento.");
    await cx.query(`DELETE FROM receta_detalle WHERE receta_id = $1 AND medicamento_id = $2`, [receta, medicamento]);
  });
}

export async function listarRecetas(q: string, pagina: number) {
  const filas = await consultar(
    `SELECT r.id, r.folio, r.fecha_emision, r.vigencia_dias, r.consulta_id, m.id AS mascota_id, m.nombre AS mascota,
            v.nombres || ' ' || v.apellidos AS veterinario,
            (SELECT string_agg(me.nombre, ', ' ORDER BY me.nombre) FROM receta_detalle rd
               JOIN medicamento me ON me.id = rd.medicamento_id WHERE rd.receta_id = r.id) AS medicamentos,
            count(*) OVER()::int AS total
       FROM receta r
       JOIN consulta c ON c.id = r.consulta_id
       JOIN mascota m ON m.id = c.mascota_id
       JOIN veterinario v ON v.id = c.veterinario_id
      WHERE ($1 = '' OR f_normalizar(m.nombre || ' ' || r.folio) LIKE '%' || f_normalizar($1) || '%')
      ORDER BY r.fecha_emision DESC, r.id DESC
      LIMIT ${POR_PAGINA} OFFSET $2`,
    [q, (pagina - 1) * POR_PAGINA],
  );
  return { filas, total: filas[0]?.total ?? 0 };
}

export const obtenerReceta = (id: number) =>
  consultarUna(
    `SELECT r.*, c.motivo, c.veterinario_id, m.id AS mascota_id, m.nombre AS mascota, m.sexo, e.nombre AS especie, ra.nombre AS raza,
            cl.nombres || ' ' || cl.apellidos AS tutor, cl.documento AS tutor_documento, cl.telefono AS tutor_telefono,
            v.nombres || ' ' || v.apellidos AS veterinario, v.matricula,
            r.fecha_emision + r.vigencia_dias AS vence
       FROM receta r
       JOIN consulta c ON c.id = r.consulta_id
       JOIN mascota m ON m.id = c.mascota_id
       JOIN especie e ON e.id = m.especie_id
       LEFT JOIN raza ra ON ra.id = m.raza_id
       JOIN cliente cl ON cl.id = m.cliente_id
       JOIN veterinario v ON v.id = c.veterinario_id
      WHERE r.id = $1`,
    [id],
  );

export const lineasDeReceta = (id: number) =>
  consultar(
    `SELECT rd.*, me.nombre || CASE WHEN me.concentracion IS NULL OR me.nombre LIKE '%' || me.concentracion || '%' THEN '' ELSE ' ' || me.concentracion END AS nombre_completo FROM receta_detalle rd
       JOIN medicamento me ON me.id = rd.medicamento_id WHERE rd.receta_id = $1 ORDER BY me.nombre`,
    [id],
  );
