import "server-only";
import { consultar, consultarUna, enTransaccion, ejecutar } from "@/lib/db";

// ── Veterinarios ────────────────────────────────────────────────────────────
export const listarVeterinarios = () =>
  consultar(
    `SELECT v.*, u.nombre_usuario,
            (SELECT string_agg(e.nombre, ', ' ORDER BY ve.es_principal DESC, e.nombre) FROM veterinario_especialidad ve
               JOIN especialidad e ON e.id = ve.especialidad_id WHERE ve.veterinario_id = v.id) AS especialidades
       FROM veterinario v LEFT JOIN usuario u ON u.id = v.usuario_id
      ORDER BY v.activo DESC, v.apellidos, v.nombres`,
  );

export const obtenerVeterinario = (id: number) => consultarUna(`SELECT * FROM veterinario WHERE id = $1`, [id]);

export const especialidadesDe = (id: number) =>
  consultar<{ especialidad_id: number; es_principal: boolean }>(
    `SELECT especialidad_id, es_principal FROM veterinario_especialidad WHERE veterinario_id = $1`, [id],
  );

export const opcionesEspecialidades = () =>
  consultar(`SELECT id AS valor, nombre AS texto FROM especialidad ORDER BY nombre`) as Promise<{ valor: number; texto: string }[]>;

/** Usuarios sin veterinario asociado, más el que ya tiene este veterinario. */
export const usuariosDisponibles = (veterinario: number | null) =>
  consultar(
    `SELECT u.id AS valor, u.nombre_usuario AS texto FROM usuario u
      WHERE u.activo AND NOT EXISTS (SELECT 1 FROM veterinario v WHERE v.usuario_id = u.id AND v.id IS DISTINCT FROM $1)
      ORDER BY u.nombre_usuario`,
    [veterinario],
  ) as Promise<{ valor: number; texto: string }[]>;

export type DatosVeterinario = {
  usuario_id: number | null;
  documento: string;
  matricula: string;
  nombres: string;
  apellidos: string;
  telefono: string | null;
  email: string | null;
  biografia: string | null;
  activo: boolean;
};

/** Guarda al veterinario y sus especialidades en una sola transacción. */
export async function guardarVeterinario(
  d: DatosVeterinario, foto: string | null, id: number | null, especialidades: number[], principal: number | null,
): Promise<number> {
  return enTransaccion(async (cx) => {
    const v = [d.usuario_id, d.documento, d.matricula, d.nombres, d.apellidos, d.telefono, d.email, d.biografia, d.activo, foto];
    let vet = id;
    if (id) {
      await cx.query(
        `UPDATE veterinario SET usuario_id=$1, documento=$2, matricula=$3, nombres=$4, apellidos=$5, telefono=$6,
                email=$7, biografia=$8, activo=$9, foto_url=COALESCE($10, foto_url) WHERE id=$11`,
        [...v, id],
      );
    } else {
      const { rows } = await cx.query(
        `INSERT INTO veterinario (usuario_id, documento, matricula, nombres, apellidos, telefono, email, biografia, activo, foto_url)
         VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10) RETURNING id`,
        v,
      );
      vet = rows[0].id;
    }
    await cx.query(`DELETE FROM veterinario_especialidad WHERE veterinario_id = $1`, [vet]);
    for (const e of especialidades) {
      await cx.query(`INSERT INTO veterinario_especialidad (veterinario_id, especialidad_id, es_principal) VALUES ($1,$2,$3)`, [vet, e, e === principal]);
    }
    return vet as number;
  });
}

// ── Usuarios ────────────────────────────────────────────────────────────────
export const listarUsuarios = () =>
  consultar(
    `SELECT u.id, u.nombre_usuario, u.email, u.activo, u.ultimo_acceso, r.nombre AS rol,
            v.nombres || ' ' || v.apellidos AS veterinario
       FROM usuario u JOIN rol r ON r.id = u.rol_id LEFT JOIN veterinario v ON v.usuario_id = u.id
      ORDER BY u.activo DESC, u.nombre_usuario`,
  );

export const obtenerUsuario = (id: number) =>
  consultarUna(`SELECT id, rol_id, nombre_usuario, email, activo FROM usuario WHERE id = $1`, [id]);

export const opcionesRoles = () =>
  consultar(`SELECT id AS valor, nombre AS texto FROM rol ORDER BY nombre`) as Promise<{ valor: number; texto: string }[]>;

export async function crearUsuario(rol: number, nombre: string, email: string, hash: string): Promise<void> {
  await ejecutar(`INSERT INTO usuario (rol_id, nombre_usuario, email, password_hash) VALUES ($1,$2,$3,$4)`, [rol, nombre, email, hash]);
}

/** La contraseña solo cambia si se escribió una nueva. */
export const actualizarUsuario = (id: number, rol: number, nombre: string, email: string, activo: boolean, hash: string | null) =>
  ejecutar(
    `UPDATE usuario SET rol_id=$2, nombre_usuario=$3, email=$4, activo=$5, password_hash=COALESCE($6, password_hash) WHERE id=$1`,
    [id, rol, nombre, email, activo, hash],
  );
