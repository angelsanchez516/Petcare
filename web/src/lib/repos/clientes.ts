import "server-only";
import { consultar, consultarUna, ejecutar, type Fila } from "@/lib/db";
import { POR_PAGINA } from "@/components/ui";

export type DatosCliente = {
  tipo_documento: string;
  documento: string;
  nombres: string;
  apellidos: string;
  telefono: string;
  email: string | null;
  direccion: string | null;
  ciudad: string | null;
  notas: string | null;
};

/** El saldo solo se calcula para quien puede ver facturación: a los demás ni siquiera
 *  les llega en la respuesta. */
export async function listarClientes(q: string, estado: string, pagina: number, conSaldo: boolean) {
  const filas = await consultar(
    `SELECT c.id, c.tipo_documento, c.documento, c.nombres, c.apellidos, c.telefono, c.email, c.activo,
            (SELECT count(*)::int FROM mascota m WHERE m.cliente_id = c.id AND m.activo) AS mascotas,
            ${conSaldo ? `(SELECT COALESCE(sum(f.saldo), 0) FROM v_factura_resumen f
              WHERE f.cliente_id = c.id AND f.estado <> 'anulada')` : "NULL"} AS saldo,
            count(*) OVER()::int AS total
       FROM cliente c
      WHERE ($1 = '' OR f_normalizar(c.nombres || ' ' || c.apellidos) LIKE '%' || f_normalizar($1) || '%'
             OR c.documento ILIKE '%' || $1 || '%' OR c.telefono ILIKE '%' || $1 || '%')
        AND ($2 = '' OR c.activo = ($2 = 'activos'))
      ORDER BY c.apellidos, c.nombres
      LIMIT ${POR_PAGINA} OFFSET $3`,
    [q, estado, (pagina - 1) * POR_PAGINA],
  );
  return { filas, total: filas[0]?.total ?? 0 };
}

export const obtenerCliente = (id: number) =>
  consultarUna(`SELECT * FROM cliente WHERE id = $1`, [id]);

export async function guardarCliente(d: DatosCliente, id: number | null): Promise<number> {
  const v = [d.tipo_documento, d.documento, d.nombres, d.apellidos, d.telefono, d.email, d.direccion, d.ciudad, d.notas];
  if (id) {
    await ejecutar(
      `UPDATE cliente SET tipo_documento=$1, documento=$2, nombres=$3, apellidos=$4, telefono=$5,
              email=$6, direccion=$7, ciudad=$8, notas=$9 WHERE id=$10`,
      [...v, id],
    );
    return id;
  }
  const f = await consultarUna<{ id: number }>(
    `INSERT INTO cliente (tipo_documento, documento, nombres, apellidos, telefono, email, direccion, ciudad, notas)
     VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9) RETURNING id`,
    v,
  );
  return f!.id;
}

export const cambiarActivoCliente = (id: number, activo: boolean) =>
  ejecutar(`UPDATE cliente SET activo = $1 WHERE id = $2`, [activo, id]);

export const opcionesClientes = () =>
  consultar(`SELECT id AS valor, apellidos || ', ' || nombres || ' · ' || documento AS texto
               FROM cliente WHERE activo ORDER BY apellidos, nombres`) as Promise<{ valor: number; texto: string }[]>;

export const mascotasDeCliente = (id: number): Promise<Fila[]> =>
  consultar(`SELECT id, nombre, especie, especie_icono, raza, foto_url, sexo_texto, edad_anios, edad_meses, activo
               FROM v_mascota_perfil WHERE cliente_id = $1 ORDER BY activo DESC, nombre`, [id]);

export const citasDeCliente = (id: number) =>
  consultar(`SELECT * FROM v_agenda WHERE cliente_id = $1 ORDER BY fecha_hora_inicio DESC LIMIT 8`, [id]);

export const facturasDeCliente = (id: number) =>
  consultar(`SELECT * FROM v_factura_resumen WHERE cliente_id = $1 ORDER BY fecha_emision DESC, id DESC LIMIT 8`, [id]);

export const consultasDeCliente = (id: number) =>
  consultar(`SELECT c.id, c.fecha_hora, c.motivo, c.tipo, m.nombre AS mascota, m.id AS mascota_id
               FROM consulta c JOIN mascota m ON m.id = c.mascota_id
              WHERE m.cliente_id = $1 ORDER BY c.fecha_hora DESC LIMIT 8`, [id]);
