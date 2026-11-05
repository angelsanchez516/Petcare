import type { Metadata } from "next";
import { Suspense } from "react";
import { redirect } from "next/navigation";
import { Aviso } from "@/components/admin/Aviso";
import { BarraLateral } from "@/components/admin/BarraLateral";
import { cerrarSesion, usuarioActual } from "@/lib/auth";
import { puede } from "@/lib/permisos";
import { contarSolicitudesNuevas } from "@/lib/repos/citas";

export const metadata: Metadata = { title: { default: "Panel", template: "%s · PetCare" } };

async function salir() {
  "use server";
  await cerrarSesion();
  redirect("/ingresar");
}

export default async function LayoutAdmin({ children }: { children: React.ReactNode }) {
  const usuario = await usuarioActual();
  if (!usuario) redirect("/ingresar");

  const pendientes = puede(usuario.rol, "solicitudes") ? await contarSolicitudesNuevas() : null;

  return (
    <div className="min-h-dvh bg-papel">
      <BarraLateral rol={usuario.rol} nombre={usuario.nombre} salir={salir} pendientes={pendientes?.n ?? 0} />
      <main className="area-admin lg:pl-60">
        <div className="mx-auto w-full max-w-[1240px] px-4 py-6 sm:px-6 lg:px-8 lg:py-8">
          {usuario.rol === "Veterinario" && !usuario.veterinario_id && (
            <p role="alert" className="no-imprimir mb-5 rounded-lg border border-alerta-600/20 bg-alerta-100 px-4 py-2.5 text-sm text-alerta-600">
              Tu usuario no está vinculado a un perfil de veterinario, así que no puedes agendar citas, firmar consultas ni registrar vacunas. Pídele a un administrador que lo vincule en Veterinarios.
            </p>
          )}
          {children}
        </div>
      </main>
      <Suspense fallback={null}><Aviso /></Suspense>
    </div>
  );
}
