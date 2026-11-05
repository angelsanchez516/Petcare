import Link from "next/link";
import { BotonAccion } from "@/components/Formulario";
import { Cabecera, Entrada, EstadoDe, Filtros, paginaDe, Paginacion, Seccion, Selector, Tabla, Vacio } from "@/components/ui";
import { exigir } from "@/lib/auth";
import { ESTADOS_TRATAMIENTO } from "@/lib/etiquetas";
import { fecha } from "@/lib/formato";
import { puedeEditarClinica } from "@/lib/permisos";
import { listarTratamientos } from "@/lib/repos/consultas";
import { estadoTratamiento } from "../consultas/acciones";

export const metadata = { title: "Tratamientos" };

export default async function Tratamientos({ searchParams }: { searchParams: Promise<Record<string, string>> }) {
  const usuario = await exigir("clinica");
  const { q = "", estado = "", pag } = await searchParams;
  const pagina = paginaDe(pag);
  const { filas, total } = await listarTratamientos(estado, q, pagina);

  return (
    <>
      <Cabecera titulo="Tratamientos" subtitulo="Se crean desde el detalle de cada consulta" />
      <Filtros>
        <div className="min-w-52 flex-1"><Entrada etiqueta="Buscar" name="q" defaultValue={q} placeholder="Mascota o tratamiento" /></div>
        <div className="w-40"><Selector etiqueta="Estado" name="estado" defaultValue={estado} vacio="Todos"
          opciones={Object.fromEntries(Object.entries(ESTADOS_TRATAMIENTO).map(([k, v]) => [k, v.texto]))} /></div>
      </Filtros>
      <Seccion sinRelleno>
        {filas.length === 0 ? <Vacio titulo="No hay tratamientos que coincidan" /> : (
          <Tabla>
            <thead><tr><th>Tratamiento</th><th>Mascota</th><th>Inicio</th><th>Fin estimado</th><th>Estado</th><th><span className="sr-only">Acciones</span></th></tr></thead>
            <tbody>
              {filas.map((t) => (
                <tr key={t.id}>
                  <td><Link href={`/admin/consultas/${t.consulta_id}`} className="font-medium text-verde-700 hover:underline">{t.descripcion}</Link></td>
                  <td><Link href={`/admin/mascotas/${t.mascota_id}`} className="hover:underline">{t.mascota}</Link></td>
                  <td className="whitespace-nowrap">{fecha(t.fecha_inicio)}</td>
                  <td className="whitespace-nowrap">{fecha(t.fecha_fin_estimada)}</td>
                  <td><EstadoDe mapa={ESTADOS_TRATAMIENTO} valor={t.estado} /></td>
                  <td className="whitespace-nowrap text-right">
                    {t.estado === "activo" && puedeEditarClinica(usuario, t.veterinario_id) && (
                      <span className="inline-flex gap-1">
                        <BotonAccion accion={estadoTratamiento} campos={{ id: t.id, estado: "completado", volver: "/admin/tratamientos" }} texto="Completar" />
                        <BotonAccion accion={estadoTratamiento} campos={{ id: t.id, estado: "suspendido", volver: "/admin/tratamientos" }} texto="Suspender" clase="btn-fantasma" />
                      </span>
                    )}
                  </td>
                </tr>
              ))}
            </tbody>
          </Tabla>
        )}
      </Seccion>
      <Paginacion pagina={pagina} total={total} ruta="/admin/tratamientos" params={{ q, estado }} />
    </>
  );
}
