import "server-only";
import { consultar, consultarUna, ejecutar } from "@/lib/db";
import { falla } from "@/lib/validar";
import { POR_PAGINA } from "@/components/ui";

/** Sin filtro muestra lo que hay que atender: vencidos y próximos. */
export const refuerzosPendientes = (estado: string) =>
  consultar(
    `SELECT * FROM v_vacunas_pendientes
      WHERE ($1 = '' AND estado <> 'VIGENTE') OR estado = $1
      ORDER BY vence`,
    [estado],
  );

export async function listarAplicaciones(q: string, pagina: number) {
  const filas = await consultar(
    `SELECT av.id, av.fecha_aplicacion, av.fecha_proximo_refuerzo, av.lote, av.dosis_numero,
            vac.nombre AS vacuna, m.id AS mascota_id, m.nombre AS mascota,
            v.nombres || ' ' || v.apellidos AS veterinario, count(*) OVER()::int AS total
       FROM aplicacion_vacuna av
       JOIN vacuna vac ON vac.id = av.vacuna_id
       JOIN mascota m ON m.id = av.mascota_id
       JOIN veterinario v ON v.id = av.veterinario_id
      WHERE ($1 = '' OR f_normalizar(m.nombre || ' ' || vac.nombre) LIKE '%' || f_normalizar($1) || '%')
      ORDER BY av.fecha_aplicacion DESC, av.id DESC
      LIMIT ${POR_PAGINA} OFFSET $2`,
    [q, (pagina - 1) * POR_PAGINA],
  );
  return { filas, total: filas[0]?.total ?? 0 };
}

/** Vacunas indicadas para la especie. Una vacuna sin especies declaradas es universal,
 *  igual que en el trigger fn_vacuna_apta. */
export const vacunasAptas = (especie: number) =>
  consultar(
    `SELECT v.id AS valor,
            v.nombre || COALESCE(' · refuerzo cada ' || v.intervalo_refuerzo_meses || ' meses', '') AS texto
       FROM vacuna v
      WHERE v.activo AND (
            EXISTS (SELECT 1 FROM vacuna_especie ve WHERE ve.vacuna_id = v.id AND ve.especie_id = $1)
         OR NOT EXISTS (SELECT 1 FROM vacuna_especie ve WHERE ve.vacuna_id = v.id))
      ORDER BY v.nombre`,
    [especie],
  ) as Promise<{ valor: number; texto: string }[]>;

export type DatosAplicacion = {
  mascota_id: number;
  vacuna_id: number;
  veterinario_id: number;
  consulta_id: number | null;
  fecha_aplicacion: string;
  fecha_proximo_refuerzo: string | null;
  lote: string;
  dosis_numero: number;
  observaciones: string | null;
};

/** Que la vacuna sirva para la especie lo valida un trigger. La edad mínima no está
 *  en la base: se revisa aquí, con la edad que tendría la mascota el día de la aplicación.
 *  El próximo refuerzo, si no se escribe, lo calcula el trigger fn_refuerzo_automatico. */
export async function aplicarVacuna(d: DatosAplicacion) {
  const f = await consultarUna(
    `SELECT v.nombre, v.edad_minima_semanas AS minimo, ($2::date - m.fecha_nacimiento) / 7 AS semanas
       FROM vacuna v, mascota m WHERE v.id = $1 AND m.id = $3`,
    [d.vacuna_id, d.fecha_aplicacion, d.mascota_id],
  );
  if (f?.minimo && f.semanas !== null && f.semanas < f.minimo) {
    falla(`«${f.nombre}» se aplica desde las ${f.minimo} semanas de edad; la mascota tendría ${f.semanas}.`);
  }
  await ejecutar(
    `INSERT INTO aplicacion_vacuna (mascota_id, vacuna_id, veterinario_id, consulta_id, fecha_aplicacion,
                                    fecha_proximo_refuerzo, lote, dosis_numero, observaciones)
     VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9)`,
    [d.mascota_id, d.vacuna_id, d.veterinario_id, d.consulta_id, d.fecha_aplicacion,
      d.fecha_proximo_refuerzo, d.lote, d.dosis_numero, d.observaciones],
  );
}
