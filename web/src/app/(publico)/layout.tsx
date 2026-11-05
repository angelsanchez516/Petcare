import { Navegacion } from "@/components/web/Navegacion";
import { PieDePagina } from "@/components/web/PieDePagina";

export default function LayoutPublico({ children }: { children: React.ReactNode }) {
  return (
    <div className="flex min-h-dvh flex-col">
      <a
        href="#contenido"
        className="sr-only focus:not-sr-only focus:absolute focus:z-[60] focus:left-4 focus:top-4
                   focus:rounded-lg focus:bg-verde-700 focus:px-4 focus:py-2 focus:text-sm focus:text-white"
      >
        Saltar al contenido
      </a>
      <Navegacion />
      <main id="contenido" className="flex-1">{children}</main>
      <PieDePagina />
    </div>
  );
}
