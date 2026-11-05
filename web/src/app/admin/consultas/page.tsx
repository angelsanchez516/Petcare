import Link from "next/link";
import { Cabecera, Entrada, Filtros, paginaDe, Paginacion, Seccion, Selector, Tabla, Vacio } from "@/components/ui";
import { exigir } from "@/lib/auth";
import { TIPOS_CONSULTA } from "@/lib/etiquetas";
import { fechaHora } from "@/lib/formato";
import { puedeFirmar } from "@/lib/permisos";
import { opcionesVeterinarios } from "@/lib/repos/citas";
import { listarConsultas } from "@/lib/repos/consultas";

export const metadata = { title: "Consultas" };

export default async function Consultas({ searchParams }: { searchParams: Promise<Record<string, string>> }) {
  const usuario = await exigir("clinica");
  const { q = "", tipo = "", vet = "", pag } = await searchParams;
  const pagina = paginaDe(pag);
  const [{ filas, total }, veterinarios] = await Promise.all([listarConsultas(q, tipo, vet, pagina), opcionesVeterinarios()]);

  return (
    <>
      <Cabecera titulo="Consultas" subtitulo="Registro clínico de todas las atenciones">
        {puedeFirmar(usuario) && <Link href="/admin/consultas/nueva" className="btn btn-md btn-primario">Nueva consulta</Link>}
      </Cabecera>

      <Filtros>
        <div className="min-w-52 flex-1"><Entrada etiqueta="Buscar" name="q" defaultValue={q} placeholder="Mascota o motivo" /></div>
        <div className="w-40"><Selector etiqueta="Tipo" name="tipo" defaultValue={tipo} opciones={TIPOS_CONSULTA} vacio="Todos" /></div>
        <div className="w-56"><Selector etiqueta="Veterinario" name="vet" defaultValue={vet} opciones={veterinarios} vacio="Todos" /></div>
      </Filtros>

      <Seccion sinRelleno>
        {filas.length === 0 ? <Vacio titulo="No hay consultas que coincidan" /> : (
          <Tabla>
            <thead><tr><th>Fecha</th><th>Mascota</th><th>Motivo</th><th>Diagnóstico</th><th>Tipo</th><th>Veterinario</th></tr></thead>
            <tbody>
              {filas.map((c) => (
                <tr key={c.id}>
                  <td className="whitespace-nowrap"><Link href={`/admin/consultas/${c.id}`} className="font-medium text-verde-700 hover:underline">{fechaHora(c.fecha_hora)}</Link></td>
                  <td><Link href={`/admin/mascotas/${c.mascota_id}`} className="hover:underline">{c.mascota}</Link><p className="text-xs text-gris-600">{c.tutor}</p></td>
                  <td>{c.motivo}</td>
                  <td>{c.diagnostico ?? <span className="text-gris-400">Sin registrar</span>}</td>
                  <td>{TIPOS_CONSULTA[c.tipo] ?? c.tipo}</td>
                  <td className="whitespace-nowrap">{c.veterinario}</td>
                </tr>
              ))}
            </tbody>
          </Tabla>
        )}
      </Seccion>
      <Paginacion pagina={pagina} total={total} ruta="/admin/consultas" params={{ q, tipo, vet }} />
    </>
  );
}
