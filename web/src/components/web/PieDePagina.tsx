import Link from "next/link";
import { Logo } from "@/components/Logo";
import { HORARIOS, CONTACTO } from "@/lib/clinica";

export function PieDePagina() {
  return (
    <footer className="mt-24 border-t border-gris-200 bg-white">
      <div className="contenedor-web py-14">
        <div className="grid gap-10 md:grid-cols-12">
          <div className="md:col-span-4">
            <div className="flex items-center gap-2.5">
              <Logo className="h-8 w-8 text-verde-700" />
              <span className="font-display text-[22px] leading-none text-verde-900">
                PetCare
              </span>
            </div>
            <p className="mt-4 text-sm leading-relaxed text-gris-600 max-w-xs">
              Clínica veterinaria con atención clínica, cirugía, diagnóstico por
              imagen y medicina preventiva. Historia clínica completa para cada
              paciente.
            </p>
          </div>

          <nav className="md:col-span-2" aria-labelledby="pie-navegar">
            <h3 id="pie-navegar" className="text-xs font-semibold uppercase tracking-wider text-gris-600">
              Navegar
            </h3>
            <ul className="mt-4 space-y-2.5 text-sm">
              {[
                ["/servicios", "Servicios"],
                ["/equipo", "Equipo"],
                ["/nosotros", "La clínica"],
                ["/contacto", "Contacto"],
                ["/agendar", "Agendar cita"],
              ].map(([href, texto]) => (
                <li key={href}>
                  <Link href={href} className="text-gris-700 hover:text-verde-700 transition-colors">
                    {texto}
                  </Link>
                </li>
              ))}
            </ul>
          </nav>

          <div className="md:col-span-3">
            <h3 className="text-xs font-semibold uppercase tracking-wider text-gris-600">
              Horarios
            </h3>
            <ul className="mt-4 space-y-2 text-sm">
              {HORARIOS.map((h) => (
                <li key={h.dias} className="flex justify-between gap-4">
                  <span className="text-gris-700">{h.dias}</span>
                  <span className="text-tinta cifra">{h.horas}</span>
                </li>
              ))}
            </ul>
            <p className="mt-4 inline-flex items-center gap-2 rounded-lg bg-ambar-100 px-3 py-2 text-xs text-ambar-600">
              <span aria-hidden="true">🚨</span>
              Urgencias 24 h los 365 días
            </p>
          </div>

          <div className="md:col-span-3">
            <h3 className="text-xs font-semibold uppercase tracking-wider text-gris-600">
              Contacto
            </h3>
            <ul className="mt-4 space-y-2.5 text-sm">
              <li>
                <a href={`tel:${CONTACTO.telefonoLink}`} className="text-gris-700 hover:text-verde-700 transition-colors">
                  {CONTACTO.telefono}
                </a>
              </li>
              <li>
                <a href={`mailto:${CONTACTO.email}`} className="text-gris-700 hover:text-verde-700 transition-colors break-all">
                  {CONTACTO.email}
                </a>
              </li>
              <li className="text-gris-700 leading-relaxed">
                {CONTACTO.direccion}
                <br />
                {CONTACTO.ciudad}
              </li>
            </ul>
          </div>
        </div>

        <div className="mt-12 flex flex-col gap-3 border-t border-gris-200 pt-6 sm:flex-row sm:items-center sm:justify-between">
          <p className="text-xs text-gris-600">
            © {new Date().getFullYear()} PetCare · Clínica Veterinaria
          </p>
          <p className="text-xs text-gris-400">
            Proyecto académico — Base de Datos
          </p>
        </div>
      </div>
    </footer>
  );
}
