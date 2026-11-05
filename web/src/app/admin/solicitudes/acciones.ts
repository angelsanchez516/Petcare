"use server";

import { exigir } from "@/lib/auth";
import { cambiarEstadoSolicitud } from "@/lib/repos/citas";
import { entero, fallo, terminar, type Estado } from "@/lib/validar";

export async function marcarContactada(_: Estado, f: FormData): Promise<Estado> {
  await exigir("solicitudes");
  try {
    await cambiarEstadoSolicitud(entero(f, "id", "id"), "contactada");
  } catch (e) {
    return fallo(e);
  }
  terminar("/admin/solicitudes", "Solicitud marcada como contactada");
}

export async function descartar(_: Estado, f: FormData): Promise<Estado> {
  await exigir("solicitudes");
  try {
    await cambiarEstadoSolicitud(entero(f, "id", "id"), "descartada");
  } catch (e) {
    return fallo(e);
  }
  terminar("/admin/solicitudes", "Solicitud descartada");
}
