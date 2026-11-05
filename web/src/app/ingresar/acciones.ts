"use server";

import { redirect } from "next/navigation";
import { crearSesion, verificarClave } from "@/lib/auth";
import { limiteAgotado, limpiarIntentos, sumarIntento } from "@/lib/limite";
import { buscarCredenciales, marcarAcceso } from "@/lib/repos/sesion";
import type { Estado } from "@/lib/validar";

const MAX_INTENTOS = 5;
const MINUTOS_ESPERA = 10;

export async function ingresar(_: Estado, f: FormData): Promise<Estado> {
  const nombre = String(f.get("usuario") ?? "").trim();
  const clave = String(f.get("clave") ?? "");
  if (!nombre || !clave) return { error: "Escribe tu usuario y tu contraseña." };

  const llave = `ingreso:${nombre.toLowerCase()}`;
  if (limiteAgotado(llave, MAX_INTENTOS)) {
    return { error: `Demasiados intentos fallidos. Espera ${MINUTOS_ESPERA} minutos e inténtalo de nuevo.` };
  }

  let usuarioId: number;
  try {
    const u = await buscarCredenciales(nombre);
    // Mismo mensaje en todos los casos: no revela si el usuario existe.
    if (!u || !u.activo || !verificarClave(clave, u.password_hash)) {
      sumarIntento(llave, MINUTOS_ESPERA);
      return { error: "Usuario o contraseña incorrectos." };
    }
    limpiarIntentos(llave);
    usuarioId = u.id;
    await marcarAcceso(u.id);
  } catch {
    return { error: "No se pudo conectar con la base de datos. Verifica que PostgreSQL esté en ejecución." };
  }

  await crearSesion(usuarioId);
  redirect("/admin");
}
