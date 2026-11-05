import "server-only";

/** Límite de intentos para el inicio de sesión y el formulario público.
 *  Vive en memoria, así que se reinicia con el servidor: alcanza para frenar
 *  a quien prueba contraseñas o envía formularios en serie. */

type Registro = { veces: number; vence: number };

const registros = new Map<string, Registro>();

export function limiteAgotado(clave: string, maximo: number): boolean {
  const r = registros.get(clave);
  if (!r) return false;
  if (r.vence < Date.now()) {
    registros.delete(clave);
    return false;
  }
  return r.veces >= maximo;
}

export function sumarIntento(clave: string, minutos: number): void {
  const ahora = Date.now();
  // Quien inventa nombres de usuario no debe poder llenar la memoria.
  if (registros.size > 5000) {
    for (const [k, r] of registros) if (r.vence < ahora) registros.delete(k);
  }
  const r = registros.get(clave);
  if (r && r.vence >= ahora) r.veces++;
  else registros.set(clave, { veces: 1, vence: ahora + minutos * 60_000 });
}

export function limpiarIntentos(clave: string): void {
  registros.delete(clave);
}
