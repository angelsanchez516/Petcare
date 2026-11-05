"use server";

import { exigir, type Usuario } from "@/lib/auth";
import { puedeGestionarCita } from "@/lib/permisos";
import { cancelarCita, confirmarCita, convertirSolicitud, guardarCita, marcarNoAsistio, veterinarioDeCita } from "@/lib/repos/citas";
import { exigirMascotaAtendible } from "@/lib/repos/mascotas";
import { entero, enteroOpc, fallo, falla, fecha, terminar, texto, textoOpc, type Estado } from "@/lib/validar";

/** Ocultar los botones no basta: cada acción vuelve a comprobar de quién es la cita. */
async function comprobarCita(usuario: Usuario, id: number) {
  const veterinario = await veterinarioDeCita(id);
  if (veterinario === null) falla("La cita no existe.");
  if (!puedeGestionarCita(usuario, veterinario as number)) falla("Esta cita es de otro veterinario. Solo puedes consultarla.");
}

export async function guardar(_: Estado, f: FormData): Promise<Estado> {
  const usuario = await exigir("citas");
  if (f.get("solicitud_id")) await exigir("solicitudes");
  let id: number | null;
  let solicitud: number | null;
  let citaId: number;
  try {
    id = enteroOpc(f, "id");
    solicitud = enteroOpc(f, "solicitud_id");
    if (id) await comprobarCita(usuario, id);

    // El veterinario solo agenda a su propio nombre, sin importar lo que llegue en el formulario.
    const veterinario = usuario.rol === "Veterinario" ? usuario.veterinario_id : entero(f, "veterinario_id", "Veterinario");
    if (!veterinario) falla("Tu usuario no está vinculado a un perfil de veterinario.");

    const inicio = fecha(f, "inicio", "Fecha y hora");
    if (!inicio.includes("T")) falla("Indica también la hora de la cita.");
    if (new Date(inicio) < new Date()) falla("La cita no puede empezar en el pasado.");

    const mascota = entero(f, "mascota_id", "Mascota");
    await exigirMascotaAtendible(mascota);

    const datos = {
      mascota_id: mascota,
      veterinario_id: veterinario as number,
      servicio_id: enteroOpc(f, "servicio_id"),
      inicio,
      duracion: entero(f, "duracion", "Duración"),
      motivo: texto(f, "motivo", "Motivo", 300),
      notas: textoOpc(f, "notas", 2000),
    };
    citaId = solicitud ? await convertirSolicitud(datos, solicitud) : await guardarCita(datos, id);
  } catch (e) {
    return fallo(e);
  }
  terminar(`/admin/citas/${citaId}`, id ? "Cita actualizada" : "Cita agendada");
}

export async function confirmar(_: Estado, f: FormData): Promise<Estado> {
  const usuario = await exigir("citas");
  let id: number;
  try {
    id = entero(f, "id", "id");
    await comprobarCita(usuario, id);
    await confirmarCita(id);
  } catch (e) {
    return fallo(e);
  }
  terminar(`/admin/citas/${id}`, "Cita confirmada");
}

export async function cancelar(_: Estado, f: FormData): Promise<Estado> {
  const usuario = await exigir("citas");
  let id: number;
  try {
    id = entero(f, "id", "id");
    await comprobarCita(usuario, id);
    await cancelarCita(id, texto(f, "motivo", "Motivo de cancelación", 250));
  } catch (e) {
    return fallo(e);
  }
  terminar(`/admin/citas/${id}`, "Cita cancelada");
}

export async function noAsistio(_: Estado, f: FormData): Promise<Estado> {
  const usuario = await exigir("citas");
  let id: number;
  try {
    id = entero(f, "id", "id");
    await comprobarCita(usuario, id);
    await marcarNoAsistio(id);
  } catch (e) {
    return fallo(e);
  }
  terminar(`/admin/citas/${id}`, "Inasistencia registrada");
}
