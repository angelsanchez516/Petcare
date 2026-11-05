import Link from "next/link";
import { BotonEnviar, Formulario } from "@/components/Formulario";
import { AreaTexto, Cabecera, Entrada, Seccion, Selector, Vacio } from "@/components/ui";
import { exigir } from "@/lib/auth";
import { paraInput } from "@/lib/formato";
import { puede } from "@/lib/permisos";
import { obtenerPerfil, opcionesMascotas } from "@/lib/repos/mascotas";
import { vacunasAptas } from "@/lib/repos/vacunas";
import { aplicar } from "../acciones";

export const metadata = { title: "Registrar vacuna" };

export default async function AplicarVacuna({ searchParams }: { searchParams: Promise<Record<string, string>> }) {
  const usuario = await exigir("vacunas.aplicar");
  const { mascota: mascotaParam, vacuna, consulta } = await searchParams;
  const m = /^\d+$/.test(mascotaParam ?? "") ? await obtenerPerfil(Number(mascotaParam)) : null;
  const migas = [{ texto: "Vacunación", href: "/admin/vacunas" }, { texto: "Registrar aplicación" }];

  // La aplicación se firma con el perfil de quien inició sesión.
  if (!usuario.veterinario_id) {
    return (
      <>
        <Cabecera titulo="Registrar aplicación" migas={migas} />
        <div className="tarjeta"><Vacio titulo="No puedes registrar vacunas" texto="Tu usuario no está vinculado a un perfil de veterinario. Un administrador puede vincularlo en Veterinarios." /></div>
      </>
    );
  }

  // La lista de vacunas depende de la especie, así que primero se elige la mascota.
  if (!m) {
    const mascotas = await opcionesMascotas();
    return (
      <>
        <Cabecera titulo="Registrar aplicación" migas={migas} />
        <form method="get" className="tarjeta flex max-w-xl flex-wrap items-end gap-3 p-5">
          <div className="min-w-60 flex-1"><Selector etiqueta="¿A qué mascota?" name="mascota" opciones={mascotas} vacio="Selecciona…" required /></div>
          <button className="btn btn-md btn-primario">Continuar</button>
        </form>
      </>
    );
  }

  if (!m.activo || m.fecha_fallecimiento) {
    return (
      <>
        <Cabecera titulo={`Vacuna para ${m.nombre}`} migas={migas} />
        <div className="tarjeta">
          <Vacio titulo="Esta mascota no puede recibir vacunas nuevas" texto="Está dada de baja o falleció. Su historial se conserva y se puede leer en la ficha.">
            <Link href={`/admin/mascotas/${m.id}?tab=vacunas`} className="btn btn-sm btn-secundario">Volver a la ficha</Link>
          </Vacio>
        </div>
      </>
    );
  }

  const aptas = await vacunasAptas(m.especie_id);
  const hoy = paraInput(new Date());

  // Sin vacunas compatibles no se muestra un formulario que no se podría completar.
  if (aptas.length === 0) {
    return (
      <>
        <Cabecera titulo={`Vacuna para ${m.nombre}`} subtitulo={`${m.especie} · Tutor: ${m.tutor}`} migas={migas} />
        <div className="tarjeta">
          <Vacio titulo="No hay vacunas registradas para esta especie" texto={`El catálogo no tiene vacunas compatibles con la especie ${m.especie.toLowerCase()}.`}>
            <div className="flex flex-wrap justify-center gap-2">
              <Link href={`/admin/mascotas/${m.id}`} className="btn btn-sm btn-secundario">Volver a la ficha</Link>
              {puede(usuario.rol, "catalogos") && <Link href="/admin/catalogos/vacunas" className="btn btn-sm btn-secundario">Revisar el catálogo de vacunas</Link>}
            </div>
          </Vacio>
        </div>
      </>
    );
  }

  return (
    <>
      <Cabecera titulo={`Vacuna para ${m.nombre}`} subtitulo={`${m.especie} · Tutor: ${m.tutor}`} migas={migas} />
      <Seccion className="max-w-3xl">
        <Formulario accion={aplicar}>
          <input type="hidden" name="mascota_id" value={m.id} />
          {consulta && <input type="hidden" name="consulta_id" value={consulta} />}
          <div className="grid gap-4 sm:grid-cols-2">
            <div className="sm:col-span-2">
              <Selector etiqueta={`Vacuna (indicadas para ${m.especie.toLowerCase()})`} name="vacuna_id" opciones={aptas} vacio="Selecciona…" defaultValue={vacuna ?? ""} required />
            </div>
            <Entrada etiqueta="Fecha de aplicación" name="fecha_aplicacion" type="date" max={hoy} defaultValue={hoy} required />
            <Entrada etiqueta="Lote" name="lote" maxLength={40} required />
            <Entrada etiqueta="Número de dosis" name="dosis_numero" type="number" min={1} max={20} defaultValue={1} required />
            <Entrada etiqueta="Próximo refuerzo" name="fecha_proximo_refuerzo" type="date" ayuda="Si lo dejas vacío, se calcula con el intervalo de la vacuna" />
          </div>
          <AreaTexto etiqueta="Observaciones" name="observaciones" />
          <div className="flex gap-2">
            <BotonEnviar>Registrar</BotonEnviar>
            <Link href={`/admin/mascotas/${m.id}?tab=vacunas`} className="btn btn-md btn-fantasma">Cancelar</Link>
          </div>
        </Formulario>
      </Seccion>
    </>
  );
}
