import Link from "next/link";
import { Barras } from "@/components/admin/Barras";
import { Avatar, Cabecera, Cifra, EstadoDe, Seccion, Vacio } from "@/components/ui";
import { exigir } from "@/lib/auth";
import { ESTADOS_CITA } from "@/lib/etiquetas";
import { dinero, fechaLarga, hora, relativo } from "@/lib/formato";
import { puede, puedeAgendar, puedeFirmar } from "@/lib/permisos";
import {
  alertasTablero, cifrasTablero, citasDeHoy, consultasRecientes, ingresosRecientes, mascotasPorEspecie,
} from "@/lib/repos/tablero";

export const metadata = { title: "Tablero" };

const NOMBRE_MES = new Intl.DateTimeFormat("es-CO", { month: "short", year: "numeric" });

export default async function Tablero() {
  const usuario = await exigir("tablero");
  const verClinica = puede(usuario.rol, "clinica");
  const verFacturas = puede(usuario.rol, "facturas");
  const verSolicitudes = puede(usuario.rol, "solicitudes");
  const esVeterinario = usuario.rol === "Veterinario";

  // Sin perfil vinculado el 0 no coincide con nadie: «Mis citas» sale vacío, no con las de toda la clínica.
  const vetPropio = esVeterinario ? usuario.veterinario_id ?? 0 : null;
  const [c, a, citas, recientes, ingresos, especies] = await Promise.all([
    cifrasTablero(vetPropio), alertasTablero(vetPropio), citasDeHoy(vetPropio),
    verClinica ? consultasRecientes() : [],
    verFacturas ? ingresosRecientes() : [],
    mascotasPorEspecie(),
  ]);

  const alertas = [
    { n: a?.citas_sin_cerrar, texto: "citas pasadas sin cerrar", href: "/admin/citas?pendientes=1", ver: true, urgente: true },
    { n: a?.vacunas_vencidas, texto: "refuerzos de vacuna vencidos", href: "/admin/vacunas?estado=VENCIDA", ver: true, urgente: true },
    { n: a?.vacunas_proximas, texto: "refuerzos en los próximos 30 días", href: "/admin/vacunas?estado=PROXIMA", ver: true },
    { n: a?.solicitudes, texto: "solicitudes web sin atender", href: "/admin/solicitudes", ver: verSolicitudes },
    { n: a?.por_cobrar, texto: "facturas con saldo por cobrar", href: "/admin/facturas?estado=abiertas", ver: verFacturas },
    { n: a?.stock_bajo, texto: "medicamentos con stock bajo", href: "/admin/catalogos/medicamentos", ver: puede(usuario.rol, "catalogos") },
  ].filter((x) => x.ver && x.n > 0);

  return (
    <>
      <Cabecera titulo={`Hola, ${usuario.nombre}`} subtitulo={<span className="inline-block first-letter:uppercase">{fechaLarga(new Date())}</span>}>
        {puedeAgendar(usuario) && <Link href="/admin/citas/nueva" className="btn btn-md btn-secundario">Agendar cita</Link>}
        {puedeFirmar(usuario) && <Link href="/admin/consultas/nueva" className="btn btn-md btn-secundario">Nueva consulta</Link>}
        {verFacturas && <Link href="/admin/facturas/nueva" className="btn btn-md btn-secundario">Nueva factura</Link>}
        <Link href="/admin/mascotas/nueva" className="btn btn-md btn-primario">Nueva mascota</Link>
      </Cabecera>

      <div className="grid grid-cols-2 gap-3 md:grid-cols-3 xl:grid-cols-6">
        <Cifra etiqueta={esVeterinario ? "Mis citas de hoy" : "Citas de hoy"} valor={c?.citas_hoy} href="/admin/citas" />
        <Cifra etiqueta="Mascotas activas" valor={c?.mascotas} href="/admin/mascotas" />
        <Cifra etiqueta="Tutores activos" valor={c?.clientes} href="/admin/clientes" />
        {verClinica
          ? <Cifra etiqueta="Consultas del mes" valor={c?.consultas_mes} href="/admin/consultas" />
          : <Cifra etiqueta="Consultas del mes" valor={c?.consultas_mes} />}
        <Cifra etiqueta="Refuerzos por atender" valor={c?.refuerzos} href="/admin/vacunas" alerta={c?.refuerzos > 0} />
        {verFacturas && <Cifra etiqueta="Cobrado este mes" valor={dinero(c?.ingresos_mes)} nota="Pagos recibidos" href={puede(usuario.rol, "reportes") ? "/admin/reportes" : undefined} />}
      </div>

      <div className="mt-5 grid gap-5 lg:grid-cols-3">
        <Seccion titulo={esVeterinario ? "Mis citas de hoy" : "Citas de hoy"} sinRelleno className="lg:col-span-2"
          accion={<Link href="/admin/citas" className="text-sm text-verde-700 hover:underline">Ver agenda</Link>}>
          {citas.length === 0 ? <Vacio titulo={esVeterinario ? "No tienes citas para hoy" : "No hay citas para hoy"} texto="Las citas agendadas para este día aparecerán aquí." /> : (
            <ul className="divide-y divide-gris-200">
              {citas.map((x) => (
                <li key={x.cita_id}>
                  <Link href={`/admin/citas/${x.cita_id}`} className="flex items-center gap-3 px-5 py-3 hover:bg-verde-50/60">
                    <span className="w-12 shrink-0 text-sm font-medium text-tinta cifra">{hora(x.fecha_hora_inicio)}</span>
                    <Avatar foto={x.mascota_foto} nombre={x.mascota} icono={x.especie_icono} tam={36} />
                    <span className="min-w-0 flex-1">
                      <span className="block truncate text-sm font-medium text-tinta">{x.mascota} · {x.motivo}</span>
                      <span className="block truncate text-xs text-gris-600">{x.tutor} · {x.veterinario}</span>
                    </span>
                    <EstadoDe mapa={ESTADOS_CITA} valor={x.estado} />
                  </Link>
                </li>
              ))}
            </ul>
          )}
        </Seccion>

        <Seccion titulo="Requiere atención" sinRelleno>
          {alertas.length === 0 ? <Vacio titulo="Todo al día" texto="No hay pendientes que revisar." /> : (
            <ul className="divide-y divide-gris-200">
              {alertas.map((x) => (
                <li key={x.href}>
                  <Link href={x.href} className="flex items-center gap-3 px-5 py-3 text-sm hover:bg-verde-50/60">
                    <span className={`insignia ${x.urgente ? "insignia-roja" : "insignia-ambar"} cifra`}>{x.n}</span>
                    <span className="text-gris-700">{x.texto}</span>
                  </Link>
                </li>
              ))}
            </ul>
          )}
        </Seccion>

        {verClinica && (
          <Seccion titulo="Consultas recientes" sinRelleno className="lg:col-span-2">
            {recientes.length === 0 ? <Vacio titulo="Aún no hay consultas" /> : (
              <ul className="divide-y divide-gris-200">
                {recientes.map((k) => (
                  <li key={k.id}>
                    <Link href={`/admin/consultas/${k.id}`} className="flex items-center gap-3 px-5 py-3 hover:bg-verde-50/60">
                      <Avatar foto={k.foto_url} nombre={k.mascota} icono={k.icono} tam={36} />
                      <span className="min-w-0 flex-1">
                        <span className="block truncate text-sm font-medium text-tinta">{k.mascota} · {k.motivo}</span>
                        <span className="block truncate text-xs text-gris-600">{k.veterinario}</span>
                      </span>
                      <span className="shrink-0 text-xs text-gris-600">{relativo(k.fecha_hora)}</span>
                    </Link>
                  </li>
                ))}
              </ul>
            )}
          </Seccion>
        )}

        {verFacturas && (
          <Seccion titulo="Facturado por mes" className={verClinica ? "" : "lg:col-span-2"}>
            {ingresos.length === 0 ? <Vacio titulo="Sin facturas todavía" /> : (
              <Barras datos={[...ingresos].reverse().map((i) => ({
                etiqueta: NOMBRE_MES.format(new Date(i.mes)), valor: Number(i.facturado), texto: dinero(i.facturado),
              }))} />
            )}
          </Seccion>
        )}

        <Seccion titulo="Mascotas por especie">
          <Barras datos={especies.map((e) => ({ etiqueta: e.nombre, valor: e.total, texto: String(e.total) }))} />
        </Seccion>
      </div>
    </>
  );
}
