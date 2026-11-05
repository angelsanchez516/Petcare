import Link from "next/link";
import { notFound } from "next/navigation";
import { BotonAccion, BotonEnviar, Formulario } from "@/components/Formulario";
import { AreaTexto, Cabecera, Casilla, Entrada, Filtros, Insignia, Seccion, Selector, Tabla, Vacio } from "@/components/ui";
import { exigir } from "@/lib/auth";
import { CATALOGOS, type Campo } from "@/lib/catalogos";
import type { Fila } from "@/lib/db";
import { dinero, numero } from "@/lib/formato";
import { especiesDeVacuna, listarCatalogo, obtenerRegistro, opcionesFk } from "@/lib/repos/catalogos";
import { especies as listaEspecies } from "@/lib/repos/mascotas";
import { eliminar, guardar } from "../acciones";

export const metadata = { title: "Catálogo" };

function Celda({ campo, fila }: { campo: Campo; fila: Fila }) {
  const v = fila[campo.col];
  if (campo.tipo === "casilla") return v ? <Insignia tono="verde">Sí</Insignia> : <Insignia>No</Insignia>;
  if (campo.tipo === "dinero") return <span className="cifra">{dinero(v)}</span>;
  if (campo.tipo === "entero") return <span className="cifra">{numero(v)}</span>;
  if (campo.tipo === "fk") return <>{fila[`${campo.col}_texto`]}</>;
  if (campo.tipo === "opcion") return <>{campo.opciones?.[v] ?? "—"}</>;
  return <>{v ?? "—"}</>;
}

async function CampoForm({ campo, r }: { campo: Campo; r: Fila | null }) {
  const comun = { etiqueta: campo.etiqueta, name: campo.col, required: campo.requerido };
  switch (campo.tipo) {
    case "casilla":
      // Un registro nuevo nace activo; las demás casillas nacen sin marcar.
      return <Casilla etiqueta={campo.etiqueta} name={campo.col} defaultChecked={r ? r[campo.col] : campo.col === "activo" || campo.col === "visible_publico"} />;
    case "opcion":
      return <Selector {...comun} opciones={campo.opciones ?? {}} vacio={campo.requerido ? "Selecciona…" : "Sin definir"} defaultValue={r?.[campo.col] ?? ""} />;
    case "fk":
      return <Selector {...comun} opciones={await opcionesFk(campo.fk!)} vacio="Selecciona…" defaultValue={r?.[campo.col] ?? ""} />;
    case "area":
      return <AreaTexto {...comun} defaultValue={r?.[campo.col] ?? ""} />;
    case "entero":
      return <Entrada {...comun} type="number" min={0} defaultValue={r?.[campo.col] ?? ""} />;
    case "dinero":
      return <Entrada {...comun} inputMode="decimal" defaultValue={r?.[campo.col] ?? ""} />;
    default:
      return <Entrada {...comun} maxLength={campo.max} defaultValue={r?.[campo.col] ?? ""} />;
  }
}

export default async function Catalogo({ params, searchParams }: {
  params: Promise<{ c: string }>;
  searchParams: Promise<Record<string, string>>;
}) {
  await exigir("catalogos");
  const clave = (await params).c;
  const c = Object.hasOwn(CATALOGOS, clave) ? CATALOGOS[clave] : null;
  if (!c) notFound();

  const { q = "", editar } = await searchParams;
  const idEditar = /^\d+$/.test(editar ?? "") ? Number(editar) : null;
  const [filas, r] = await Promise.all([listarCatalogo(c, q), idEditar ? obtenerRegistro(c, idEditar) : null]);
  const especies = c.conEspecies ? await listaEspecies() : [];
  const marcadas = c.conEspecies && r ? (await especiesDeVacuna(r.id)).map((e) => e.especie_id) : [];
  const columnas = c.campos.filter((x) => x.enLista);

  return (
    <>
      <Cabecera titulo={c.titulo} subtitulo={c.descripcion} migas={[{ texto: "Catálogos", href: "/admin/catalogos" }, { texto: c.titulo }]} />

      <div className="grid items-start gap-5 xl:grid-cols-3">
        <div className="min-w-0 xl:col-span-2">
          <Filtros>
            <div className="min-w-52 flex-1"><Entrada etiqueta="Buscar por nombre" name="q" defaultValue={q} /></div>
          </Filtros>
          <Seccion sinRelleno>
            {filas.length === 0 ? <Vacio titulo="No hay registros" /> : (
              <Tabla>
                <thead>
                  <tr>
                    {columnas.map((x) => <th key={x.col}>{x.etiqueta}</th>)}
                    {c.conEspecies && <th>Especies</th>}
                    <th><span className="sr-only">Acciones</span></th>
                  </tr>
                </thead>
                <tbody>
                  {filas.map((f) => (
                    <tr key={f.id}>
                      {columnas.map((x) => (
                        <td key={x.col}>
                          <Celda campo={x} fila={f} />
                          {clave === "medicamentos" && x.col === "stock" && f.stock <= f.stock_minimo && (
                            <span className="ml-1.5"><Insignia tono={f.stock === 0 ? "roja" : "ambar"}>{f.stock === 0 ? "Agotado" : "Bajo"}</Insignia></span>
                          )}
                        </td>
                      ))}
                      {c.conEspecies && <td>{f.especies ?? "Todas"}</td>}
                      <td className="whitespace-nowrap text-right">
                        <span className="inline-flex flex-wrap justify-end gap-1">
                          <Link href={`/admin/catalogos/${clave}?editar=${f.id}`} className="btn btn-sm btn-secundario">Editar</Link>
                          <BotonAccion accion={eliminar} campos={{ catalogo: clave, id: f.id }} texto="Eliminar" clase="btn-fantasma"
                            confirmar={`¿Eliminar «${f.nombre}»? Si está en uso, el sistema no lo permitirá.`} />
                        </span>
                      </td>
                    </tr>
                  ))}
                </tbody>
              </Tabla>
            )}
          </Seccion>
        </div>

        <Seccion titulo={r ? `Editar ${c.singular}` : `Nuevo registro: ${c.singular}`}
          accion={r ? <Link href={`/admin/catalogos/${clave}`} className="btn btn-sm btn-fantasma">Cancelar</Link> : undefined}>
          <Formulario key={r?.id ?? "nuevo"} accion={guardar}>
            <input type="hidden" name="catalogo" value={clave} />
            {r && <input type="hidden" name="id" value={r.id} />}
            {c.campos.map((x) => <CampoForm key={x.col} campo={x} r={r} />)}
            {c.conEspecies && (
              <fieldset>
                <legend className="etiqueta">Indicada para</legend>
                <div className="grid grid-cols-2 gap-2">
                  {especies.map((e) => (
                    <Casilla key={e.valor} etiqueta={e.texto} name="especies" value={e.valor} defaultChecked={marcadas.includes(e.valor)} />
                  ))}
                </div>
                <p className="ayuda">Si no marcas ninguna, se considera apta para todas.</p>
              </fieldset>
            )}
            <BotonEnviar>{r ? "Guardar cambios" : "Crear"}</BotonEnviar>
          </Formulario>
        </Seccion>
      </div>
    </>
  );
}
