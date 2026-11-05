import { Pool, type PoolClient, type QueryResultRow } from "pg";

/**
 * Acceso a PostgreSQL.
 *
 * El proyecto NO usa un ORM a propósito: la base de datos se diseñó y se creó a
 * mano, y la aplicación se conecta a un esquema que ya existe y no tiene permiso
 * para alterarlo. Todas las consultas se escriben en SQL explícito.
 *
 * La contraseña no vive en este archivo ni en .env.local: node-postgres la lee
 * del archivo pgpass del sistema, igual que psql.
 */

/** Fila genérica de una consulta. Las columnas son las de la base de datos. */
// eslint-disable-next-line @typescript-eslint/no-explicit-any
export type Fila = Record<string, any>;

declare global {
  // En desarrollo Next recarga los módulos en cada cambio. Sin esto se abriría
  // un pool nuevo por recarga hasta agotar las conexiones del servidor.
  // eslint-disable-next-line no-var
  var __petcarePool: Pool | undefined;
}

function crearPool(): Pool {
  const pool = new Pool({
    host: process.env.PGHOST ?? "localhost",
    port: Number(process.env.PGPORT ?? 5432),
    database: process.env.PGDATABASE ?? "petcare",
    user: process.env.PGUSER ?? "postgres",
    password: process.env.PGPASSWORD,
    max: 10,
    idleTimeoutMillis: 30_000,
    connectionTimeoutMillis: 5_000,
  });

  pool.on("error", (err) => {
    console.error("[db] error en una conexión inactiva del pool:", err.message);
  });

  return pool;
}

export const pool: Pool = global.__petcarePool ?? crearPool();
if (process.env.NODE_ENV !== "production") global.__petcarePool = pool;

/** Ejecuta una consulta y devuelve todas las filas. */
export async function consultar<T extends QueryResultRow = QueryResultRow>(
  sql: string,
  valores: unknown[] = [],
): Promise<T[]> {
  const res = await pool.query<T>(sql, valores);
  return res.rows;
}

/** Ejecuta una consulta que devuelve como mucho una fila. */
export async function consultarUna<T extends QueryResultRow = QueryResultRow>(
  sql: string,
  valores: unknown[] = [],
): Promise<T | null> {
  const res = await pool.query<T>(sql, valores);
  return res.rows[0] ?? null;
}

/** Ejecuta una sentencia y devuelve cuántas filas afectó. */
export async function ejecutar(sql: string, valores: unknown[] = []): Promise<number> {
  const res = await pool.query(sql, valores);
  return res.rowCount ?? 0;
}

/**
 * Corre varias sentencias dentro de una transacción. Si la función lanza, se
 * revierte todo. Es imprescindible donde el modelo tiene reglas que abarcan
 * varias tablas: una factura y sus líneas, o una consulta con su diagnóstico,
 * su tratamiento y su receta.
 */
export async function enTransaccion<T>(
  fn: (cx: PoolClient) => Promise<T>,
): Promise<T> {
  const cx = await pool.connect();
  try {
    await cx.query("BEGIN");
    const resultado = await fn(cx);
    await cx.query("COMMIT");
    return resultado;
  } catch (e) {
    await cx.query("ROLLBACK");
    throw e;
  } finally {
    cx.release();
  }
}

/**
 * Traduce los errores de PostgreSQL a mensajes que una persona pueda entender.
 *
 * Las restricciones del esquema son la última línea de defensa y se disparan de
 * verdad: el usuario merece saber qué regla rompió, no un código SQLSTATE.
 */
