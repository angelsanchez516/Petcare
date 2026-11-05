import Link from "next/link";
import { Avatar, Cabecera, Insignia, Seccion, Tabla, Vacio } from "@/components/ui";
import { exigir } from "@/lib/auth";
import { listarVeterinarios } from "@/lib/repos/personal";

export const metadata = { title: "Veterinarios" };

export default async function Veterinarios() {
  await exigir("personal");
  const filas = await listarVeterinarios();
  return (
    <>
      <Cabecera titulo="Veterinarios" subtitulo="Equipo clínico y sus especialidades">
        <Link href="/admin/veterinarios/nuevo" className="btn btn-md btn-primario">Nuevo veterinario</Link>
      </Cabecera>
      <Seccion sinRelleno>
        {filas.length === 0 ? <Vacio titulo="No hay veterinarios registrados" /> : (
          <Tabla>
            <thead><tr><th>Veterinario</th><th>Matrícula</th><th>Especialidades</th><th>Usuario</th><th>Estado</th></tr></thead>
            <tbody>
              {filas.map((v) => (
                <tr key={v.id}>
                  <td>
                    <Link href={`/admin/veterinarios/${v.id}`} className="flex items-center gap-3 font-medium text-verde-700 hover:underline">
                      <Avatar foto={v.foto_url} nombre={`${v.nombres} ${v.apellidos}`} tam={36} />
                      {v.nombres} {v.apellidos}
                    </Link>
                  </td>
                  <td className="cifra">{v.matricula}</td>
                  <td>{v.especialidades ?? "—"}</td>
                  <td>{v.nombre_usuario ?? "—"}</td>
                  <td>{v.activo ? <Insignia tono="verde">Activo</Insignia> : <Insignia>Inactivo</Insignia>}</td>
                </tr>
              ))}
            </tbody>
          </Tabla>
        )}
      </Seccion>
    </>
  );
}
