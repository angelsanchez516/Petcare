"use client";

import { usePathname, useRouter, useSearchParams } from "next/navigation";
import { useEffect } from "react";

/** Mensaje de éxito. Las acciones vuelven a la página con ?ok=texto; este
 *  componente lo muestra unos segundos y limpia la URL. */
export function Aviso() {
  const parametros = useSearchParams();
  const ruta = usePathname();
  const router = useRouter();
  const texto = parametros.get("ok");

  useEffect(() => {
    if (!texto) return;
    const t = setTimeout(() => {
      const q = new URLSearchParams(parametros);
      q.delete("ok");
      router.replace(q.size ? `${ruta}?${q}` : ruta, { scroll: false });
    }, 4000);
    return () => clearTimeout(t);
  }, [texto, parametros, ruta, router]);

  if (!texto) return null;
  return (
    <div role="status" className="no-imprimir fixed bottom-5 right-5 z-50 max-w-sm animate-aparecer rounded-lg bg-verde-800 px-4 py-3 text-sm text-white shadow-alta">
      {texto}
    </div>
  );
}