export function mensajeDeError(e: unknown): string {
  const err = e as { code?: string; constraint?: string; message?: string; detail?: string };

  const porRestriccion: Record<string, string> = {
    uq_cliente_documento:      "Ya existe un tutor con ese tipo y número de documento.",
    uq_veterinario_documento:  "Ya existe un veterinario con ese documento.",
    uq_veterinario_matricula:  "Esa matrícula profesional ya está registrada.",
    uq_usuario_nombre:         "Ese nombre de usuario ya está en uso.",
    uq_usuario_email:          "Ese correo ya está registrado.",
    uq_cliente_email:          "Ese correo ya está registrado para otro tutor.",
    uq_veterinario_email:      "Ese correo ya está registrado para otro veterinario.",
    uq_veterinario_usuario:    "Ese usuario ya está vinculado a otro veterinario.",
    uq_rol_nombre:             "Ya existe un rol con ese nombre.",
    uq_especialidad_nombre:    "Ya existe una especialidad con ese nombre.",
    uq_condicion_nombre:       "Ya existe una condición médica con ese nombre.",
    uq_diagnostico_nombre:     "Ya existe un diagnóstico con ese nombre.",
    uq_metodo_pago_nombre:     "Ya existe un método de pago con ese nombre.",
    pk_consulta_diagnostico:   "Ese diagnóstico ya está registrado en la consulta.",
    uq_consulta_diag_principal:"La consulta ya tiene un diagnóstico principal.",
    uq_vet_especialidad_principal: "El veterinario ya tiene una especialidad principal.",
    pk_receta_detalle:         "Ese medicamento ya está en la receta.",
    pk_mascota_condicion:      "Esa condición ya está registrada en la mascota.",
    ck_mascota_deceso:         "La fecha de fallecimiento no puede ser anterior a la de nacimiento.",
    ck_consulta_revision:      "La próxima revisión no puede ser anterior a la consulta.",
    ck_tratamiento_fechas:     "La fecha de fin no puede ser anterior a la de inicio.",
    ck_registro_fecha:         "La fecha del peso no puede ser futura.",
    ck_aplicacion_fecha:       "La fecha de aplicación no puede ser futura.",
    ck_aplicacion_dosis:       "El número de dosis debe estar entre 1 y 20.",
    ck_receta_det_duracion:    "La duración debe estar entre 1 y 365 días.",
    ck_receta_det_cantidad:    "La cantidad debe ser mayor que cero.",
    ck_receta_vigencia:        "La vigencia debe estar entre 1 y 365 días.",
    ck_factura_fecha:          "La fecha de emisión no puede ser futura.",
    uq_mascota_microchip:      "Ese número de microchip ya pertenece a otra mascota.",
    uq_registro_peso_dia:      "Ya se registró un peso para esta mascota en esa fecha.",
    uq_consulta_cita:          "Esa cita ya tiene una consulta registrada.",
    uq_receta_consulta:        "Esa consulta ya tiene una receta emitida.",
    uq_aplicacion_vacuna:      "Esa vacuna ya fue aplicada a esta mascota en esa fecha.",
    uq_raza_especie_nombre:    "Esa raza ya existe para la especie seleccionada.",
    uq_especie_nombre:         "Ya existe una especie con ese nombre.",
    uq_servicio_codigo:        "Ya existe un servicio con ese código.",
    uq_servicio_nombre:        "Ya existe un servicio con ese nombre.",
    uq_diagnostico_codigo:     "Ya existe un diagnóstico con ese código.",
    uq_vacuna_nombre:          "Ya existe una vacuna con ese nombre.",
    uq_medicamento_nombre:     "Ya existe un medicamento con ese nombre y concentración.",
    uq_factura_detalle_linea:  "Ese número de línea ya existe en la factura.",

    ex_cita_sin_solapamiento:  "El veterinario ya tiene otra cita que se superpone con ese horario.",

    fk_mascota_raza_especie:   "La raza seleccionada no corresponde a la especie de la mascota.",
    fk_mascota_cliente:        "El tutor indicado no existe.",
    fk_consulta_mascota:       "La mascota indicada no existe.",

    ck_mascota_sexo:           "El sexo debe ser M (macho) o H (hembra).",
    ck_mascota_nacimiento:     "La fecha de nacimiento no puede ser futura.",
    ck_mascota_microchip:      "El microchip debe tener entre 9 y 25 caracteres alfanuméricos.",
    ck_cita_estado:            "El estado de la cita no es válido.",
    ck_cita_duracion:          "La duración debe estar entre 10 y 480 minutos.",
    ck_cita_cancelacion:       "Para cancelar una cita hay que indicar el motivo.",
    ck_consulta_temp:          "La temperatura debe estar entre 30 y 45 °C.",
    ck_consulta_fc:            "La frecuencia cardíaca debe estar entre 20 y 400 lpm.",
    ck_consulta_fr:            "La frecuencia respiratoria debe estar entre 5 y 200 rpm.",
    ck_consulta_fecha:         "La consulta no puede tener fecha futura.",
    ck_registro_peso:          "El peso debe ser mayor que cero.",
    ck_aplicacion_refuerzo:    "El refuerzo no puede ser anterior a la fecha de aplicación.",
    ck_factura_det_cantidad:   "La cantidad debe ser mayor que cero.",
    ck_factura_det_item:       "Cada línea debe facturar un servicio o un medicamento, no ambos.",
    ck_factura_descuento:      "El descuento no puede superar el subtotal.",
    ck_pago_monto:             "El monto del pago debe ser mayor que cero.",
    ck_medicamento_stock:      "El stock no puede quedar negativo.",
    dom_dinero_no_negativo:    "El importe no puede ser negativo.",
    dom_email_formato:         "El formato del correo electrónico no es válido.",
    dom_telefono_formato:      "El teléfono solo admite números, espacios, paréntesis, «+» y «-».",
  };

  if (err.constraint && porRestriccion[err.constraint]) {
    return porRestriccion[err.constraint];
  }

  // Los errores que los triggers lanzan con RAISE EXCEPTION ya traen un mensaje
  // redactado para una persona: se muestra tal cual.
  if (err.code === "23514" || err.code === "P0001") {
    return err.message ?? "La operación no cumple una regla del sistema.";
  }
  if (err.code === "23503") {
    return "No se puede completar: el registro está siendo usado por otro, o el dato relacionado no existe.";
  }
  if (err.code === "23505") {
    return "Ya existe un registro con esos datos.";
  }
  if (err.code === "22003") {
    return "Uno de los valores numéricos es demasiado grande.";
  }
  if (err.code === "22008" || err.code === "22007") {
    return "Una de las fechas no es válida.";
  }
  if (err.code === "23502") {
    return "Falta completar un campo obligatorio.";
  }
  if (err.code === "ECONNREFUSED" || err.code === "28P01") {
    return "No se pudo conectar con la base de datos. Revisa la configuración.";
  }

  console.error("[db] error no catalogado:", err.code, err.message, err.detail);
  return "Ocurrió un error inesperado al procesar la operación.";
}
