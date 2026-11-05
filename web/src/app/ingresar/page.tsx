import Link from "next/link";
import { redirect } from "next/navigation";
import { BotonEnviar, Formulario } from "@/components/Formulario";
import { Logo } from "@/components/Logo";
import { Entrada } from "@/components/ui";
import { usuarioActual } from "@/lib/auth";
import { ingresar } from "./acciones";

export const metadata = { title: "Iniciar sesión" };

export default async function PaginaIngreso() {
  if (await usuarioActual()) redirect("/admin");
  return (
    <main className="flex min-h-dvh items-center justify-center bg-verde-50 px-4 py-10">
      <div className="w-full max-w-sm">
        <Link href="/" className="mb-6 flex items-center justify-center gap-2.5">
          <Logo className="h-9 w-9 text-verde-700" />
          <span className="font-display text-2xl text-verde-900">PetCare</span>
        </Link>
        <div className="tarjeta-sombra p-6">
          <h1 className="text-lg font-semibold text-tinta">Iniciar sesión</h1>
          <p className="mt-1 mb-5 text-sm text-gris-600">Solo para el personal de la clínica.</p>
          <Formulario accion={ingresar}>
            <Entrada etiqueta="Usuario o correo" name="usuario" required autoComplete="username" autoFocus />
            <Entrada etiqueta="Contraseña" name="clave" type="password" required autoComplete="current-password" />
            <div className="[&>button]:w-full"><BotonEnviar pendiente="Iniciando sesión…">Iniciar sesión</BotonEnviar></div>
          </Formulario>
        </div>
        <p className="mt-4 text-center text-sm">
          <Link href="/" className="text-gris-600 hover:text-verde-700">Volver al sitio</Link>
        </p>
      </div>
    </main>
  );
}
