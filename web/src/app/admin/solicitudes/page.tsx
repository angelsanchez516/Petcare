import Link from "next/link";
import { BotonAccion } from "@/components/Formulario";
import { Cabecera, EstadoDe, Filtros, Seccion, Selector, Vacio } from "@/components/ui";
import { exigir } from "@/lib/auth";
import { ESTADOS_SOLICITUD, FRANJAS } from "@/lib/etiquetas";
import { fecha, relativo } from "@/lib/formato";
import { listarSolicitudes } from "@/lib/repos/citas";
import { descartar, marcarContactada } from "./acciones";

export const metadata = { title: "Solicitudes web" };

export default async function Solicitudes({ searchParams }: { searchParams: Promise<Record<string, string>> }) {
  await exigir("solicitudes");
  const { estado = "" } = await searchParams;
  const filas = await listarSolicitudes(estado);

  return (
    <>
      <Cabecera titulo="Solicitudes web" subtitulo="Pedidos de cita enviados desde el sitio público" />
      <Filtros>
        <div className="w-52"><Selector etiqueta="Estado" name="estado" defaultValue={estado} vacio="Todos"
          opciones={Object.fromEntries(Object.entries(ESTADOS_SOLICITUD).map(([k, v]) => [k, v.texto]))} /></div>
      </Filtros>

      <Seccion sinRelleno>
        {filas.length === 0 ? <Vacio titulo={estado ? "No hay solicitudes en este estado" : "Aún no hay solicitudes"} /> : (
          <ul className="divide-y divide-gris-200">
            {filas.map((s) => {
              const abierta = s.estado === "nueva" || s.estado === "contactada";
              return (
                <li key={s.id} className="px-5 py-4">
                  <div className="flex flex-wrap items-center gap-2">
                    <span className="font-medium text-tinta">{s.nombre_contacto}</span>
                    <EstadoDe mapa={ESTADOS_SOLICITUD} valor={s.estado} />
                    <span className="ml-auto text-xs text-gris-600">{relativo(s.creado_en)}</span>
                  </div>
                  <p className="mt-1 text-sm text-gris-700">{s.motivo}</p>
                  <p className="mt-1 text-xs text-gris-600">
                    <a href={`tel:${s.telefono_contacto}`} className="text-verde-700 hover:underline">{s.telefono_contacto}</a>
                    {s.email_contacto && ` · ${s.email_contacto}`}
                    {s.nombre_mascota && ` · Mascota: ${s.nombre_mascota}`}
                    {s.especie && ` (${s.especie})`}
                    {s.fecha_preferida && ` · Prefiere ${fecha(s.fecha_preferida)}`}
                    {s.franja_preferida && `, ${FRANJAS[s.franja_preferida]?.toLowerCase()}`}
                  </p>
                  <div className="mt-3 flex flex-wrap gap-2">
                    {abierta && <Link href={`/admin/solicitudes/${s.id}`} className="btn btn-sm btn-primario">Convertir en cita</Link>}
                    {s.estado === "nueva" && <BotonAccion accion={marcarContactada} campos={{ id: s.id }} texto="Marcar contactada" />}
                    {abierta && (
                      <BotonAccion accion={descartar} campos={{ id: s.id }} texto="Descartar" clase="btn-fantasma"
                        confirmar={`La solicitud de ${s.nombre_contacto} se cerrará sin crear una cita.`} />
                    )}
                    {s.cita_id && <Link href={`/admin/citas/${s.cita_id}`} className="btn btn-sm btn-secundario">Ver la cita</Link>}
                  </div>
                </li>
              );
            })}
          </ul>
        )}
      </Seccion>
    </>
  );
}
