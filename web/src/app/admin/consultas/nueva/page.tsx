import Link from "next/link";
import { BotonEnviar, Formulario } from "@/components/Formulario";
import { Cabecera, Entrada, Seccion, Selector, Vacio } from "@/components/ui";
import { exigir } from "@/lib/auth";
import { SEVERIDADES } from "@/lib/etiquetas";
import { obtenerCita } from "@/lib/repos/citas";
import { alergiasDeMascota } from "@/lib/repos/consultas";
import { obtenerPerfil, opcionesMascotas } from "@/lib/repos/mascotas";
import { nueva } from "../acciones";
import { CamposConsulta } from "../CamposConsulta";

export const metadata = { title: "Nueva consulta" };

export default async function NuevaConsulta({ searchParams }: { searchParams: Promise<Record<string, string>> }) {
  const usuario = await exigir("clinica");
  const { mascota: mascotaParam, cita: citaParam } = await searchParams;
  const mascotaId = /^\d+$/.test(mascotaParam ?? "") ? Number(mascotaParam) : null;
  const m = mascotaId ? await obtenerPerfil(mascotaId) : null;
  const migas = [{ texto: "Consultas", href: "/admin/consultas" }, { texto: "Nueva" }];

  // Toda consulta se firma con el perfil de quien inició sesión.
  if (!usuario.veterinario_id) {
    return (
      <>
        <Cabecera titulo="Nueva consulta" migas={migas} />
        <div className="tarjeta"><Vacio titulo="No puedes firmar consultas" texto="Tu usuario no está vinculado a un perfil de veterinario. Un administrador puede vincularlo en Veterinarios." /></div>
      </>
    );
  }

  // Primero se elige la mascota: de ella dependen las alergias que se deben mostrar.
  if (!m) {
    const mascotas = await opcionesMascotas();
    return (
      <>
        <Cabecera titulo="Nueva consulta" migas={migas} />
        <form method="get" className="tarjeta flex max-w-xl flex-wrap items-end gap-3 p-5">
          <div className="min-w-60 flex-1"><Selector etiqueta="¿Qué mascota se atiende?" name="mascota" opciones={mascotas} vacio="Selecciona…" required /></div>
          <button className="btn btn-md btn-primario">Continuar</button>
        </form>
      </>
    );
  }

  if (!m.activo || m.fecha_fallecimiento) {
    return (
      <>
        <Cabecera titulo={`Consulta de ${m.nombre}`} migas={migas} />
        <div className="tarjeta">
          <Vacio titulo="Esta mascota no puede recibir consultas nuevas" texto="Está dada de baja o falleció. Su historial se conserva y se puede leer en la ficha.">
            <Link href={`/admin/mascotas/${m.id}`} className="btn btn-sm btn-secundario">Volver a la ficha</Link>
          </Vacio>
        </div>
      </>
    );
  }

  const cita = /^\d+$/.test(citaParam ?? "") ? await obtenerCita(Number(citaParam)) : null;
  if (cita && cita.veterinario_id !== usuario.veterinario_id) {
    return (
      <>
        <Cabecera titulo={`Consulta de ${m.nombre}`} migas={migas} />
        <div className="tarjeta">
          <Vacio titulo={`Esta cita está asignada a ${cita.veterinario}`} texto="Solo esa persona puede atenderla y firmar la consulta.">
            <Link href={`/admin/citas/${cita.cita_id}`} className="btn btn-sm btn-secundario">Volver a la cita</Link>
          </Vacio>
        </div>
      </>
    );
  }
  const alergias = await alergiasDeMascota(m.id);

  return (
    <>
      <Cabecera titulo={`Consulta de ${m.nombre}`} subtitulo={`${m.especie} · ${m.raza ?? "Sin raza definida"} · Tutor: ${m.tutor}`} migas={migas} />
      {alergias.length > 0 && (
        <p role="alert" className="mb-5 max-w-3xl rounded-lg border border-error-600/20 bg-error-100 px-4 py-2.5 text-sm text-error-600">
          <strong>Alergias:</strong> {alergias.map((a) => `${a.nombre} (${SEVERIDADES[a.severidad]?.texto.toLowerCase()})`).join(", ")}
        </p>
      )}
      <Seccion className="max-w-3xl">
        <Formulario accion={nueva}>
          <input type="hidden" name="mascota_id" value={m.id} />
          {cita && <input type="hidden" name="cita_id" value={cita.cita_id} />}
          {cita && <p className="rounded-lg bg-verde-50 px-3 py-2 text-sm text-verde-800">Al guardar, la cita con {cita.veterinario} quedará como atendida.</p>}
          <CamposConsulta c={cita ? { motivo: cita.motivo } : undefined} />
          <div className="sm:w-1/3"><Entrada etiqueta="Peso de hoy (kg)" name="peso_kg" inputMode="decimal" /></div>
          <div className="flex gap-2">
            <BotonEnviar>Registrar consulta</BotonEnviar>
            <Link href={`/admin/mascotas/${m.id}`} className="btn btn-md btn-fantasma">Cancelar</Link>
          </div>
        </Formulario>
      </Seccion>
    </>
  );
}
