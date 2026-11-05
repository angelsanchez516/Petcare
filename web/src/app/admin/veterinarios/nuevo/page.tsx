import { Cabecera } from "@/components/ui";
import { exigir } from "@/lib/auth";
import { opcionesEspecialidades, usuariosDisponibles } from "@/lib/repos/personal";
import { FormVeterinario } from "../FormVeterinario";

export const metadata = { title: "Nuevo veterinario" };

export default async function NuevoVeterinario() {
  await exigir("personal");
  const [usuarios, especialidades] = await Promise.all([usuariosDisponibles(null), opcionesEspecialidades()]);
  return (
    <>
      <Cabecera titulo="Nuevo veterinario" migas={[{ texto: "Veterinarios", href: "/admin/veterinarios" }, { texto: "Nuevo" }]} />
      <FormVeterinario usuarios={usuarios} especialidades={especialidades} marcadas={[]} />
    </>
  );
}
