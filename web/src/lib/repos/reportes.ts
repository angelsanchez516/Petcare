import "server-only";
import { consultar } from "@/lib/db";

/** Consultas del módulo de reportes. Cada una lee una vista de la base, que ya
 *  trae el cálculo hecho (05_vistas.sql). */

/** desde y hasta son meses AAAA-MM; vacío significa sin límite. */
export const ingresosMensuales = (desde: string, hasta: string) =>
  consultar(
    `SELECT * FROM v_ingresos_mensuales
      WHERE ($1 = '' OR mes >= ($1 || '-01')::date) AND ($2 = '' OR mes <= ($2 || '-01')::date)
      ORDER BY mes DESC`,
    [desde, hasta],
  );

export const serviciosMasUsados = () =>
  consultar(`SELECT * FROM v_servicios_mas_usados ORDER BY veces DESC, ingresos DESC LIMIT 10`);

export const diagnosticosFrecuentes = () =>
  consultar(`SELECT * FROM v_morbilidad ORDER BY casos DESC, nombre LIMIT 10`);
