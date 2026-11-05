import Link from "next/link";
import { notFound } from "next/navigation";
import { BotonAccion, BotonEnviar, Formulario } from "@/components/Formulario";
import { Avatar, Cabecera, Dato, Entrada, EstadoDe, idDe, Insignia, Seccion, Selector, Tabla, Vacio } from "@/components/ui";
import { exigir } from "@/lib/auth";
import {
  ESTADOS_CITA, ESTADOS_FACTURA, ESTADOS_TRATAMIENTO, ESTADOS_VACUNA, SEVERIDADES, TIPOS_CONSULTA, TIPOS_DIAGNOSTICO, TIPOS_HISTORIAL,
} from "@/lib/etiquetas";
import { dinero, edad, fecha, fechaHora, numero, paraInput } from "@/lib/formato";
import { puede, puedeAgendar, puedeFirmar } from "@/lib/permisos";
import {
  citasAbiertasDeMascota, citasDeMascota, condicionesDeMascota, consultasDeMascota, diagnosticosDeMascota, facturasDeMascota, historialDeMascota,
  obtenerPerfil, opcionesCondiciones, pesosDeMascota, recetasDeMascota, tratamientosDeMascota, vacunasDeMascota,
} from "@/lib/repos/mascotas";
import { vacunasAptas } from "@/lib/repos/vacunas";
import { cambiarActivo, eliminarCondicion, nuevaCondicion, nuevoPeso } from "../acciones";
import { GraficaPeso } from "./GraficaPeso";

export const metadata = { title: "Ficha de la mascota" };

const PESTANAS = [
  { id: "resumen", texto: "Resumen" },
  { id: "historial", texto: "Historial", clinica: true },
  { id: "consultas", texto: "Consultas", clinica: true },
  { id: "vacunas", texto: "Vacunas" },
  { id: "tratamientos", texto: "Tratamientos", clinica: true },
  { id: "recetas", texto: "Recetas", clinica: true },
  { id: "peso", texto: "Peso" },
  { id: "citas", texto: "Citas" },
  { id: "facturas", texto: "Facturas", facturas: true },
];

