"use server";

import { exigir } from "@/lib/auth";
import { CATALOGOS, type Campo } from "@/lib/catalogos";
import { eliminarRegistro, guardarRegistro } from "@/lib/repos/catalogos";
import { decimal, decimalOpc, entero, enteroOpc, fallo, falla, marcado, opcion, terminar, texto, textoOpc, type Estado } from "@/lib/validar";

function catalogoDe(f: FormData) {
  const c = CATALOGOS[String(f.get("catalogo"))];
  return c ?? falla("Ese catálogo no existe.");
}

function leerCampo(f: FormData, c: Campo): unknown {
  switch (c.tipo) {
    case "casilla":
      return marcado(f, c.col);
    case "entero": {
      const v = c.requerido ? entero(f, c.col, c.etiqueta) : enteroOpc(f, c.col);
      if (v !== null && v < 0) falla(`«${c.etiqueta}» no puede ser negativo.`);
      return v;
    }
    case "dinero": {
      const v = c.requerido ? decimal(f, c.col, c.etiqueta) : decimalOpc(f, c.col);
      if (v !== null && Number(v) < 0) falla(`«${c.etiqueta}» no puede ser negativo.`);
      return v;
    }
    case "fk":
      return c.requerido ? entero(f, c.col, c.etiqueta) : enteroOpc(f, c.col);
    case "opcion":
      if (!c.requerido && !f.get(c.col)) return null;
      return opcion(f, c.col, Object.keys(c.opciones ?? {}), c.etiqueta);
    default:
      return c.requerido ? texto(f, c.col, c.etiqueta, c.max) : textoOpc(f, c.col, c.max ?? 5000);
  }
}

export async function guardar(_: Estado, f: FormData): Promise<Estado> {
  await exigir("catalogos");
  let clave: string;
  let id: number | null;
  try {
    const c = catalogoDe(f);
    clave = String(f.get("catalogo"));
    id = enteroOpc(f, "id");
    const especies = f.getAll("especies").map(Number).filter(Number.isInteger);
    await guardarRegistro(c, c.campos.map((x) => leerCampo(f, x)), id, especies);
  } catch (e) {
    return fallo(e);
  }
  terminar(`/admin/catalogos/${clave}`, id ? "Cambios guardados" : "Registro creado");
}

export async function eliminar(_: Estado, f: FormData): Promise<Estado> {
  await exigir("catalogos");
  let clave: string;
  try {
    const c = catalogoDe(f);
    clave = String(f.get("catalogo"));
    await eliminarRegistro(c, entero(f, "id", "id"));
  } catch (e) {
    return fallo(e);
  }
  terminar(`/admin/catalogos/${clave}`, "Registro eliminado");
}
