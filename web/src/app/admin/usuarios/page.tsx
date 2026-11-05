import Link from "next/link";
import { notFound } from "next/navigation";
import { BotonEnviar, Formulario } from "@/components/Formulario";
import { Cabecera, Casilla, Entrada, Insignia, Seccion, Selector, Tabla } from "@/components/ui";
import { exigir } from "@/lib/auth";
import { fechaHora } from "@/lib/formato";
import { listarUsuarios, obtenerUsuario, opcionesRoles } from "@/lib/repos/personal";
import { guardar } from "./acciones";

export const metadata = { title: "Usuarios" };

export default async function Usuarios({ searchParams }: { searchParams: Promise<Record<string, string>> }) {
  const yo = await exigir("personal");
  const { editar } = await searchParams;
  const idEditar = /^\d+$/.test(editar ?? "") ? Number(editar) : null;
  const [filas, roles, u] = await Promise.all([listarUsuarios(), opcionesRoles(), idEditar ? obtenerUsuario(idEditar) : null]);
  if (idEditar && !u) notFound();

  return (
    <>
      <Cabecera titulo="Usuarios" subtitulo="Cuentas del personal y rol de cada persona" />
      <div className="grid items-start gap-5 xl:grid-cols-3">
        <Seccion sinRelleno className="min-w-0 xl:col-span-2">
          <Tabla>
            <thead><tr><th>Usuario</th><th>Rol</th><th>Veterinario</th><th>Último acceso</th><th>Estado</th><th><span className="sr-only">Acción</span></th></tr></thead>
            <tbody>
              {filas.map((f) => (
                <tr key={f.id}>
                  <td><span className="font-medium text-tinta">{f.nombre_usuario}</span>{f.id === yo.id && <span className="ml-1 text-xs text-gris-600">(tú)</span>}<p className="text-xs text-gris-600">{f.email}</p></td>
                  <td>{f.rol}</td>
                  <td>{f.veterinario ?? "—"}</td>
                  <td className="whitespace-nowrap">{f.ultimo_acceso ? fechaHora(f.ultimo_acceso) : "Nunca"}</td>
                  <td>{f.activo ? <Insignia tono="verde">Activo</Insignia> : <Insignia>Inactivo</Insignia>}</td>
                  <td className="text-right"><Link href={`/admin/usuarios?editar=${f.id}`} className="btn btn-sm btn-secundario">Editar</Link></td>
                </tr>
              ))}
            </tbody>
          </Tabla>
        </Seccion>

        <Seccion titulo={u ? `Editar a ${u.nombre_usuario}` : "Nuevo usuario"}
          accion={u ? <Link href="/admin/usuarios" className="btn btn-sm btn-fantasma">Cancelar</Link> : undefined}>
          <Formulario key={u?.id ?? "nuevo"} accion={guardar}>
            {u && <input type="hidden" name="id" value={u.id} />}
            <Entrada etiqueta="Usuario" name="nombre_usuario" defaultValue={u?.nombre_usuario} maxLength={50} required autoComplete="off" />
            <Entrada etiqueta="Correo electrónico" name="email" type="email" defaultValue={u?.email} maxLength={120} required autoComplete="off" />
            <Selector etiqueta="Rol" name="rol_id" opciones={roles} vacio="Selecciona…" defaultValue={u?.rol_id ?? ""} required />
            <Entrada etiqueta={u ? "Contraseña nueva" : "Contraseña"} name="clave" type="password" maxLength={100} required={!u} autoComplete="new-password"
              ayuda={u ? "Déjala vacía para conservar la actual. Mínimo 8 caracteres." : "Mínimo 8 caracteres."} />
            <Casilla etiqueta="Activo" name="activo" defaultChecked={u ? u.activo : true} />
            <BotonEnviar>{u ? "Guardar cambios" : "Crear usuario"}</BotonEnviar>
          </Formulario>
        </Seccion>
      </div>
    </>
  );
}
