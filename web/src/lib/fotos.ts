import "server-only";
import { randomUUID } from "node:crypto";
import { mkdir, writeFile } from "node:fs/promises";
import path from "node:path";
import { falla } from "@/lib/validar";

/** Guarda las fotos que se suben desde los formularios. En la base solo queda la
 *  ruta (mascota.foto_url, veterinario.foto_url); el archivo vive en web/uploads
 *  y lo entrega la ruta /fotos/[archivo]. */

export const CARPETA_FOTOS = path.join(process.cwd(), "uploads");
const MAX_BYTES = 3 * 1024 * 1024;

// Se revisan los primeros bytes del archivo: la extensión la elige quien lo sube.
function extension(b: Buffer): string | null {
  if (b[0] === 0xff && b[1] === 0xd8) return "jpg";
  if (b.subarray(0, 4).toString("hex") === "89504e47") return "png";
  if (b.subarray(0, 4).toString() === "RIFF" && b.subarray(8, 12).toString() === "WEBP") return "webp";
  return null;
}

/** Devuelve la ruta de la foto nueva, o null si no se eligió ningún archivo. */
export async function guardarFoto(f: FormData, campo = "foto"): Promise<string | null> {
  const archivo = f.get(campo);
  if (!(archivo instanceof File) || archivo.size === 0) return null;
  if (archivo.size > MAX_BYTES) falla("La foto no puede pesar más de 3 MB.");

  const datos = Buffer.from(await archivo.arrayBuffer());
  const ext = extension(datos);
  if (!ext) return falla("La foto debe ser JPG, PNG o WebP.");

  await mkdir(CARPETA_FOTOS, { recursive: true });
  const nombre = `${randomUUID()}.${ext}`;
  await writeFile(path.join(CARPETA_FOTOS, nombre), datos);
  return `/fotos/${nombre}`;
}
