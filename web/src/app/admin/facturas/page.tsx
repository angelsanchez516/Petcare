import Link from "next/link";
import { Cabecera, Entrada, EstadoDe, Filtros, paginaDe, Paginacion, Seccion, Selector, Tabla, Vacio } from "@/components/ui";
import { exigir } from "@/lib/auth";
import { ESTADOS_FACTURA } from "@/lib/etiquetas";
import { dinero, fecha } from "@/lib/formato";
import { listarFacturas } from "@/lib/repos/facturas";

export const metadata = { title: "Facturación" };

export default async function Facturas({ searchParams }: { searchParams: Promise<Record<string, string>> }) {
  await exigir("facturas");
  const { q = "", estado = "", pag } = await searchParams;
  const pagina = paginaDe(pag);
  const { filas, total } = await listarFacturas(q, estado, pagina);

  return (
    <>
      <Cabecera titulo="Facturación" subtitulo="Facturas, pagos y saldos">
        <Link href="/admin/facturas/nueva" className="btn btn-md btn-primario">Nueva factura</Link>
      </Cabecera>
      <Filtros>
        <div className="min-w-52 flex-1"><Entrada etiqueta="Buscar" name="q" defaultValue={q} placeholder="Número, tutor o documento" /></div>
        <div className="w-44"><Selector etiqueta="Estado" name="estado" defaultValue={estado} vacio="Todos"
          opciones={{ abiertas: "Con saldo por cobrar", ...Object.fromEntries(Object.entries(ESTADOS_FACTURA).map(([k, v]) => [k, v.texto])) }} /></div>
      </Filtros>
      <Seccion sinRelleno>
        {filas.length === 0 ? <Vacio titulo="No hay facturas que coincidan" /> : (
          <Tabla>
            <thead><tr><th>Número</th><th>Fecha</th><th>Tutor</th><th>Total</th><th>Pagado</th><th>Saldo</th><th>Estado</th></tr></thead>
            <tbody>
              {filas.map((f) => (
                <tr key={f.id}>
                  <td><Link href={`/admin/facturas/${f.id}`} className="whitespace-nowrap font-medium text-verde-700 hover:underline cifra">{f.numero}</Link></td>
                  <td className="whitespace-nowrap">{fecha(f.fecha_emision)}</td>
                  <td><Link href={`/admin/clientes/${f.cliente_id}`} className="hover:underline">{f.cliente}</Link></td>
                  <td className="cifra">{dinero(f.total)}</td>
                  <td className="cifra">{dinero(f.pagado)}</td>
                  <td className="cifra">{f.estado === "anulada" ? "—" : dinero(f.saldo)}</td>
                  <td><EstadoDe mapa={ESTADOS_FACTURA} valor={f.estado} /></td>
                </tr>
              ))}
            </tbody>
          </Tabla>
        )}
      </Seccion>
      <Paginacion pagina={pagina} total={total} ruta="/admin/facturas" params={{ q, estado }} />
    </>
  );
}
