import Link from "next/link";
import type { ReactNode } from "react";
import type { Tono } from "@/lib/etiquetas";
import { iniciales } from "@/lib/formato";

/** Piezas visuales que se repiten en todo el panel. */

export function Cabecera({
  titulo, subtitulo, migas, children,
}: {
  titulo: ReactNode;
  subtitulo?: ReactNode;
  migas?: { texto: string; href?: string }[];
  children?: ReactNode;
}) {
  return (
    <header className="mb-6">
      {migas && (
        <nav aria-label="Ruta" className="no-imprimir mb-2 flex flex-wrap items-center gap-1.5 text-xs text-gris-600">
          {migas.map((m, i) => (
            <span key={i} className="flex items-center gap-1.5">
              {i > 0 && <span aria-hidden="true">/</span>}
              {m.href ? <Link href={m.href} className="hover:text-verde-700">{m.texto}</Link> : <span>{m.texto}</span>}
            </span>
          ))}
        </nav>
      )}
      <div className="flex flex-wrap items-start justify-between gap-4">
        <div className="min-w-0">
          <h1 className="text-2xl font-semibold tracking-tight text-tinta">{titulo}</h1>
          {subtitulo && <p className="mt-1 text-sm text-gris-600">{subtitulo}</p>}
        </div>
        {children && <div className="no-imprimir flex flex-wrap items-center gap-2">{children}</div>}
      </div>
    </header>
  );
}

export function Insignia({ tono = "neutra", children }: { tono?: Tono; children: ReactNode }) {
  return <span className={`insignia insignia-${tono}`}>{children}</span>;
}

export function EstadoDe({ mapa, valor }: { mapa: Record<string, { texto: string; tono: Tono }>; valor: string }) {
  const e = mapa[valor];
  return <Insignia tono={e?.tono}>{e?.texto ?? valor}</Insignia>;
}

export function Seccion({
  titulo, children, accion, className = "", sinRelleno = false,
}: {
  titulo?: ReactNode;
  children: ReactNode;
  accion?: ReactNode;
  className?: string;
  sinRelleno?: boolean;
}) {
  return (
    <section className={`tarjeta ${className}`}>
      {titulo && (
        <div className="flex flex-wrap items-center justify-between gap-2 border-b border-gris-200 px-5 py-3.5">
          <h2 className="text-[15px] font-semibold text-tinta">{titulo}</h2>
          {accion && <div className="no-imprimir">{accion}</div>}
        </div>
      )}
      <div className={sinRelleno ? "" : "p-5"}>{children}</div>
    </section>
  );
}

export function Vacio({ titulo, texto, children }: { titulo: string; texto?: string; children?: ReactNode }) {
  return (
    <div className="px-6 py-10 text-center">
      <p className="text-sm font-medium text-gris-700">{titulo}</p>
      {texto && <p className="mx-auto mt-1 max-w-sm text-sm text-gris-600">{texto}</p>}
      {children && <div className="mt-4">{children}</div>}
    </div>
  );
}

export function Cifra({ etiqueta, valor, nota, href, alerta }: {
  etiqueta: string; valor: ReactNode; nota?: string; href?: string; alerta?: boolean;
}) {
  const contenido = (
    <>
      <p className="text-xs font-medium text-gris-600">{etiqueta}</p>
      <p className={`mt-1.5 text-2xl font-semibold tracking-tight cifra ${alerta ? "text-alerta-600" : "text-tinta"}`}>{valor}</p>
      {nota && <p className="mt-0.5 text-xs text-gris-600">{nota}</p>}
    </>
  );
  const clase = "tarjeta block p-4";
  return href
    ? <Link href={href} className={`${clase} transition-colors hover:border-verde-200 hover:bg-verde-50/40`}>{contenido}</Link>
    : <div className={clase}>{contenido}</div>;
}

export function Dato({ etiqueta, children }: { etiqueta: string; children: ReactNode }) {
  return (
    <div>
      <dt className="text-xs text-gris-600">{etiqueta}</dt>
      <dd className="mt-0.5 text-sm text-tinta">{children || "—"}</dd>
    </div>
  );
}

export function Avatar({ foto, nombre, icono, tam = 40 }: {
  foto?: string | null; nombre: string; icono?: string | null; tam?: number;
}) {
  const estilo = { width: tam, height: tam, fontSize: tam * 0.38 };
  if (foto) {
    // eslint-disable-next-line @next/next/no-img-element
    return <img src={foto} alt="" style={estilo} className="shrink-0 rounded-full object-cover" />;
  }
  return (
    <span style={estilo} aria-hidden="true"
      className="flex shrink-0 items-center justify-center rounded-full bg-verde-100 font-medium text-verde-700">
      {icono ?? iniciales(nombre)}
    </span>
  );
}

