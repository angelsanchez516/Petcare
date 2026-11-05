"use server";

import { crearHash, exigir } from "@/lib/auth";
import { actualizarUsuario, crearUsuario } from "@/lib/repos/personal";
import { emailOpc, entero, enteroOpc, fallo, falla, marcado, terminar, texto, textoOpc, type Estado } from "@/lib/validar";

export async function guardar(_: Estado, f: FormData): Promise<Estado> {
  const yo = await exigir("personal");
  let id: number | null;
  try {
    id = enteroOpc(f, "id");
    const nombre = texto(f, "nombre_usuario", "Usuario", 50);
    const email = emailOpc(f, "email") ?? falla("Falta completar: Correo electrónico.");
    const rol = entero(f, "rol_id", "Rol");
    const activo = marcado(f, "activo");
    const clave = textoOpc(f, "clave", 100);

    if (clave && clave.length < 8) falla("La contraseña debe tener al menos 8 caracteres.");
    if (!id && !clave) falla("Falta completar: Contraseña.");
    // Evita que quien administra se quede sin acceso por accidente.
    if (id === yo.id && !activo) falla("No puedes desactivar tu propio usuario.");

    const hash = clave ? await crearHash(clave) : null;
    if (id) await actualizarUsuario(id, rol, nombre, email, activo, hash);
    else await crearUsuario(rol, nombre, email, hash as string);
  } catch (e) {
    return fallo(e);
  }
  terminar("/admin/usuarios", id ? "Usuario actualizado" : "Usuario creado");
}
