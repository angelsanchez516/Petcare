import Link from "next/link";
import { cuidadosPorEspecie } from "@/lib/repos/publico";

export const dynamic = "force-dynamic";
export const metadata = { title: "Cuidado de mascotas" };

/** Información por especie. El esquema de vacunas se lee del catálogo real:
 *  la tabla vacuna_especie dice qué vacuna está indicada para cada especie. */
export default async function Cuidados() {
  const especies = await cuidadosPorEspecie();

  return (
    <>
      <section className="bg-verde-50">
        <div className="contenedor-web py-14 md:py-20">
          <p className="text-xs font-semibold uppercase tracking-[0.14em] text-verde-600">Cuidado de mascotas</p>
          <h1 className="mt-3 max-w-2xl font-display text-[clamp(2.2rem,5vw,3.4rem)] leading-tight text-verde-900 equilibrar">
            Qué vacunas necesita tu mascota
          </h1>
          <p className="mt-4 max-w-xl text-[17px] leading-relaxed text-gris-700">
            Esta es una guía general. El esquema exacto depende de la edad y del estado de salud;
            lo define el veterinario en consulta.
          </p>
        </div>
      </section>

      <div className="contenedor-web grid gap-5 py-14 md:grid-cols-2 md:py-20">
        {especies.map((e) => (
          <section key={e.id} className="tarjeta p-6">
            <h2 className="font-display text-3xl text-verde-900">{e.icono} {e.nombre}</h2>
            {e.esperanza_vida_anios && <p className="mt-1 text-sm text-gris-600">Esperanza de vida aproximada: {e.esperanza_vida_anios} años</p>}
            {e.vacunas.length === 0 ? (
              <p className="mt-4 text-sm text-gris-600">No tiene un esquema de vacunación general. Consulta al veterinario.</p>
            ) : (
              <ul className="mt-4 divide-y divide-gris-200 border-t border-gris-200">
                {/* eslint-disable-next-line @typescript-eslint/no-explicit-any */}
                {e.vacunas.map((v: any) => (
                  <li key={v.nombre} className="py-3">
                    <p className="text-sm font-medium text-tinta">{v.nombre}</p>
                    {v.previene && <p className="mt-0.5 text-sm text-gris-600">Previene: {v.previene}</p>}
                    {v.meses && <p className="mt-0.5 text-xs text-gris-600">Refuerzo cada {v.meses} meses</p>}
                  </li>
                ))}
              </ul>
            )}
          </section>
        ))}
      </div>

      <section className="contenedor-web pb-16 text-center">
        <Link href="/agendar" className="btn btn-lg btn-primario">Agendar vacunación</Link>
      </section>
    </>
  );
}
