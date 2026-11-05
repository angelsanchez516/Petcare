import Link from "next/link";
import { Cabecera, Entrada, EstadoDe, Filtros, paginaDe, Paginacion, Seccion, Selector, Tabla, Vacio } from "@/components/ui";
import { exigir } from "@/lib/auth";
import { ESTADOS_VACUNA } from "@/lib/etiquetas";
import { fecha, relativo } from "@/lib/formato";
import { puede, puedeAgendar, puedeFirmar } from "@/lib/permisos";
import { listarAplicaciones, refuerzosPendientes } from "@/lib/repos/vacunas";

export const metadata = { title: "Vacunación" };

export default async function Vacunas({ searchParams }: { searchParams: Promise<Record<string, string>> }) {
  const usuario = await exigir("vacunas");
  const { estado = "", q = "", pag } = await searchParams;
  const pagina = paginaDe(pag);
  const [refuerzos, { filas, total }] = await Promise.all([refuerzosPendientes(estado), listarAplicaciones(q, pagina)]);
  const puedeAplicar = puede(usuario.rol, "vacunas.aplicar") && puedeFirmar(usuario);

  return (
    <>
      <Cabecera titulo="Vacunación" subtitulo="Control de refuerzos y aplicaciones">
        {puedeAplicar && <Link href="/admin/vacunas/aplicar" className="btn btn-md btn-primario">Registrar aplicación</Link>}
      </Cabecera>

      <Filtros>
        <input type="hidden" name="q" value={q} />
        <div className="w-52"><Selector etiqueta="Refuerzos" name="estado" defaultValue={estado} vacio="Por atender"
          opciones={{ VENCIDA: "Vencidos", PROXIMA: "Próximos 30 días", VIGENTE: "Vigentes" }} /></div>
      </Filtros>

      <Seccion titulo={`Refuerzos (${refuerzos.length})`} sinRelleno className="mb-5">
        {refuerzos.length === 0 ? <Vacio titulo="No hay refuerzos en este estado" /> : (
          <Tabla>
            <thead><tr><th>Mascota</th><th>Vacuna</th><th>Vence</th><th>Tutor</th><th>Estado</th><th><span className="sr-only">Acción</span></th></tr></thead>
            <tbody>
              {refuerzos.map((r) => (
                <tr key={r.aplicacion_id}>
                  <td><Link href={`/admin/mascotas/${r.mascota_id}?tab=vacunas`} className="font-medium text-verde-700 hover:underline">{r.mascota}</Link><p className="text-xs text-gris-600">{r.especie}</p></td>
                  <td>{r.vacuna}</td>
                  <td className="whitespace-nowrap">{fecha(r.vence)}<p className="text-xs text-gris-600">{relativo(r.vence)}</p></td>
                  <td className="whitespace-nowrap">{r.tutor}<p className="text-xs"><a href={`tel:${r.telefono}`} className="text-verde-700 hover:underline">{r.telefono}</a></p></td>
                  <td><EstadoDe mapa={ESTADOS_VACUNA} valor={r.estado} /></td>
                  <td className="text-right">
                    {puedeAplicar && <Link href={`/admin/vacunas/aplicar?mascota=${r.mascota_id}&vacuna=${r.vacuna_id}`} className="btn btn-sm btn-secundario">Aplicar</Link>}
                    {!puedeAplicar && puedeAgendar(usuario) && <Link href={`/admin/citas/nueva?mascota=${r.mascota_id}`} className="btn btn-sm btn-secundario">Agendar</Link>}
                  </td>
                </tr>
              ))}
            </tbody>
          </Tabla>
        )}
      </Seccion>

      <Seccion titulo="Aplicaciones registradas" sinRelleno>
        <form method="get" className="no-imprimir flex flex-wrap items-end gap-2 border-b border-gris-200 p-4">
          <input type="hidden" name="estado" value={estado} />
          <div className="min-w-52 flex-1"><Entrada etiqueta="Buscar" name="q" defaultValue={q} placeholder="Mascota o vacuna" /></div>
          <button className="btn btn-md btn-secundario">Buscar</button>
        </form>
        {filas.length === 0 ? <Vacio titulo="No hay aplicaciones que coincidan" /> : (
          <Tabla>
            <thead><tr><th>Fecha</th><th>Mascota</th><th>Vacuna</th><th>Dosis</th><th>Lote</th><th>Próximo refuerzo</th><th>Veterinario</th></tr></thead>
            <tbody>
              {filas.map((a) => (
                <tr key={a.id}>
                  <td className="whitespace-nowrap">{fecha(a.fecha_aplicacion)}</td>
                  <td><Link href={`/admin/mascotas/${a.mascota_id}?tab=vacunas`} className="text-verde-700 hover:underline">{a.mascota}</Link></td>
                  <td>{a.vacuna}</td>
                  <td className="cifra">{a.dosis_numero}</td>
                  <td className="cifra">{a.lote}</td>
                  <td className="whitespace-nowrap">{fecha(a.fecha_proximo_refuerzo)}</td>
                  <td className="whitespace-nowrap">{a.veterinario}</td>
                </tr>
              ))}
            </tbody>
          </Tabla>
        )}
      </Seccion>
      <Paginacion pagina={pagina} total={total} ruta="/admin/vacunas" params={{ estado, q }} />
    </>
  );
}
