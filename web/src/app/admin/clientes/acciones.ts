"use server";

import { exigir } from "@/lib/auth";
import { cambiarActivoCliente, guardarCliente } from "@/lib/repos/clientes";
import { TIPOS_DOCUMENTO } from "@/lib/etiquetas";
import { emailOpc, entero, enteroOpc, fallo, opcion, telefono, terminar, texto, textoOpc, type Estado } from "@/lib/validar";

export async function guardar(_: Estado, f: FormData): Promise<Estado> {
  await exigir("clientes.editar");
  let id: number | null;
  let nuevoId: number;
  try {
    id = enteroOpc(f, "id");
    nuevoId = await guardarCliente({
      tipo_documento: opcion(f, "tipo_documento", Object.keys(TIPOS_DOCUMENTO), "Tipo de documento"),
      documento: texto(f, "documento", "Documento", 20),
      nombres: texto(f, "nombres", "Nombres", 80),
      apellidos: texto(f, "apellidos", "Apellidos", 80),
      telefono: telefono(f, "telefono"),
      email: emailOpc(f, "email"),
      direccion: textoOpc(f, "direccion", 200),
      ciudad: textoOpc(f, "ciudad", 80),
      notas: textoOpc(f, "notas", 2000),
    }, id);
  } catch (e) {
    return fallo(e);
  }
  terminar(`/admin/clientes/${nuevoId}`, id ? "Tutor actualizado" : "Tutor registrado");
}

export async function cambiarActivo(_: Estado, f: FormData): Promise<Estado> {
  await exigir("clientes.editar");
  const activo = f.get("activo") === "1";
  let id: number;
  try {
    id = entero(f, "id", "id");
    await cambiarActivoCliente(id, activo);
  } catch (e) {
    return fallo(e);
  }
  terminar(`/admin/clientes/${id}`, activo ? "Tutor reactivado" : "Tutor dado de baja");
}
