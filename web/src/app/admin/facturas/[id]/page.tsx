import Link from "next/link";
import { notFound } from "next/navigation";
import { BotonAccion, BotonEnviar, BotonImprimir, Formulario } from "@/components/Formulario";
import { Logo } from "@/components/Logo";
import { Cabecera, Dato, Entrada, EstadoDe, idDe, Seccion, Selector, Vacio } from "@/components/ui";
import { exigir } from "@/lib/auth";
import { CONTACTO } from "@/lib/clinica";
import { ESTADOS_FACTURA } from "@/lib/etiquetas";
import { dinero, fecha, fechaHora, numero } from "@/lib/formato";
import { puede } from "@/lib/permisos";
import {
  lineasDeFactura, obtenerFactura, opcionesItems, opcionesMascotasDeCliente, opcionesMetodosPago, pagosDeFactura,
} from "@/lib/repos/facturas";
import { ajustar, anular, eliminarLinea, nuevaLinea, pagar, quitarPago } from "../acciones";

export const metadata = { title: "Factura" };

export default async function DetalleFactura({ params }: { params: Promise<{ id: string }> }) {
  const usuario = await exigir("facturas");
  const id = idDe((await params).id);
  const f = id && await obtenerFactura(id);
  if (!f || !id) notFound();

  const [lineas, pagos, items, mascotas, metodos] = await Promise.all([
    lineasDeFactura(id), pagosDeFactura(id), opcionesItems(), opcionesMascotasDeCliente(f.cliente_id), opcionesMetodosPago(),
  ]);

  const anulada = f.estado === "anulada";
  // pagada y anulada son documentos cerrados: la base rechaza cambios en sus líneas.
  const editable = f.estado === "pendiente" || f.estado === "parcial";

  return (
    <>
      <div className="no-imprimir">
        <Cabecera titulo={<>Factura {f.numero} <EstadoDe mapa={ESTADOS_FACTURA} valor={f.estado} /></>}
          migas={[{ texto: "Facturación", href: "/admin/facturas" }, { texto: f.numero }]}>
          <BotonImprimir />
          {editable && pagos.length === 0 && (
            <BotonAccion accion={anular} campos={{ id }} texto="Anular" tam="btn-md" clase="btn-peligro"
              confirmar="La factura queda anulada y los medicamentos vuelven al inventario. El documento se conserva." motivo="Motivo de la anulación" />
          )}
        </Cabecera>
      </div>

      <div className="grid items-start gap-5 lg:grid-cols-3">
        <article className="tarjeta p-6 lg:col-span-2 print:col-span-3">
          <header className="flex flex-wrap items-start justify-between gap-4 border-b border-gris-200 pb-5">
            <div className="flex items-center gap-3">
              <Logo className="h-10 w-10 text-verde-700" />
              <div>
                <p className="font-display text-2xl leading-none text-verde-900">PetCare</p>
                <p className="mt-1 text-xs text-gris-600">{CONTACTO.direccion}, {CONTACTO.ciudad} · {CONTACTO.telefono}</p>
              </div>
            </div>
            <div className="text-right">
              <p className="text-xs uppercase tracking-wider text-gris-600">Factura</p>
              <p className="font-semibold text-tinta cifra">{f.numero}</p>
              <p className="text-xs text-gris-600">{fecha(f.fecha_emision)}</p>
              {anulada && <p className="mt-1 text-sm font-semibold text-error-600">ANULADA</p>}
            </div>
          </header>

          <dl className="grid gap-4 border-b border-gris-200 py-4 sm:grid-cols-2">
            <Dato etiqueta="Tutor">
              <Link href={`/admin/clientes/${f.cliente_id}`} className="text-verde-700 hover:underline print:text-tinta">{f.cliente}</Link>
              <br /><span className="text-xs text-gris-600">{f.tipo_documento} {f.cliente_documento}</span>
            </Dato>
            <Dato etiqueta="Contacto">{f.cliente_telefono}{f.cliente_direccion && <><br /><span className="text-xs text-gris-600">{f.cliente_direccion}{f.cliente_ciudad && `, ${f.cliente_ciudad}`}</span></>}</Dato>
          </dl>

          <div className="scroll-x">
            <table className="tabla mt-2">
              <thead><tr><th>#</th><th>Descripción</th><th className="!text-right">Cant.</th><th className="!text-right">Precio</th><th className="!text-right">Subtotal</th>{editable && <th className="no-imprimir"><span className="sr-only">Acción</span></th>}</tr></thead>
              <tbody>
                {lineas.map((l) => (
                  <tr key={l.id}>
                    <td className="cifra text-gris-600">{l.linea_nro}</td>
                    <td>{l.descripcion}{l.mascota && <span className="block text-xs text-gris-600">{l.mascota}</span>}</td>
                    <td className="text-right cifra">{numero(l.cantidad)}</td>
                    <td className="whitespace-nowrap text-right cifra">{dinero(l.precio_unitario)}</td>
                    <td className="whitespace-nowrap text-right cifra">{dinero(l.subtotal)}</td>
                    {editable && (
                      <td className="no-imprimir text-right">
                        {lineas.length > 1 && (
                          <BotonAccion accion={eliminarLinea} campos={{ factura_id: id, linea_id: l.id }} texto="Quitar" clase="btn-fantasma"
                            confirmar={`¿Quitar «${l.descripcion}» de la factura?`} />
                        )}
                      </td>
                    )}
                  </tr>
                ))}
              </tbody>
            </table>
          </div>

          <dl className="ml-auto mt-4 w-full max-w-xs space-y-1.5 text-sm">
            {[["Subtotal", f.subtotal], ["Descuento", Number(f.descuento) > 0 ? `-${f.descuento}` : f.descuento], ["Impuesto", f.impuesto]].map(([k, v]) => (
              <div key={k} className="flex justify-between"><dt className="text-gris-600">{k}</dt><dd className="cifra">{dinero(v)}</dd></div>
            ))}
            <div className="flex justify-between border-t border-gris-300 pt-1.5 text-base font-semibold"><dt>Total</dt><dd className="cifra">{dinero(f.total)}</dd></div>
            {!anulada && (
              <>
                <div className="flex justify-between"><dt className="text-gris-600">Pagado</dt><dd className="cifra">{dinero(f.pagado)}</dd></div>
                <div className="flex justify-between font-medium"><dt>Saldo</dt><dd className="cifra">{dinero(f.saldo)}</dd></div>
              </>
            )}
          </dl>

          {f.observaciones && <p className="mt-4 whitespace-pre-line border-t border-gris-200 pt-3 text-sm text-gris-700">{f.observaciones}</p>}
        </article>

        <div className="no-imprimir space-y-5">
          <Seccion titulo="Pagos" sinRelleno>
            {pagos.length === 0 ? <Vacio titulo="Sin pagos registrados" /> : (
              <ul className="divide-y divide-gris-200">
                {pagos.map((p) => (
                  <li key={p.id} className="flex items-start justify-between gap-2 px-5 py-3 text-sm">
                    <div>
                      <p className="font-medium text-tinta cifra">{dinero(p.monto)}</p>
                      <p className="text-xs text-gris-600">{p.metodo}{p.referencia && ` · ${p.referencia}`}<br />{fechaHora(p.fecha_hora)}</p>
                    </div>
                    {puede(usuario.rol, "catalogos") && (
                      <BotonAccion accion={quitarPago} campos={{ factura_id: id, pago_id: p.id }} texto="Eliminar" clase="btn-fantasma"
                        confirmar={`Se eliminará el pago de ${dinero(p.monto)} y el saldo volverá a aumentar.`} />
                    )}
                  </li>
                ))}
              </ul>
            )}
            {editable && Number(f.saldo) > 0 && (
              <div className="border-t border-gris-200 p-5">
                <Formulario accion={pagar}>
                  <input type="hidden" name="factura_id" value={id} />
                  <Selector etiqueta="Método de pago" name="metodo_pago_id" opciones={metodos} vacio="Selecciona…" required />
                  <Entrada etiqueta="Monto" name="monto" inputMode="decimal" defaultValue={f.saldo} required />
                  <Entrada etiqueta="Referencia" name="referencia" maxLength={60} />
                  <BotonEnviar>Registrar pago</BotonEnviar>
                </Formulario>
              </div>
            )}
          </Seccion>

          {editable && (
            <Seccion titulo="Agregar línea">
              <Formulario accion={nuevaLinea}>
                <input type="hidden" name="factura_id" value={id} />
                <Selector etiqueta="Servicio o medicamento" name="item" opciones={items} vacio="Selecciona…" required />
                <Selector etiqueta="Mascota" name="mascota_id" opciones={mascotas} vacio="Sin asociar" />
                <Entrada etiqueta="Cantidad" name="cantidad" inputMode="decimal" defaultValue="1" required />
                <BotonEnviar clase="btn-secundario">Agregar</BotonEnviar>
              </Formulario>
            </Seccion>
          )}

          {editable && (
            <Seccion titulo="Descuento e impuesto">
              <Formulario accion={ajustar}>
                <input type="hidden" name="factura_id" value={id} />
                <Entrada etiqueta="Descuento" name="descuento" inputMode="decimal" defaultValue={f.descuento} />
                <Entrada etiqueta="Impuesto" name="impuesto" inputMode="decimal" defaultValue={f.impuesto} />
                <BotonEnviar clase="btn-secundario">Aplicar</BotonEnviar>
              </Formulario>
            </Seccion>
          )}
        </div>
      </div>
    </>
  );
}
