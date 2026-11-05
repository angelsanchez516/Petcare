import Link from "next/link";
import { notFound, redirect } from "next/navigation";
import { Cabecera, Dato, idDe, Seccion } from "@/components/ui";
import { exigir } from "@/lib/auth";
import { FRANJAS } from "@/lib/etiquetas";
import { fecha, paraInputHora } from "@/lib/formato";
import { obtenerSolicitud, opcionesServicios, opcionesVeterinarios } from "@/lib/repos/citas";
import { opcionesMascotas } from "@/lib/repos/mascotas";
import { FormCita } from "../../citas/FormCita";

export const metadata = { title: "Convertir solicitud" };

/** Una cita necesita una mascota registrada. Si el visitante es nuevo, primero se
 *  registra el tutor y su mascota y después se vuelve a esta página. */
export default async function ConvertirSolicitud({ params }: { params: Promise<{ id: string }> }) {
  await exigir("solicitudes");
  const id = idDe((await params).id);
  const s = id && await obtenerSolicitud(id);
  if (!s || !id) notFound();
  if (s.estado !== "nueva" && s.estado !== "contactada") redirect("/admin/solicitudes");

  const [m, v, sv] = await Promise.all([opcionesMascotas(), opcionesVeterinarios(), opcionesServicios()]);
  const nombres = s.nombre_contacto;
  const datosTutor = new URLSearchParams({ nombres, telefono: s.telefono_contacto, ...(s.email_contacto ? { email: s.email_contacto } : {}) });
  const preferida = s.fecha_preferida ? new Date(s.fecha_preferida) : null;
  if (preferida) preferida.setHours(s.franja_preferida === "TARDE" ? 14 : 9);

  return (
    <>
      <Cabecera titulo="Convertir solicitud en cita"
        migas={[{ texto: "Solicitudes web", href: "/admin/solicitudes" }, { texto: s.nombre_contacto }]} />
      <div className="grid items-start gap-5 lg:grid-cols-3">
        <Seccion titulo="Lo que pidió">
          <dl className="space-y-3">
            <Dato etiqueta="Contacto">{s.nombre_contacto} · {s.telefono_contacto}</Dato>
            <Dato etiqueta="Mascota">{s.nombre_mascota}{s.especie && ` (${s.especie})`}</Dato>
            <Dato etiqueta="Motivo">{s.motivo}</Dato>
            <Dato etiqueta="Prefiere">{s.fecha_preferida ? fecha(s.fecha_preferida) : "Sin fecha"}{s.franja_preferida && `, ${FRANJAS[s.franja_preferida]?.toLowerCase()}`}</Dato>
          </dl>
          <div className="mt-4 border-t border-gris-200 pt-4 text-sm text-gris-700">
            <p>¿La mascota no aparece en la lista? Regístrala primero y vuelve a esta página:</p>
            <div className="mt-3 flex flex-wrap gap-2">
              <Link href={`/admin/clientes/nuevo?${datosTutor}`} className="btn btn-sm btn-secundario">Registrar tutor</Link>
              <Link href="/admin/mascotas/nueva" className="btn btn-sm btn-secundario">Registrar mascota</Link>
            </div>
          </div>
        </Seccion>
        <div className="lg:col-span-2">
          <FormCita mascotas={m} veterinarios={v} servicios={sv} ahora={paraInputHora(new Date())} volver="/admin/solicitudes" solicitud={id}
            c={{ motivo: s.motivo, inicio: preferida && preferida > new Date() ? paraInputHora(preferida) : "" }} />
        </div>
      </div>
    </>
  );
}
