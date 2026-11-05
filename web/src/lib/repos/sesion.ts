import "server-only";
import type { Usuario } from "@/lib/auth";
import { consultarUna, ejecutar } from "@/lib/db";

/** Consultas del inicio de sesión y de la sesión activa. */

export const buscarCredenciales = (nombre: string) =>
  consultarUna<{ id: number; password_hash: string; activo: boolean }>(
    `SELECT id, password_hash, activo FROM usuario
      WHERE nombre_usuario = $1 OR lower(email) = lower($1)`,
    [nombre],
  );

export const marcarAcceso = (id: number) =>
  ejecutar(`UPDATE usuario SET ultimo_acceso = now() WHERE id = $1`, [id]);

/** El rol y el perfil de veterinario se leen en cada petición, así un cambio
 *  hecho por el administrador aplica de inmediato. */
export const usuarioDeSesion = (id: number) =>
  consultarUna<Usuario>(
    `SELECT u.id, u.nombre_usuario, u.email, r.nombre AS rol, v.id AS veterinario_id,
            COALESCE(v.nombres || ' ' || v.apellidos, u.nombre_usuario) AS nombre
       FROM usuario u
       JOIN rol r ON r.id = u.rol_id
       LEFT JOIN veterinario v ON v.usuario_id = u.id
      WHERE u.id = $1 AND u.activo`,
    [id],
  );
