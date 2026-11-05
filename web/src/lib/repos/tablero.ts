import "server-only";
import { consultar, consultarUna } from "@/lib/db";

/** Consultas del tablero principal. Todo sale de tablas y vistas reales. */

/** Con un veterinario, las cifras de citas son solo las suyas. */
export const cifrasTablero = (veterinario: number | null) =>
  consultarUna(
    `SELECT (SELECT count(*)::int FROM mascota WHERE activo) AS mascotas,
            (SELECT count(*)::int FROM cliente WHERE activo) AS clientes,
            (SELECT count(*)::int FROM cita WHERE fecha_hora_inicio::date = CURRENT_DATE
                AND estado IN ('programada','confirmada','atendida')
                AND ($1::int IS NULL OR veterinario_id = $1)) AS citas_hoy,
            (SELECT count(*)::int FROM consulta
              WHERE date_trunc('month', fecha_hora) = date_trunc('month', now())) AS consultas_mes,
            (SELECT count(*)::int FROM v_vacunas_pendientes WHERE estado <> 'VIGENTE') AS refuerzos,
            (SELECT COALESCE(sum(monto), 0) FROM pago
              WHERE date_trunc('month', fecha_hora) = date_trunc('month', now())) AS ingresos_mes`,
    [veterinario],
  );

export const alertasTablero = (veterinario: number | null) =>
  consultarUna(
    `SELECT (SELECT count(*)::int FROM v_vacunas_pendientes WHERE estado = 'VENCIDA') AS vacunas_vencidas,
            (SELECT count(*)::int FROM v_vacunas_pendientes WHERE estado = 'PROXIMA') AS vacunas_proximas,
            (SELECT count(*)::int FROM v_stock_alerta) AS stock_bajo,
            (SELECT count(*)::int FROM solicitud_cita WHERE estado = 'nueva') AS solicitudes,
            (SELECT count(*)::int FROM factura WHERE estado IN ('pendiente','parcial')) AS por_cobrar,
            (SELECT count(*)::int FROM cita
              WHERE estado IN ('programada','confirmada') AND fecha_hora_fin < now()
                AND ($1::int IS NULL OR veterinario_id = $1)) AS citas_sin_cerrar`,
    [veterinario],
  );

/** Un veterinario ve sus propias citas; los demás roles, las de toda la clínica. */
export const citasDeHoy = (veterinario: number | null) =>
  consultar(
    `SELECT * FROM v_agenda
      WHERE fecha_hora_inicio::date = CURRENT_DATE
        AND ($1::int IS NULL OR veterinario_id = $1)
      ORDER BY fecha_hora_inicio`,
    [veterinario],
  );

export const consultasRecientes = () =>
  consultar(
    `SELECT c.id, c.fecha_hora, c.motivo, m.id AS mascota_id, m.nombre AS mascota, m.foto_url, e.icono,
            v.nombres || ' ' || v.apellidos AS veterinario
       FROM consulta c
       JOIN mascota m ON m.id = c.mascota_id
       JOIN especie e ON e.id = m.especie_id
       JOIN veterinario v ON v.id = c.veterinario_id
      ORDER BY c.fecha_hora DESC LIMIT 5`,
  );

export const ingresosRecientes = () =>
  consultar(`SELECT mes, facturado, cobrado FROM v_ingresos_mensuales ORDER BY mes DESC LIMIT 6`);

export const mascotasPorEspecie = () =>
  consultar(
    `SELECT e.nombre, count(*)::int AS total
       FROM mascota m JOIN especie e ON e.id = m.especie_id
      WHERE m.activo GROUP BY e.nombre ORDER BY total DESC, e.nombre`,
  );
