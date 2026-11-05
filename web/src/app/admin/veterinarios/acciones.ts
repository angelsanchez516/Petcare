"use server";

import { exigir } from "@/lib/auth";
import { guardarFoto } from "@/lib/fotos";
import { guardarVeterinario } from "@/lib/repos/personal";
import { emailOpc, enteroOpc, fallo, falla, marcado, telefonoOpc, terminar, texto, textoOpc, type Estado } from "@/lib/validar";

export async function guardar(_: Estado, f: FormData): Promise<Estado> {
  await exigir("personal");
  let id: number | null;
  try {
    id = enteroOpc(f, "id");
    const especialidades = f.getAll("especialidades").map(Number).filter(Number.isInteger);
    const principal = enteroOpc(f, "principal");
    if (principal && !especialidades.includes(principal)) falla("La especialidad principal debe estar marcada en la lista.");
    await guardarVeterinario({
      usuario_id: enteroOpc(f, "usuario_id"),
      documento: texto(f, "documento", "Documento", 20),
      matricula: texto(f, "matricula", "Matrícula", 30),
      nombres: texto(f, "nombres", "Nombres", 80),
      apellidos: texto(f, "apellidos", "Apellidos", 80),
      telefono: telefonoOpc(f, "telefono"),
      email: emailOpc(f, "email"),
      biografia: textoOpc(f, "biografia", 2000),
      activo: marcado(f, "activo"),
    }, await guardarFoto(f), id, especialidades, principal);
  } catch (e) {
    return fallo(e);
  }
  terminar("/admin/veterinarios", id ? "Veterinario actualizado" : "Veterinario registrado");
}
