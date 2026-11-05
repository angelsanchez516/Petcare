import Link from "next/link";
import { BotonEnviar, Formulario } from "@/components/Formulario";
import { AreaTexto, Casilla, Entrada, Selector } from "@/components/ui";
import type { Fila } from "@/lib/db";
import { guardar } from "./acciones";

type Opcion = { valor: number; texto: string };

export function FormVeterinario({ v, usuarios, especialidades, marcadas, principal }: {
  v?: Fila | null;
  usuarios: Opcion[];
  especialidades: Opcion[];
  marcadas: number[];
  principal?: number;
}) {
  return (
    <Formulario accion={guardar} className="tarjeta max-w-3xl p-5">
      {v?.id && <input type="hidden" name="id" value={v.id} />}
      <div className="grid gap-4 sm:grid-cols-2">
        <Entrada etiqueta="Nombres" name="nombres" defaultValue={v?.nombres} maxLength={80} required />
        <Entrada etiqueta="Apellidos" name="apellidos" defaultValue={v?.apellidos} maxLength={80} required />
        <Entrada etiqueta="Documento" name="documento" defaultValue={v?.documento} maxLength={20} required />
        <Entrada etiqueta="Matrícula profesional" name="matricula" defaultValue={v?.matricula} maxLength={30} required />
        <Entrada etiqueta="Teléfono" name="telefono" defaultValue={v?.telefono ?? ""} maxLength={25} />
        <Entrada etiqueta="Correo electrónico" name="email" type="email" defaultValue={v?.email ?? ""} maxLength={120} />
        <Selector etiqueta="Usuario del sistema" name="usuario_id" opciones={usuarios} vacio="Sin usuario" defaultValue={v?.usuario_id ?? ""} />
        <Entrada etiqueta="Fotografía" name="foto" type="file" accept="image/jpeg,image/png,image/webp" className="campo py-1.5" ayuda="JPG, PNG o WebP, máximo 3 MB" />
      </div>
      <AreaTexto etiqueta="Biografía (aparece en el sitio público)" name="biografia" defaultValue={v?.biografia ?? ""} />
      <fieldset>
        <legend className="etiqueta">Especialidades</legend>
        <div className="grid gap-2 sm:grid-cols-2">
          {especialidades.map((e) => (
            <Casilla key={e.valor} etiqueta={e.texto} name="especialidades" value={e.valor} defaultChecked={marcadas.includes(e.valor)} />
          ))}
        </div>
      </fieldset>
      <div className="sm:w-1/2">
        <Selector etiqueta="Especialidad principal" name="principal" opciones={especialidades} vacio="Ninguna" defaultValue={principal ?? ""} />
      </div>
      <Casilla etiqueta="Activo: se puede agendar con este veterinario" name="activo" defaultChecked={v ? v.activo : true} />
      <div className="flex gap-2">
        <BotonEnviar>Guardar</BotonEnviar>
        <Link href="/admin/veterinarios" className="btn btn-md btn-fantasma">Cancelar</Link>
      </div>
    </Formulario>
  );
}
