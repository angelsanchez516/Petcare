import "server-only";
import type { PoolClient } from "pg";
import { consultar, consultarUna, enTransaccion, ejecutar } from "@/lib/db";
import { falla } from "@/lib/validar";
import { POR_PAGINA } from "@/components/ui";

/** Facturación. Los totales y el estado los mantienen los triggers de la base; aquí
 *  solo se cubre lo que ellos no hacen: reponer stock y bloquear pagos en anuladas. */

export async function listarFacturas(q: string, estado: string, pagina: number) {
  const filas = await consultar(
    `SELECT *, count(*) OVER()::int AS total FROM v_factura_resumen
      WHERE ($1 = '' OR f_normalizar(numero || ' ' || cliente || ' ' || cliente_documento) LIKE '%' || f_normalizar($1) || '%')
        AND ($2 = '' OR estado = $2 OR ($2 = 'abiertas' AND estado IN ('pendiente','parcial')))
      ORDER BY fecha_emision DESC, id DESC
      LIMIT ${POR_PAGINA} OFFSET $3`,
    [q, estado, (pagina - 1) * POR_PAGINA],
  );
  return { filas, total: filas[0]?.total ?? 0 };
}

export const obtenerFactura = (id: number) =>
  consultarUna(
    `SELECT r.*, c.tipo_documento, c.direccion AS cliente_direccion, c.ciudad AS cliente_ciudad, c.email AS cliente_email
       FROM v_factura_resumen r JOIN cliente c ON c.id = r.cliente_id WHERE r.id = $1`,
    [id],
  );

export const lineasDeFactura = (id: number) =>
  consultar(
    `SELECT d.*, m.nombre AS mascota FROM factura_detalle d LEFT JOIN mascota m ON m.id = d.mascota_id
      WHERE d.factura_id = $1 ORDER BY d.linea_nro`,
    [id],
  );

export const pagosDeFactura = (id: number) =>
  consultar(
    `SELECT p.*, mp.nombre AS metodo FROM pago p JOIN metodo_pago mp ON mp.id = p.metodo_pago_id
      WHERE p.factura_id = $1 ORDER BY p.fecha_hora`,
    [id],
  );

/** Lo que se puede facturar. El valor lleva un prefijo: S = servicio, M = medicamento. */
export const opcionesItems = () =>
  consultar(
    `SELECT 'S:' || id AS valor, 'Servicio · ' || nombre || ' · $' || to_char(precio_base, 'FM999G999G990') AS texto, 1 AS orden
       FROM servicio WHERE activo
     UNION ALL
     SELECT 'M:' || id, 'Medicamento · ' || nombre || CASE WHEN concentracion IS NULL OR nombre LIKE '%' || concentracion || '%' THEN '' ELSE ' ' || concentracion END || ' · $' || to_char(precio, 'FM999G999G990')
            || ' · ' || stock || ' en stock', 2
       FROM medicamento WHERE activo AND stock > 0
     ORDER BY orden, texto`,
  ) as Promise<{ valor: string; texto: string }[]>;

export const opcionesMetodosPago = () =>
  consultar(`SELECT id AS valor, nombre || CASE WHEN requiere_referencia THEN ' (exige referencia)' ELSE '' END AS texto
               FROM metodo_pago WHERE activo ORDER BY nombre`) as Promise<{ valor: number; texto: string }[]>;

export const opcionesMascotasDeCliente = (cliente: number) =>
  consultar(`SELECT id AS valor, nombre AS texto FROM mascota WHERE cliente_id = $1 AND activo ORDER BY nombre`, [cliente]) as
    Promise<{ valor: number; texto: string }[]>;

export type Linea = { item: string; mascota_id: number | null; cantidad: string };

/** Agrega una línea copiando el nombre y el precio del catálogo: si mañana cambia el
 *  precio, esta factura no cambia. El stock lo descuenta el trigger fn_descontar_stock. */
async function insertarLinea(cx: PoolClient, factura: number, cliente: number, l: Linea) {
  const [tipo, idTexto] = l.item.split(":");
  const idItem = Number(idTexto);
  if (!Number.isInteger(idItem) || (tipo !== "S" && tipo !== "M")) falla("Selecciona un servicio o un medicamento.");

  const { rows: item } = await cx.query(
    tipo === "S"
      ? `SELECT nombre, precio_base AS precio FROM servicio WHERE id = $1 AND activo`
      : `SELECT nombre || CASE WHEN concentracion IS NULL OR nombre LIKE '%' || concentracion || '%' THEN '' ELSE ' ' || concentracion END AS nombre, precio FROM medicamento WHERE id = $1 AND activo`,
    [idItem],
  );
  if (!item[0]) falla("Ese elemento ya no está disponible.");

  const cantidad = Number(l.cantidad);
  if (!(cantidad > 0) || cantidad > 9999) falla("La cantidad debe estar entre 1 y 9999.");
  // El trigger de stock convierte la cantidad a entero: un medicamento no se vende en fracciones.
  if (tipo === "M" && !Number.isInteger(cantidad)) falla("Los medicamentos se facturan en unidades enteras.");

  if (l.mascota_id) {
    const { rowCount } = await cx.query(`SELECT 1 FROM mascota WHERE id = $1 AND cliente_id = $2`, [l.mascota_id, cliente]);
    if (!rowCount) falla("Esa mascota no pertenece al tutor de la factura.");
  }

  await cx.query(
    `INSERT INTO factura_detalle (factura_id, servicio_id, medicamento_id, mascota_id, linea_nro, descripcion, cantidad, precio_unitario)
     VALUES ($1,$2,$3,$4,(SELECT COALESCE(max(linea_nro), 0) + 1 FROM factura_detalle WHERE factura_id = $1),$5,$6,$7)`,
    [factura, tipo === "S" ? idItem : null, tipo === "M" ? idItem : null, l.mascota_id, item[0].nombre, l.cantidad, item[0].precio],
  );
}