export default async function FichaMascota({ params, searchParams }: {
  params: Promise<{ id: string }>;
  searchParams: Promise<Record<string, string>>;
}) {
  const usuario = await exigir("mascotas");
  const id = idDe((await params).id);
  const m = id && await obtenerPerfil(id);
  if (!m || !id) notFound();

  const verClinica = puede(usuario.rol, "clinica");
  const verFacturas = puede(usuario.rol, "facturas");
  const pestanas = PESTANAS.filter((p) => (!p.clinica || verClinica) && (!p.facturas || verFacturas));
  const pedida = (await searchParams).tab;
  const tab = pestanas.some((p) => p.id === pedida) ? pedida : "resumen";
  const [condiciones, citasAbiertas] = await Promise.all([condicionesDeMascota(id), citasAbiertasDeMascota(id)]);
  const alergias = condiciones.filter((c) => c.tipo === "ALERGIA");
  const atendible = m.activo && !m.fecha_fallecimiento;
  const avisoCitas = citasAbiertas === 1 ? "Tiene 1 cita abierta" : `Tiene ${citasAbiertas} citas abiertas`;

  return (
    <>
      <Cabecera titulo="Ficha de la mascota" migas={[{ texto: "Mascotas", href: "/admin/mascotas" }, { texto: m.nombre }]}>
        <Link href={`/admin/mascotas/${id}/editar`} className="btn btn-md btn-secundario">Editar</Link>
        {puede(usuario.rol, "mascotas.administrar") && (m.activo
          ? <BotonAccion accion={cambiarActivo} campos={{ id, activo: "0" }} texto="Dar de baja" tam="btn-md"
              confirmar={`La mascota deja de aparecer en las listas. Su historial clínico no se borra.${citasAbiertas > 0 ? ` ${avisoCitas}, que no se cancelan solas.` : ""}`} />
          : <BotonAccion accion={cambiarActivo} campos={{ id, activo: "1" }} texto="Reactivar" tam="btn-md" />)}
        {atendible && puedeAgendar(usuario) && <Link href={`/admin/citas/nueva?mascota=${id}`} className="btn btn-md btn-secundario">Agendar cita</Link>}
        {atendible && puedeFirmar(usuario) && <Link href={`/admin/consultas/nueva?mascota=${id}`} className="btn btn-md btn-primario">Nueva consulta</Link>}
      </Cabecera>

      {!atendible && (
        <p className="mb-5 rounded-lg bg-gris-100 px-4 py-2.5 text-sm text-gris-700">
          {m.fecha_fallecimiento ? "Esta mascota falleció" : "Esta mascota está dada de baja"}. Su historial se conserva, pero no recibe citas ni atenciones nuevas.
          {citasAbiertas > 0 && <> {avisoCitas}: <Link href={`/admin/mascotas/${id}?tab=citas`} scroll={false} className="text-verde-700 hover:underline">revísalas</Link>.</>}
        </p>
      )}

      {/* Identidad del paciente */}
      <section className="tarjeta mb-5 flex flex-wrap items-center gap-5 p-5">
        <Avatar foto={m.foto_url} nombre={m.nombre} icono={m.especie_icono} tam={84} />
        <div className="min-w-48 flex-1">
          <h2 className="font-display text-3xl leading-none text-verde-900">{m.nombre}</h2>
          <p className="mt-2 text-sm text-gris-700">
            {m.especie} · {m.raza ?? "Sin raza definida"} · {m.sexo_texto} · {edad(m.edad_anios, m.edad_meses)}
          </p>
          <p className="mt-1 text-sm text-gris-600">
            Tutor: <Link href={`/admin/clientes/${m.cliente_id}`} className="text-verde-700 hover:underline">{m.tutor}</Link> · {m.tutor_telefono}
          </p>
        </div>
        <dl className="flex gap-6">
          <div><dt className="text-xs text-gris-600">Peso actual</dt><dd className="mt-1 text-xl font-semibold cifra text-tinta">{numero(m.peso_actual_kg, " kg")}</dd></div>
          <div><dt className="text-xs text-gris-600">Vacunación</dt><dd className="mt-1.5"><EstadoDe mapa={ESTADOS_VACUNA} valor={m.vacuna_estado} /></dd></div>
          {m.fecha_fallecimiento && <div><dt className="text-xs text-gris-600">Falleció</dt><dd className="mt-1 text-sm">{fecha(m.fecha_fallecimiento)}</dd></div>}
        </dl>
      </section>

      {alergias.length > 0 && (
        <p role="alert" className="mb-5 rounded-lg border border-error-600/20 bg-error-100 px-4 py-2.5 text-sm text-error-600">
          <strong>Alergias:</strong> {alergias.map((a) => `${a.nombre} (${SEVERIDADES[a.severidad]?.texto.toLowerCase()})`).join(", ")}
        </p>
      )}

      <nav aria-label="Secciones de la ficha" className="scroll-x mb-5 border-b border-gris-200">
        <ul className="flex gap-1">
          {pestanas.map((p) => (
            <li key={p.id}>
              <Link href={`/admin/mascotas/${id}?tab=${p.id}`} aria-current={tab === p.id ? "page" : undefined} scroll={false}
                className={`block whitespace-nowrap border-b-2 px-3 py-2 text-sm ${tab === p.id ? "border-verde-700 font-medium text-verde-800" : "border-transparent text-gris-600 hover:text-tinta"}`}>
                {p.texto}
              </Link>
            </li>
          ))}
        </ul>
      </nav>

      {tab === "resumen" && <Resumen m={m} condiciones={condiciones} puedeClinica={verClinica} puedeAgregar={verClinica && atendible} />}
      {tab === "historial" && <Historial id={id} />}
      {tab === "consultas" && <Consultas id={id} />}
      {tab === "vacunas" && <Vacunas id={id} especie={m.especie_id} puedeAplicar={atendible && puedeFirmar(usuario)} puedeCatalogo={puede(usuario.rol, "catalogos")} />}
      {tab === "tratamientos" && <Tratamientos id={id} />}
      {tab === "recetas" && <Recetas id={id} />}
      {tab === "peso" && <Peso id={id} puedeRegistrar={atendible} />}
      {tab === "citas" && <Citas id={id} />}
      {tab === "facturas" && <Facturas id={id} />}
    </>
  );
}

