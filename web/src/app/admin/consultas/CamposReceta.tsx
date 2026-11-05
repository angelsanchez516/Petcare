import { Entrada, Selector } from "@/components/ui";
import { VIAS } from "@/lib/etiquetas";

/** Datos de un medicamento dentro de una receta. */
export function CamposReceta({ medicamentos }: { medicamentos: { valor: number; texto: string }[] }) {
  return (
    <div className="grid gap-3 sm:grid-cols-3">
      <div className="sm:col-span-3"><Selector etiqueta="Medicamento" name="medicamento_id" opciones={medicamentos} vacio="Selecciona…" required /></div>
      <Entrada etiqueta="Dosis" name="dosis" maxLength={60} required placeholder="1 comprimido" />
      <Entrada etiqueta="Frecuencia" name="frecuencia" maxLength={60} required placeholder="Cada 12 horas" />
      <Entrada etiqueta="Duración (días)" name="duracion_dias" type="number" min={1} max={365} required />
      <Selector etiqueta="Vía" name="via_administracion" opciones={VIAS} defaultValue="ORAL" />
      <Entrada etiqueta="Cantidad" name="cantidad" inputMode="decimal" defaultValue="1" required />
      <Entrada etiqueta="Instrucciones" name="instrucciones" maxLength={300} placeholder="Con alimento" />
    </div>
  );
}
