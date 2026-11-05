import { Cabecera } from "@/components/ui";
import { exigir } from "@/lib/auth";
import { FormCliente } from "../FormCliente";

export const metadata = { title: "Nuevo tutor" };

export default async function NuevoCliente({ searchParams }: { searchParams: Promise<Record<string, string>> }) {
  await exigir("clientes.editar");
  // Desde una solicitud web llegan el nombre y el teléfono ya escritos.
  const { nombres, telefono, email } = await searchParams;
  return (
    <>
      <Cabecera titulo="Nuevo tutor" migas={[{ texto: "Tutores", href: "/admin/clientes" }, { texto: "Nuevo" }]} />
      <FormCliente c={{ nombres, telefono, email }} volver="/admin/clientes" />
    </>
  );
}
