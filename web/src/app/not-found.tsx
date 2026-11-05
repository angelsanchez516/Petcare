import Link from "next/link";

export default function NoEncontrado() {
  return (
    <div className="mx-auto max-w-md px-6 py-24 text-center">
      <p className="font-display text-5xl text-verde-700">404</p>
      <h1 className="mt-3 text-lg font-semibold text-tinta">No encontramos lo que buscas</h1>
      <p className="mt-1 text-sm text-gris-600">El enlace no existe o el registro ya no está disponible.</p>
      <Link href="/" className="btn btn-md btn-primario mt-6">Ir al inicio</Link>
    </div>
  );
}
