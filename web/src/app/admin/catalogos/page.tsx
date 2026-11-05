import Link from "next/link";
import { Cabecera } from "@/components/ui";
import { exigir } from "@/lib/auth";
import { CATALOGOS } from "@/lib/catalogos";
import { contarStockBajo } from "@/lib/repos/catalogos";

export const metadata = { title: "Catálogos" };

export default async function Catalogos() {
  await exigir("catalogos");
  const stock = await contarStockBajo();
  return (
    <>
      <Cabecera titulo="Catálogos" subtitulo="Datos de referencia que usan los demás módulos" />
      <ul className="grid gap-4 sm:grid-cols-2 xl:grid-cols-3">
        {Object.entries(CATALOGOS).map(([clave, c]) => (
          <li key={clave}>
            <Link href={`/admin/catalogos/${clave}`} className="tarjeta block h-full p-4 hover:border-verde-200 hover:bg-verde-50/40">
              <p className="font-semibold text-tinta">
                {c.titulo}
                {clave === "medicamentos" && !!stock?.n && <span className="insignia insignia-ambar ml-2">{stock.n} con stock bajo</span>}
              </p>
              <p className="mt-1 text-sm text-gris-600">{c.descripcion}</p>
            </Link>
          </li>
        ))}
      </ul>
    </>
  );
}
