import Link from "next/link";
import { notFound } from "next/navigation";
import { BotonAccion } from "@/components/Formulario";
import { Cabecera, Dato, EstadoDe, idDe, Insignia, Seccion } from "@/components/ui";
import { exigir } from "@/lib/auth";
import { ESTADOS_CITA } from "@/lib/etiquetas";
import { fechaHora, hora } from "@/lib/formato";
import { puede, puedeGestionarCita } from "@/lib/permisos";
import { obtenerCita } from "@/lib/repos/citas";
import { cancelar, confirmar, noAsistio } from "../acciones";

export const metadata = { title: "Detalle de la cita" };

export default async function DetalleCita({ params }: { params: Promise<{ id: string }> }) {
  const usuario = await exigir("citas");
  const id = idDe((await params).id);
  const c = id && await obtenerCita(id);
  if (!c || !id) notFound();

  const gestiona = puedeGestionarCita(usuario, c.veterinario_id);
  const abierta = c.estado === "programada" || c.estado === "confirmada";
  const editable = abierta && gestiona;
  const yaPaso = new Date(c.fecha_hora_inicio) <= new Date();
  const sinCerrar = editable && new Date(c.fecha_hora_fin) < new Date();
  const hoyOAntes = new Date(c.fecha_hora_inicio).setHours(0, 0, 0, 0) <= Date.now();

  return (
    <>
      <Cabecera titulo={<>Cita de {c.mascota} <EstadoDe mapa={ESTADOS_CITA} valor={c.estado} /></>}
        subtitulo={fechaHora(c.fecha_hora_inicio)}
        migas={[{ texto: "Agenda", href: "/admin/citas" }, { texto: c.mascota }]}>
        {editable && c.mascota_atendible && <Link href={`/admin/citas/${id}/editar`} className="btn btn-md btn-secundario">Reprogramar</Link>}
        {gestiona && c.estado === "programada" && c.mascota_atendible && <BotonAccion accion={confirmar} campos={{ id }} texto="Confirmar" tam="btn-md" />}
        {editable && yaPaso && (
          <BotonAccion accion={noAsistio} campos={{ id }} texto="No asistió" tam="btn-md"
            confirmar={`Se registrará que ${c.mascota} no asistió a esta cita.`} />
        )}
        {editable && (
          <BotonAccion accion={cancelar} campos={{ id }} texto="Cancelar cita" tam="btn-md" clase="btn-peligro"
            confirmar="La cita queda registrada como cancelada y el horario se libera." motivo="Motivo de la cancelación" />
        )}
        {abierta && hoyOAntes && c.mascota_atendible && puede(usuario.rol, "clinica") && usuario.veterinario_id === c.veterinario_id && (
          <Link href={`/admin/consultas/nueva?mascota=${c.mascota_id}&cita=${id}`} className="btn btn-md btn-primario">Atender</Link>
        )}
      </Cabecera>

      {!gestiona && (
        <p className="mb-5 rounded-lg bg-gris-100 px-4 py-2.5 text-sm text-gris-700">
          Esta cita es de {c.veterinario}. Puedes consultarla, pero no modificarla.
        </p>
      )}

      {abierta && !c.mascota_atendible && (
        <p role="alert" className="mb-5 rounded-lg border border-alerta-600/20 bg-alerta-100 px-4 py-2.5 text-sm text-alerta-600">
          {c.mascota} está dada de baja o falleció y esta cita sigue abierta. Conviene cancelarla para liberar el horario.
        </p>
      )}

      {sinCerrar && c.mascota_atendible && (
        <p role="alert" className="mb-5 rounded-lg border border-alerta-600/20 bg-alerta-100 px-4 py-2.5 text-sm text-alerta-600">
          La hora de esta cita ya pasó y sigue abierta. Registra la consulta, marca la inasistencia o cancélala.
        </p>
      )}

      <div className="grid gap-5 md:grid-cols-2">
        <Seccion titulo="Datos de la cita">
          <dl className="grid grid-cols-2 gap-4">
            <Dato etiqueta="Horario">{hora(c.fecha_hora_inicio)} a {hora(c.fecha_hora_fin)} ({c.duracion_minutos} min)</Dato>
            <Dato etiqueta="Veterinario">{c.veterinario}</Dato>
            <Dato etiqueta="Servicio">{c.servicio}</Dato>
            <Dato etiqueta="Motivo">{c.motivo}</Dato>
            {c.notas && <Dato etiqueta="Notas">{c.notas}</Dato>}
            {c.motivo_cancelacion && <Dato etiqueta="Motivo de cancelación">{c.motivo_cancelacion}</Dato>}
          </dl>
        </Seccion>
        <Seccion titulo="Paciente y tutor">
          <dl className="grid grid-cols-2 gap-4">
            <Dato etiqueta="Mascota"><Link href={`/admin/mascotas/${c.mascota_id}`} className="text-verde-700 hover:underline">{c.mascota}</Link> ({c.especie})</Dato>
            <Dato etiqueta="Tutor"><Link href={`/admin/clientes/${c.cliente_id}`} className="text-verde-700 hover:underline">{c.tutor}</Link></Dato>
            <Dato etiqueta="Teléfono"><a href={`tel:${c.tutor_telefono}`} className="text-verde-700 hover:underline">{c.tutor_telefono}</a></Dato>
            {c.consulta_id && puede(usuario.rol, "clinica") && (
              <Dato etiqueta="Consulta"><Link href={`/admin/consultas/${c.consulta_id}`} className="text-verde-700 hover:underline">Ver la consulta</Link></Dato>
            )}
            {c.consulta_id && !puede(usuario.rol, "clinica") && <Dato etiqueta="Consulta"><Insignia tono="verde">Registrada</Insignia></Dato>}
          </dl>
        </Seccion>
      </div>
    </>
  );
}
