/** Tablas de referencia que se administran con la misma pantalla.
 *
 *  Cada catálogo describe sus columnas. Los nombres de tabla y columna que se usan
 *  en el SQL salen únicamente de esta lista; lo que escribe el usuario siempre va
 *  como parámetro de la consulta. */

export type Campo = {
  col: string;
  etiqueta: string;
  tipo: "texto" | "area" | "entero" | "dinero" | "casilla" | "opcion" | "fk";
  requerido?: boolean;
  max?: number;
  opciones?: Record<string, string>;
  /** Consulta que devuelve las opciones de una clave foránea (valor, texto). */
  fk?: string;
  /** Se muestra como columna en la lista. */
  enLista?: boolean;
  ayuda?: string;
};

export type Catalogo = {
  titulo: string;
  singular: string;
  descripcion: string;
  tabla: string;
  /** Consulta de la lista: debe traer id y nombre. */
  lista: string;
  campos: Campo[];
  /** Vacunas: relación N:M con especie, en vacuna_especie. */
  conEspecies?: boolean;
};

export const CATALOGOS: Record<string, Catalogo> = {
  especies: {
    titulo: "Especies", singular: "especie", descripcion: "Perros, gatos y demás especies que atiende la clínica",
    tabla: "especie", lista: `SELECT * FROM especie`,
    campos: [
      { col: "nombre", etiqueta: "Nombre", tipo: "texto", requerido: true, max: 50, enLista: true },
      { col: "icono", etiqueta: "Ícono (emoji)", tipo: "texto", max: 16, enLista: true },
      { col: "esperanza_vida_anios", etiqueta: "Esperanza de vida (años)", tipo: "entero", enLista: true },
    ],
  },
  razas: {
    titulo: "Razas", singular: "raza", descripcion: "Cada raza pertenece a una especie",
    tabla: "raza",
    lista: `SELECT r.*, e.nombre AS especie_id_texto FROM raza r JOIN especie e ON e.id = r.especie_id`,
    campos: [
      { col: "nombre", etiqueta: "Nombre", tipo: "texto", requerido: true, max: 80, enLista: true },
      { col: "especie_id", etiqueta: "Especie", tipo: "fk", requerido: true, enLista: true, fk: `SELECT id AS valor, nombre AS texto FROM especie ORDER BY nombre` },
      { col: "tamanio", etiqueta: "Tamaño", tipo: "opcion", enLista: true, opciones: { PEQUENO: "Pequeño", MEDIANO: "Mediano", GRANDE: "Grande", GIGANTE: "Gigante" } },
    ],
  },
  medicamentos: {
    titulo: "Medicamentos", singular: "medicamento", descripcion: "Inventario y precios; facturar un medicamento descuenta su stock",
    tabla: "medicamento", lista: `SELECT * FROM medicamento`,
    campos: [
      { col: "nombre", etiqueta: "Nombre", tipo: "texto", requerido: true, max: 120, enLista: true },
      { col: "principio_activo", etiqueta: "Principio activo", tipo: "texto", requerido: true, max: 120 },
      { col: "presentacion", etiqueta: "Presentación", tipo: "opcion", requerido: true, enLista: true,
        opciones: { COMPRIMIDO: "Comprimido", JARABE: "Jarabe", INYECTABLE: "Inyectable", CREMA: "Crema", GOTAS: "Gotas", SPRAY: "Spray", POLVO: "Polvo" } },
      { col: "concentracion", etiqueta: "Concentración", tipo: "texto", max: 40, enLista: true },
      { col: "laboratorio", etiqueta: "Laboratorio", tipo: "texto", max: 100 },
      { col: "stock", etiqueta: "Stock", tipo: "entero", requerido: true, enLista: true },
      { col: "stock_minimo", etiqueta: "Stock mínimo", tipo: "entero", requerido: true, enLista: true },
      { col: "precio", etiqueta: "Precio", tipo: "dinero", requerido: true, enLista: true },
      { col: "requiere_receta", etiqueta: "Requiere receta", tipo: "casilla" },
      { col: "activo", etiqueta: "Activo", tipo: "casilla", enLista: true },
    ],
  },
  vacunas: {
    titulo: "Vacunas", singular: "vacuna", descripcion: "Intervalos de refuerzo y especies para las que está indicada",
    tabla: "vacuna", conEspecies: true,
    lista: `SELECT v.*, (SELECT string_agg(e.nombre, ', ' ORDER BY e.nombre) FROM vacuna_especie ve
                          JOIN especie e ON e.id = ve.especie_id WHERE ve.vacuna_id = v.id) AS especies FROM vacuna v`,
    campos: [
      { col: "nombre", etiqueta: "Nombre", tipo: "texto", requerido: true, max: 100, enLista: true },
      { col: "laboratorio", etiqueta: "Laboratorio", tipo: "texto", max: 100 },
      { col: "enfermedades_previene", etiqueta: "Enfermedades que previene", tipo: "texto", max: 300 },
      { col: "intervalo_refuerzo_meses", etiqueta: "Refuerzo cada (meses)", tipo: "entero", enLista: true },
      { col: "edad_minima_semanas", etiqueta: "Edad mínima (semanas)", tipo: "entero" },
      { col: "precio", etiqueta: "Precio", tipo: "dinero", requerido: true, enLista: true },
      { col: "activo", etiqueta: "Activa", tipo: "casilla", enLista: true },
    ],
  },
  servicios: {
    titulo: "Servicios", singular: "servicio", descripcion: "Lo que se agenda y se factura; también aparece en el sitio público",
    tabla: "servicio", lista: `SELECT * FROM servicio`,
    campos: [
      { col: "codigo", etiqueta: "Código", tipo: "texto", requerido: true, max: 15, enLista: true },
      { col: "nombre", etiqueta: "Nombre", tipo: "texto", requerido: true, max: 120, enLista: true },
      { col: "categoria", etiqueta: "Categoría", tipo: "opcion", requerido: true, enLista: true,
        opciones: { CONSULTA: "Consulta", CIRUGIA: "Cirugía", DIAGNOSTICO: "Diagnóstico", ESTETICA: "Estética", VACUNACION: "Vacunación", OTRO: "Otro" } },
      { col: "precio_base", etiqueta: "Precio base", tipo: "dinero", requerido: true, enLista: true },
      { col: "duracion_estimada_min", etiqueta: "Duración (min)", tipo: "entero", enLista: true },
      { col: "icono", etiqueta: "Ícono (emoji)", tipo: "texto", max: 16 },
      { col: "descripcion", etiqueta: "Descripción", tipo: "area" },
      { col: "visible_publico", etiqueta: "Visible en el sitio", tipo: "casilla" },
      { col: "activo", etiqueta: "Activo", tipo: "casilla", enLista: true },
    ],
  },
  diagnosticos: {
    titulo: "Diagnósticos", singular: "diagnóstico", descripcion: "Catálogo que alimenta el reporte de morbilidad",
    tabla: "diagnostico", lista: `SELECT * FROM diagnostico`,
    campos: [
      { col: "codigo", etiqueta: "Código", tipo: "texto", requerido: true, max: 15, enLista: true },
      { col: "nombre", etiqueta: "Nombre", tipo: "texto", requerido: true, max: 120, enLista: true },
      { col: "categoria", etiqueta: "Categoría", tipo: "texto", max: 50, enLista: true },
    ],
  },
  condiciones: {
    titulo: "Condiciones médicas", singular: "condición", descripcion: "Alergias y enfermedades crónicas o congénitas",
    tabla: "condicion_medica", lista: `SELECT * FROM condicion_medica`,
    campos: [
      { col: "nombre", etiqueta: "Nombre", tipo: "texto", requerido: true, max: 100, enLista: true },
      { col: "tipo", etiqueta: "Tipo", tipo: "opcion", requerido: true, enLista: true, opciones: { ALERGIA: "Alergia", CRONICA: "Crónica", CONGENITA: "Congénita" } },
      { col: "descripcion", etiqueta: "Descripción", tipo: "texto", max: 300 },
    ],
  },
  especialidades: {
    titulo: "Especialidades", singular: "especialidad", descripcion: "Áreas de los veterinarios",
    tabla: "especialidad", lista: `SELECT * FROM especialidad`,
    campos: [
      { col: "nombre", etiqueta: "Nombre", tipo: "texto", requerido: true, max: 80, enLista: true },
      { col: "descripcion", etiqueta: "Descripción", tipo: "texto", max: 200, enLista: true },
    ],
  },
  "metodos-pago": {
    titulo: "Métodos de pago", singular: "método de pago", descripcion: "Formas de pago que acepta caja",
    tabla: "metodo_pago", lista: `SELECT * FROM metodo_pago`,
    campos: [
      { col: "nombre", etiqueta: "Nombre", tipo: "texto", requerido: true, max: 40, enLista: true },
      { col: "requiere_referencia", etiqueta: "Exige número de referencia", tipo: "casilla", enLista: true },
      { col: "activo", etiqueta: "Activo", tipo: "casilla", enLista: true },
    ],
  },
};
