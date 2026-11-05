import Link from "next/link";
import { Avatar, Cabecera, EstadoDe, Seccion, Selector, Vacio } from "@/components/ui";
import { exigir } from "@/lib/auth";
import { ESTADOS_CITA } from "@/lib/etiquetas";
import { fechaHora, fechaLarga, hora, paraInput } from "@/lib/formato";
import { puedeAgendar } from "@/lib/permisos";
import { citasDelDia, citasSinCerrar, conteoDelMes, opcionesVeterinarios } from "@/lib/repos/citas";

export const metadata = { title: "Agenda" };

const SEMANA = ["Lun", "Mar", "Mié", "Jue", "Vie", "Sáb", "Dom"];
const MES = new Intl.DateTimeFormat("es-CO", { month: "long", year: "numeric" });

export default async function Agenda({ searchParams }: { searchParams: Promise<Record<string, string>> }) {
  const usuario = await exigir("citas");
  const { dia: diaParam = "", vet: vetParam, pendientes } = await searchParams;

  // El veterinario entra a su propia agenda. Si elige «Todos» llega vet vacío y ve la
  // de toda la clínica, pero las citas ajenas se abren solo para consulta.
  const esVeterinario = usuario.rol === "Veterinario";
  const propio = usuario.veterinario_id ? String(usuario.veterinario_id) : "";
  const vet = vetParam ?? (esVeterinario ? propio : "");
  const misCitas = esVeterinario && propio !== "" && vet === propio;

  const hoy = paraInput(new Date());
  const dia = /^\d{4}-\d{2}-\d{2}$/.test(diaParam) && !Number.isNaN(new Date(`${diaParam}T12:00`).getTime()) ? diaParam : hoy;
  const seleccionado = new Date(`${dia}T12:00`);
  const primero = new Date(seleccionado.getFullYear(), seleccionado.getMonth(), 1);

  const [citas, conteo, veterinarios, sinCerrar] = await Promise.all([
    citasDelDia(dia, vet), conteoDelMes(paraInput(primero), vet), opcionesVeterinarios(),
    citasSinCerrar(esVeterinario ? usuario.veterinario_id ?? 0 : null),
  ]);
  const porDia = new Map(conteo.map((c) => [c.dia, c.total]));

  // Celdas del calendario: los huecos iniciales hacen que el día 1 caiga en su columna.
  const huecos = (primero.getDay() + 6) % 7;
  const totalDias = new Date(primero.getFullYear(), primero.getMonth() + 1, 0).getDate();
  const dias = Array.from({ length: totalDias }, (_, i) => paraInput(new Date(primero.getFullYear(), primero.getMonth(), i + 1)));

  const enlace = (d: string) => `/admin/citas?${new URLSearchParams({ dia: d, ...(vetParam !== undefined ? { vet: vetParam } : {}) })}`;
  const mesVecino = (n: number) => paraInput(new Date(primero.getFullYear(), primero.getMonth() + n, 1));

  return (
    <>
      <Cabecera titulo={misCitas ? "Mi agenda" : "Agenda"} subtitulo={misCitas ? "Tus citas por día" : "Citas por día y por veterinario"}>
        {puedeAgendar(usuario) && <Link href="/admin/citas/nueva" className="btn btn-md btn-primario">Agendar cita</Link>}
      </Cabecera>

      {esVeterinario && !misCitas && (
        <p className="mb-5 rounded-lg bg-gris-100 px-4 py-2.5 text-sm text-gris-700">
          Estás viendo citas de otros profesionales. Solo puedes modificar las tuyas.{" "}
          {propio && <Link href="/admin/citas" className="text-verde-700 hover:underline">Volver a mi agenda</Link>}
        </p>
      )}

      {sinCerrar.length > 0 && (
        <Seccion titulo={`Pendientes de cerrar (${sinCerrar.length})`} sinRelleno className="mb-5">
          {pendientes ? (
            <ul className="divide-y divide-gris-200">
              {sinCerrar.map((c) => (
                <li key={c.cita_id}>
                  <Link href={`/admin/citas/${c.cita_id}`} className="flex flex-wrap items-center gap-x-3 gap-y-1 px-5 py-2.5 text-sm hover:bg-verde-50/60">
                    <span className="font-medium text-tinta">{c.mascota}</span>
                    <span className="text-gris-600">{fechaHora(c.fecha_hora_inicio)} · {c.veterinario}</span>
                    <span className="ml-auto"><EstadoDe mapa={ESTADOS_CITA} valor={c.estado} /></span>
                  </Link>
                </li>
              ))}
            </ul>
          ) : (
            <p className="px-5 py-3 text-sm text-gris-700">
              Hay citas cuya hora ya pasó y siguen abiertas.{" "}
              <Link href={`/admin/citas?${new URLSearchParams({ dia, vet, pendientes: "1" })}`} className="text-verde-700 hover:underline">Ver cuáles son</Link>
            </p>
          )}
        </Seccion>
      )}

      <form method="get" className="no-imprimir mb-4 flex flex-wrap items-end gap-2">
        <input type="hidden" name="dia" value={dia} />
        <div className="w-64"><Selector etiqueta="Veterinario" name="vet" defaultValue={vet} opciones={veterinarios} vacio={esVeterinario ? "Todos (solo consulta)" : "Todos"} /></div>
        <button className="btn btn-md btn-secundario">Filtrar</button>
      </form>

      <div className="grid gap-5 lg:grid-cols-5">
        <Seccion className="lg:col-span-2" titulo={<span className="inline-block first-letter:uppercase">{MES.format(primero)}</span>}
          accion={
            <span className="flex gap-1">
              <Link href={enlace(mesVecino(-1))} className="btn btn-sm btn-secundario" aria-label="Mes anterior">‹</Link>
              <Link href={enlace(hoy)} className="btn btn-sm btn-secundario">Hoy</Link>
              <Link href={enlace(mesVecino(1))} className="btn btn-sm btn-secundario" aria-label="Mes siguiente">›</Link>
            </span>
          }>
          <div className="grid grid-cols-7 gap-1 text-center">
            {SEMANA.map((s) => <span key={s} className="pb-1 text-[11px] font-semibold uppercase text-gris-600">{s}</span>)}
            {Array.from({ length: huecos }, (_, i) => <span key={`h${i}`} />)}
            {dias.map((d) => {
              const n = porDia.get(d);
              const elegido = d === dia;
              return (
                <Link key={d} href={enlace(d)} aria-current={elegido ? "date" : undefined}
                  aria-label={`${d}${n ? `, ${n} citas` : ""}`}
                  className={`flex aspect-square flex-col items-center justify-center rounded-lg text-sm cifra ${
                    elegido ? "bg-verde-700 text-white" : d === hoy ? "bg-verde-100 text-verde-900" : "text-gris-700 hover:bg-gris-100"
                  }`}>
                  {Number(d.slice(-2))}
                  <span className={`text-[10px] leading-none ${elegido ? "text-verde-100" : "text-verde-700"}`}>{n ?? " "}</span>
                </Link>
              );
            })}
          </div>
        </Seccion>

        <Seccion className="lg:col-span-3" sinRelleno titulo={<span className="inline-block first-letter:uppercase">{fechaLarga(seleccionado)}</span>}>
          {citas.length === 0 ? <Vacio titulo={misCitas ? "No tienes citas este día" : "No hay citas este día"} /> : (
            <ul className="divide-y divide-gris-200">
              {citas.map((c) => (
                <li key={c.cita_id}>
                  <Link href={`/admin/citas/${c.cita_id}`} className="flex items-center gap-3 px-5 py-3 hover:bg-verde-50/60">
                    <span className="w-11 shrink-0 text-sm font-medium text-tinta cifra">{hora(c.fecha_hora_inicio)}</span>
                    <Avatar foto={c.mascota_foto} nombre={c.mascota} icono={c.especie_icono} tam={36} />
                    <span className="min-w-0 flex-1">
                      <span className="block truncate text-sm font-medium text-tinta">{c.mascota} · {c.motivo}</span>
                      <span className="block truncate text-xs text-gris-600">{c.tutor} · {c.veterinario}</span>
                    </span>
                    <EstadoDe mapa={ESTADOS_CITA} valor={c.estado} />
                  </Link>
                </li>
              ))}
            </ul>
          )}
        </Seccion>
      </div>
    </>
  );
}
