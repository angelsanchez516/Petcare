"use server";

import { exigir } from "@/lib/auth";
import {
  agregarLinea, ajustarTotales, anularFactura, crearFactura, eliminarPago, quitarLinea, registrarPago, type Linea,
} from "@/lib/repos/facturas";
import { decimal, decimalOpc, entero, enteroOpc, fallo, falla, terminar, texto, textoOpc, type Estado } from "@/lib/validar";

function leerLinea(f: FormData): Linea {
  return {
    item: texto(f, "item", "Servicio o medicamento", 20),
    mascota_id: enteroOpc(f, "mascota_id"),
    cantidad: decimal(f, "cantidad", "Cantidad"),
  };
}

export async function nueva(_: Estado, f: FormData): Promise<Estado> {
  await exigir("facturas");
  let id: number;
  try {
    id = await crearFactura(entero(f, "cliente_id", "Tutor"), textoOpc(f, "observaciones", 1000), leerLinea(f));
  } catch (e) {
    return fallo(e);
  }
  terminar(`/admin/facturas/${id}`, "Factura creada");
}

export async function nuevaLinea(_: Estado, f: FormData): Promise<Estado> {
  await exigir("facturas");
  let id: number;
  try {
    id = entero(f, "factura_id", "Factura");
    await agregarLinea(id, leerLinea(f));
  } catch (e) {
    return fallo(e);
  }
  terminar(`/admin/facturas/${id}`, "Línea agregada");
}

export async function eliminarLinea(_: Estado, f: FormData): Promise<Estado> {
  await exigir("facturas");
  let id: number;
  try {
    id = entero(f, "factura_id", "Factura");
    await quitarLinea(id, entero(f, "linea_id", "Línea"));
  } catch (e) {
    return fallo(e);
  }
  terminar(`/admin/facturas/${id}`, "Línea retirada");
}

export async function ajustar(_: Estado, f: FormData): Promise<Estado> {
  await exigir("facturas");
  let id: number;
  try {
    id = entero(f, "factura_id", "Factura");
    const descuento = decimalOpc(f, "descuento") ?? "0";
    const impuesto = decimalOpc(f, "impuesto") ?? "0";
    if (Number(descuento) < 0 || Number(impuesto) < 0) falla("El descuento y el impuesto no pueden ser negativos.");
    await ajustarTotales(id, descuento, impuesto);
  } catch (e) {
    return fallo(e);
  }
  terminar(`/admin/facturas/${id}`, "Totales actualizados");
}

export async function pagar(_: Estado, f: FormData): Promise<Estado> {
  await exigir("facturas");
  let id: number;
  try {
    id = entero(f, "factura_id", "Factura");
    const monto = decimal(f, "monto", "Monto");
    if (Number(monto) <= 0) falla("El monto del pago debe ser mayor que cero.");
    await registrarPago(id, entero(f, "metodo_pago_id", "Método de pago"), monto, textoOpc(f, "referencia", 60));
  } catch (e) {
    return fallo(e);
  }
  terminar(`/admin/facturas/${id}`, "Pago registrado");
}

/** Borrar un pago cambia la caja, por eso solo lo puede hacer el administrador. */
export async function quitarPago(_: Estado, f: FormData): Promise<Estado> {
  await exigir("catalogos");
  let id: number;
  try {
    id = entero(f, "factura_id", "Factura");
    await eliminarPago(entero(f, "pago_id", "Pago"), id);
  } catch (e) {
    return fallo(e);
  }
  terminar(`/admin/facturas/${id}`, "Pago eliminado");
}

export async function anular(_: Estado, f: FormData): Promise<Estado> {
  await exigir("facturas");
  let id: number;
  try {
    id = entero(f, "id", "Factura");
    await anularFactura(id, texto(f, "motivo", "Motivo de la anulación", 250));
  } catch (e) {
    return fallo(e);
  }
  terminar(`/admin/facturas/${id}`, "Factura anulada");
}
