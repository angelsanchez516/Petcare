import { Barras } from "@/components/admin/Barras";
import { Cabecera, Cifra, Entrada, Filtros, Seccion, Tabla, Vacio } from "@/components/ui";
import { exigir } from "@/lib/auth";
import { dinero, numero } from "@/lib/formato";
import { diagnosticosFrecuentes, ingresosMensuales, serviciosMasUsados } from "@/lib/repos/reportes";

export const metadata = { title: "Reportes" };

const MES = new Intl.DateTimeFormat("es-CO", { month: "long", year: "numeric" });
const VALIDO = /^\d{4}-\d{2}$/;

/** Cada reporte lee una vista de la base de datos. */
export default async function Reportes({ searchParams }: { searchParams: Promise<Record<string, string>> }) {
  await exigir("reportes");
  const p = await searchParams;
  const desde = VALIDO.test(p.desde ?? "") ? p.desde : "";
  const hasta = VALIDO.test(p.hasta ?? "") ? p.hasta : "";

  const [ingresos, servicios, morbilidad] = await Promise.all([
    ingresosMensuales(desde, hasta),
    serviciosMasUsados(),
    diagnosticosFrecuentes(),
  ]);

  const suma = (col: string) => ingresos.reduce((t, f) => t + Number(f[col]), 0);

  return (
    <>
      <Cabecera titulo="Reportes" subtitulo="Ingresos, servicios y morbilidad, calculados con los datos del sistema" />

      <Filtros>
        <div className="w-44"><Entrada etiqueta="Desde" name="desde" type="month" defaultValue={desde} /></div>
        <div className="w-44"><Entrada etiqueta="Hasta" name="hasta" type="month" defaultValue={hasta} /></div>
      </Filtros>

      <div className="mb-5 grid gap-3 sm:grid-cols-3">
        <Cifra etiqueta="Facturado" valor={dinero(suma("facturado"))} />
        <Cifra etiqueta="Cobrado" valor={dinero(suma("cobrado"))} />
        <Cifra etiqueta="Por cobrar" valor={dinero(suma("por_cobrar"))} alerta={suma("por_cobrar") > 0} />
      </div>

      <Seccion titulo="Ingresos mensuales" sinRelleno className="mb-5">
        <p className="border-b border-gris-200 px-5 py-2.5 text-xs text-gris-600">
          Cada fila reúne las facturas emitidas ese mes. «Cobrado» es lo que se ha pagado de ellas, aunque el pago llegara después; por eso puede diferir de «Cobrado este mes» en el tablero.
        </p>
        {ingresos.length === 0 ? <Vacio titulo="No hay facturas en ese período" /> : (
          <Tabla>
            <thead><tr><th>Mes</th><th>Facturas</th><th>Subtotal</th><th>Descuentos</th><th>Facturado</th><th>Cobrado</th><th>Por cobrar</th></tr></thead>
            <tbody>
              {ingresos.map((f) => (
                <tr key={String(f.mes)}>
                  <td className="whitespace-nowrap first-letter:uppercase">{MES.format(new Date(f.mes))}</td>
                  <td className="cifra">{f.facturas}</td>
                  <td className="cifra">{dinero(f.subtotal)}</td>
                  <td className="cifra">{dinero(f.descuentos)}</td>
                  <td className="cifra font-medium">{dinero(f.facturado)}</td>
                  <td className="cifra">{dinero(f.cobrado)}</td>
                  <td className="cifra">{dinero(f.por_cobrar)}</td>
                </tr>
              ))}
            </tbody>
          </Tabla>
        )}
      </Seccion>

      <div className="grid gap-5 lg:grid-cols-2">
        <Seccion titulo="Servicios más usados">
          {servicios.length === 0 ? <Vacio titulo="Aún no se han facturado servicios" /> : (
            <Barras datos={servicios.map((s) => ({
              etiqueta: s.nombre, valor: Number(s.veces), texto: `${s.veces} · ${dinero(s.ingresos)}`,
            }))} />
          )}
        </Seccion>
        <Seccion titulo="Diagnósticos más frecuentes">
          {morbilidad.length === 0 ? <Vacio titulo="Aún no hay diagnósticos registrados" /> : (
            <Barras datos={morbilidad.map((d) => ({
              etiqueta: d.nombre, valor: Number(d.casos), texto: `${numero(d.casos)} casos · ${d.pacientes} pacientes`,
            }))} />
          )}
        </Seccion>
      </div>
    </>
  );
}
