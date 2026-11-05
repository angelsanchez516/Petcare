"use client";

import Link from "next/link";
import { usePathname } from "next/navigation";
import { useEffect, useState } from "react";
import { Logo } from "@/components/Logo";

const ENLACES = [
  { href: "/", texto: "Inicio" },
  { href: "/servicios", texto: "Servicios" },
  { href: "/equipo", texto: "Equipo" },
  { href: "/nosotros", texto: "La clínica" },
  { href: "/cuidados", texto: "Cuidado de mascotas" },
  { href: "/contacto", texto: "Contacto" },
];

export function Navegacion() {
  const ruta = usePathname();
  const [abierto, setAbierto] = useState(false);
  const [desplazado, setDesplazado] = useState(false);

  // La barra gana fondo sólido y sombra al despegarse del borde superior, para
  // que el texto no compita con la fotografía del encabezado.
  useEffect(() => {
    const alDesplazar = () => setDesplazado(window.scrollY > 16);
    alDesplazar();
    window.addEventListener("scroll", alDesplazar, { passive: true });
    return () => window.removeEventListener("scroll", alDesplazar);
  }, []);

  // Cerrar el menú al navegar evita que quede abierto sobre la página nueva.
  useEffect(() => setAbierto(false), [ruta]);

  const activo = (href: string) =>
    href === "/" ? ruta === "/" : ruta.startsWith(href);

  return (
    <header
      className={`sticky top-0 z-50 transition-all duration-200 ${
        desplazado
          ? "bg-white/95 backdrop-blur-sm border-b border-gris-200 shadow-suave"
          : "bg-white/80 backdrop-blur-sm border-b border-transparent"
      }`}
    >
      <nav className="contenedor-web flex h-16 items-center justify-between gap-6">
        <Link href="/" className="flex items-center gap-2.5 shrink-0" aria-label="PetCare, inicio">
          <Logo className="h-8 w-8 text-verde-700" />
          <span className="font-display text-[22px] leading-none text-verde-900">
            PetCare
          </span>
        </Link>

        <ul className="hidden md:flex items-center gap-1">
          {ENLACES.map((e) => (
            <li key={e.href}>
              <Link
                href={e.href}
                aria-current={activo(e.href) ? "page" : undefined}
                className={`px-3 py-2 rounded-lg text-sm transition-colors ${
                  activo(e.href)
                    ? "text-verde-800 font-medium bg-verde-50"
                    : "text-gris-700 hover:text-verde-800 hover:bg-gris-100"
                }`}
              >
                {e.texto}
              </Link>
            </li>
          ))}
        </ul>

        <div className="hidden md:flex items-center gap-2">
          <Link href="/ingresar" className="btn btn-sm btn-fantasma">
            Acceso
          </Link>
          <Link href="/agendar" className="btn btn-md btn-primario">
            Agendar cita
          </Link>
        </div>

        <button
          type="button"
          onClick={() => setAbierto((v) => !v)}
          aria-expanded={abierto}
          aria-controls="menu-movil"
          aria-label={abierto ? "Cerrar menú" : "Abrir menú"}
          className="md:hidden -mr-2 p-2 rounded-lg text-gris-700 hover:bg-gris-100"
        >
          <svg width="22" height="22" viewBox="0 0 24 24" fill="none" aria-hidden="true">
            {abierto ? (
              <path d="M6 6l12 12M18 6L6 18" stroke="currentColor" strokeWidth="1.8" strokeLinecap="round" />
            ) : (
              <path d="M3.5 7h17M3.5 12h17M3.5 17h17" stroke="currentColor" strokeWidth="1.8" strokeLinecap="round" />
            )}
          </svg>
        </button>
      </nav>

      {abierto && (
        <div id="menu-movil" className="md:hidden border-t border-gris-200 bg-white animate-aparecer">
          <ul className="contenedor-web py-2">
            {ENLACES.map((e) => (
              <li key={e.href}>
                <Link
                  href={e.href}
                  className={`block px-2 py-3 rounded-lg text-[15px] ${
                    activo(e.href) ? "text-verde-800 font-medium" : "text-gris-700"
                  }`}
                >
                  {e.texto}
                </Link>
              </li>
            ))}
          </ul>
          <div className="contenedor-web pb-4 flex flex-col gap-2">
            <Link href="/agendar" className="btn btn-md btn-primario w-full">
              Agendar cita
            </Link>
            <Link href="/ingresar" className="btn btn-md btn-secundario w-full">
              Acceso
            </Link>
          </div>
        </div>
      )}
    </header>
  );
}