// eslint-disable-next-line @typescript-eslint/no-explicit-any
async function Resumen({ m, condiciones, puedeClinica, puedeAgregar }: { m: any; condiciones: any[]; puedeClinica: boolean; puedeAgregar: boolean }) {
  const catalogo = puedeAgregar ? await opcionesCondiciones() : [];
  return (
    <div className="grid gap-5 lg:grid-cols-2">
      <Seccion titulo="Datos generales">
        <dl className="grid grid-cols-2 gap-4">
          <Dato etiqueta="Fecha de nacimiento">{fecha(m.fecha_nacimiento)}</Dato>
          <Dato etiqueta="Color">{m.color}</Dato>
          <Dato etiqueta="Microchip">{m.microchip && <span className="cifra">{m.microchip}</span>}</Dato>
          <Dato etiqueta="Esterilizado">{m.esterilizado ? "Sí" : "No"}</Dato>
          <Dato etiqueta="Próximo refuerzo">{fecha(m.vacuna_vence)}</Dato>
          <Dato etiqueta="Registrado">{fecha(m.creado_en)}</Dato>
        </dl>
        {m.observaciones && <p className="mt-4 border-t border-gris-200 pt-4 text-sm leading-relaxed text-gris-700">{m.observaciones}</p>}
      </Seccion>

      <Seccion titulo="Alergias y condiciones" sinRelleno>
        {condiciones.length === 0 ? <Vacio titulo="Sin condiciones registradas" /> : (
          <ul className="divide-y divide-gris-200">
            {condiciones.map((c) => (
              <li key={c.id} className="flex items-start justify-between gap-3 px-5 py-3">
                <div>
                  <p className="text-sm font-medium text-tinta">{c.nombre} <EstadoDe mapa={SEVERIDADES} valor={c.severidad} /></p>
                  <p className="mt-0.5 text-xs text-gris-600">{c.tipo === "ALERGIA" ? "Alergia" : c.tipo === "CRONICA" ? "Crónica" : "Congénita"}{c.fecha_deteccion && ` · desde ${fecha(c.fecha_deteccion)}`}</p>
                  {c.notas && <p className="mt-1 text-sm text-gris-700">{c.notas}</p>}
                </div>
                {puedeClinica && (
                  <BotonAccion accion={eliminarCondicion} campos={{ mascota_id: m.id, condicion_id: c.id }} texto="Quitar" clase="btn-fantasma"
                    confirmar={`¿Quitar «${c.nombre}» de la ficha de ${m.nombre}?`} />
                )}
              </li>
            ))}
          </ul>
        )}
        {puedeAgregar && (
          <div className="border-t border-gris-200 p-5">
            <Formulario accion={nuevaCondicion}>
              <input type="hidden" name="mascota_id" value={m.id} />
              <div className="grid gap-3 sm:grid-cols-3">
                <div className="sm:col-span-3"><Selector etiqueta="Agregar condición" name="condicion_id" opciones={catalogo} vacio="Selecciona…" required /></div>
                <Selector etiqueta="Severidad" name="severidad" opciones={{ LEVE: "Leve", MEDIA: "Media", GRAVE: "Grave" }} defaultValue="MEDIA" />
                <Entrada etiqueta="Detectada" name="fecha_deteccion" type="date" max={paraInput(new Date())} />
                <Entrada etiqueta="Notas" name="notas" maxLength={1000} />
              </div>
              <BotonEnviar clase="btn-secundario">Agregar</BotonEnviar>
            </Formulario>
          </div>
        )}
      </Seccion>
    </div>
  );
}

async function Historial({ id }: { id: number }) {
  const [eventos, diagnosticos] = await Promise.all([historialDeMascota(id), diagnosticosDeMascota(id)]);
  if (eventos.length === 0) return <div className="tarjeta"><Vacio titulo="El historial todavía está vacío" /></div>;
  return (
    <ol className="relative ml-2 space-y-4 border-l border-gris-300 pl-6">
      {eventos.map((e, i) => {
        const dx = e.tipo === "CONSULTA" ? diagnosticos.filter((d) => d.consulta_id === e.referencia_id) : [];
        const contenido = (
          <>
            <div className="flex flex-wrap items-center gap-2">
              <EstadoDe mapa={TIPOS_HISTORIAL} valor={e.tipo} />
              <span className="text-sm font-medium text-tinta">{e.tipo === "CITA" ? `Cita ${(ESTADOS_CITA[e.titulo.toLowerCase()]?.texto ?? "no atendida").toLowerCase()}` : e.titulo}</span>
              <span className="ml-auto text-xs text-gris-600">{fecha(e.fecha)}</span>
            </div>
            {e.detalle && <p className="mt-1.5 text-sm text-gris-700">{e.detalle}</p>}
            {dx.length > 0 && (
              <ul className="mt-2 flex flex-wrap gap-1.5">
                {dx.map((d) => <li key={d.nombre}><Insignia tono={TIPOS_DIAGNOSTICO[d.tipo]?.tono}>{d.nombre}</Insignia></li>)}
              </ul>
            )}
            {e.veterinario && <p className="mt-1.5 text-xs text-gris-600">{e.veterinario}</p>}
          </>
        );
        return (
          <li key={i} className="relative">
            <span aria-hidden="true" className="absolute -left-[29px] top-4 h-2.5 w-2.5 rounded-full border-2 border-white bg-verde-600" />
            {e.tipo === "CONSULTA"
              ? <Link href={`/admin/consultas/${e.referencia_id}`} className="tarjeta block p-4 hover:border-verde-200">{contenido}</Link>
              : <div className="tarjeta p-4">{contenido}</div>}
          </li>
        );
      })}
    </ol>
  );
}

