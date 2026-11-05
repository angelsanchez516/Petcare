import Link from "next/link";
import { notFound } from "next/navigation";
import { BotonAccion } from "@/components/Formulario";
import { Avatar, Cabecera, Dato, EstadoDe, idDe, Insignia, Seccion, Tabla, Vacio } from "@/components/ui";
import { exigir } from "@/lib/auth";
import { ESTADOS_CITA, ESTADOS_FACTURA, TIPOS_CONSULTA, TIPOS_DOCUMENTO } from "@/lib/etiquetas";
import { dinero, edad, fecha, fechaHora } from "@/lib/formato";
import { puede } from "@/lib/permisos";
import { citasDeCliente, consultasDeCliente, facturasDeCliente, mascotasDeCliente, obtenerCliente } from "@/lib/repos/clientes";
import { cambiarActivo } from "../acciones";

export const metadata = { title: "Ficha del tutor" };

export default async function FichaCliente({ params }: { params: Promise<{ id: string }> }) {
  const usuario = await exigir("clientes");
  const id = idDe((await params).id);
  const c = id && await obtenerCliente(id);
  if (!c || !id) notFound();

  const puedeEditar = puede(usuario.rol, "clientes.editar");
  const verClinica = puede(usuario.rol, "clinica");
  const verFacturas = puede(usuario.rol, "facturas");
  const [mascotas, citas, consultas, facturas] = await Promise.all([
    mascotasDeCliente(id), citasDeCliente(id),
    verClinica ? consultasDeCliente(id) : [],
    verFacturas ? facturasDeCliente(id) : [],
  ]);

  return (
    <>
      <Cabecera
        titulo={<>{c.nombres} {c.apellidos} {!c.activo && <Insignia>De baja</Insignia>}</>}
        subtitulo={`${TIPOS_DOCUMENTO[c.tipo_documento] ?? c.tipo_documento} ${c.documento}`}
        migas={[{ texto: "Tutores", href: "/admin/clientes" }, { texto: `${c.nombres} ${c.apellidos}` }]}
      >
        {puedeEditar && <Link href={`/admin/clientes/${id}/editar`} className="btn btn-md btn-secundario">Editar</Link>}
        {puedeEditar && (c.activo
          ? <BotonAccion accion={cambiarActivo} campos={{ id, activo: "0" }} texto="Dar de baja" tam="btn-md"
              confirmar="El tutor deja de aparecer en las listas. Sus mascotas, consultas y facturas se conservan." />
          : <BotonAccion accion={cambiarActivo} campos={{ id, activo: "1" }} texto="Reactivar" tam="btn-md" />)}
        {verFacturas && c.activo && <Link href={`/admin/facturas/nueva?cliente=${id}`} className="btn btn-md btn-primario">Nueva factura</Link>}
      </Cabecera>

      <div className="grid gap-5 lg:grid-cols-3">
        <div className="space-y-5">
          <Seccion titulo="Contacto">
            <dl className="space-y-3">
              <Dato etiqueta="Teléfono"><a href={`tel:${c.telefono}`} className="text-verde-700 hover:underline">{c.telefono}</a></Dato>
              <Dato etiqueta="Correo">{c.email}</Dato>
              <Dato etiqueta="Dirección">{[c.direccion, c.ciudad].filter(Boolean).join(", ") || null}</Dato>
              {c.notas && <Dato etiqueta="Notas">{c.notas}</Dato>}
              <Dato etiqueta="Registrado">{fecha(c.creado_en)}</Dato>
            </dl>
          </Seccion>

          <Seccion titulo={`Mascotas (${mascotas.length})`} sinRelleno
            accion={c.activo ? <Link href={`/admin/mascotas/nueva?cliente=${id}`} className="btn btn-sm btn-secundario">Agregar</Link> : undefined}>
            {mascotas.length === 0 ? <Vacio titulo="Aún no tiene mascotas registradas" /> : (
              <ul className="divide-y divide-gris-200">
                {mascotas.map((m) => (
                  <li key={m.id}>
                    <Link href={`/admin/mascotas/${m.id}`} className="flex items-center gap-3 px-5 py-3 hover:bg-verde-50/60">
                      <Avatar foto={m.foto_url} nombre={m.nombre} icono={m.especie_icono} />
                      <span className="min-w-0">
                        <span className="block text-sm font-medium text-tinta">{m.nombre} {!m.activo && <Insignia>De baja</Insignia>}</span>
                        <span className="block truncate text-xs text-gris-600">{m.especie} · {m.raza ?? "Sin raza definida"} · {edad(m.edad_anios, m.edad_meses)}</span>
                      </span>
                    </Link>
                  </li>
                ))}
              </ul>
            )}
          </Seccion>
        </div>

        <div className="space-y-5 lg:col-span-2">
          <Seccion titulo="Citas recientes" sinRelleno>
            {citas.length === 0 ? <Vacio titulo="Sin citas registradas" /> : (
              <Tabla>
                <thead><tr><th>Fecha</th><th>Mascota</th><th>Motivo</th><th>Estado</th></tr></thead>
                <tbody>{citas.map((a) => (
                  <tr key={a.cita_id}>
                    <td className="whitespace-nowrap"><Link href={`/admin/citas/${a.cita_id}`} className="text-verde-700 hover:underline">{fechaHora(a.fecha_hora_inicio)}</Link></td>
                    <td>{a.mascota}</td><td>{a.motivo}</td>
                    <td><EstadoDe mapa={ESTADOS_CITA} valor={a.estado} /></td>
                  </tr>
                ))}</tbody>
              </Tabla>
            )}
          </Seccion>

          {verClinica && (
            <Seccion titulo="Consultas de sus mascotas" sinRelleno>
              {consultas.length === 0 ? <Vacio titulo="Sin consultas registradas" /> : (
                <Tabla>
                  <thead><tr><th>Fecha</th><th>Mascota</th><th>Tipo</th><th>Motivo</th></tr></thead>
                  <tbody>{consultas.map((k) => (
                    <tr key={k.id}>
                      <td className="whitespace-nowrap"><Link href={`/admin/consultas/${k.id}`} className="text-verde-700 hover:underline">{fecha(k.fecha_hora)}</Link></td>
                      <td>{k.mascota}</td><td>{TIPOS_CONSULTA[k.tipo] ?? k.tipo}</td><td>{k.motivo}</td>
                    </tr>
                  ))}</tbody>
                </Tabla>
              )}
            </Seccion>
          )}

          {verFacturas && (
            <Seccion titulo="Facturas" sinRelleno>
              {facturas.length === 0 ? <Vacio titulo="Sin facturas emitidas" /> : (
                <Tabla>
                  <thead><tr><th>Número</th><th>Fecha</th><th>Total</th><th>Saldo</th><th>Estado</th></tr></thead>
                  <tbody>{facturas.map((x) => (
                    <tr key={x.id}>
                      <td><Link href={`/admin/facturas/${x.id}`} className="whitespace-nowrap text-verde-700 hover:underline">{x.numero}</Link></td>
                      <td className="whitespace-nowrap">{fecha(x.fecha_emision)}</td>
                      <td className="cifra">{dinero(x.total)}</td>
                      <td className="cifra">{x.estado === "anulada" ? "—" : dinero(x.saldo)}</td>
                      <td><EstadoDe mapa={ESTADOS_FACTURA} valor={x.estado} /></td>
                    </tr>
                  ))}</tbody>
                </Tabla>
              )}
            </Seccion>
          )}
        </div>
      </div>
    </>
  );
}
