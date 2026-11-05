import Link from "next/link";
import { BotonEnviar, Formulario } from "@/components/Formulario";
import { AreaTexto, Entrada, Selector } from "@/components/ui";
import { TIPOS_DOCUMENTO } from "@/lib/etiquetas";
import type { Fila } from "@/lib/db";
import { guardar } from "./acciones";

export function FormCliente({ c, volver }: { c?: Fila | null; volver: string }) {
  return (
    <Formulario accion={guardar} className="tarjeta max-w-3xl p-5">
      {c?.id && <input type="hidden" name="id" value={c.id} />}
      <div className="grid gap-4 sm:grid-cols-2">
        <Selector etiqueta="Tipo de documento" name="tipo_documento" opciones={TIPOS_DOCUMENTO} defaultValue={c?.tipo_documento ?? "CC"} required />
        <Entrada etiqueta="Número de documento" name="documento" defaultValue={c?.documento} maxLength={20} required />
        <Entrada etiqueta="Nombres" name="nombres" defaultValue={c?.nombres} maxLength={80} required />
        <Entrada etiqueta="Apellidos" name="apellidos" defaultValue={c?.apellidos} maxLength={80} required />
        <Entrada etiqueta="Teléfono" name="telefono" defaultValue={c?.telefono} maxLength={25} required placeholder="+57 300 000 0000" />
        <Entrada etiqueta="Correo electrónico" name="email" type="email" defaultValue={c?.email ?? ""} maxLength={120} />
        <Entrada etiqueta="Dirección" name="direccion" defaultValue={c?.direccion ?? ""} maxLength={200} />
        <Entrada etiqueta="Ciudad" name="ciudad" defaultValue={c?.ciudad ?? ""} maxLength={80} />
      </div>
      <AreaTexto etiqueta="Notas de recepción" name="notas" defaultValue={c?.notas ?? ""} />
      <div className="flex gap-2">
        <BotonEnviar>Guardar</BotonEnviar>
        <Link href={volver} className="btn btn-md btn-fantasma">Cancelar</Link>
      </div>
    </Formulario>
  );
}
