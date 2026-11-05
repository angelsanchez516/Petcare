import "server-only";
import { consultar, ejecutar } from "@/lib/db";

/** Consultas del sitio público. Solo leen datos marcados como publicables y
 *  escriben en solicitud_cita, que es la tabla de cuarentena: un visitante
 *  nunca toca las tablas maestras. */

export type ServicioPublico = {
  id: number;
  codigo: string;
  nombre: string;
  categoria: string;
  descripcion: string | null;
  precio_base: string;
  duracion_estimada_min: number | null;
  icono: string | null;
};

export async function serviciosPublicos(): Promise<ServicioPublico[]> {
  return consultar<ServicioPublico>(
    `SELECT id, codigo, nombre, categoria, descripcion, precio_base,
            duracion_estimada_min, icono
       FROM servicio
      WHERE activo AND visible_publico
      ORDER BY CASE categoria
                 WHEN 'CONSULTA'    THEN 1 WHEN 'VACUNACION' THEN 2
                 WHEN 'DIAGNOSTICO' THEN 3 WHEN 'CIRUGIA'    THEN 4
                 WHEN 'ESTETICA'    THEN 5 ELSE 6 END,
               precio_base`,
  );
}

export type VeterinarioPublico = {
  id: number;
  nombres: string;
  apellidos: string;
  matricula: string;
  foto_url: string | null;
  biografia: string | null;
  especialidades: string[];
  especialidad_principal: string | null;
};

export async function veterinariosPublicos(): Promise<VeterinarioPublico[]> {
  return consultar<VeterinarioPublico>(
    `SELECT v.id, v.nombres, v.apellidos, v.matricula, v.foto_url, v.biografia,
            COALESCE(array_agg(e.nombre ORDER BY ve.es_principal DESC, e.nombre)
                     FILTER (WHERE e.nombre IS NOT NULL), '{}') AS especialidades,
            max(e.nombre) FILTER (WHERE ve.es_principal) AS especialidad_principal
       FROM veterinario v
       LEFT JOIN veterinario_especialidad ve ON ve.veterinario_id = v.id
       LEFT JOIN especialidad e ON e.id = ve.especialidad_id
      WHERE v.activo
      GROUP BY v.id
      ORDER BY v.apellidos, v.nombres`,
  );
}

export type EspeciePublica = { id: number; nombre: string; icono: string | null };

export async function especiesPublicas(): Promise<EspeciePublica[]> {
  return consultar<EspeciePublica>(
    `SELECT id, nombre, icono FROM especie ORDER BY id`,
  );
}

/** Cifras reales de la base para la franja de credibilidad de la portada.
 *  No son números inventados: salen de los registros del sistema. */
export type CifrasClinica = {
  mascotas: number;
  especies: number;
  veterinarios: number;
  consultas: number;
};

export async function cifrasClinica(): Promise<CifrasClinica> {
  const [f] = await consultar<Record<string, string>>(
    `SELECT (SELECT count(*) FROM mascota WHERE activo)                AS mascotas,
            (SELECT count(DISTINCT especie_id) FROM mascota)           AS especies,
            (SELECT count(*) FROM veterinario WHERE activo)            AS veterinarios,
            (SELECT count(*) FROM consulta)                            AS consultas`,
  );
  return {
    mascotas: Number(f.mascotas),
    especies: Number(f.especies),
    veterinarios: Number(f.veterinarios),
    consultas: Number(f.consultas),
  };
}

/** Página de cuidados: por especie, sus razas y las vacunas indicadas según
 *  vacuna_especie. */
export const cuidadosPorEspecie = () =>
  consultar(
    `SELECT e.id, e.nombre, e.icono, e.esperanza_vida_anios,
            (SELECT count(*)::int FROM raza r WHERE r.especie_id = e.id) AS razas,
            COALESCE((SELECT json_agg(json_build_object('nombre', v.nombre, 'previene', v.enfermedades_previene,
                                                        'meses', v.intervalo_refuerzo_meses) ORDER BY v.nombre)
                        FROM vacuna v JOIN vacuna_especie ve ON ve.vacuna_id = v.id
                       WHERE ve.especie_id = e.id AND v.activo), '[]') AS vacunas
       FROM especie e ORDER BY razas DESC, e.nombre`,
  );

/** Registra una solicitud de turno del sitio público.
 *
 *  Escribe en solicitud_cita y NO en cita: la cita exige mascota_id y
 *  veterinario_id, y un visitante no tiene mascota registrada. Recepción revisa
 *  la solicitud y la convierte en cita real desde el panel. */
export async function registrarSolicitud(datos: {
  nombre: string;
  telefono: string;
  email: string | null;
  especieId: number | null;
  nombreMascota: string | null;
  motivo: string;
  fechaPreferida: string | null;
  franja: string | null;
}): Promise<void> {
  await ejecutar(
    `INSERT INTO solicitud_cita
       (nombre_contacto, telefono_contacto, email_contacto, especie_id,
        nombre_mascota, motivo, fecha_preferida, franja_preferida)
     VALUES ($1, $2, $3, $4, $5, $6, $7, $8)`,
    [
      datos.nombre,
      datos.telefono,
      datos.email,
      datos.especieId,
      datos.nombreMascota,
      datos.motivo,
      datos.fechaPreferida,
      datos.franja,
    ],
  );
}
