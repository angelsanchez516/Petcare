/** Traduce los valores que guarda la base a lo que ve el usuario. Cada lista
 *  coincide con el CHECK correspondiente de database/01_esquema.sql. */

export type Tono = "neutra" | "verde" | "ambar" | "roja" | "azul" | "marca";
type Etiqueta = { texto: string; tono: Tono };

export const ESTADOS_CITA: Record<string, Etiqueta> = {
  programada: { texto: "Programada", tono: "azul" },
  confirmada: { texto: "Confirmada", tono: "marca" },
  atendida: { texto: "Atendida", tono: "verde" },
  cancelada: { texto: "Cancelada", tono: "neutra" },
  no_asistio: { texto: "No asistió", tono: "roja" },
};

export const ESTADOS_FACTURA: Record<string, Etiqueta> = {
  pendiente: { texto: "Pendiente", tono: "ambar" },
  parcial: { texto: "Pago parcial", tono: "azul" },
  pagada: { texto: "Pagada", tono: "verde" },
  anulada: { texto: "Anulada", tono: "neutra" },
};

export const ESTADOS_VACUNA: Record<string, Etiqueta> = {
  VIGENTE: { texto: "Vigente", tono: "verde" },
  PROXIMA: { texto: "Próxima", tono: "ambar" },
  VENCIDA: { texto: "Vencida", tono: "roja" },
  SIN_DATOS: { texto: "Sin registro", tono: "neutra" },
  NO_APLICA: { texto: "No aplica", tono: "neutra" },
};

export const ESTADOS_TRATAMIENTO: Record<string, Etiqueta> = {
  activo: { texto: "Activo", tono: "marca" },
  completado: { texto: "Completado", tono: "verde" },
  suspendido: { texto: "Suspendido", tono: "neutra" },
};

export const ESTADOS_SOLICITUD: Record<string, Etiqueta> = {
  nueva: { texto: "Nueva", tono: "ambar" },
  contactada: { texto: "Contactada", tono: "azul" },
  convertida: { texto: "Convertida en cita", tono: "verde" },
  descartada: { texto: "Descartada", tono: "neutra" },
};

export const SEVERIDADES: Record<string, Etiqueta> = {
  LEVE: { texto: "Leve", tono: "neutra" },
  MEDIA: { texto: "Media", tono: "ambar" },
  GRAVE: { texto: "Grave", tono: "roja" },
};

export const TIPOS_DIAGNOSTICO: Record<string, Etiqueta> = {
  PRESUNTIVO: { texto: "Presuntivo", tono: "ambar" },
  DEFINITIVO: { texto: "Definitivo", tono: "verde" },
  DESCARTADO: { texto: "Descartado", tono: "neutra" },
};

export const TIPOS_CONSULTA: Record<string, string> = {
  GENERAL: "General",
  CONTROL: "Control",
  URGENCIA: "Urgencia",
  VACUNACION: "Vacunación",
  ESTETICA: "Estética",
};

export const VIAS: Record<string, string> = {
  ORAL: "Oral",
  TOPICA: "Tópica",
  INTRAMUSCULAR: "Intramuscular",
  SUBCUTANEA: "Subcutánea",
  INTRAVENOSA: "Intravenosa",
  OFTALMICA: "Oftálmica",
  OTICA: "Ótica",
};

export const TIPOS_DOCUMENTO: Record<string, string> = {
  CC: "Cédula de ciudadanía",
  CE: "Cédula de extranjería",
  TI: "Tarjeta de identidad",
  PASAPORTE: "Pasaporte",
  NIT: "NIT",
  OTRO: "Otro",
};

export const FRANJAS: Record<string, string> = {
  MANANA: "Mañana",
  TARDE: "Tarde",
  INDIFERENTE: "Indiferente",
};

export const TIPOS_HISTORIAL: Record<string, Etiqueta> = {
  CONSULTA: { texto: "Consulta", tono: "marca" },
  VACUNA: { texto: "Vacuna", tono: "azul" },
  PESO: { texto: "Peso", tono: "neutra" },
  CITA: { texto: "Cita", tono: "ambar" },
};
