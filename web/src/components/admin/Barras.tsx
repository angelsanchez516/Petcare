/** Gráfica de barras horizontales de una sola serie, hecha solo con HTML. El valor
 *  siempre va escrito al lado de la barra, así que se lee también al imprimir. */
export function Barras({ datos }: { datos: { etiqueta: string; valor: number; texto: string }[] }) {
  const maximo = Math.max(...datos.map((d) => d.valor), 1);
  return (
    <ul className="space-y-3">
      {datos.map((d) => (
        <li key={d.etiqueta} title={`${d.etiqueta}: ${d.texto}`}>
          <div className="flex items-baseline justify-between gap-3 text-sm">
            <span className="truncate text-gris-700">{d.etiqueta}</span>
            <span className="shrink-0 font-medium text-tinta cifra">{d.texto}</span>
          </div>
          <div className="mt-1 h-2 rounded-full bg-gris-100">
            <div className="h-2 rounded-full bg-verde-600" style={{ width: `${(d.valor / maximo) * 100}%` }} />
          </div>
        </li>
      ))}
    </ul>
  );
}
