import { Vacio } from "@/components/ui";
import type { Fila } from "@/lib/db";
import { fecha, numero } from "@/lib/formato";

/** Línea de peso en SVG. El eje X respeta el tiempo real entre mediciones. */
export function GraficaPeso({ pesos }: { pesos: Fila[] }) {
  if (pesos.length < 2) return <Vacio titulo="Hacen falta al menos dos mediciones para ver la evolución" />;

  const W = 640, H = 200, MX = 44, MY = 22;
  const tiempos = pesos.map((p) => new Date(p.fecha_registro).getTime());
  const valores = pesos.map((p) => Number(p.peso_kg));
  const [t0, t1] = [Math.min(...tiempos), Math.max(...tiempos)];
  const [v0, v1] = [Math.min(...valores), Math.max(...valores)];
  const rango = v1 - v0 || 1;

  const x = (t: number) => MX + ((t - t0) / (t1 - t0 || 1)) * (W - MX * 2);
  const y = (v: number) => H - MY - ((v - v0) / rango) * (H - MY * 2);
  const puntos = pesos.map((_, i) => `${x(tiempos[i])},${y(valores[i])}`).join(" ");
  const ultimo = pesos.length - 1;

  return (
    <div className="scroll-x">
      <svg viewBox={`0 0 ${W} ${H}`} role="img" className="w-full min-w-[420px]"
        aria-label={`Peso desde ${fecha(pesos[0].fecha_registro)}: de ${numero(valores[0])} a ${numero(valores[ultimo])} kilos`}>
        {[v0, v1].map((v) => (
          <g key={v}>
            <line x1={MX} x2={W - MX} y1={y(v)} y2={y(v)} stroke="rgb(227 233 231)" />
            <text x={MX - 6} y={y(v) + 4} textAnchor="end" fontSize="11" fill="rgb(92 107 103)">{numero(v)}</text>
          </g>
        ))}
        <polyline points={puntos} fill="none" stroke="rgb(20 85 76)" strokeWidth="2" strokeLinejoin="round" />
        {pesos.map((p, i) => (
          <circle key={p.id} cx={x(tiempos[i])} cy={y(valores[i])} r={i === ultimo ? 4.5 : 3} fill="rgb(20 85 76)">
            <title>{`${fecha(p.fecha_registro)}: ${numero(p.peso_kg)} kg`}</title>
          </circle>
        ))}
        <text x={MX} y={H - 4} fontSize="11" fill="rgb(92 107 103)">{fecha(pesos[0].fecha_registro)}</text>
        <text x={W - MX} y={H - 4} textAnchor="end" fontSize="11" fill="rgb(92 107 103)">{fecha(pesos[ultimo].fecha_registro)}</text>
      </svg>
    </div>
  );
}
