import { notFound } from "next/navigation";
import { Cabecera, idDe } from "@/components/ui";
import { exigir } from "@/lib/auth";
import { obtenerCliente } from "@/lib/repos/clientes";
import { FormCliente } from "../../FormCliente";

export const metadata = { title: "Editar tutor" };

export default async function EditarCliente({ params }: { params: Promise<{ id: string }> }) {
  await exigir("clientes.editar");
  const id = idDe((await params).id);
  const c = id && await obtenerCliente(id);
  if (!c) notFound();
  return (
    <>
      <Cabecera titulo={`Editar a ${c.nombres} ${c.apellidos}`}
        migas={[{ texto: "Tutores", href: "/admin/clientes" }, { texto: `${c.nombres} ${c.apellidos}`, href: `/admin/clientes/${c.id}` }, { texto: "Editar" }]} />
      <FormCliente c={c} volver={`/admin/clientes/${c.id}`} />
    </>
  );
}
