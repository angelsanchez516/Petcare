"use client";

import Link from "next/link";
import { useState } from "react";
import { BotonEnviar, Formulario } from "@/components/Formulario";
import { AreaTexto, Entrada, Selector } from "@/components/ui";
import { guardar } from "./acciones";

type Opcion = { valor: number; texto: string };

/** Al elegir un servicio se propone su duración; se puede cambiar a mano. */
export function FormCita({ c, mascotas, veterinarios, servicios, ahora, volver, solicitud }: {
  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  c?: Record<string, any>;
  mascotas: Opcion[];
  veterinarios: Opcion[];
  servicios: { id: number; nombre: string; duracion: number | null }[];
  ahora: string;
  volver: string;
  solicitud?: number;
}) {
  const [duracion, setDuracion] = useState<number>(c?.duracion ?? 30);

  return (
    <Formulario accion={guardar} className="tarjeta max-w-3xl p-5">
      {c?.id && <input type="hidden" name="id" value={c.id} />}
      {solicitud && <input type="hidden" name="solicitud_id" value={solicitud} />}
      <div className="grid gap-4 sm:grid-cols-2">
        <Selector etiqueta="Mascota" name="mascota_id" opciones={mascotas} vacio="Selecciona…" defaultValue={c?.mascota_id ?? ""} required />
        <Selector etiqueta="Veterinario" name="veterinario_id" opciones={veterinarios} vacio="Selecciona…" defaultValue={c?.veterinario_id ?? ""} required />
        <Selector etiqueta="Servicio" name="servicio_id" vacio="Sin servicio específico" defaultValue={c?.servicio_id ?? ""}
          opciones={servicios.map((s) => ({ valor: s.id, texto: s.nombre }))}
          onChange={(e) => {
            const s = servicios.find((x) => x.id === Number(e.target.value));
            if (s?.duracion) setDuracion(s.duracion);
          }} />
        <Entrada etiqueta="Fecha y hora" name="inicio" type="datetime-local" min={ahora} defaultValue={c?.inicio ?? ""} required />
        <Entrada etiqueta="Duración (minutos)" name="duracion" type="number" min={10} max={480} step={5} required
          value={duracion} onChange={(e) => setDuracion(Number(e.target.value))} />
      </div>
      <Entrada etiqueta="Motivo" name="motivo" defaultValue={c?.motivo ?? ""} maxLength={300} required />
      <AreaTexto etiqueta="Notas" name="notas" defaultValue={c?.notas ?? ""} />
      <div className="flex gap-2">
        <BotonEnviar>{solicitud ? "Crear la cita" : "Guardar"}</BotonEnviar>
        <Link href={volver} className="btn btn-md btn-fantasma">Cancelar</Link>
      </div>
    </Formulario>
  );
}
