import { Cabecera } from "@/components/ui";
import { exigir } from "@/lib/auth";
import { paraInput } from "@/lib/formato";
import { opcionesClientes } from "@/lib/repos/clientes";
import { especies, razas } from "@/lib/repos/mascotas";
import { FormMascota } from "../FormMascota";

export const metadata = { title: "Nueva mascota" };

export default async function NuevaMascota({ searchParams }: { searchParams: Promise<Record<string, string>> }) {
  await exigir("mascotas.editar");
  const { cliente, nombre, especie } = await searchParams;
  const [c, e, r] = await Promise.all([opcionesClientes(), especies(), razas()]);
  return (
    <>
      <Cabecera titulo="Nueva mascota" migas={[{ texto: "Mascotas", href: "/admin/mascotas" }, { texto: "Nueva" }]} />
      <FormMascota clientes={c} especies={e} razas={r} hoy={paraInput(new Date())} volver="/admin/mascotas"
        m={{ cliente_id: cliente ? Number(cliente) : undefined, nombre, especie_id: especie ? Number(especie) : undefined }} />
    </>
  );
}
