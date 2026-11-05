import { AreaTexto, Entrada, Selector } from "@/components/ui";
import type { Fila } from "@/lib/db";
import { TIPOS_CONSULTA } from "@/lib/etiquetas";
import { paraInput } from "@/lib/formato";

/** Campos compartidos por «nueva consulta» y «editar consulta». */
export function CamposConsulta({ c }: { c?: Fila }) {
  return (
    <>
      <div className="grid gap-4 sm:grid-cols-3">
        <Selector etiqueta="Tipo" name="tipo" opciones={TIPOS_CONSULTA} defaultValue={c?.tipo ?? "GENERAL"} required />
        <div className="sm:col-span-2"><Entrada etiqueta="Motivo" name="motivo" defaultValue={c?.motivo ?? ""} maxLength={300} required /></div>
      </div>
      <AreaTexto etiqueta="Anamnesis" name="anamnesis" defaultValue={c?.anamnesis ?? ""} />
      <div className="grid gap-4 sm:grid-cols-3">
        <Entrada etiqueta="Temperatura (°C)" name="temperatura_c" inputMode="decimal" defaultValue={c?.temperatura_c ?? ""} ayuda="Entre 30 y 45" />
        <Entrada etiqueta="Frecuencia cardíaca (lpm)" name="frecuencia_cardiaca" inputMode="numeric" defaultValue={c?.frecuencia_cardiaca ?? ""} ayuda="Entre 20 y 400" />
        <Entrada etiqueta="Frecuencia respiratoria (rpm)" name="frecuencia_respiratoria" inputMode="numeric" defaultValue={c?.frecuencia_respiratoria ?? ""} ayuda="Entre 5 y 200" />
      </div>
      <AreaTexto etiqueta="Examen físico" name="examen_fisico" defaultValue={c?.examen_fisico ?? ""} />
      <AreaTexto etiqueta="Observaciones" name="observaciones" defaultValue={c?.observaciones ?? ""} />
      <div className="sm:w-1/3">
        <Entrada etiqueta="Próxima revisión" name="proxima_revision" type="date" defaultValue={paraInput(c?.proxima_revision)} />
      </div>
    </>
  );
}
