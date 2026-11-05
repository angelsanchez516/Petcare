/** Datos institucionales de la clínica.
 *
 *  Viven en código y no en la base de datos a propósito: el MER no contempla
 *  una entidad de configuración, y agregar una tabla de una sola fila solo para
 *  esto sería desproporcionado. Si más adelante la clínica necesita varias
 *  sedes, ahí sí corresponde modelarlo. */

export const CONTACTO = {
  telefono: "+57 601 742 8800",
  telefonoLink: "+576017428800",
  whatsapp: "+57 310 555 1000",
  whatsappLink: "573105551000",
  email: "contacto@petcare.vet",
  direccion: "Cra. 15 #93-47, Chapinero",
  ciudad: "Bogotá, Colombia",
} as const;

export const HORARIOS = [
  { dias: "Lunes a viernes", horas: "7:00 – 19:00" },
  { dias: "Sábados",         horas: "8:00 – 16:00" },
  { dias: "Domingos",        horas: "9:00 – 13:00" },
] as const;

export const CATEGORIAS_SERVICIO: Record<string, { nombre: string; descripcion: string }> = {
  CONSULTA:    { nombre: "Consulta",    descripcion: "Atención clínica general y de urgencia" },
  VACUNACION:  { nombre: "Prevención",  descripcion: "Vacunación y desparasitación con control de refuerzos" },
  DIAGNOSTICO: { nombre: "Diagnóstico", descripcion: "Imagen y laboratorio con informe del especialista" },
  CIRUGIA:     { nombre: "Cirugía",     descripcion: "Procedimientos programados con monitoreo anestésico" },
  ESTETICA:    { nombre: "Estética",    descripcion: "Higiene y cuidado del pelaje" },
  OTRO:        { nombre: "Otros",       descripcion: "Servicios complementarios" },
};
