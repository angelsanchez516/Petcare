"use server";

import { exigir } from "@/lib/auth";
import { guardarFoto } from "@/lib/fotos";
import { puede } from "@/lib/permisos";
import { paraInput } from "@/lib/formato";
import { agregarCondicion, cambiarActivoMascota, exigirMascotaAtendible, guardarMascota, obtenerMascota, quitarCondicion, registrarPeso } from "@/lib/repos/mascotas";
import { decimal, entero, enteroOpc, fallo, falla, fecha, fechaOpc, marcado, opcion, terminar, texto, textoOpc, type Estado } from "@/lib/validar";

export async function guardar(_: Estado, f: FormData): Promise<Estado> {
  const usuario = await exigir("mascotas.editar");
  let id: number | null;
  let nuevoId: number;
  try {
    id = enteroOpc(f, "id");
    const actual = id ? await obtenerMascota(id) : null;
    if (id && !actual) falla("La mascota no existe.");
    // Quien no administra mascotas conserva el tutor actual, llegue lo que llegue en el formulario.
    const tutorFijo = actual && !puede(usuario.rol, "mascotas.administrar");
    const fallecimiento = fechaOpc(f, "fecha_fallecimiento");
    if (fallecimiento && fallecimiento > paraInput(new Date())) falla("La fecha de fallecimiento no puede estar en el futuro.");
    nuevoId = await guardarMascota({
      cliente_id: tutorFijo ? actual.cliente_id : entero(f, "cliente_id", "Tutor"),
      especie_id: entero(f, "especie_id", "Especie"),
      raza_id: enteroOpc(f, "raza_id"),
      nombre: texto(f, "nombre", "Nombre", 60),
      sexo: opcion(f, "sexo", ["M", "H"], "Sexo"),
      fecha_nacimiento: fechaOpc(f, "fecha_nacimiento"),
      color: textoOpc(f, "color", 60),
      microchip: textoOpc(f, "microchip", 25),
      esterilizado: marcado(f, "esterilizado"),
      observaciones: textoOpc(f, "observaciones", 2000),
      fecha_fallecimiento: fallecimiento,
    }, await guardarFoto(f), id);
  } catch (e) {
    return fallo(e);
  }
  terminar(`/admin/mascotas/${nuevoId}`, id ? "Mascota actualizada" : "Mascota registrada");
}

export async function cambiarActivo(_: Estado, f: FormData): Promise<Estado> {
  await exigir("mascotas.administrar");
  const activo = f.get("activo") === "1";
  let id: number;
  try {
    id = entero(f, "id", "id");
    await cambiarActivoMascota(id, activo);
  } catch (e) {
    return fallo(e);
  }
  terminar(`/admin/mascotas/${id}`, activo ? "Mascota reactivada" : "Mascota dada de baja; su historial se conserva");
}

export async function nuevaCondicion(_: Estado, f: FormData): Promise<Estado> {
  await exigir("clinica");
  let id: number;
  try {
    id = entero(f, "mascota_id", "Mascota");
    await exigirMascotaAtendible(id);
    await agregarCondicion(id, entero(f, "condicion_id", "Condición"),
      opcion(f, "severidad", ["LEVE", "MEDIA", "GRAVE"], "Severidad"),
      fechaOpc(f, "fecha_deteccion"), textoOpc(f, "notas", 1000));
  } catch (e) {
    return fallo(e);
  }
  terminar(`/admin/mascotas/${id}`, "Condición registrada");
}

export async function eliminarCondicion(_: Estado, f: FormData): Promise<Estado> {
  await exigir("clinica");
  let id: number;
  try {
    id = entero(f, "mascota_id", "Mascota");
    await quitarCondicion(id, entero(f, "condicion_id", "Condición"));
  } catch (e) {
    return fallo(e);
  }
  terminar(`/admin/mascotas/${id}`, "Condición retirada");
}

export async function nuevoPeso(_: Estado, f: FormData): Promise<Estado> {
  await exigir("mascotas.editar");
  let id: number;
  try {
    id = entero(f, "mascota_id", "Mascota");
    await exigirMascotaAtendible(id);
    await registrarPeso(id, fecha(f, "fecha_registro", "Fecha"), decimal(f, "peso_kg", "Peso"), textoOpc(f, "observacion", 200));
  } catch (e) {
    return fallo(e);
  }
  terminar(`/admin/mascotas/${id}?tab=peso`, "Peso registrado");
}
