"use client";

/** Pantalla cuando una página falla, por ejemplo si PostgreSQL está detenido. */
export default function ErrorGeneral({ reset }: { error: Error; reset: () => void }) {
  return (
    <div className="mx-auto max-w-md px-6 py-24 text-center">
      <h1 className="text-xl font-semibold text-tinta">No se pudo cargar esta página</h1>
      <p className="mt-2 text-sm leading-relaxed text-gris-600">
        Puede que la base de datos no esté disponible. Verifica que el servicio de PostgreSQL esté en ejecución e inténtalo de nuevo.
      </p>
      <button onClick={reset} className="btn btn-md btn-primario mt-6">Reintentar</button>
    </div>
  );
}
