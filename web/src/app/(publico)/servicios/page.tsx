import Link from "next/link";
import { CATEGORIAS_SERVICIO } from "@/lib/clinica";
import { dinero } from "@/lib/formato";
import { serviciosPublicos } from "@/lib/repos/publico";

export const dynamic = "force-dynamic";
export const metadata = { title: "Servicios" };

export default async function Servicios() {
  const servicios = await serviciosPublicos();
  // La consulta ya viene ordenada por categoría: aquí solo se agrupa.
  const categorias = [...new Set(servicios.map((s) => s.categoria))];

  return (
    <>
      <section className="bg-verde-50">
        <div className="contenedor-web py-14 md:py-20">
          <p className="text-xs font-semibold uppercase tracking-[0.14em] text-verde-600">Servicios</p>
          <h1 className="mt-3 max-w-2xl font-display text-[clamp(2.2rem,5vw,3.4rem)] leading-tight text-verde-900 equilibrar">
            Atención veterinaria para cada etapa de tu mascota
          </h1>
          <p className="mt-4 max-w-xl text-[17px] leading-relaxed text-gris-700">
            Los valores son de referencia. El profesional confirma el costo final según el caso.
          </p>
        </div>
      </section>

      <div className="contenedor-web space-y-14 py-14 md:py-20">
        {categorias.map((c) => (
          <section key={c} aria-labelledby={`cat-${c}`} className="grid gap-6 md:grid-cols-12">
            <div className="md:col-span-4">
              <h2 id={`cat-${c}`} className="font-display text-3xl text-verde-900">{CATEGORIAS_SERVICIO[c]?.nombre ?? c}</h2>
              <p className="mt-2 text-sm leading-relaxed text-gris-600">{CATEGORIAS_SERVICIO[c]?.descripcion}</p>
            </div>
            <ul className="divide-y divide-gris-200 border-y border-gris-200 md:col-span-8">
              {servicios.filter((s) => s.categoria === c).map((s) => (
                <li key={s.id} className="flex flex-wrap items-baseline justify-between gap-x-6 gap-y-1 py-4">
                  <div className="min-w-0 flex-1 basis-64">
                    <h3 className="font-medium text-tinta">{s.nombre}</h3>
                    {s.descripcion && <p className="mt-1 text-sm leading-relaxed text-gris-600">{s.descripcion}</p>}
                  </div>
                  <div className="text-right">
                    <p className="font-medium text-verde-800 cifra">{dinero(s.precio_base)}</p>
                    {s.duracion_estimada_min && <p className="text-xs text-gris-600">{s.duracion_estimada_min} min aprox.</p>}
                  </div>
                </li>
              ))}
            </ul>
          </section>
        ))}

        <div className="flex flex-wrap items-center justify-between gap-4 rounded-xl bg-verde-900 px-6 py-8 text-white">
          <p className="font-display text-2xl">¿Quieres reservar un espacio?</p>
          <Link href="/agendar" className="btn btn-lg btn-ambar">Agendar una cita</Link>
        </div>
      </div>
    </>
  );
}