/** La factura nace con su primera línea: nunca existe una factura sin detalle. El número lo pone un trigger. */
export async function crearFactura(cliente: number, observaciones: string | null, l: Linea): Promise<number> {
  return enTransaccion(async (cx) => {
    const { rows } = await cx.query<{ id: number }>(
      `INSERT INTO factura (cliente_id, observaciones) VALUES ($1, $2) RETURNING id`, [cliente, observaciones],
    );
    await insertarLinea(cx, rows[0].id, cliente, l);
    return rows[0].id;
  });
}

/** Bloquea la fila de la factura para que dos cajeros no la modifiquen a la vez. */
async function bloquear(cx: PoolClient, id: number) {
  const { rows } = await cx.query(`SELECT cliente_id, estado FROM factura WHERE id = $1 FOR UPDATE`, [id]);
  if (!rows[0]) falla("La factura no existe.");
  return rows[0] as { cliente_id: number; estado: string };
}

/** Si ya hay pagos, el nuevo total no puede quedar por debajo de lo cobrado. */
async function validarTotal(cx: PoolClient, id: number) {
  const { rows } = await cx.query(
    `SELECT f.total, COALESCE((SELECT sum(monto) FROM pago WHERE factura_id = f.id), 0) AS pagado FROM factura f WHERE f.id = $1`, [id],
  );
  if (Number(rows[0].total) < Number(rows[0].pagado)) falla("El total no puede quedar por debajo de lo que ya se pagó.");
}

export async function agregarLinea(factura: number, l: Linea) {
  await enTransaccion(async (cx) => {
    const f = await bloquear(cx, factura);
    await insertarLinea(cx, factura, f.cliente_id, l);
  });
}

/** Quitar un medicamento devuelve las unidades: el trigger de stock solo actúa al insertar. */
export async function quitarLinea(factura: number, linea: number) {
  await enTransaccion(async (cx) => {
    await bloquear(cx, factura);
    const { rows: conteo } = await cx.query(`SELECT count(*)::int AS n FROM factura_detalle WHERE factura_id = $1`, [factura]);
    if (conteo[0].n <= 1) falla("La factura debe conservar al menos una línea. Si ya no sirve, anúlala.");

    const { rows } = await cx.query(
      `DELETE FROM factura_detalle WHERE id = $1 AND factura_id = $2 RETURNING medicamento_id, cantidad`, [linea, factura],
    );
    if (rows[0]?.medicamento_id) {
      await cx.query(`UPDATE medicamento SET stock = stock + $2::numeric::int WHERE id = $1`, [rows[0].medicamento_id, rows[0].cantidad]);
    }
    await validarTotal(cx, factura);
  });
}

/** ck_factura_total exige que total cuadre en la misma sentencia que cambia el descuento. */
export async function ajustarTotales(factura: number, descuento: string, impuesto: string) {
  await enTransaccion(async (cx) => {
    const f = await bloquear(cx, factura);
    if (f.estado === "anulada") falla("Una factura anulada no se puede modificar.");
    const { rows } = await cx.query(`SELECT subtotal FROM factura WHERE id = $1`, [factura]);
    if (Number(descuento) > Number(rows[0].subtotal)) falla("El descuento no puede superar el subtotal.");
    await cx.query(
      `UPDATE factura SET descuento = $2::numeric, impuesto = $3::numeric, total = subtotal - $2::numeric + $3::numeric WHERE id = $1`,
      [factura, descuento, impuesto],
    );
    await validarTotal(cx, factura);
    await cx.query(`SELECT fn_factura_recalcular($1)`, [factura]);
  });
}

/** El tope del saldo y la referencia obligatoria los valida el trigger fn_trg_pago. */
export async function registrarPago(factura: number, metodo: number, monto: string, referencia: string | null) {
  await enTransaccion(async (cx) => {
    const f = await bloquear(cx, factura);
    if (f.estado === "anulada") falla("No se pueden registrar pagos en una factura anulada.");
    await cx.query(`INSERT INTO pago (factura_id, metodo_pago_id, monto, referencia) VALUES ($1,$2,$3,$4)`, [factura, metodo, monto, referencia]);
  });
}

export const eliminarPago = (pago: number, factura: number) =>
  ejecutar(`DELETE FROM pago WHERE id = $1 AND factura_id = $2`, [pago, factura]);

/** Anular conserva el documento, pero las unidades vendidas vuelven al inventario. */
export async function anularFactura(id: number, motivo: string) {
  await enTransaccion(async (cx) => {
    const f = await bloquear(cx, id);
    if (f.estado === "anulada") falla("La factura ya está anulada.");
    const { rows } = await cx.query(`SELECT count(*)::int AS n FROM pago WHERE factura_id = $1`, [id]);
    if (rows[0].n > 0) falla("No se puede anular una factura con pagos. Elimina primero los pagos.");

    await cx.query(
      `UPDATE medicamento m SET stock = m.stock + d.cantidad::int
         FROM (SELECT medicamento_id, sum(cantidad) AS cantidad FROM factura_detalle
                WHERE factura_id = $1 AND medicamento_id IS NOT NULL GROUP BY medicamento_id) d
        WHERE m.id = d.medicamento_id`,
      [id],
    );
    await cx.query(
      `UPDATE factura SET estado = 'anulada', observaciones = concat_ws(E'\n', observaciones, 'Anulada: ' || $2::text) WHERE id = $1`,
      [id, motivo],
    );
  });
}
