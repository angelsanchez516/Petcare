import Link from "next/link";
import { notFound } from "next/navigation";
import { BotonAccion, BotonEnviar, Formulario } from "@/components/Formulario";
import { AreaTexto, Avatar, Cabecera, Casilla, Dato, Entrada, EstadoDe, idDe, Seccion, Selector, Vacio } from "@/components/ui";
import { exigir } from "@/lib/auth";
import { ESTADOS_TRATAMIENTO, SEVERIDADES, TIPOS_CONSULTA, TIPOS_DIAGNOSTICO } from "@/lib/etiquetas";
import { fecha, fechaHora, numero, paraInput } from "@/lib/formato";
import { puedeEditarClinica, puedeFirmar } from "@/lib/permisos";
import {
  alergiasDeMascota, diagnosticosDeConsulta, obtenerConsulta, opcionesDiagnosticos, opcionesMedicamentos, recetaDeConsulta, tratamientosDeConsulta,
} from "@/lib/repos/consultas";
import { eliminarDiagnostico, estadoTratamiento, nuevaReceta, nuevoDiagnostico, nuevoTratamiento, tipoDiagnostico } from "../acciones";
import { CamposReceta } from "../CamposReceta";

export const metadata = { title: "Detalle de la consulta" };

export default async function DetalleConsulta({ params }: { params: Promise<{ id: string }> }) {
  const usuario = await exigir("clinica");
  const id = idDe((await params).id);
  const c = id && await obtenerConsulta(id);
  if (!c || !id) notFound();

  const [alergias, dx, tratamientos, receta, catalogoDx, medicamentos] = await Promise.all([
    alergiasDeMascota(c.mascota_id), diagnosticosDeConsulta(id), tratamientosDeConsulta(id), recetaDeConsulta(id),
    opcionesDiagnosticos(), opcionesMedicamentos(),
  ]);
  const volver = `/admin/consultas/${id}`;
  const editable = puedeEditarClinica(usuario, c.veterinario_id);

  return (
    <>
      <Cabecera titulo={`Consulta de ${c.mascota}`} subtitulo={`${fechaHora(c.fecha_hora)} · ${c.veterinario}`}
        migas={[{ texto: "Consultas", href: "/admin/consultas" }, { texto: c.mascota }]}>
        {editable && <Link href={`${volver}/editar`} className="btn btn-md btn-secundario">Editar</Link>}
        {editable && puedeFirmar(usuario) && <Link href={`/admin/vacunas/aplicar?mascota=${c.mascota_id}&consulta=${id}`} className="btn btn-md btn-secundario">Aplicar vacuna</Link>}
      </Cabecera>

      {!editable && (
        <p className="mb-5 rounded-lg bg-gris-100 px-4 py-2.5 text-sm text-gris-700">
          Consulta firmada por {c.veterinario}. Puedes leerla para dar continuidad a la atención, pero solo esa persona o un administrador pueden modificarla.
        </p>
      )}

      {alergias.length > 0 && (
        <p role="alert" className="mb-5 rounded-lg border border-error-600/20 bg-error-100 px-4 py-2.5 text-sm text-error-600">
          <strong>Alergias:</strong> {alergias.map((a) => `${a.nombre} (${SEVERIDADES[a.severidad]?.texto.toLowerCase()})`).join(", ")}
        </p>
      )}

      <div className="grid items-start gap-5 lg:grid-cols-3">
        <div className="space-y-5 lg:col-span-2">
          <Seccion titulo="Registro de la consulta">
            <dl className="grid gap-4 sm:grid-cols-3">
              <Dato etiqueta="Tipo">{TIPOS_CONSULTA[c.tipo] ?? c.tipo}</Dato>
              <Dato etiqueta="Temperatura">{numero(c.temperatura_c, " °C")}</Dato>
              <Dato etiqueta="Peso">{numero(c.peso_kg, " kg")}</Dato>
              <Dato etiqueta="Frec. cardíaca">{numero(c.frecuencia_cardiaca, " lpm")}</Dato>
              <Dato etiqueta="Frec. respiratoria">{numero(c.frecuencia_respiratoria, " rpm")}</Dato>
              <Dato etiqueta="Próxima revisión">{fecha(c.proxima_revision)}</Dato>
            </dl>
            <dl className="mt-4 space-y-3 border-t border-gris-200 pt-4">
              <Dato etiqueta="Motivo">{c.motivo}</Dato>
              {c.anamnesis && <Dato etiqueta="Anamnesis">{c.anamnesis}</Dato>}
              {c.examen_fisico && <Dato etiqueta="Examen físico">{c.examen_fisico}</Dato>}
              {c.observaciones && <Dato etiqueta="Observaciones">{c.observaciones}</Dato>}
            </dl>
          </Seccion>

          <Seccion titulo="Diagnósticos" sinRelleno>
            {dx.length === 0 ? <Vacio titulo="Aún no hay diagnósticos" /> : (
              <ul className="divide-y divide-gris-200">
                {dx.map((d) => (
                  <li key={d.diagnostico_id} className="flex flex-wrap items-center gap-2 px-5 py-3">
                    <span className="min-w-0 flex-1 basis-56">
                      <span className="text-sm font-medium text-tinta">{d.nombre}</span>
                      <span className="ml-2 text-xs text-gris-600 cifra">{d.codigo}</span>
                      {d.es_principal && <span className="ml-2 text-xs font-medium text-verde-700">Principal</span>}
                      {d.notas && <span className="mt-0.5 block text-sm text-gris-700">{d.notas}</span>}
                    </span>
                    <EstadoDe mapa={TIPOS_DIAGNOSTICO} valor={d.tipo} />
                    {editable && d.tipo === "PRESUNTIVO" && (
                      <BotonAccion accion={tipoDiagnostico} campos={{ consulta_id: id, diagnostico_id: d.diagnostico_id, tipo: "DEFINITIVO" }} texto="Confirmar" />
                    )}
                    {editable && d.tipo === "PRESUNTIVO" && (
                      <BotonAccion accion={tipoDiagnostico} campos={{ consulta_id: id, diagnostico_id: d.diagnostico_id, tipo: "DESCARTADO" }} texto="Descartar" />
                    )}
                    {editable && (
                      <BotonAccion accion={eliminarDiagnostico} campos={{ consulta_id: id, diagnostico_id: d.diagnostico_id }} texto="Quitar" clase="btn-fantasma"
                        confirmar={`¿Quitar «${d.nombre}» de esta consulta?`} />
                    )}
                  </li>
                ))}
              </ul>
            )}
            {editable && <div className="border-t border-gris-200 p-5">
              <Formulario accion={nuevoDiagnostico}>
                <input type="hidden" name="consulta_id" value={id} />
                <div className="grid gap-3 sm:grid-cols-3">
                  <div className="sm:col-span-2"><Selector etiqueta="Agregar diagnóstico" name="diagnostico_id" opciones={catalogoDx} vacio="Selecciona…" required /></div>
                  <Selector etiqueta="Tipo" name="tipo" defaultValue="PRESUNTIVO"
                    opciones={Object.fromEntries(Object.entries(TIPOS_DIAGNOSTICO).map(([k, v]) => [k, v.texto]))} />
                </div>
                <Entrada etiqueta="Notas" name="notas" maxLength={1000} />
                <Casilla etiqueta="Es el diagnóstico principal" name="es_principal" defaultChecked={dx.length === 0} />
                <BotonEnviar clase="btn-secundario">Agregar diagnóstico</BotonEnviar>
              </Formulario>
            </div>}
          </Seccion>

          <Seccion titulo="Tratamientos" sinRelleno>
            {tratamientos.length === 0 ? <Vacio titulo="Aún no hay tratamientos" /> : (
              <ul className="divide-y divide-gris-200">
                {tratamientos.map((t) => (
                  <li key={t.id} className="px-5 py-3">
                    <div className="flex flex-wrap items-center gap-2">
                      <span className="min-w-0 flex-1 basis-56 text-sm font-medium text-tinta">{t.descripcion}</span>
                      <EstadoDe mapa={ESTADOS_TRATAMIENTO} valor={t.estado} />
                      {editable && t.estado === "activo" && <BotonAccion accion={estadoTratamiento} campos={{ id: t.id, estado: "completado", volver }} texto="Completar" />}
                      {editable && t.estado === "activo" && <BotonAccion accion={estadoTratamiento} campos={{ id: t.id, estado: "suspendido", volver }} texto="Suspender" clase="btn-fantasma" />}
                    </div>
                    {t.indicaciones && <p className="mt-1 text-sm text-gris-700">{t.indicaciones}</p>}
                    <p className="mt-1 text-xs text-gris-600">Desde {fecha(t.fecha_inicio)}{t.fecha_fin_estimada && ` hasta ${fecha(t.fecha_fin_estimada)}`}</p>
                  </li>
                ))}
              </ul>
            )}
            {editable && <div className="border-t border-gris-200 p-5">
              <Formulario accion={nuevoTratamiento}>
                <input type="hidden" name="consulta_id" value={id} />
                <Entrada etiqueta="Agregar tratamiento" name="descripcion" maxLength={300} required />
                <AreaTexto etiqueta="Indicaciones" name="indicaciones" rows={2} />
                <div className="grid gap-3 sm:grid-cols-2">
                  <Entrada etiqueta="Inicio" name="fecha_inicio" type="date" required defaultValue={paraInput(new Date())} />
                  <Entrada etiqueta="Fin estimado" name="fecha_fin_estimada" type="date" />
                </div>
                <BotonEnviar clase="btn-secundario">Agregar tratamiento</BotonEnviar>
              </Formulario>
            </div>}
          </Seccion>
        </div>

        <div className="space-y-5">
          <Seccion titulo="Paciente">
            <div className="flex items-center gap-3">
              <Avatar foto={c.foto_url} nombre={c.mascota} icono={c.especie_icono} tam={52} />
              <div className="min-w-0">
                <Link href={`/admin/mascotas/${c.mascota_id}`} className="font-medium text-verde-700 hover:underline">{c.mascota}</Link>
                <p className="text-xs text-gris-600">{c.especie}</p>
              </div>
            </div>
            <dl className="mt-4 space-y-3">
              <Dato etiqueta="Tutor"><Link href={`/admin/clientes/${c.cliente_id}`} className="text-verde-700 hover:underline">{c.tutor}</Link></Dato>
              <Dato etiqueta="Teléfono">{c.tutor_telefono}</Dato>
              {c.cita_id && <Dato etiqueta="Cita"><Link href={`/admin/citas/${c.cita_id}`} className="text-verde-700 hover:underline">Ver la cita</Link></Dato>}
            </dl>
          </Seccion>

          <Seccion titulo="Receta">
            {receta ? (
              <div>
                <p className="text-sm text-gris-700">Folio <span className="font-medium text-tinta cifra">{receta.folio}</span>, emitida el {fecha(receta.fecha_emision)}.</p>
                <Link href={`/admin/recetas/${receta.id}`} className="btn btn-md btn-secundario mt-3">Ver la receta</Link>
              </div>
            ) : !editable ? (
              <p className="text-sm text-gris-600">Esta consulta no tiene receta emitida.</p>
            ) : (
              <Formulario accion={nuevaReceta}>
                <input type="hidden" name="consulta_id" value={id} />
                <CamposReceta medicamentos={medicamentos} />
                <AreaTexto etiqueta="Indicaciones generales" name="indicaciones_generales" rows={2} />
                <Entrada etiqueta="Vigencia (días)" name="vigencia_dias" type="number" min={1} max={365} defaultValue={30} required />
                <BotonEnviar>Emitir receta</BotonEnviar>
              </Formulario>
            )}
          </Seccion>
        </div>
      </div>
    </>
  );
}
