import Link from "next/link";
import { Avatar } from "@/components/ui";
import { veterinariosPublicos } from "@/lib/repos/publico";

export const dynamic = "force-dynamic";
export const metadata = { title: "Equipo" };

export default async function Equipo() {
  const equipo = await veterinariosPublicos();

  return (
    <>
      <section className="bg-verde-50">
        <div className="contenedor-web py-14 md:py-20">
          <p className="text-xs font-semibold uppercase tracking-[0.14em] text-verde-600">Equipo</p>
          <h1 className="mt-3 max-w-2xl font-display text-[clamp(2.2rem,5vw,3.4rem)] leading-tight text-verde-900 equilibrar">
            Las personas que cuidan a tu mascota
          </h1>
        </div>
      </section>

      <div className="contenedor-web py-14 md:py-20">
        <ul className="grid gap-5 md:grid-cols-2">
          {equipo.map((v) => (
            <li key={v.id} className="tarjeta flex gap-5 p-6">
              <Avatar foto={v.foto_url} nombre={`${v.nombres} ${v.apellidos}`} tam={72} />
              <div className="min-w-0">
                <h2 className="text-lg font-semibold text-tinta">{v.nombres} {v.apellidos}</h2>
                <p className="text-sm text-verde-700">{v.especialidad_principal ?? "Medicina veterinaria"}</p>
                <p className="mt-0.5 text-xs text-gris-600">Matrícula {v.matricula}</p>
                {v.biografia && <p className="mt-3 text-sm leading-relaxed text-gris-700">{v.biografia}</p>}
                {v.especialidades.length > 1 && (
                  <ul className="mt-3 flex flex-wrap gap-1.5">
                    {v.especialidades.map((e) => <li key={e} className="insignia insignia-marca">{e}</li>)}
                  </ul>
                )}
              </div>
            </li>
          ))}
        </ul>
        <div className="mt-10 text-center">
          <Link href="/agendar" className="btn btn-lg btn-primario">Agendar una cita</Link>
        </div>
      </div>
    </>
  );
}
