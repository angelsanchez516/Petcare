import Link from "next/link";
import { notFound, redirect } from "next/navigation";
import { BotonEnviar, Formulario } from "@/components/Formulario";
import { Cabecera, idDe, Seccion } from "@/components/ui";
import { exigir } from "@/lib/auth";
import { puedeEditarClinica } from "@/lib/permisos";
import { obtenerConsulta } from "@/lib/repos/consultas";
import { editar } from "../../acciones";
import { CamposConsulta } from "../../CamposConsulta";

export const metadata = { title: "Editar consulta" };

export default async function EditarConsulta({ params }: { params: Promise<{ id: string }> }) {
  const usuario = await exigir("clinica");
  const id = idDe((await params).id);
  const c = id && await obtenerConsulta(id);
  if (!c) notFound();
  if (!puedeEditarClinica(usuario, c.veterinario_id)) redirect(`/admin/consultas/${c.id}`);
  return (
    <>
      <Cabecera titulo={`Editar consulta de ${c.mascota}`}
        migas={[{ texto: "Consultas", href: "/admin/consultas" }, { texto: c.mascota, href: `/admin/consultas/${c.id}` }, { texto: "Editar" }]} />
      <Seccion className="max-w-3xl">
        <Formulario accion={editar}>
          <input type="hidden" name="id" value={c.id} />
          <CamposConsulta c={c} />
          <div className="flex gap-2">
            <BotonEnviar>Guardar</BotonEnviar>
            <Link href={`/admin/consultas/${c.id}`} className="btn btn-md btn-fantasma">Cancelar</Link>
          </div>
        </Formulario>
      </Seccion>
    </>
  );
}
