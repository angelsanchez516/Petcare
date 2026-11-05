import "server-only";
import { createHmac, randomBytes, scryptSync, timingSafeEqual } from "node:crypto";
import { cache } from "react";
import { cookies } from "next/headers";
import { redirect } from "next/navigation";
import { puede, type Permiso } from "@/lib/permisos";
import { usuarioDeSesion } from "@/lib/repos/sesion";

/** Inicio de sesión y control de acceso.
 *  La cookie solo guarda el id del usuario y su vencimiento, firmados con HMAC.
 *  El rol y si sigue activo se leen de la base en cada petición, así un cambio
 *  hecho por el administrador aplica de inmediato. */

const COOKIE = "petcare_sesion";
const DURACION_SEG = 60 * 60 * 10; // 10 horas: una jornada de trabajo

export type Usuario = {
  id: number;
  nombre_usuario: string;
  email: string;
  rol: string;
  veterinario_id: number | null;
  nombre: string;
};

// Contraseñas: formato scrypt$sal$hash, el mismo de los datos de demostración.
export function crearHash(clave: string): string {
  const sal = randomBytes(16);
  return `scrypt$${sal.toString("hex")}$${scryptSync(clave, sal, 64).toString("hex")}`;
}

export function verificarClave(clave: string, guardado: string): boolean {
  const [tipo, sal, hash] = guardado.split("$");
  if (tipo !== "scrypt" || !sal || !hash) return false;
  const esperado = Buffer.from(hash, "hex");
  const calculado = scryptSync(clave, Buffer.from(sal, "hex"), esperado.length);
  return timingSafeEqual(esperado, calculado);
}

function firmar(valor: string): string {
  const secreto = process.env.AUTH_SECRET;
  if (!secreto) throw new Error("Falta la variable AUTH_SECRET en .env.local");
  return createHmac("sha256", secreto).update(valor).digest("hex");
}

export async function crearSesion(usuarioId: number): Promise<void> {
  const valor = `${usuarioId}.${Math.floor(Date.now() / 1000) + DURACION_SEG}`;
  const almacen = await cookies();
  almacen.set(COOKIE, `${valor}.${firmar(valor)}`, {
    httpOnly: true,
    sameSite: "lax",
    secure: process.env.COOKIE_SEGURA === "1",
    path: "/",
    maxAge: DURACION_SEG,
  });
}

export async function cerrarSesion(): Promise<void> {
  (await cookies()).delete(COOKIE);
}

/** Usuario de la petición actual, o null. cache() evita repetir la consulta
 *  cuando el layout y la página lo piden en el mismo render. */
export const usuarioActual = cache(async (): Promise<Usuario | null> => {
  const cookie = (await cookies()).get(COOKIE)?.value;
  if (!cookie) return null;

  const [id, vence, firma] = cookie.split(".");
  if (!id || !vence || !firma) return null;

  const esperada = Buffer.from(firmar(`${id}.${vence}`));
  const recibida = Buffer.from(firma);
  if (esperada.length !== recibida.length || !timingSafeEqual(esperada, recibida)) return null;
  if (Number(vence) < Date.now() / 1000) return null;

  return usuarioDeSesion(Number(id));
});

/** Se llama al inicio de cada página y de cada acción del panel. Ocultar un botón
 *  no protege nada: esta es la comprobación que de verdad impide el acceso. */
export async function exigir(permiso: Permiso): Promise<Usuario> {
  const usuario = await usuarioActual();
  if (!usuario) redirect("/ingresar");
  if (!puede(usuario.rol, permiso)) redirect("/admin/sin-permiso");
  return usuario;
}
