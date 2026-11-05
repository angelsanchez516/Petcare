import { notFound, redirect } from "next/navigation";
import { Cabecera, idDe } from "@/components/ui";
import { exigir } from "@/lib/auth";
import { paraInputHora } from "@/lib/formato";
import { puedeGestionarCita } from "@/lib/permisos";
import { obtenerCita, opcionesServicios, opcionesVeterinarios } from "@/lib/repos/citas";
import { opcionesMascotas } from "@/lib/repos/mascotas";
import { FormCita } from "../../FormCita";

export const metadata = { title: "Reprogramar cita" };

export default async function EditarCita({ params }: { params: Promise<{ id: string }> }) {
  const usuario = await exigir("citas");
  const id = idDe((await params).id);
  const c = id && await obtenerCita(id);
  if (!c) notFound();
  if ((c.estado !== "programada" && c.estado !== "confirmada") || !puedeGestionarCita(usuario, c.veterinario_id) || !c.mascota_atendible) {
    redirect(`/admin/citas/${c.cita_id}`);
  }

  const [m, v, s] = await Promise.all([opcionesMascotas(), opcionesVeterinarios(), opcionesServicios()]);
  // La lista solo trae veterinarios activos: si el de la cita está inactivo se agrega.
  if (!v.some((x) => x.valor === c.veterinario_id)) v.push({ valor: c.veterinario_id, texto: `${c.veterinario} (inactivo)` });
  return (
    <>
      <Cabecera titulo="Reprogramar cita"
        migas={[{ texto: "Agenda", href: "/admin/citas" }, { texto: c.mascota, href: `/admin/citas/${c.cita_id}` }, { texto: "Reprogramar" }]} />
      <FormCita mascotas={m} veterinarios={usuario.rol === "Veterinario" ? v.filter((x) => x.valor === usuario.veterinario_id) : v} servicios={s} ahora={paraInputHora(new Date())} volver={`/admin/citas/${c.cita_id}`}
        c={{
          id: c.cita_id, mascota_id: c.mascota_id, veterinario_id: c.veterinario_id, servicio_id: c.servicio_id,
          inicio: paraInputHora(c.fecha_hora_inicio), duracion: c.duracion_minutos, motivo: c.motivo, notas: c.notas,
        }} />
    </>
  );
}
