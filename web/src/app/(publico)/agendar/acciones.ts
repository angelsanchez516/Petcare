"use server";

import { headers } from "next/headers";
import { redirect } from "next/navigation";
import { limiteAgotado, sumarIntento } from "@/lib/limite";
import { registrarSolicitud } from "@/lib/repos/publico";
import { emailOpc, enteroOpc, fallo, falla, fechaOpc, opcion, telefono, texto, textoOpc, type Estado } from "@/lib/validar";
import { paraInput } from "@/lib/formato";
import { FRANJAS } from "@/lib/etiquetas";

/** Registra la solicitud del visitante. Recepción la convierte en cita desde el panel. */
export async function enviarSolicitud(_: Estado, f: FormData): Promise<Estado> {
  // Campo oculto que una persona nunca llena: los bots de formularios sí.
  if (f.get("sitio_web")) redirect("/agendar/gracias");
  const llave = `agendar:${(await headers()).get("x-forwarded-for") ?? "local"}`;
  try {
    if (limiteAgotado(llave, 10)) falla("Ya recibimos varias solicitudes desde este equipo. Espera un rato o llámanos.");
    const fechaPreferida = fechaOpc(f, "fecha_preferida");
    if (fechaPreferida && fechaPreferida < paraInput(new Date())) falla("La fecha preferida no puede estar en el pasado.");
    await registrarSolicitud({
      nombre: texto(f, "nombre", "Tu nombre", 120),
      telefono: telefono(f, "telefono"),
      email: emailOpc(f, "email"),
      especieId: enteroOpc(f, "especie_id"),
      nombreMascota: textoOpc(f, "nombre_mascota", 60),
      motivo: texto(f, "motivo", "Motivo de la visita", 300),
      fechaPreferida,
      franja: opcion(f, "franja", Object.keys(FRANJAS), "Franja horaria"),
    });
    sumarIntento(llave, 60);
  } catch (e) {
    return fallo(e);
  }
  redirect("/agendar/gracias");
}
