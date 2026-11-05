import Link from "next/link";
import { BotonEnviar, Formulario } from "@/components/Formulario";
import { AreaTexto, Cabecera, Entrada, Seccion, Selector } from "@/components/ui";
import { exigir } from "@/lib/auth";
import { obtenerCliente, opcionesClientes } from "@/lib/repos/clientes";
import { opcionesItems, opcionesMascotasDeCliente } from "@/lib/repos/facturas";
import { nueva } from "../acciones";

export const metadata = { title: "Nueva factura" };

export default async function NuevaFactura({ searchParams }: { searchParams: Promise<Record<string, string>> }) {
  await exigir("facturas");
  const { cliente: clienteParam } = await searchParams;
  const c = /^\d+$/.test(clienteParam ?? "") ? await obtenerCliente(Number(clienteParam)) : null;
  const migas = [{ texto: "Facturación", href: "/admin/facturas" }, { texto: "Nueva" }];

  // Primero el tutor: de él dependen las mascotas que se pueden asociar a la línea.
  if (!c) {
    const clientes = await opcionesClientes();
    return (
      <>
        <Cabecera titulo="Nueva factura" migas={migas} />
        <form method="get" className="tarjeta flex max-w-xl flex-wrap items-end gap-3 p-5">
          <div className="min-w-60 flex-1"><Selector etiqueta="¿A quién se le factura?" name="cliente" opciones={clientes} vacio="Selecciona…" required /></div>
          <button className="btn btn-md btn-primario">Continuar</button>
        </form>
      </>
    );
  }

  const [items, mascotas] = await Promise.all([opcionesItems(), opcionesMascotasDeCliente(c.id)]);
  return (
    <>
      <Cabecera titulo={`Factura para ${c.nombres} ${c.apellidos}`} subtitulo="El número y los totales se generan al guardar" migas={migas} />
      <Seccion className="max-w-3xl">
        <Formulario accion={nueva}>
          <input type="hidden" name="cliente_id" value={c.id} />
          <Selector etiqueta="Primer servicio o medicamento" name="item" opciones={items} vacio="Selecciona…" required />
          <div className="grid gap-4 sm:grid-cols-2">
            <Selector etiqueta="Mascota" name="mascota_id" opciones={mascotas} vacio="Sin asociar" />
            <Entrada etiqueta="Cantidad" name="cantidad" inputMode="decimal" defaultValue="1" required />
          </div>
          <AreaTexto etiqueta="Observaciones" name="observaciones" rows={2} />
          <div className="flex gap-2">
            <BotonEnviar>Crear factura</BotonEnviar>
            <Link href="/admin/facturas" className="btn btn-md btn-fantasma">Cancelar</Link>
          </div>
        </Formulario>
      </Seccion>
    </>
  );
}
