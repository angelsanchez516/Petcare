import "server-only";
import { consultar, consultarUna, ejecutar, enTransaccion } from "@/lib/db";
import { falla } from "@/lib/validar";

type Opcion = { valor: number; texto: string };

export const opcionesVeterinarios = () =>
  consultar(`SELECT id AS valor, nombres || ' ' || apellidos AS texto FROM veterinario
              WHERE activo ORDER BY apellidos, nombres`) as Promise<Opcion[]>;

export const opcionesServicios = () =>
  consultar(`SELECT id, nombre, duracion_estimada_min AS duracion FROM servicio WHERE activo ORDER BY nombre`) as
    Promise<{ id: number; nombre: string; duracion: number | null }[]>;

export const citasDelDia = (dia: string, vet: string) =>
  consultar(
    `SELECT * FROM v_agenda
      WHERE fecha_hora_inicio::date = $1::date AND ($2 = '' OR veterinario_id::text = $2)
      ORDER BY fecha_hora_inicio`,
    [dia, vet],
  );

/** Citas activas por día del mes, para los números del calendario. */
export const conteoDelMes = (primerDia: string, vet: string) =>
  consultar(
    `SELECT to_char(fecha_hora_inicio, 'YYYY-MM-DD') AS dia, count(*)::int AS total
       FROM cita
      WHERE fecha_hora_inicio >= $1::date AND fecha_hora_inicio < ($1::date + INTERVAL '1 month')
        AND estado IN ('programada','confirmada','atendida')
        AND ($2 = '' OR veterinario_id::text = $2)
      GROUP BY 1`,
    [primerDia, vet],
  );

/** Citas ya vencidas que nadie marcó como atendidas, canceladas o no asistidas.
 *  Con un veterinario, solo las suyas. */
export const citasSinCerrar = (veterinario: number | null) =>
  consultar(`SELECT * FROM v_agenda
              WHERE estado IN ('programada','confirmada') AND fecha_hora_fin < now()
                AND ($1::int IS NULL OR veterinario_id = $1)
              ORDER BY fecha_hora_inicio`, [veterinario]);

export async function veterinarioDeCita(id: number): Promise<number | null> {
  const f = await consultarUna<{ veterinario_id: number }>(`SELECT veterinario_id FROM cita WHERE id = $1`, [id]);
  return f?.veterinario_id ?? null;
}

export const obtenerCita = (id: number) =>
  consultarUna(
    `SELECT a.*, c.motivo_cancelacion, m.activo AND m.fecha_fallecimiento IS NULL AS mascota_atendible
       FROM v_agenda a JOIN cita c ON c.id = a.cita_id JOIN mascota m ON m.id = c.mascota_id
      WHERE a.cita_id = $1`,
    [id],
  );

export type DatosCita = {
  mascota_id: number;
  veterinario_id: number;
  servicio_id: number | null;
  inicio: string;
  duracion: number;
  motivo: string;
  notas: string | null;
};

/** El solapamiento de horarios lo impide la restricción EXCLUDE de la tabla cita. */
export async function guardarCita(d: DatosCita, id: number | null): Promise<number> {
  const v = [d.mascota_id, d.veterinario_id, d.servicio_id, d.inicio, d.duracion, d.motivo, d.notas];
  if (id) {
    const n = await ejecutar(
      `UPDATE cita SET mascota_id=$1, veterinario_id=$2, servicio_id=$3, fecha_hora_inicio=$4,
              duracion_minutos=$5, motivo=$6, notas=$7
        WHERE id=$8 AND estado IN ('programada','confirmada')`,
      [...v, id],
    );
    if (n === 0) falla("Solo se pueden modificar citas programadas o confirmadas.");
    return id;
  }
  const f = await consultarUna<{ id: number }>(
    `INSERT INTO cita (mascota_id, veterinario_id, servicio_id, fecha_hora_inicio, duracion_minutos, motivo, notas)
     VALUES ($1,$2,$3,$4,$5,$6,$7) RETURNING id`,
    v,
  );
  return f!.id;
}

/** Crea la cita y marca la solicitud web como convertida, las dos cosas o ninguna. */
export async function convertirSolicitud(d: DatosCita, solicitud: number): Promise<number> {
  return enTransaccion(async (cx) => {
    const { rows } = await cx.query<{ id: number }>(
      `INSERT INTO cita (mascota_id, veterinario_id, servicio_id, fecha_hora_inicio, duracion_minutos, motivo, notas)
       VALUES ($1,$2,$3,$4,$5,$6,$7) RETURNING id`,
      [d.mascota_id, d.veterinario_id, d.servicio_id, d.inicio, d.duracion, d.motivo, d.notas],
    );
    const r = await cx.query(
      `UPDATE solicitud_cita SET estado = 'convertida', cita_id = $1
        WHERE id = $2 AND estado IN ('nueva','contactada')`,
      [rows[0].id, solicitud],
    );
    if (r.rowCount === 0) falla("Esa solicitud ya fue atendida.");
    return rows[0].id;
  });
}

export async function confirmarCita(id: number) {
  const n = await ejecutar(`UPDATE cita SET estado = 'confirmada' WHERE id = $1 AND estado = 'programada'`, [id]);
  if (n === 0) falla("Solo se puede confirmar una cita programada.");
}

export async function cancelarCita(id: number, motivo: string) {
  const n = await ejecutar(
    `UPDATE cita SET estado = 'cancelada', motivo_cancelacion = $2 WHERE id = $1 AND estado IN ('programada','confirmada')`,
    [id, motivo],
  );
  if (n === 0) falla("Esta cita ya fue cerrada y no se puede cancelar.");
}

export async function marcarNoAsistio(id: number) {
  const n = await ejecutar(
    `UPDATE cita SET estado = 'no_asistio'
      WHERE id = $1 AND estado IN ('programada','confirmada') AND fecha_hora_inicio <= now()`,
    [id],
  );
  if (n === 0) falla("Solo se puede marcar la inasistencia cuando la hora de la cita ya pasó.");
}

// ── Solicitudes del sitio web ───────────────────────────────────────────────
export const listarSolicitudes = (estado: string) =>
  consultar(
    `SELECT s.*, e.nombre AS especie FROM solicitud_cita s LEFT JOIN especie e ON e.id = s.especie_id
      WHERE ($1 = '' OR s.estado = $1)
      ORDER BY CASE s.estado WHEN 'nueva' THEN 1 WHEN 'contactada' THEN 2 ELSE 3 END, s.creado_en DESC`,
    [estado],
  );

export const obtenerSolicitud = (id: number) =>
  consultarUna(
    `SELECT s.*, e.nombre AS especie FROM solicitud_cita s LEFT JOIN especie e ON e.id = s.especie_id WHERE s.id = $1`,
    [id],
  );

/** Solicitudes sin revisar, para el contador del menú lateral. */
export const contarSolicitudesNuevas = () =>
  consultarUna<{ n: number }>(`SELECT count(*)::int AS n FROM solicitud_cita WHERE estado = 'nueva'`);

export async function cambiarEstadoSolicitud(id: number, estado: "contactada" | "descartada") {
  const n = await ejecutar(`UPDATE solicitud_cita SET estado = $2 WHERE id = $1 AND estado IN ('nueva','contactada')`, [id, estado]);
  if (n === 0) falla("Esa solicitud ya fue atendida.");
}
