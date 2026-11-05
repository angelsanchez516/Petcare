"use client";

import { startTransition, useActionState, useRef, type ReactNode } from "react";
import { useFormStatus } from "react-dom";

type Estado = { error?: string };
type Accion = (estado: Estado, datos: FormData) => Promise<Estado>;

function MensajeError({ texto }: { texto?: string }) {
  if (!texto) return null;
  return (
    <p role="alert" className="rounded-lg border border-error-600/20 bg-error-100 px-3 py-2 text-sm text-error-600">
      {texto}
    </p>
  );
}

export function BotonEnviar({ children, clase = "btn-primario", pendiente = "Guardando…" }: {
  children: ReactNode; clase?: string; pendiente?: string;
}) {
  const { pending } = useFormStatus();
  return (
    <button type="submit" disabled={pending} className={`btn btn-md ${clase}`}>
      {pending ? pendiente : children}
    </button>
  );
}

/** Formulario conectado a una server action. Muestra el error que devuelva y
 *  conserva lo escrito: si se usara el atributo action, React limpiaría los campos
 *  después de cada envío, aunque el servidor haya rechazado los datos. */
export function Formulario({ accion, children, className = "" }: { accion: Accion; children: ReactNode; className?: string }) {
  const [estado, enviar] = useActionState(accion, {} as Estado);
  return (
    <form
      method="post"
      onSubmit={(e) => {
        e.preventDefault();
        const datos = new FormData(e.currentTarget);
        startTransition(() => enviar(datos));
      }}
      className={`space-y-4 ${className}`}
    >
      <MensajeError texto={estado.error} />
      {children}
    </form>
  );
}

/** Botón de una sola acción (confirmar, dar de baja, quitar…), con confirmación
 *  opcional y, si hace falta, un motivo escrito. No usa alert() del navegador. */
export function BotonAccion({
  accion,
  campos,
  texto,
  clase = "btn-secundario",
  tam = "btn-sm",
  confirmar,
  motivo,
}: {
  accion: Accion;
  campos: Record<string, string | number>;
  texto: string;
  clase?: string;
  tam?: string;
  confirmar?: string;
  motivo?: string;
}) {
  const [estado, enviar, pendiente] = useActionState(accion, {} as Estado);
  const dialogo = useRef<HTMLDialogElement>(null);
  const ocultos = Object.entries(campos).map(([k, v]) => <input key={k} type="hidden" name={k} value={v} />);

  if (!confirmar) {
    return (
      <form action={enviar} className="inline-block">
        {ocultos}
        <button disabled={pendiente} className={`btn ${tam} ${clase}`}>{pendiente ? "…" : texto}</button>
        {estado.error && <p role="alert" className="mt-1 max-w-xs basis-full whitespace-normal text-xs text-error-600">{estado.error}</p>}
      </form>
    );
  }

  return (
    <>
      <button type="button" onClick={() => dialogo.current?.showModal()} className={`btn ${tam} ${clase}`}>
        {texto}
      </button>
      {estado.error && <p role="alert" className="mt-1 max-w-xs basis-full whitespace-normal text-xs text-error-600">{estado.error}</p>}
      <dialog ref={dialogo} className="w-[min(92vw,26rem)] rounded-xl border border-gris-200 p-0 shadow-alta backdrop:bg-tinta/40">
        <form
          action={enviar}
          onSubmit={() => dialogo.current?.close()}
          className="space-y-4 p-5 text-left"
        >
          {ocultos}
          <p className="text-[15px] font-semibold text-tinta">{texto}</p>
          <p className="text-sm leading-relaxed text-gris-700">{confirmar}</p>
          {motivo && (
            <label className="block">
              <span className="etiqueta">{motivo}</span>
              <textarea name="motivo" required maxLength={250} rows={3} className="campo" />
            </label>
          )}
          <div className="flex justify-end gap-2">
            <button type="button" onClick={() => dialogo.current?.close()} className="btn btn-md btn-fantasma">
              Volver
            </button>
            <button className={`btn btn-md ${clase === "btn-secundario" ? "btn-primario" : clase}`}>{texto}</button>
          </div>
        </form>
      </dialog>
    </>
  );
}

export function BotonImprimir() {
  return (
    <button type="button" onClick={() => window.print()} className="btn btn-md btn-secundario no-imprimir">
      Imprimir
    </button>
  );
}
