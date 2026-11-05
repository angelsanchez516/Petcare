"use client";

import Link from "next/link";
import { useState } from "react";
import { BotonEnviar, Formulario } from "@/components/Formulario";
import { AreaTexto, Casilla, Entrada, Selector } from "@/components/ui";
import { guardar } from "./acciones";

type Opcion = { valor: number; texto: string };
type Raza = { id: number; especie_id: number; nombre: string };

/** Es un componente de cliente para que la lista de razas cambie con la especie:
 *  la clave foránea (raza_id, especie_id) rechazaría una combinación inválida. */
export function FormMascota({ m, clientes, especies, razas, hoy, volver, tutorFijo = false }: {
  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  m?: Record<string, any>;
  clientes: Opcion[];
  especies: Opcion[];
  razas: Raza[];
  hoy: string;
  volver: string;
  tutorFijo?: boolean;
}) {
  const [especie, setEspecie] = useState<number | "">(m?.especie_id ?? "");
  const opcionesRaza = razas.filter((r) => r.especie_id === especie).map((r) => ({ valor: r.id, texto: r.nombre }));

  return (
    <Formulario accion={guardar} className="tarjeta max-w-3xl p-5">
      {m?.id && <input type="hidden" name="id" value={m.id} />}
      <div className="grid gap-4 sm:grid-cols-2">
        <div>
          <Selector etiqueta="Tutor" name="cliente_id" opciones={clientes} vacio="Selecciona…" defaultValue={m?.cliente_id ?? ""} required disabled={tutorFijo} />
          {tutorFijo && <p className="ayuda">Solo recepción o administración pueden cambiar el tutor.</p>}
        </div>
        <Entrada etiqueta="Nombre" name="nombre" defaultValue={m?.nombre} maxLength={60} required />
        <Selector etiqueta="Especie" name="especie_id" opciones={especies} vacio="Selecciona…" required
          value={especie} onChange={(e) => setEspecie(e.target.value ? Number(e.target.value) : "")} />
        <Selector key={especie} etiqueta="Raza" name="raza_id" opciones={opcionesRaza} vacio="Sin definir / mestizo"
          defaultValue={m?.especie_id === especie ? m?.raza_id ?? "" : ""} />
        <Selector etiqueta="Sexo" name="sexo" opciones={{ M: "Macho", H: "Hembra" }} vacio="Selecciona…" defaultValue={m?.sexo ?? ""} required />
        <Entrada etiqueta="Fecha de nacimiento" name="fecha_nacimiento" type="date" max={hoy} defaultValue={m?.fecha_nacimiento ?? ""} />
        <Entrada etiqueta="Color" name="color" defaultValue={m?.color ?? ""} maxLength={60} />
        <Entrada etiqueta="Microchip" name="microchip" defaultValue={m?.microchip ?? ""} maxLength={25} ayuda="De 9 a 25 letras o números, sin espacios" />
        <Entrada etiqueta="Fotografía" name="foto" type="file" accept="image/jpeg,image/png,image/webp" className="campo py-1.5" ayuda="JPG, PNG o WebP, máximo 3 MB" />
        <Entrada etiqueta="Fecha de fallecimiento" name="fecha_fallecimiento" type="date" max={hoy} defaultValue={m?.fecha_fallecimiento ?? ""} ayuda="Solo si aplica; cierra el expediente" />
      </div>
      <Casilla etiqueta="Esterilizado" name="esterilizado" defaultChecked={m?.esterilizado} />
      <AreaTexto etiqueta="Observaciones" name="observaciones" defaultValue={m?.observaciones ?? ""} />
      <div className="flex gap-2">
        <BotonEnviar>Guardar</BotonEnviar>
        <Link href={volver} className="btn btn-md btn-fantasma">Cancelar</Link>
      </div>
    </Formulario>
  );
}
