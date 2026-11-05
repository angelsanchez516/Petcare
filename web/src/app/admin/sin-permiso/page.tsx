import Link from "next/link";

export const metadata = { title: "Sin permiso" };

export default function SinPermiso() {
  return (
    <div className="tarjeta mx-auto mt-16 max-w-md p-8 text-center">
      <h1 className="text-lg font-semibold text-tinta">No tienes acceso a esta sección</h1>
      <p className="mt-2 text-sm text-gris-600">Tu rol no incluye este módulo. Si crees que es un error, habla con el administrador.</p>
      <Link href="/admin" className="btn btn-md btn-primario mt-5">Volver al tablero</Link>
    </div>
  );
}
