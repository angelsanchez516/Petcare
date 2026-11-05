"use server";

import { exigir } from "@/lib/auth";
import { paraInput } from "@/lib/formato";
import { puedeEditarClinica } from "@/lib/permisos";
import { obtenerConsulta } from "@/lib/repos/consultas";
import { exigirMascotaAtendible } from "@/lib/repos/mascotas";
import { aplicarVacuna } from "@/lib/repos/vacunas";
import { entero, enteroOpc, fallo, falla, fecha, fechaOpc, terminar, texto, textoOpc, type Estado } from "@/lib/validar";

export async function aplicar(_: Estado, f: FormData): Promise<Estado> {
  const usuario = await exigir("vacunas.aplicar");
  let mascota: number;
  try {
    mascota = entero(f, "mascota_id", "Mascota");
    // La aplicación se firma con el perfil de quien inició sesión.
    if (!usuario.veterinario_id) falla("Tu usuario no está vinculado a un perfil de veterinario.");
    await exigirMascotaAtendible(mascota);
    const aplicada = fecha(f, "fecha_aplicacion", "Fecha de aplicación");
    if (aplicada > paraInput(new Date())) falla("La fecha de aplicación no puede ser futura.");
    const consulta = enteroOpc(f, "consulta_id");
    if (consulta) {
      const c = await obtenerConsulta(consulta);
      if (!c || !puedeEditarClinica(usuario, c.veterinario_id)) falla("No puedes asociar la vacuna a una consulta de otro veterinario.");
      if (c?.mascota_id !== mascota) falla("Esa consulta es de otra mascota.");
    }
    await aplicarVacuna({
      mascota_id: mascota,
      vacuna_id: entero(f, "vacuna_id", "Vacuna"),
      veterinario_id: usuario.veterinario_id as number,
      consulta_id: consulta,
      fecha_aplicacion: aplicada,
      fecha_proximo_refuerzo: fechaOpc(f, "fecha_proximo_refuerzo"),
      lote: texto(f, "lote", "Lote", 40),
      dosis_numero: entero(f, "dosis_numero", "Número de dosis"),
      observaciones: textoOpc(f, "observaciones", 1000),
    });
  } catch (e) {
    return fallo(e);
  }
  terminar(`/admin/mascotas/${mascota}?tab=vacunas`, "Vacuna registrada");
}