async function Consultas({ id }: { id: number }) {
  const filas = await consultasDeMascota(id);
  return (
    <Seccion sinRelleno>
      {filas.length === 0 ? <Vacio titulo="Sin consultas registradas" /> : (
        <Tabla>
          <thead><tr><th>Fecha</th><th>Tipo</th><th>Motivo</th><th>Veterinario</th></tr></thead>
          <tbody>{filas.map((c) => (
            <tr key={c.id}>
              <td className="whitespace-nowrap"><Link href={`/admin/consultas/${c.id}`} className="text-verde-700 hover:underline">{fechaHora(c.fecha_hora)}</Link></td>
              <td>{TIPOS_CONSULTA[c.tipo] ?? c.tipo}</td><td>{c.motivo}</td><td>{c.veterinario}</td>
            </tr>
          ))}</tbody>
        </Tabla>
      )}
    </Seccion>
  );
}

async function Vacunas({ id, especie, puedeAplicar, puedeCatalogo }: {
  id: number; especie: number; puedeAplicar: boolean; puedeCatalogo: boolean;
}) {
  const [filas, aptas] = await Promise.all([vacunasDeMascota(id), vacunasAptas(especie)]);
  const hayCompatibles = aptas.length > 0;
  return (
    <Seccion titulo="Vacunas aplicadas" sinRelleno
      accion={puedeAplicar && hayCompatibles ? <Link href={`/admin/vacunas/aplicar?mascota=${id}`} className="btn btn-sm btn-primario">Registrar aplicación</Link> : undefined}>
      {filas.length === 0 ? (
        hayCompatibles ? <Vacio titulo="Esta mascota aún no tiene vacunas registradas" /> : (
          <Vacio titulo="No hay vacunas registradas para esta especie" texto="El catálogo no tiene vacunas compatibles, así que no hay nada que aplicar.">
            {puedeCatalogo && <Link href="/admin/catalogos/vacunas" className="btn btn-sm btn-secundario">Revisar el catálogo de vacunas</Link>}
          </Vacio>
        )
      ) : (
        <Tabla>
          <thead><tr><th>Vacuna</th><th>Aplicada</th><th>Próximo refuerzo</th><th>Dosis</th><th>Lote</th><th>Veterinario</th></tr></thead>
          <tbody>{filas.map((v) => (
            <tr key={v.id}>
              <td className="font-medium">{v.vacuna}</td>
              <td className="whitespace-nowrap">{fecha(v.fecha_aplicacion)}</td>
              <td className="whitespace-nowrap">{v.ultima ? fecha(v.fecha_proximo_refuerzo) : <span className="text-gris-400">Reforzada</span>}</td>
              <td className="cifra">{v.dosis_numero}</td><td className="cifra">{v.lote}</td><td>{v.veterinario}</td>
            </tr>
          ))}</tbody>
        </Tabla>
      )}
    </Seccion>
  );
}

async function Tratamientos({ id }: { id: number }) {
  const filas = await tratamientosDeMascota(id);
  return (
    <Seccion sinRelleno>
      {filas.length === 0 ? <Vacio titulo="Sin tratamientos registrados" /> : (
        <ul className="divide-y divide-gris-200">
          {filas.map((t) => (
            <li key={t.id} className="px-5 py-3.5">
              <div className="flex flex-wrap items-center justify-between gap-2">
                <Link href={`/admin/consultas/${t.consulta_id}`} className="text-sm font-medium text-verde-700 hover:underline">{t.descripcion}</Link>
                <EstadoDe mapa={ESTADOS_TRATAMIENTO} valor={t.estado} />
              </div>
              {t.indicaciones && <p className="mt-1 text-sm text-gris-700">{t.indicaciones}</p>}
              <p className="mt-1 text-xs text-gris-600">Desde {fecha(t.fecha_inicio)}{t.fecha_fin_estimada && ` hasta ${fecha(t.fecha_fin_estimada)}`}</p>
            </li>
          ))}
        </ul>
      )}
    </Seccion>
  );
}

