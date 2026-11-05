/** Qué puede hacer cada rol. Está separado de auth.ts porque también lo usa el
 *  menú lateral, que corre en el navegador. */

const A = "Administrador";
const V = "Veterinario";
const R = "Recepcionista";

const PERMISOS = {
  tablero: [A, V, R],
  clientes: [A, V, R],
  "clientes.editar": [A, R],
  mascotas: [A, V, R],
  "mascotas.editar": [A, V, R],
  "mascotas.administrar": [A, R], // cambiar el tutor y dar de baja
  citas: [A, V, R],
  solicitudes: [A, R],
  clinica: [A, V], // consultas, diagnósticos, tratamientos y recetas
  vacunas: [A, V, R],
  "vacunas.aplicar": [A, V],
  facturas: [A, R],
  catalogos: [A],
  personal: [A], // veterinarios y usuarios
  reportes: [A],
} as const;

export type Permiso = keyof typeof PERMISOS;

export function puede(rol: string, permiso: Permiso): boolean {
  return (PERMISOS[permiso] as readonly string[]).includes(rol);
}

// Reglas que dependen del registro, no solo del rol. El veterinario autenticado se
// conoce por veterinario.usuario_id, y el autor de un registro por su veterinario_id.
type Quien = { rol: string; veterinario_id: number | null };

/** El historial clínico lo lee todo el equipo, pero solo lo modifica quien firmó
 *  el registro o un administrador. */
export function puedeEditarClinica(u: Quien, veterinarioDelRegistro: number): boolean {
  return u.rol === A || (u.rol === V && u.veterinario_id === veterinarioDelRegistro);
}

/** Recepción y administración manejan toda la agenda; el veterinario, solo sus citas. */
export function puedeGestionarCita(u: Quien, veterinarioDeLaCita: number): boolean {
  return u.rol !== V || u.veterinario_id === veterinarioDeLaCita;
}

/** Un veterinario sin perfil vinculado no tiene a nombre de quién agendar. */
export const puedeAgendar = (u: Quien): boolean => u.rol !== V || u.veterinario_id !== null;

/** Consultas y vacunas se firman siempre con el perfil de quien inició sesión. */
export const puedeFirmar = (u: Quien): boolean => u.veterinario_id !== null && (u.rol === A || u.rol === V);
