import { BotonEnviar, Formulario } from "@/components/Formulario";
import { AreaTexto, Entrada, Selector } from "@/components/ui";
import { CONTACTO } from "@/lib/clinica";
import { FRANJAS } from "@/lib/etiquetas";
import { paraInput } from "@/lib/formato";
import { especiesPublicas } from "@/lib/repos/publico";
import { enviarSolicitud } from "./acciones";

export const dynamic = "force-dynamic";
export const metadata = { title: "Agendar una cita" };

export default async function Agendar() {
  const especies = await especiesPublicas();
  return (
    <div className="contenedor-web grid gap-10 py-14 md:grid-cols-12 md:py-20">
      <div className="md:col-span-5">
        <p className="text-xs font-semibold uppercase tracking-[0.14em] text-verde-600">Agendar</p>
        <h1 className="mt-3 font-display text-[clamp(2.2rem,5vw,3.2rem)] leading-tight text-verde-900 equilibrar">
          Solicita una cita para tu mascota
        </h1>
        <p className="mt-4 text-[17px] leading-relaxed text-gris-700">
          Déjanos tus datos y recepción te contactará para confirmar el día y la hora.
          Tu solicitud todavía no es una cita confirmada.
        </p>
        <p className="mt-6 rounded-lg bg-alerta-100 px-4 py-3 text-sm text-alerta-600">
          ¿Es una urgencia? No esperes: llama al{" "}
          <a href={`tel:${CONTACTO.telefonoLink}`} className="font-medium underline">{CONTACTO.telefono}</a>.
        </p>
      </div>

      <Formulario accion={enviarSolicitud} className="tarjeta p-6 md:col-span-7">
        <div className="grid gap-4 sm:grid-cols-2">
          <Entrada etiqueta="Tu nombre" name="nombre" maxLength={120} required autoComplete="name" />
          <Entrada etiqueta="Teléfono" name="telefono" maxLength={25} required autoComplete="tel" placeholder="+57 300 000 0000" />
          <div className="sm:col-span-2"><Entrada etiqueta="Correo electrónico" name="email" type="email" maxLength={120} autoComplete="email" /></div>
          <Entrada etiqueta="Nombre de tu mascota" name="nombre_mascota" maxLength={60} />
          <Selector etiqueta="Especie" name="especie_id" vacio="Selecciona…" opciones={especies.map((e) => ({ valor: e.id, texto: e.nombre }))} />
          <Entrada etiqueta="Fecha preferida" name="fecha_preferida" type="date" min={paraInput(new Date())} />
          <Selector etiqueta="Franja horaria" name="franja" opciones={FRANJAS} defaultValue="INDIFERENTE" />
        </div>
        <AreaTexto etiqueta="Motivo de la visita" name="motivo" maxLength={300} required />
        {/* Trampa para bots: no es visible para las personas. */}
        <input type="text" name="sitio_web" tabIndex={-1} autoComplete="off" aria-hidden="true" className="hidden" />
        <p className="text-xs text-gris-600">Usaremos estos datos solo para responder a tu solicitud.</p>
        <BotonEnviar>Enviar solicitud</BotonEnviar>
      </Formulario>
    </div>
  );
}