/** Campo de formulario con su etiqueta. `name` y demás atributos pasan al input. */
export function Entrada({ etiqueta, ayuda, ...props }: {
  etiqueta: string; ayuda?: string;
} & React.InputHTMLAttributes<HTMLInputElement>) {
  return (
    <label className="block">
      <span className="etiqueta">{etiqueta}{props.required && <span className="text-error-600"> *</span>}</span>
      <input className="campo" {...props} />
      {ayuda && <span className="ayuda block">{ayuda}</span>}
    </label>
  );
}

export function AreaTexto({ etiqueta, ...props }: {
  etiqueta: string;
} & React.TextareaHTMLAttributes<HTMLTextAreaElement>) {
  return (
    <label className="block">
      <span className="etiqueta">{etiqueta}{props.required && <span className="text-error-600"> *</span>}</span>
      <textarea rows={3} className="campo" {...props} />
    </label>
  );
}

export function Selector({ etiqueta, opciones, vacio, ...props }: {
  etiqueta: string;
  opciones: { valor: string | number; texto: string }[] | Record<string, string>;
  vacio?: string;
} & React.SelectHTMLAttributes<HTMLSelectElement>) {
  const lista = Array.isArray(opciones)
    ? opciones
    : Object.entries(opciones).map(([valor, texto]) => ({ valor, texto }));
  return (
    <label className="block">
      <span className="etiqueta">{etiqueta}{props.required && <span className="text-error-600"> *</span>}</span>
      <select className="campo" {...props}>
        {vacio !== undefined && <option value="">{vacio}</option>}
        {lista.map((o) => <option key={o.valor} value={o.valor}>{o.texto}</option>)}
      </select>
      {props.required && lista.length === 0 && <span className="ayuda block">No hay opciones disponibles. Revisa los catálogos o pídele ayuda a un administrador.</span>}
    </label>
  );
}

export function Casilla({ etiqueta, ...props }: { etiqueta: string } & React.InputHTMLAttributes<HTMLInputElement>) {
  return (
    <label className="flex items-center gap-2 text-sm text-gris-700">
      <input type="checkbox" className="h-4 w-4 accent-verde-700" {...props} />
      {etiqueta}
    </label>
  );
}

/** Buscador y filtros: un formulario GET normal, los valores quedan en la URL. */
export function Filtros({ children }: { children: ReactNode }) {
  return (
    <form method="get" className="no-imprimir mb-4 flex flex-wrap items-end gap-2">
      {children}
      <button className="btn btn-md btn-secundario">Filtrar</button>
    </form>
  );
}

export const POR_PAGINA = 12;

export function Paginacion({ pagina, total, ruta, params = {} }: {
  pagina: number; total: number; ruta: string; params?: Record<string, string | undefined>;
}) {
  const paginas = Math.ceil(total / POR_PAGINA);
  if (paginas <= 1) return null;
  const enlace = (n: number) => {
    const q = new URLSearchParams();
    Object.entries(params).forEach(([k, v]) => v && q.set(k, v));
    q.set("pag", String(n));
    return `${ruta}?${q}`;
  };
  return (
    <nav aria-label="Paginación" className="no-imprimir mt-4 flex items-center justify-between text-sm text-gris-600">
      <span>Página {pagina} de {paginas} · {total} registros</span>
      <span className="flex gap-2">
        {pagina > 1 && <Link href={enlace(pagina - 1)} className="btn btn-sm btn-secundario">Anterior</Link>}
        {pagina < paginas && <Link href={enlace(pagina + 1)} className="btn btn-sm btn-secundario">Siguiente</Link>}
      </span>
    </nav>
  );
}

export function paginaDe(valor?: string): number {
  const n = Number(valor);
  return Number.isInteger(n) && n > 0 ? n : 1;
}

/** Id numérico de la URL. Devuelve null si no es un entero válido. */
export function idDe(valor: string): number | null {
  return /^\d{1,9}$/.test(valor) ? Number(valor) : null;
}

/** Tabla que se desplaza dentro de su caja en pantallas pequeñas. */
export function Tabla({ children }: { children: ReactNode }) {
  return (
    <div className="scroll-x">
      <table className="tabla tabla-hover">{children}</table>
    </div>
  );
}
