"use server";

import { exigir, type Usuario } from "@/lib/auth";
import { puedeEditarClinica } from "@/lib/permisos";
import { TIPOS_CONSULTA, TIPOS_DIAGNOSTICO, ESTADOS_TRATAMIENTO, VIAS } from "@/lib/etiquetas";
import {
  actualizarConsulta, agregarDiagnostico, agregarLineaReceta, agregarTratamiento, cambiarEstadoTratamiento,
  cambiarTipoDiagnostico, crearConsulta, emitirReceta, quitarDiagnostico, quitarLineaReceta,
  veterinarioDeConsulta, veterinarioDeReceta, veterinarioDeTratamiento, type DatosConsulta, type LineaReceta,
} from "@/lib/repos/consultas";
import { exigirMascotaAtendible } from "@/lib/repos/mascotas";
import {
  decimal, decimalOpc, entero, enteroOpc, fallo, falla, fecha, fechaOpc, marcado, opcion, terminar, texto, textoOpc, type Estado,
} from "@/lib/validar";

/** El historial se comparte, pero solo quien firmó el registro o un administrador
 *  pueden modificarlo. Se comprueba aquí porque ocultar un botón no protege nada. */
function comprobarAutor(usuario: Usuario, veterinario: number | null) {
  if (veterinario === null) falla("El registro no existe.");
  if (!puedeEditarClinica(usuario, veterinario as number)) {
    falla("Este registro lo firmó otro veterinario. Solo esa persona o un administrador pueden modificarlo.");
  }
}

function leerConsulta(f: FormData): DatosConsulta {
  return {
    tipo: opcion(f, "tipo", Object.keys(TIPOS_CONSULTA), "Tipo de consulta"),
    motivo: texto(f, "motivo", "Motivo", 300),
    anamnesis: textoOpc(f, "anamnesis", 5000),
    temperatura_c: decimalOpc(f, "temperatura_c"),
    frecuencia_cardiaca: enteroOpc(f, "frecuencia_cardiaca"),
    frecuencia_respiratoria: enteroOpc(f, "frecuencia_respiratoria"),
    examen_fisico: textoOpc(f, "examen_fisico", 5000),
    observaciones: textoOpc(f, "observaciones", 5000),
    proxima_revision: fechaOpc(f, "proxima_revision"),
  };
}

function leerLinea(f: FormData): LineaReceta {
  return {
    medicamento_id: entero(f, "medicamento_id", "Medicamento"),
    dosis: texto(f, "dosis", "Dosis", 60),
    frecuencia: texto(f, "frecuencia", "Frecuencia", 60),
    duracion_dias: entero(f, "duracion_dias", "Duración"),
    via_administracion: opcion(f, "via_administracion", Object.keys(VIAS), "Vía"),
    cantidad: decimal(f, "cantidad", "Cantidad"),
    instrucciones: textoOpc(f, "instrucciones", 300),
  };
}

export async function nueva(_: Estado, f: FormData): Promise<Estado> {
  const usuario = await exigir("clinica");
  let id: number;
  try {
    // Toda consulta se firma con el perfil de quien inició sesión.
    if (!usuario.veterinario_id) falla("Tu usuario no está vinculado a un perfil de veterinario.");
    const peso = decimalOpc(f, "peso_kg");
    if (peso !== null && Number(peso) <= 0) falla("El peso debe ser mayor que cero.");
    const mascota = entero(f, "mascota_id", "Mascota");
    await exigirMascotaAtendible(mascota);
    id = await crearConsulta({
      ...leerConsulta(f),
      mascota_id: mascota,
      veterinario_id: usuario.veterinario_id as number,
      cita_id: enteroOpc(f, "cita_id"),
      peso_kg: peso,
    });
  } catch (e) {
    return fallo(e);
  }
  terminar(`/admin/consultas/${id}`, "Consulta registrada. Agrega el diagnóstico y el tratamiento.");
}

export async function editar(_: Estado, f: FormData): Promise<Estado> {
  const usuario = await exigir("clinica");
  let id: number;
  try {
    id = entero(f, "id", "id");
    comprobarAutor(usuario, await veterinarioDeConsulta(id));
    await actualizarConsulta(id, leerConsulta(f));
  } catch (e) {
    return fallo(e);
  }
  terminar(`/admin/consultas/${id}`, "Consulta actualizada");
}

