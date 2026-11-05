/** Formateo compartido por toda la aplicación. Centralizado para que la misma
 *  cifra o la misma fecha no se vean de dos maneras distintas según la pantalla. */

const LOCALE = "es-CO";

const fmtMoneda = new Intl.NumberFormat(LOCALE, {
  style: "currency",
  currency: "COP",
  maximumFractionDigits: 0,
});

const fmtNumero = new Intl.NumberFormat(LOCALE, { maximumFractionDigits: 2 });

/** Los importes llegan de PostgreSQL como texto: NUMERIC no cabe en un número
 *  de JavaScript sin perder precisión, así que el driver lo entrega como string. */
export function dinero(valor: string | number | null | undefined): string {
  if (valor === null || valor === undefined) return "—";
  const n = typeof valor === "string" ? Number(valor) : valor;
  return Number.isFinite(n) ? fmtMoneda.format(n) : "—";
}

export function numero(valor: string | number | null | undefined, sufijo = ""): string {
  if (valor === null || valor === undefined) return "—";
  const n = typeof valor === "string" ? Number(valor) : valor;
  return Number.isFinite(n) ? fmtNumero.format(n) + sufijo : "—";
}

export function fecha(valor: Date | string | null | undefined): string {
  if (!valor) return "—";
  const d = valor instanceof Date ? valor : new Date(valor);
  if (Number.isNaN(d.getTime())) return "—";
  return d.toLocaleDateString(LOCALE, { day: "2-digit", month: "short", year: "numeric" });
}

export function fechaLarga(valor: Date | string | null | undefined): string {
  if (!valor) return "—";
  const d = valor instanceof Date ? valor : new Date(valor);
  if (Number.isNaN(d.getTime())) return "—";
  return d.toLocaleDateString(LOCALE, {
    weekday: "long", day: "numeric", month: "long", year: "numeric",
  });
}

export function hora(valor: Date | string | null | undefined): string {
  if (!valor) return "—";
  const d = valor instanceof Date ? valor : new Date(valor);
  if (Number.isNaN(d.getTime())) return "—";
  return d.toLocaleTimeString(LOCALE, { hour: "2-digit", minute: "2-digit", hour12: false });
}

export function fechaHora(valor: Date | string | null | undefined): string {
  if (!valor) return "—";
  return `${fecha(valor)} · ${hora(valor)}`;
}

/** Para los campos <input type="date"> y type="datetime-local">. */
export function paraInput(valor: Date | string | null | undefined): string {
  if (!valor) return "";
  const d = valor instanceof Date ? valor : new Date(valor);
  if (Number.isNaN(d.getTime())) return "";
  const p = (n: number) => String(n).padStart(2, "0");
  return `${d.getFullYear()}-${p(d.getMonth() + 1)}-${p(d.getDate())}`;
}

export function paraInputHora(valor: Date | string | null | undefined): string {
  if (!valor) return "";
  const d = valor instanceof Date ? valor : new Date(valor);
  if (Number.isNaN(d.getTime())) return "";
  const p = (n: number) => String(n).padStart(2, "0");
  return `${paraInput(d)}T${p(d.getHours())}:${p(d.getMinutes())}`;
}

/** «hace 3 días», «en 2 semanas». Para listas donde lo que importa es la
 *  cercanía, no la fecha exacta. */
export function relativo(valor: Date | string | null | undefined): string {
  if (!valor) return "—";
  const d = valor instanceof Date ? valor : new Date(valor);
  if (Number.isNaN(d.getTime())) return "—";

  const dias = Math.round((d.getTime() - Date.now()) / 86_400_000);
  const abs = Math.abs(dias);
  if (abs === 0) return "hoy";
  if (dias === 1) return "mañana";
  if (dias === -1) return "ayer";

  const rtf = new Intl.RelativeTimeFormat(LOCALE, { numeric: "auto" });
  if (abs < 30) return rtf.format(dias, "day");
  if (abs < 365) return rtf.format(Math.round(dias / 30), "month");
  return rtf.format(Math.round(dias / 365), "year");
}

/** Edad en el formato que usa un veterinario: años y meses, o solo meses en
 *  cachorros, donde la diferencia entre 2 y 5 meses es clínicamente relevante. */
export function edad(anios: number | null, meses: number | null): string {
  if (meses === null || meses === undefined) return "Edad desconocida";
  if (meses < 24) return `${meses} ${meses === 1 ? "mes" : "meses"}`;
  const a = anios ?? Math.floor(meses / 12);
  const resto = meses - a * 12;
  return resto === 0 ? `${a} años` : `${a} años y ${resto} ${resto === 1 ? "mes" : "meses"}`;
}

export function iniciales(nombre: string): string {
  return nombre
    .trim().split(/\s+/).slice(0, 2)
    .map((p) => p[0]?.toUpperCase() ?? "")
    .join("");
}
