import Link from "next/link";
import { Cabecera, Entrada, Filtros, paginaDe, Paginacion, Seccion, Tabla, Vacio } from "@/components/ui";
import { exigir } from "@/lib/auth";
import { fecha } from "@/lib/formato";
import { listarRecetas } from "@/lib/repos/consultas";

export const metadata = { title: "Recetas" };

export default async function Recetas({ searchParams }: { searchParams: Promise<Record<string, string>> }) {
  await exigir("clinica");
  const { q = "", pag } = await searchParams;
  const pagina = paginaDe(pag);
  const { filas, total } = await listarRecetas(q, pagina);

  return (
    <>
      <Cabecera titulo="Recetas" subtitulo="Se emiten desde el detalle de cada consulta" />
      <Filtros>
        <div className="min-w-52 flex-1"><Entrada etiqueta="Buscar" name="q" defaultValue={q} placeholder="Mascota o folio" /></div>
      </Filtros>
      <Seccion sinRelleno>
        {filas.length === 0 ? <Vacio titulo="No hay recetas que coincidan" /> : (
          <Tabla>
            <thead><tr><th>Folio</th><th>Fecha</th><th>Mascota</th><th>Medicamentos</th><th>Veterinario</th></tr></thead>
            <tbody>
              {filas.map((r) => (
                <tr key={r.id}>
                  <td><Link href={`/admin/recetas/${r.id}`} className="whitespace-nowrap font-medium text-verde-700 hover:underline cifra">{r.folio}</Link></td>
                  <td className="whitespace-nowrap">{fecha(r.fecha_emision)}</td>
                  <td><Link href={`/admin/mascotas/${r.mascota_id}`} className="hover:underline">{r.mascota}</Link></td>
                  <td>{r.medicamentos ?? "—"}</td>
                  <td className="whitespace-nowrap">{r.veterinario}</td>
                </tr>
              ))}
            </tbody>
          </Tabla>
        )}
      </Seccion>
      <Paginacion pagina={pagina} total={total} ruta="/admin/recetas" params={{ q }} />
    </>
  );
}
