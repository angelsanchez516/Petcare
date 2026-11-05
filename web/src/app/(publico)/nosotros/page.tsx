import Image from "next/image";
import Link from "next/link";
import { cifrasClinica } from "@/lib/repos/publico";

export const dynamic = "force-dynamic";
export const metadata = { title: "La clínica" };

const PRINCIPIOS = [
  { titulo: "Una historia clínica que no se pierde", texto: "Consultas, vacunas, tratamientos y pesos quedan registrados en un solo expediente por cada mascota." },
  { titulo: "Prevención con seguimiento", texto: "Controlamos las fechas de refuerzo de cada vacuna y las revisamos en cada visita." },
  { titulo: "Información clara para ti", texto: "Te explicamos el diagnóstico, el tratamiento y su costo antes de empezar." },
];

export default async function Nosotros() {
  const cifras = await cifrasClinica();
  return (
    <>
      <section className="contenedor-web grid items-center gap-10 py-14 md:grid-cols-2 md:py-20">
        <div>
          <p className="text-xs font-semibold uppercase tracking-[0.14em] text-verde-600">La clínica</p>
          <h1 className="mt-3 font-display text-[clamp(2.2rem,5vw,3.4rem)] leading-tight text-verde-900 equilibrar">
            Medicina veterinaria con memoria
          </h1>
          <p className="mt-5 text-[17px] leading-relaxed text-gris-700">
            PetCare es una clínica veterinaria que atiende perros, gatos y otras especies. Cada paciente
            tiene un expediente completo para que cualquier profesional del equipo conozca su historia.
          </p>
          <dl className="mt-8 grid grid-cols-3 gap-6 border-t border-gris-200 pt-6">
            {[[cifras.mascotas, "pacientes"], [cifras.consultas, "consultas registradas"], [cifras.veterinarios, "veterinarios"]].map(([valor, texto]) => (
              <div key={texto}>
                <dt className="font-display text-3xl text-verde-800 cifra">{valor}</dt>
                <dd className="mt-0.5 text-xs leading-tight text-gris-600">{texto}</dd>
              </div>
            ))}
          </dl>
        </div>
        <div className="relative aspect-[4/3] overflow-hidden rounded-xl">
          <Image src="/img/clinica-1.jpg" alt="Veterinaria atendiendo a un perro en consulta" fill sizes="(min-width: 768px) 50vw, 100vw" className="object-cover" />
        </div>
      </section>

      <section className="bg-verde-50">
        <div className="contenedor-web grid gap-8 py-14 md:grid-cols-3 md:py-20">
          {PRINCIPIOS.map((p) => (
            <div key={p.titulo}>
              <h2 className="font-display text-2xl leading-snug text-verde-900">{p.titulo}</h2>
              <p className="mt-3 text-sm leading-relaxed text-gris-700">{p.texto}</p>
            </div>
          ))}
        </div>
      </section>

      <section className="contenedor-web flex flex-wrap items-center justify-between gap-4 py-14">
        <p className="font-display text-3xl text-verde-900">Conoce a quienes te atenderán</p>
        <div className="flex flex-wrap gap-3">
          <Link href="/equipo" className="btn btn-lg btn-secundario">Ver el equipo</Link>
          <Link href="/contacto" className="btn btn-lg btn-primario">Cómo llegar</Link>
        </div>
      </section>
    </>
  );
}
