import Link from "next/link";
import { notFound } from "next/navigation";
import { BotonAccion, BotonEnviar, BotonImprimir, Formulario } from "@/components/Formulario";
import { Logo } from "@/components/Logo";
import { Cabecera, Dato, idDe, Seccion } from "@/components/ui";
import { exigir } from "@/lib/auth";
import { CONTACTO } from "@/lib/clinica";
import { VIAS } from "@/lib/etiquetas";
import { fecha, numero } from "@/lib/formato";
import { puedeEditarClinica } from "@/lib/permisos";
import { lineasDeReceta, obtenerReceta, opcionesMedicamentos } from "@/lib/repos/consultas";
import { eliminarLineaReceta, nuevaLineaReceta } from "../../consultas/acciones";
import { CamposReceta } from "../../consultas/CamposReceta";

export const metadata = { title: "Receta" };

export default async function DetalleReceta({ params }: { params: Promise<{ id: string }> }) {
  const usuario = await exigir("clinica");
  const id = idDe((await params).id);
  const r = id && await obtenerReceta(id);
  if (!r || !id) notFound();
  const [lineas, medicamentos] = await Promise.all([lineasDeReceta(id), opcionesMedicamentos()]);
  const editable = puedeEditarClinica(usuario, r.veterinario_id);

  return (
    <>
      <div className="no-imprimir">
        <Cabecera titulo={`Receta ${r.folio}`} migas={[{ texto: "Recetas", href: "/admin/recetas" }, { texto: r.folio }]}>
          <Link href={`/admin/consultas/${r.consulta_id}`} className="btn btn-md btn-secundario">Ver la consulta</Link>
          <BotonImprimir />
        </Cabecera>
      </div>

      <article className="tarjeta mx-auto max-w-3xl p-8">
        <header className="flex flex-wrap items-start justify-between gap-4 border-b border-gris-200 pb-5">
          <div className="flex items-center gap-3">
            <Logo className="h-10 w-10 text-verde-700" />
            <div>
              <p className="font-display text-2xl leading-none text-verde-900">PetCare</p>
              <p className="mt-1 text-xs text-gris-600">{CONTACTO.direccion}, {CONTACTO.ciudad} · {CONTACTO.telefono}</p>
            </div>
          </div>
          <div className="text-right">
            <p className="text-xs uppercase tracking-wider text-gris-600">Receta médica</p>
            <p className="font-semibold text-tinta cifra">{r.folio}</p>
          </div>
        </header>

        <dl className="grid gap-4 border-b border-gris-200 py-5 sm:grid-cols-3">
          <Dato etiqueta="Paciente">{r.mascota} ({r.especie}{r.raza && `, ${r.raza}`})</Dato>
          <Dato etiqueta="Tutor">{r.tutor}<br /><span className="text-xs text-gris-600">Doc. {r.tutor_documento}</span></Dato>
          <Dato etiqueta="Emitida / válida hasta">{fecha(r.fecha_emision)} / {fecha(r.vence)}</Dato>
        </dl>

        <h2 className="mt-5 font-semibold text-tinta">Medicamentos</h2>
        <ol className="mt-3 divide-y divide-gris-200">
          {lineas.map((l, i) => (
            <li key={l.medicamento_id} className="flex items-start gap-3 py-3">
              <span className="text-sm text-gris-600 cifra">{i + 1}.</span>
              <div className="min-w-0 flex-1">
                <p className="font-medium text-tinta">{l.nombre_completo}</p>
                <p className="mt-0.5 text-sm text-gris-700">
                  {l.dosis}, {l.frecuencia.toLowerCase()}, durante {l.duracion_dias} {l.duracion_dias === 1 ? "día" : "días"}. Vía {(VIAS[l.via_administracion] ?? l.via_administracion).toLowerCase()}.
                </p>
                <p className="text-sm text-gris-600">Cantidad: {numero(l.cantidad)}{l.instrucciones && ` · ${l.instrucciones}`}</p>
              </div>
              <div className="no-imprimir">
                {editable && lineas.length > 1 && (
                  <BotonAccion accion={eliminarLineaReceta} campos={{ receta_id: id, medicamento_id: l.medicamento_id }} texto="Quitar" clase="btn-fantasma"
                    confirmar={`¿Quitar ${l.nombre_completo} de la receta?`} />
                )}
              </div>
            </li>
          ))}
        </ol>

        {r.indicaciones_generales && (
          <div className="mt-4 border-t border-gris-200 pt-4">
            <h2 className="font-semibold text-tinta">Indicaciones generales</h2>
            <p className="mt-1 text-sm leading-relaxed text-gris-700">{r.indicaciones_generales}</p>
          </div>
        )}

        <footer className="mt-14 text-center">
          <div className="mx-auto w-64 border-t border-tinta pt-2 text-sm">
            <p className="font-medium text-tinta">{r.veterinario}</p>
            <p className="text-xs text-gris-600">Matrícula {r.matricula}</p>
          </div>
        </footer>
      </article>

      {editable && <div className="no-imprimir mx-auto mt-5 max-w-3xl">
        <Seccion titulo="Agregar medicamento">
          <Formulario accion={nuevaLineaReceta}>
            <input type="hidden" name="receta_id" value={id} />
            <CamposReceta medicamentos={medicamentos} />
            <BotonEnviar clase="btn-secundario">Agregar a la receta</BotonEnviar>
          </Formulario>
        </Seccion>
      </div>}
    </>
  );
}