export async function nuevoDiagnostico(_: Estado, f: FormData): Promise<Estado> {
  const usuario = await exigir("clinica");
  let id: number;
  try {
    id = entero(f, "consulta_id", "Consulta");
    comprobarAutor(usuario, await veterinarioDeConsulta(id));
    await agregarDiagnostico(id, entero(f, "diagnostico_id", "Diagnóstico"),
      opcion(f, "tipo", Object.keys(TIPOS_DIAGNOSTICO), "Tipo"), marcado(f, "es_principal"), textoOpc(f, "notas", 1000));
  } catch (e) {
    return fallo(e);
  }
  terminar(`/admin/consultas/${id}`, "Diagnóstico agregado");
}

export async function tipoDiagnostico(_: Estado, f: FormData): Promise<Estado> {
  const usuario = await exigir("clinica");
  let id: number;
  try {
    id = entero(f, "consulta_id", "Consulta");
    comprobarAutor(usuario, await veterinarioDeConsulta(id));
    await cambiarTipoDiagnostico(id, entero(f, "diagnostico_id", "Diagnóstico"), opcion(f, "tipo", Object.keys(TIPOS_DIAGNOSTICO), "Tipo"));
  } catch (e) {
    return fallo(e);
  }
  terminar(`/admin/consultas/${id}`, "Diagnóstico actualizado");
}

export async function eliminarDiagnostico(_: Estado, f: FormData): Promise<Estado> {
  const usuario = await exigir("clinica");
  let id: number;
  try {
    id = entero(f, "consulta_id", "Consulta");
    comprobarAutor(usuario, await veterinarioDeConsulta(id));
    await quitarDiagnostico(id, entero(f, "diagnostico_id", "Diagnóstico"));
  } catch (e) {
    return fallo(e);
  }
  terminar(`/admin/consultas/${id}`, "Diagnóstico retirado");
}

export async function nuevoTratamiento(_: Estado, f: FormData): Promise<Estado> {
  const usuario = await exigir("clinica");
  let id: number;
  try {
    id = entero(f, "consulta_id", "Consulta");
    comprobarAutor(usuario, await veterinarioDeConsulta(id));
    await agregarTratamiento(id, texto(f, "descripcion", "Descripción", 300), textoOpc(f, "indicaciones", 2000),
      fecha(f, "fecha_inicio", "Fecha de inicio"), fechaOpc(f, "fecha_fin_estimada"));
  } catch (e) {
    return fallo(e);
  }
  terminar(`/admin/consultas/${id}`, "Tratamiento agregado");
}

/** `volver` llega del formulario: se acepta solo si es una ruta del panel. */
export async function estadoTratamiento(_: Estado, f: FormData): Promise<Estado> {
  const usuario = await exigir("clinica");
  const volver = String(f.get("volver") ?? "");
  try {
    const tratamiento = entero(f, "id", "id");
    comprobarAutor(usuario, await veterinarioDeTratamiento(tratamiento));
    await cambiarEstadoTratamiento(tratamiento, opcion(f, "estado", Object.keys(ESTADOS_TRATAMIENTO), "Estado"));
  } catch (e) {
    return fallo(e);
  }
  terminar(volver.startsWith("/admin/") ? volver : "/admin/tratamientos", "Tratamiento actualizado");
}

export async function nuevaReceta(_: Estado, f: FormData): Promise<Estado> {
  const usuario = await exigir("clinica");
  let id: number;
  try {
    const consulta = entero(f, "consulta_id", "Consulta");
    comprobarAutor(usuario, await veterinarioDeConsulta(consulta));
    id = await emitirReceta(consulta, textoOpc(f, "indicaciones_generales", 2000),
      entero(f, "vigencia_dias", "Vigencia"), leerLinea(f));
  } catch (e) {
    return fallo(e);
  }
  terminar(`/admin/recetas/${id}`, "Receta emitida");
}

export async function nuevaLineaReceta(_: Estado, f: FormData): Promise<Estado> {
  const usuario = await exigir("clinica");
  let id: number;
  try {
    id = entero(f, "receta_id", "Receta");
    comprobarAutor(usuario, await veterinarioDeReceta(id));
    await agregarLineaReceta(id, leerLinea(f));
  } catch (e) {
    return fallo(e);
  }
  terminar(`/admin/recetas/${id}`, "Medicamento agregado");
}

export async function eliminarLineaReceta(_: Estado, f: FormData): Promise<Estado> {
  const usuario = await exigir("clinica");
  let id: number;
  try {
    id = entero(f, "receta_id", "Receta");
    comprobarAutor(usuario, await veterinarioDeReceta(id));
    await quitarLineaReceta(id, entero(f, "medicamento_id", "Medicamento"));
  } catch (e) {
    return fallo(e);
  }
  terminar(`/admin/recetas/${id}`, "Medicamento retirado");
}
