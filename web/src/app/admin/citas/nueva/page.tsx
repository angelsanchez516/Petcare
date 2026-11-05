import { Cabecera, Vacio } from "@/components/ui";
import { exigir } from "@/lib/auth";
import { paraInputHora } from "@/lib/formato";
import { puedeAgendar } from "@/lib/permisos";
import { opcionesServicios, opcionesVeterinarios } from "@/lib/repos/citas";
import { opcionesMascotas } from "@/lib/repos/mascotas";
import { FormCita } from "../FormCita";

export const metadata = { title: "Agendar cita" };

export default async function NuevaCita({ searchParams }: { searchParams: Promise<Record<string, string>> }) {
  const usuario = await exigir("citas");
  const { mascota } = await searchParams;
  if (!puedeAgendar(usuario)) {
    return (
      <>
        <Cabecera titulo="Agendar cita" migas={[{ texto: "Agenda", href: "/admin/citas" }, { texto: "Nueva" }]} />
        <div className="tarjeta"><Vacio titulo="No puedes agendar citas todavía" texto="Tu usuario no está vinculado a un perfil de veterinario." /></div>
      </>
    );
  }
  const [m, v, s] = await Promise.all([opcionesMascotas(), opcionesVeterinarios(), opcionesServicios()]);
  return (
    <>
      <Cabecera titulo="Agendar cita" migas={[{ texto: "Agenda", href: "/admin/citas" }, { texto: "Nueva" }]} />
      <FormCita mascotas={m} veterinarios={usuario.rol === "Veterinario" ? v.filter((x) => x.valor === usuario.veterinario_id) : v} servicios={s} ahora={paraInputHora(new Date())} volver="/admin/citas"
        c={{ mascota_id: mascota ? Number(mascota) : undefined, veterinario_id: usuario.veterinario_id ?? undefined }} />
    </>
  );
}