async function Recetas({ id }: { id: number }) {
  const filas = await recetasDeMascota(id);
  return (
    <Seccion sinRelleno>
      {filas.length === 0 ? <Vacio titulo="Sin recetas emitidas" /> : (
        <Tabla>
          <thead><tr><th>Folio</th><th>Fecha</th><th>Medicamentos</th></tr></thead>
          <tbody>{filas.map((r) => (
            <tr key={r.id}>
              <td><Link href={`/admin/recetas/${r.id}`} className="text-verde-700 hover:underline">{r.folio}</Link></td>
              <td className="whitespace-nowrap">{fecha(r.fecha_emision)}</td><td>{r.medicamentos ?? "—"}</td>
            </tr>
          ))}</tbody>
        </Tabla>
      )}
    </Seccion>
  );
}

async function Peso({ id, puedeRegistrar }: { id: number; puedeRegistrar: boolean }) {
  const filas = await pesosDeMascota(id);
  return (
    <div className="grid gap-5 lg:grid-cols-3">
      <div className={`space-y-5 ${puedeRegistrar ? "lg:col-span-2" : "lg:col-span-3"}`}>
        <Seccion titulo="Evolución del peso"><GraficaPeso pesos={filas} /></Seccion>
        <Seccion sinRelleno>
          {filas.length === 0 ? <Vacio titulo="Sin mediciones" /> : (
            <Tabla>
              <thead><tr><th>Fecha</th><th>Peso</th><th>Observación</th></tr></thead>
              <tbody>{[...filas].reverse().map((p) => (
                <tr key={p.id}><td className="whitespace-nowrap">{fecha(p.fecha_registro)}</td><td className="cifra">{numero(p.peso_kg, " kg")}</td><td>{p.observacion ?? "—"}</td></tr>
              ))}</tbody>
            </Tabla>
          )}
        </Seccion>
      </div>
      {puedeRegistrar && (
        <Seccion titulo="Registrar peso" className="self-start">
          <Formulario accion={nuevoPeso}>
            <input type="hidden" name="mascota_id" value={id} />
            <Entrada etiqueta="Fecha" name="fecha_registro" type="date" required max={paraInput(new Date())} defaultValue={paraInput(new Date())} />
            <Entrada etiqueta="Peso (kg)" name="peso_kg" inputMode="decimal" required placeholder="0,00" />
            <Entrada etiqueta="Observación" name="observacion" maxLength={200} />
            <BotonEnviar>Registrar</BotonEnviar>
          </Formulario>
        </Seccion>
      )}
    </div>
  );
}

async function Citas({ id }: { id: number }) {
  const filas = await citasDeMascota(id);
  return (
    <Seccion sinRelleno>
      {filas.length === 0 ? <Vacio titulo="Sin citas registradas" /> : (
        <Tabla>
          <thead><tr><th>Fecha</th><th>Motivo</th><th>Veterinario</th><th>Estado</th></tr></thead>
          <tbody>{filas.map((a) => (
            <tr key={a.cita_id}>
              <td className="whitespace-nowrap"><Link href={`/admin/citas/${a.cita_id}`} className="text-verde-700 hover:underline">{fechaHora(a.fecha_hora_inicio)}</Link></td>
              <td>{a.motivo}</td><td>{a.veterinario}</td><td><EstadoDe mapa={ESTADOS_CITA} valor={a.estado} /></td>
            </tr>
          ))}</tbody>
        </Tabla>
      )}
    </Seccion>
  );
}

async function Facturas({ id }: { id: number }) {
  const filas = await facturasDeMascota(id);
  return (
    <Seccion sinRelleno>
      {filas.length === 0 ? <Vacio titulo="Sin facturas asociadas a esta mascota" /> : (
        <Tabla>
          <thead><tr><th>Número</th><th>Fecha</th><th>Total</th><th>Saldo</th><th>Estado</th></tr></thead>
          <tbody>{filas.map((f) => (
            <tr key={f.id}>
              <td><Link href={`/admin/facturas/${f.id}`} className="text-verde-700 hover:underline">{f.numero}</Link></td>
              <td className="whitespace-nowrap">{fecha(f.fecha_emision)}</td><td className="cifra">{dinero(f.total)}</td>
              <td className="cifra">{dinero(f.saldo)}</td><td><EstadoDe mapa={ESTADOS_FACTURA} valor={f.estado} /></td>
            </tr>
          ))}</tbody>
        </Tabla>
      )}
    </Seccion>
  );
}

