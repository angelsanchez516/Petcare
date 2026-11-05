import Link from "next/link";

export const metadata = { title: "Solicitud recibida" };

export default function Gracias() {
  return (
    <div className="contenedor-web py-24 text-center">
      <h1 className="font-display text-4xl text-verde-900">Recibimos tu solicitud</h1>
      <p className="mx-auto mt-4 max-w-md text-[17px] leading-relaxed text-gris-700">
        Recepción te contactará pronto para confirmar el día y la hora de la cita.
      </p>
      <Link href="/" className="btn btn-lg btn-primario mt-8">Volver al inicio</Link>
    </div>
  );
}
