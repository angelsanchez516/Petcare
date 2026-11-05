import { notFound } from "next/navigation";
import { Cabecera, idDe } from "@/components/ui";
import { exigir } from "@/lib/auth";
import { especialidadesDe, obtenerVeterinario, opcionesEspecialidades, usuariosDisponibles } from "@/lib/repos/personal";
import { FormVeterinario } from "../FormVeterinario";

export const metadata = { title: "Editar veterinario" };

export default async function EditarVeterinario({ params }: { params: Promise<{ id: string }> }) {
  await exigir("personal");
  const id = idDe((await params).id);
  const v = id && await obtenerVeterinario(id);
  if (!v || !id) notFound();
  const [usuarios, especialidades, suyas] = await Promise.all([usuariosDisponibles(id), opcionesEspecialidades(), especialidadesDe(id)]);
  return (
    <>
      <Cabecera titulo={`${v.nombres} ${v.apellidos}`} migas={[{ texto: "Veterinarios", href: "/admin/veterinarios" }, { texto: `${v.nombres} ${v.apellidos}` }]} />
      <FormVeterinario v={v} usuarios={usuarios} especialidades={especialidades}
        marcadas={suyas.map((e) => e.especialidad_id)} principal={suyas.find((e) => e.es_principal)?.especialidad_id} />
    </>
  );
}
