import Link from "next/link";
import { Cabecera, Entrada, Filtros, Insignia, paginaDe, Paginacion, Seccion, Selector, Tabla, Vacio } from "@/components/ui";
import { exigir } from "@/lib/auth";
import { dinero } from "@/lib/formato";
import { puede } from "@/lib/permisos";
import { listarClientes } from "@/lib/repos/clientes";

export const metadata = { title: "Tutores" };

export default async function Clientes({ searchParams }: { searchParams: Promise<Record<string, string>> }) {
  const usuario = await exigir("clientes");
  const { q = "", estado = "activos", pag } = await searchParams;
  const pagina = paginaDe(pag);
  const verSaldo = puede(usuario.rol, "facturas");
  const { filas, total } = await listarClientes(q, estado === "todos" ? "" : estado, pagina, verSaldo);

  return (
    <>
      <Cabecera titulo="Tutores" subtitulo="Propietarios responsables de cada mascota">
        {puede(usuario.rol, "clientes.editar") && <Link href="/admin/clientes/nuevo" className="btn btn-md btn-primario">Nuevo tutor</Link>}
      </Cabecera>

      <Filtros>
        <div className="min-w-56 flex-1"><Entrada etiqueta="Buscar" name="q" defaultValue={q} placeholder="Nombre, documento o teléfono" /></div>
        <div className="w-40"><Selector etiqueta="Estado" name="estado" defaultValue={estado} opciones={{ activos: "Activos", inactivos: "De baja", todos: "Todos" }} /></div>
      </Filtros>

      <Seccion sinRelleno>
        {filas.length === 0 ? (
          <Vacio titulo="No hay tutores que coincidan" texto="Prueba con otra búsqueda o registra uno nuevo." />
        ) : (
          <Tabla>
            <thead><tr><th>Tutor</th><th>Documento</th><th>Teléfono</th><th>Mascotas</th>{verSaldo && <th>Saldo</th>}<th>Estado</th></tr></thead>
            <tbody>
              {filas.map((c) => (
                <tr key={c.id}>
                  <td>
                    <Link href={`/admin/clientes/${c.id}`} className="font-medium text-verde-700 hover:underline">{c.apellidos}, {c.nombres}</Link>
                    {c.email && <p className="text-xs text-gris-600">{c.email}</p>}
                  </td>
                  <td className="cifra">{c.tipo_documento} {c.documento}</td>
                  <td className="cifra whitespace-nowrap">{c.telefono}</td>
                  <td className="cifra">{c.mascotas}</td>
                  {verSaldo && <td className="cifra">{Number(c.saldo) > 0 ? <span className="text-alerta-600">{dinero(c.saldo)}</span> : "—"}</td>}
                  <td>{c.activo ? <Insignia tono="verde">Activo</Insignia> : <Insignia>De baja</Insignia>}</td>
                </tr>
              ))}
            </tbody>
          </Tabla>
        )}
      </Seccion>
      <Paginacion pagina={pagina} total={total} ruta="/admin/clientes" params={{ q, estado }} />
    </>
  );
}
