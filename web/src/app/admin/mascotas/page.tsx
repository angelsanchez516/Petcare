import Link from "next/link";
import { Avatar, Cabecera, Entrada, EstadoDe, Filtros, Insignia, paginaDe, Selector, Vacio } from "@/components/ui";
import { exigir } from "@/lib/auth";
import { ESTADOS_VACUNA } from "@/lib/etiquetas";
import { edad, numero } from "@/lib/formato";
import { especies, listarMascotas, MASCOTAS_POR_PAGINA } from "@/lib/repos/mascotas";

export const metadata = { title: "Mascotas" };

export default async function Mascotas({ searchParams }: { searchParams: Promise<Record<string, string>> }) {
  await exigir("mascotas");
  const { q = "", especie = "", vacuna = "", estado = "activas", pag } = await searchParams;
  const pagina = paginaDe(pag);
  const [{ filas, total }, listaEspecies] = await Promise.all([
    listarMascotas(q, especie, vacuna, estado, pagina), especies(),
  ]);
  const paginas = Math.ceil(total / MASCOTAS_POR_PAGINA);
  const enlace = (n: number) => `/admin/mascotas?${new URLSearchParams({ q, especie, vacuna, estado, pag: String(n) })}`;

  return (
    <>
      <Cabecera titulo="Mascotas" subtitulo={`${total} pacientes`}>
        <Link href="/admin/mascotas/nueva" className="btn btn-md btn-primario">Nueva mascota</Link>
      </Cabecera>

      <Filtros>
        <div className="min-w-52 flex-1"><Entrada etiqueta="Buscar" name="q" defaultValue={q} placeholder="Mascota, tutor o microchip" /></div>
        <div className="w-36"><Selector etiqueta="Especie" name="especie" defaultValue={especie} opciones={listaEspecies} vacio="Todas" /></div>
        <div className="w-36"><Selector etiqueta="Vacunación" name="vacuna" defaultValue={vacuna} vacio="Todas"
          opciones={Object.fromEntries(Object.entries(ESTADOS_VACUNA).map(([k, v]) => [k, v.texto]))} /></div>
        <div className="w-32"><Selector etiqueta="Estado" name="estado" defaultValue={estado} opciones={{ activas: "Activas", todas: "Todas" }} /></div>
      </Filtros>

      {filas.length === 0 ? (
        <div className="tarjeta"><Vacio titulo="No hay mascotas que coincidan" texto="Cambia los filtros o registra una nueva." /></div>
      ) : (
        <ul className="grid gap-4 sm:grid-cols-2 xl:grid-cols-3">
          {filas.map((m) => (
            <li key={m.id}>
              <Link href={`/admin/mascotas/${m.id}`} className="tarjeta block h-full p-4 transition-colors hover:border-verde-200 hover:bg-verde-50/40">
                <div className="flex items-center gap-3">
                  <Avatar foto={m.foto_url} nombre={m.nombre} icono={m.especie_icono} tam={52} />
                  <div className="min-w-0">
                    <p className="truncate font-semibold text-tinta">{m.nombre}</p>
                    <p className="truncate text-xs text-gris-600">{m.especie} · {m.raza ?? "Sin raza definida"}</p>
                  </div>
                  {!m.activo && <span className="ml-auto"><Insignia>De baja</Insignia></span>}
                </div>
                <dl className="mt-4 grid grid-cols-3 gap-2 border-t border-gris-200 pt-3 text-xs">
                  <div><dt className="text-gris-600">Edad</dt><dd className="mt-0.5 font-medium text-tinta">{edad(m.edad_anios, m.edad_meses).replace(/ y .*/, "")}</dd></div>
                  <div><dt className="text-gris-600">Sexo</dt><dd className="mt-0.5 font-medium text-tinta">{m.sexo_texto}</dd></div>
                  <div><dt className="text-gris-600">Peso</dt><dd className="mt-0.5 font-medium text-tinta cifra">{numero(m.peso_actual_kg, " kg")}</dd></div>
                </dl>
                <div className="mt-3 flex items-center justify-between gap-2">
                  <span className="truncate text-xs text-gris-600">{m.tutor}</span>
                  <EstadoDe mapa={ESTADOS_VACUNA} valor={m.vacuna_estado} />
                </div>
              </Link>
            </li>
          ))}
        </ul>
      )}

      {paginas > 1 && (
        <nav aria-label="Paginación" className="mt-4 flex items-center justify-between text-sm text-gris-600">
          <span>Página {pagina} de {paginas}</span>
          <span className="flex gap-2">
            {pagina > 1 && <Link href={enlace(pagina - 1)} className="btn btn-sm btn-secundario">Anterior</Link>}
            {pagina < paginas && <Link href={enlace(pagina + 1)} className="btn btn-sm btn-secundario">Siguiente</Link>}
          </span>
        </nav>
      )}
    </>
  );
}
