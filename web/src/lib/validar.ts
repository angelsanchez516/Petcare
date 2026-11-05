import "server-only";
import { revalidatePath } from "next/cache";
import { redirect } from "next/navigation";
import { mensajeDeError } from "@/lib/db";

/** Lectura y validación de los formularios en el servidor. La base de datos
 *  tiene sus propias restricciones; esto da mensajes claros antes de llegar a ella. */

export type Estado = { error?: string };

export class ErrorValidacion extends Error {}

const falla = (mensaje: string): never => {
  throw new ErrorValidacion(mensaje);
};

/** Convierte cualquier error en el estado que muestra el formulario. */
export function fallo(e: unknown): Estado {
  return { error: e instanceof ErrorValidacion ? e.message : mensajeDeError(e) };
}

/** Termina una acción: refresca los datos y vuelve a la página con un aviso. */
export function terminar(ruta: string, aviso: string): never {
  revalidatePath("/", "layout");
  const unión = ruta.includes("?") ? "&" : "?";
  redirect(`${ruta}${unión}ok=${encodeURIComponent(aviso)}`);
}

export function textoOpc(f: FormData, campo: string, max = 300): string | null {
  const v = String(f.get(campo) ?? "").trim();
  if (!v) return null;
  if (v.length > max) falla(`«${campo.replace(/_/g, " ")}» admite máximo ${max} caracteres.`);
  return v;
}

export function texto(f: FormData, campo: string, etiqueta: string, max = 300): string {
  return textoOpc(f, campo, max) ?? falla(`Falta completar: ${etiqueta}.`);
}

export function enteroOpc(f: FormData, campo: string): number | null {
  const v = String(f.get(campo) ?? "").trim();
  if (!v) return null;
  if (!/^-?\d+$/.test(v)) falla(`«${campo.replace(/_/g, " ")}» debe ser un número entero.`);
  return Number(v);
}

export function entero(f: FormData, campo: string, etiqueta: string): number {
  return enteroOpc(f, campo) ?? falla(`Falta completar: ${etiqueta}.`);
}

/** Decimales como texto: PostgreSQL los guarda en NUMERIC y así no se pierde
 *  precisión. Acepta coma o punto. */
export function decimalOpc(f: FormData, campo: string): string | null {
  const v = String(f.get(campo) ?? "").trim().replace(",", ".");
  if (!v) return null;
  if (!/^-?\d+(\.\d+)?$/.test(v)) falla(`«${campo.replace(/_/g, " ")}» debe ser un número.`);
  return v;
}

export function decimal(f: FormData, campo: string, etiqueta: string): string {
  return decimalOpc(f, campo) ?? falla(`Falta completar: ${etiqueta}.`);
}

export function fechaOpc(f: FormData, campo: string): string | null {
  const v = String(f.get(campo) ?? "").trim();
  if (!v) return null;
  if (!/^\d{4}-\d{2}-\d{2}(T\d{2}:\d{2})?$/.test(v) || Number.isNaN(new Date(v).getTime())) {
    falla(`«${campo.replace(/_/g, " ")}» no es una fecha válida.`);
  }
  return v;
}

export function fecha(f: FormData, campo: string, etiqueta: string): string {
  return fechaOpc(f, campo) ?? falla(`Falta completar: ${etiqueta}.`);
}

export function opcion(f: FormData, campo: string, validas: readonly string[], etiqueta: string): string {
  const v = String(f.get(campo) ?? "");
  if (!validas.includes(v)) falla(`Selecciona un valor válido en: ${etiqueta}.`);
  return v;
}

export const marcado = (f: FormData, campo: string): boolean => f.get(campo) === "on";

export function emailOpc(f: FormData, campo: string): string | null {
  const v = textoOpc(f, campo, 120);
  if (v && !/^[^@\s]+@[^@\s]+\.[A-Za-z]{2,}$/.test(v)) falla("El correo electrónico no tiene un formato válido.");
  return v;
}

export function telefono(f: FormData, campo: string, etiqueta = "Teléfono"): string {
  const v = texto(f, campo, etiqueta, 25);
  if (!/^[0-9+()\- ]{6,25}$/.test(v)) falla("El teléfono solo admite números, espacios, paréntesis, + y -.");
  return v;
}

export function telefonoOpc(f: FormData, campo: string): string | null {
  return textoOpc(f, campo, 25) ? telefono(f, campo) : null;
}

export { falla };
