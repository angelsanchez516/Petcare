"use client";

import Link from "next/link";
import { usePathname } from "next/navigation";
import { useEffect, useState } from "react";
import { Logo } from "@/components/Logo";
import { puede, type Permiso } from "@/lib/permisos";

const GRUPOS: { titulo?: string; enlaces: { href: string; texto: string; permiso: Permiso; id: string }[] }[] = [
  { enlaces: [{ href: "/admin", texto: "Tablero", permiso: "tablero", id: "tablero" }] },
  {
    titulo: "Atención",
    enlaces: [
      { href: "/admin/citas", texto: "Agenda", permiso: "citas", id: "citas" },
      { href: "/admin/solicitudes", texto: "Solicitudes web", permiso: "solicitudes", id: "solicitudes" },
      { href: "/admin/mascotas", texto: "Mascotas", permiso: "mascotas", id: "mascotas" },
      { href: "/admin/clientes", texto: "Tutores", permiso: "clientes", id: "clientes" },
    ],
  },
  {
    titulo: "Clínica",
    enlaces: [
      { href: "/admin/consultas", texto: "Consultas", permiso: "clinica", id: "consultas" },
      { href: "/admin/tratamientos", texto: "Tratamientos", permiso: "clinica", id: "tratamientos" },
      { href: "/admin/recetas", texto: "Recetas", permiso: "clinica", id: "recetas" },
      { href: "/admin/vacunas", texto: "Vacunación", permiso: "vacunas", id: "vacunas" },
    ],
  },
  {
    titulo: "Administración",
    enlaces: [
      { href: "/admin/facturas", texto: "Facturación", permiso: "facturas", id: "facturas" },
      { href: "/admin/reportes", texto: "Reportes", permiso: "reportes", id: "reportes" },
      { href: "/admin/catalogos", texto: "Catálogos", permiso: "catalogos", id: "catalogos" },
      { href: "/admin/veterinarios", texto: "Veterinarios", permiso: "personal", id: "veterinarios" },
      { href: "/admin/usuarios", texto: "Usuarios", permiso: "personal", id: "usuarios" },
    ],
  },
];

export function BarraLateral({ rol, nombre, salir, pendientes }: {
  rol: string;
  nombre: string;
  salir: () => Promise<void>;
  pendientes: number;
}) {
  const ruta = usePathname();
  const [abierta, setAbierta] = useState(false);
  useEffect(() => setAbierta(false), [ruta]);

  const activo = (href: string) => (href === "/admin" ? ruta === href : ruta.startsWith(href));

  return (
    <>
      {/* Barra superior en móvil y tableta */}
      <div className="no-imprimir sticky top-0 z-30 flex h-14 items-center justify-between bg-verde-900 px-4 text-white lg:hidden">
        <Link href="/admin" className="flex items-center gap-2">
          <Logo className="h-7 w-7 text-white" />
          <span className="font-display text-xl">PetCare</span>
        </Link>
        <button type="button" onClick={() => setAbierta((v) => !v)} aria-expanded={abierta}
          aria-label={abierta ? "Cerrar menú" : "Abrir menú"} className="btn btn-sm border border-verde-700 text-white">
          Menú
        </button>
      </div>

      {abierta && <div onClick={() => setAbierta(false)} className="fixed inset-0 z-30 bg-tinta/40 lg:hidden" aria-hidden="true" />}

      <aside className={`no-imprimir fixed inset-y-0 left-0 z-40 flex w-60 flex-col bg-verde-900 text-white transition-transform lg:translate-x-0 ${abierta ? "translate-x-0" : "-translate-x-full"}`}>
        <Link href="/admin" className="flex h-16 shrink-0 items-center gap-2.5 px-5">
          <Logo className="h-8 w-8 text-white" />
          <span>
            <span className="block font-display text-xl leading-none">PetCare</span>
            <span className="text-[11px] text-verde-200">Sistema clínico</span>
          </span>
        </Link>

        <nav className="flex-1 space-y-5 overflow-y-auto px-3 py-3 [scrollbar-color:rgb(var(--verde-700))_transparent] [scrollbar-width:thin]">
          {GRUPOS.map((g, i) => {
            const enlaces = g.enlaces.filter((e) => puede(rol, e.permiso));
            if (enlaces.length === 0) return null;
            return (
              <div key={i}>
                {g.titulo && (
                  <p className="mb-1 px-2 text-[11px] font-semibold uppercase tracking-wider text-verde-200/70">{g.titulo}</p>
                )}
                <ul className="space-y-0.5">
                  {enlaces.map((e) => (
                    <li key={e.href}>
                      <Link href={e.href} aria-current={activo(e.href) ? "page" : undefined}
                        className={`flex items-center justify-between rounded-lg px-2.5 py-2 text-sm transition-colors ${
                          activo(e.href) ? "bg-verde-700 font-medium text-white" : "text-verde-100 hover:bg-verde-800"
                        }`}>
                        {e.texto}
                        {e.id === "solicitudes" && pendientes > 0 && (
                          <span className="rounded-full bg-ambar-500 px-1.5 text-[11px] font-semibold text-white">{pendientes}</span>
                        )}
                      </Link>
                    </li>
                  ))}
                </ul>
              </div>
            );
          })}
        </nav>

        <div className="border-t border-verde-800 p-3">
          <p className="truncate px-2 text-sm font-medium">{nombre}</p>
          <p className="px-2 text-xs text-verde-200">{rol}</p>
          <div className="mt-2 flex gap-1">
            <Link href="/" className="btn btn-sm flex-1 text-verde-100 hover:bg-verde-800">Ver sitio</Link>
            <form action={salir} className="flex-1">
              <button className="btn btn-sm w-full text-verde-100 hover:bg-verde-800">Cerrar sesión</button>
            </form>
          </div>
        </div>
      </aside>
    </>
  );
}
