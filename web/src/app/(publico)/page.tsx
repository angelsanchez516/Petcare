import Link from "next/link";
import Image from "next/image";
import { serviciosPublicos, veterinariosPublicos, cifrasClinica } from "@/lib/repos/publico";
import { CATEGORIAS_SERVICIO, HORARIOS, CONTACTO } from "@/lib/clinica";
import { dinero, iniciales } from "@/lib/formato";

export const dynamic = "force-dynamic";

export default async function Inicio() {
  const [servicios, equipo, cifras] = await Promise.all([
    serviciosPublicos(),
    veterinariosPublicos(),
    cifrasClinica(),
  ]);

  const destacados = servicios.slice(0, 6);

  return (
    <>
      {/* ───────────────────────── ENCABEZADO ───────────────────────── */}
      <section className="relative overflow-hidden bg-verde-50">
        {/* La foto se coloca a la derecha y se desvanece hacia el texto: el
            gato ya trae su propio fondo difuminado, así que el degradado
            continúa esa misma transición en vez de cortarla. */}
        <div className="absolute inset-y-0 right-0 hidden w-[62%] md:block">
          <Image
            src="/img/hero-gato.jpg"
            alt=""
            fill
            priority
            sizes="62vw"
            className="object-cover object-right"
          />
          <div className="absolute inset-0 bg-gradient-to-r from-verde-50 via-verde-50/70 to-transparent" />
        </div>

        <div className="contenedor-web relative py-16 md:py-28 lg:py-32">
          <div className="max-w-xl">
            <p className="inline-flex items-center gap-2 rounded-full border border-verde-200 bg-white/70 px-3 py-1 text-xs font-medium text-verde-700">
              <span className="h-1.5 w-1.5 rounded-full bg-exito-600" aria-hidden="true" />
              Urgencias 24 horas, todos los días
            </p>

            <h1 className="mt-6 font-display text-[clamp(2.6rem,6vw,4.2rem)] leading-[1.04] text-verde-900 equilibrar">
              El cuidado que tu
              <br className="hidden sm:block" /> mascota{" "}
              <em className="italic text-verde-700">merece</em>
            </h1>

            <p className="mt-6 max-w-md text-[17px] leading-relaxed text-gris-700">
              Medicina veterinaria con historia clínica completa: cada consulta,
              vacuna y tratamiento queda registrado para que nada se pierda entre
              una visita y la siguiente.
            </p>

            <div className="mt-9 flex flex-col gap-3 sm:flex-row">
              <Link href="/agendar" className="btn btn-lg btn-primario">
                Agendar una cita
              </Link>
              <Link href="/servicios" className="btn btn-lg btn-secundario">
                Ver servicios
              </Link>
            </div>

            <dl className="mt-12 grid max-w-md grid-cols-3 gap-6 border-t border-verde-200 pt-7">
              {[
                [cifras.mascotas, "pacientes"],
                [cifras.veterinarios, "veterinarios"],
                [cifras.especies, "especies atendidas"],
              ].map(([valor, texto]) => (
                <div key={texto as string}>
                  <dt className="font-display text-3xl text-verde-800 cifra">{valor}</dt>
                  <dd className="mt-0.5 text-xs leading-tight text-gris-600">{texto}</dd>
                </div>
              ))}
            </dl>
          </div>
        </div>

        {/* En móvil la foto va debajo del texto, en su recorte vertical. */}
        <div className="relative h-60 w-full md:hidden">
          <Image
            src="/img/gato-16x9.jpg"
            alt="Gato atendido en la clínica"
            fill
            sizes="100vw"
            className="object-cover object-center"
          />
        </div>
      </section>

      {/* ───────────────────────── SERVICIOS ───────────────────────── */}
      <section className="contenedor-web py-20 md:py-28">
        <div className="flex flex-wrap items-end justify-between gap-6">
          <div className="max-w-lg">
            <p className="text-xs font-semibold uppercase tracking-[0.14em] text-verde-600">
              Servicios
            </p>
            <h2 className="mt-3 font-display text-[clamp(1.9rem,3.6vw,2.6rem)] leading-tight text-verde-900 equilibrar">
              Todo lo que tu mascota necesita, en un solo lugar
            </h2>
          </div>
          <Link href="/servicios" className="btn btn-md btn-secundario">
            Ver los {servicios.length} servicios
          </Link>
        </div>

        <ul className="mt-12 grid gap-4 sm:grid-cols-2 lg:grid-cols-3">
          {destacados.map((s) => (
            <li key={s.id}>
              <article className="group h-full tarjeta p-6 transition-colors hover:border-verde-200 hover:bg-verde-50/40">
                <div className="flex items-start justify-between gap-3">
                  <span className="text-2xl" aria-hidden="true">{s.icono ?? "🐾"}</span>
                  <span className="insignia insignia-marca">
                    {CATEGORIAS_SERVICIO[s.categoria]?.nombre ?? s.categoria}
                  </span>
                </div>
                <h3 className="mt-4 text-[17px] font-semibold text-tinta">{s.nombre}</h3>
                {s.descripcion && (
                  <p className="mt-2 text-sm leading-relaxed text-gris-600">{s.descripcion}</p>
                )}
                <p className="mt-5 flex items-baseline gap-2 border-t border-gris-200 pt-4">
                  <span className="font-display text-xl text-verde-800 cifra">
                    {dinero(s.precio_base)}
                  </span>
                  {s.duracion_estimada_min && (
                    <span className="text-xs text-gris-600">· {s.duracion_estimada_min} min</span>
                  )}
                </p>
              </article>
            </li>
          ))}
        </ul>
      </section>

      {/* ───────────────────────── POR QUÉ ───────────────────────── */}
      <section className="border-y border-gris-200 bg-white">
        <div className="contenedor-web grid gap-14 py-20 md:grid-cols-2 md:py-28">
          <div className="relative aspect-[4/5] overflow-hidden rounded-2xl md:aspect-auto">
            <Image
              src="/img/clinica-1.jpg"
              alt="Consulta veterinaria en la clínica"
              fill
              sizes="(max-width: 768px) 100vw, 50vw"
              className="object-cover"
            />
          </div>

          <div className="flex flex-col justify-center">
            <p className="text-xs font-semibold uppercase tracking-[0.14em] text-verde-600">
              Cómo trabajamos
            </p>
            <h2 className="mt-3 font-display text-[clamp(1.9rem,3.6vw,2.6rem)] leading-tight text-verde-900 equilibrar">
              Una historia clínica que no se pierde
            </h2>
            <p className="mt-5 text-[16px] leading-relaxed text-gris-700">
              Cada paciente tiene un expediente permanente. Cuando vuelve, el
              veterinario ve su peso a lo largo del tiempo, sus alergias, qué se
              le recetó la última vez y cuándo le toca el próximo refuerzo.
            </p>

            <ul className="mt-10 space-y-7">
              {[
                ["Expediente completo",
                 "Consultas, diagnósticos, tratamientos, recetas y vacunas, en orden cronológico."],
                ["Alertas de prevención",
                 "El sistema avisa del próximo refuerzo antes de que venza, no después."],
                ["Alergias siempre visibles",
                 "Las condiciones médicas del paciente se muestran antes de prescribir."],
                ["Agenda sin choques",
                 "Cada profesional tiene su propia agenda y el sistema impide superponer turnos."],
              ].map(([titulo, texto]) => (
                <li key={titulo} className="flex gap-4">
                  <span
                    className="mt-1 flex h-7 w-7 shrink-0 items-center justify-center rounded-lg bg-verde-100 text-verde-700"
                    aria-hidden="true"
                  >
                    <svg width="15" height="15" viewBox="0 0 16 16" fill="none">
                      <path d="M3 8.5l3.2 3.2L13 5" stroke="currentColor" strokeWidth="2"
                            strokeLinecap="round" strokeLinejoin="round" />
                    </svg>
                  </span>
                  <div>
                    <h3 className="text-[15px] font-semibold text-tinta">{titulo}</h3>
                    <p className="mt-1 text-sm leading-relaxed text-gris-600">{texto}</p>
                  </div>
                </li>
              ))}
            </ul>
          </div>
        </div>
      </section>

      {/* ───────────────────────── EQUIPO ───────────────────────── */}
      <section className="contenedor-web py-20 md:py-28">
        <div className="flex flex-wrap items-end justify-between gap-6">
          <div className="max-w-lg">
            <p className="text-xs font-semibold uppercase tracking-[0.14em] text-verde-600">
              Equipo
            </p>
            <h2 className="mt-3 font-display text-[clamp(1.9rem,3.6vw,2.6rem)] leading-tight text-verde-900 equilibrar">
              Profesionales con matrícula y especialidad
            </h2>
          </div>
          <Link href="/equipo" className="btn btn-md btn-secundario">
            Conocer al equipo
          </Link>
        </div>

        <ul className="mt-12 grid gap-5 sm:grid-cols-2 lg:grid-cols-4">
          {equipo.slice(0, 4).map((v) => (
            <li key={v.id}>
              <article className="h-full tarjeta p-6 text-center">
                <div className="mx-auto flex h-16 w-16 items-center justify-center rounded-full bg-verde-100 font-display text-xl text-verde-700">
                  {iniciales(`${v.nombres} ${v.apellidos}`)}
                </div>
                <h3 className="mt-4 text-[15px] font-semibold text-tinta">
                  {v.nombres} {v.apellidos}
                </h3>
                {v.especialidad_principal && (
                  <p className="mt-1 text-sm text-verde-700">{v.especialidad_principal}</p>
                )}
                <p className="mt-2 text-xs text-gris-400">M.V. {v.matricula}</p>
              </article>
            </li>
          ))}
        </ul>
      </section>

      {/* ───────────────────────── VISITA ───────────────────────── */}
      <section className="bg-verde-900 text-white">
        <div className="contenedor-web grid gap-12 py-20 md:grid-cols-12 md:py-24">
          <div className="md:col-span-5">
            <h2 className="font-display text-[clamp(1.9rem,3.6vw,2.6rem)] leading-tight equilibrar">
              Visítanos o escríbenos
            </h2>
            <p className="mt-4 text-[15px] leading-relaxed text-verde-200">
              Atendemos con y sin turno. Para urgencias, llámanos directamente: hay
              un profesional de guardia las 24 horas.
            </p>
            <div className="mt-8 flex flex-col gap-3 sm:flex-row">
              <Link href="/agendar" className="btn btn-lg btn-ambar">
                Agendar una cita
              </Link>
              <a href={`tel:${CONTACTO.telefonoLink}`}
                 className="btn btn-lg border border-verde-700 text-white hover:bg-verde-800">
                Llamar ahora
              </a>
            </div>
          </div>

          <div className="md:col-span-4">
            <h3 className="text-xs font-semibold uppercase tracking-[0.14em] text-verde-200">
              Horarios
            </h3>
            <ul className="mt-5 space-y-3">
              {HORARIOS.map((h) => (
                <li key={h.dias} className="flex justify-between gap-6 border-b border-verde-800 pb-3 text-sm">
                  <span className="text-verde-200">{h.dias}</span>
                  <span className="cifra">{h.horas}</span>
                </li>
              ))}
            </ul>
          </div>

          <div className="md:col-span-3">
            <h3 className="text-xs font-semibold uppercase tracking-[0.14em] text-verde-200">
              Dónde estamos
            </h3>
            <address className="mt-5 space-y-3 text-sm not-italic leading-relaxed">
              <p>{CONTACTO.direccion}<br />{CONTACTO.ciudad}</p>
              <p><a href={`tel:${CONTACTO.telefonoLink}`} className="hover:text-ambar-500">{CONTACTO.telefono}</a></p>
              <p><a href={`mailto:${CONTACTO.email}`} className="hover:text-ambar-500 break-all">{CONTACTO.email}</a></p>
            </address>
          </div>
        </div>
      </section>
    </>
  );
}
