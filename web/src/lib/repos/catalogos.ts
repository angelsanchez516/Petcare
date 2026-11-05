import "server-only";
import type { Catalogo } from "@/lib/catalogos";
import { consultar, consultarUna, ejecutar, enTransaccion } from "@/lib/db";

export const listarCatalogo = (c: Catalogo, q: string) =>
  consultar(
    `SELECT t.* FROM (${c.lista}) t
      WHERE $1 = '' OR f_normalizar(t.nombre) LIKE '%' || f_normalizar($1) || '%'
      ORDER BY t.nombre`,
    [q],
  );

export const obtenerRegistro = (c: Catalogo, id: number) =>
  consultarUna(`SELECT * FROM ${c.tabla} WHERE id = $1`, [id]);

export const opcionesFk = (sql: string) => consultar(sql) as Promise<{ valor: number; texto: string }[]>;

export const especiesDeVacuna = (id: number) =>
  consultar<{ especie_id: number }>(`SELECT especie_id FROM vacuna_especie WHERE vacuna_id = $1`, [id]);

export async function guardarRegistro(c: Catalogo, valores: unknown[], id: number | null, especies: number[]): Promise<void> {
  const cols = c.campos.map((x) => x.col);
  await enTransaccion(async (cx) => {
    let registro = id;
    if (id) {
      await cx.query(
        `UPDATE ${c.tabla} SET ${cols.map((col, i) => `${col} = $${i + 1}`).join(", ")} WHERE id = $${cols.length + 1}`,
        [...valores, id],
      );
    } else {
      const { rows } = await cx.query(
        `INSERT INTO ${c.tabla} (${cols.join(", ")}) VALUES (${cols.map((_, i) => `$${i + 1}`).join(", ")}) RETURNING id`,
        valores,
      );
      registro = rows[0].id;
    }
    if (c.conEspecies) {
      await cx.query(`DELETE FROM vacuna_especie WHERE vacuna_id = $1`, [registro]);
      for (const e of especies) {
        await cx.query(`INSERT INTO vacuna_especie (vacuna_id, especie_id) VALUES ($1, $2)`, [registro, e]);
      }
    }
  });
}

/** Medicamentos en su stock mínimo o sin existencias (vista v_stock_alerta). */
export const contarStockBajo = () =>
  consultarUna<{ n: number }>(`SELECT count(*)::int AS n FROM v_stock_alerta`);

/** Si el registro está en uso, la clave foránea (RESTRICT) impide borrarlo. */
export const eliminarRegistro = (c: Catalogo, id: number) =>
  ejecutar(`DELETE FROM ${c.tabla} WHERE id = $1`, [id]);
