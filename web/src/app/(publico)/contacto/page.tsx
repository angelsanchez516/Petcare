import Link from "next/link";
import { CONTACTO, HORARIOS } from "@/lib/clinica";

export const metadata = { title: "Contacto y ubicación" };

export default function Contacto() {
  return (
    <>
      <section className="bg-verde-50">
        <div className="contenedor-web py-14 md:py-20">
          <p className="text-xs font-semibold uppercase tracking-[0.14em] text-verde-600">Contacto</p>
          <h1 className="mt-3 max-w-2xl font-display text-[clamp(2.2rem,5vw,3.4rem)] leading-tight text-verde-900 equilibrar">
            Estamos para ayudarte
          </h1>
          <p className="mt-4 max-w-xl text-[17px] leading-relaxed text-gris-700">
            Para urgencias, llámanos directamente: hay un profesional de guardia las 24 horas.
          </p>
        </div>
      </section>

      <div className="contenedor-web grid gap-5 py-14 md:grid-cols-3 md:py-20">
        <section className="tarjeta p-6">
          <h2 className="text-lg font-semibold text-tinta">Escríbenos o llámanos</h2>
          <ul className="mt-4 space-y-3 text-sm">
            <li><span className="block text-xs text-gris-600">Teléfono</span><a href={`tel:${CONTACTO.telefonoLink}`} className="text-verde-700 hover:underline">{CONTACTO.telefono}</a></li>
            <li><span className="block text-xs text-gris-600">WhatsApp</span><a href={`https://wa.me/${CONTACTO.whatsappLink}`} className="text-verde-700 hover:underline">{CONTACTO.whatsapp}</a></li>
            <li><span className="block text-xs text-gris-600">Correo</span><a href={`mailto:${CONTACTO.email}`} className="break-all text-verde-700 hover:underline">{CONTACTO.email}</a></li>
          </ul>
        </section>

        <section className="tarjeta p-6">
          <h2 className="text-lg font-semibold text-tinta">Dónde estamos</h2>
          <address className="mt-4 text-sm not-italic leading-relaxed text-gris-700">
            {CONTACTO.direccion}<br />{CONTACTO.ciudad}
          </address>
          <a href={`https://www.google.com/maps/search/?api=1&query=${encodeURIComponent(`${CONTACTO.direccion}, ${CONTACTO.ciudad}`)}`}
            className="btn btn-md btn-secundario mt-4">Abrir en el mapa</a>
        </section>

        <section className="tarjeta p-6">
          <h2 className="text-lg font-semibold text-tinta">Horarios</h2>
          <ul className="mt-4 space-y-3">
            {HORARIOS.map((h) => (
              <li key={h.dias} className="flex justify-between gap-4 border-b border-gris-200 pb-3 text-sm">
                <span className="text-gris-700">{h.dias}</span><span className="cifra">{h.horas}</span>
              </li>
            ))}
          </ul>
        </section>
      </div>

      <section className="contenedor-web pb-16 text-center">
        <Link href="/agendar" className="btn btn-lg btn-primario">Agendar una cita</Link>
      </section>
    </>
  );
}
