import { notFound } from "next/navigation";
import { Cabecera, idDe } from "@/components/ui";
import { exigir } from "@/lib/auth";
import { paraInput } from "@/lib/formato";
import { puede } from "@/lib/permisos";
import { obtenerCliente, opcionesClientes } from "@/lib/repos/clientes";
import { especies, obtenerMascota, razas } from "@/lib/repos/mascotas";
import { FormMascota } from "../../FormMascota";

export const metadata = { title: "Editar mascota" };

export default async function EditarMascota({ params }: { params: Promise<{ id: string }> }) {
  const usuario = await exigir("mascotas.editar");
  const id = idDe((await params).id);
  const m = id && await obtenerMascota(id);
  if (!m) notFound();
  const [c, e, r] = await Promise.all([opcionesClientes(), especies(), razas()]);
  // La lista solo trae tutores activos: si el de esta mascota está de baja se agrega.
  if (!c.some((x) => x.valor === m.cliente_id)) {
    const tutor = await obtenerCliente(m.cliente_id);
    c.push({ valor: m.cliente_id, texto: `${tutor?.apellidos}, ${tutor?.nombres} (de baja)` });
  }
  return (
    <>
      <Cabecera titulo={`Editar a ${m.nombre}`}
        migas={[{ texto: "Mascotas", href: "/admin/mascotas" }, { texto: m.nombre, href: `/admin/mascotas/${m.id}` }, { texto: "Editar" }]} />
      <FormMascota clientes={c} especies={e} razas={r} hoy={paraInput(new Date())} volver={`/admin/mascotas/${m.id}`} tutorFijo={!puede(usuario.rol, "mascotas.administrar")}
        m={{ ...m, fecha_nacimiento: paraInput(m.fecha_nacimiento), fecha_fallecimiento: paraInput(m.fecha_fallecimiento), creado_en: undefined }} />
    </>
  );
}
