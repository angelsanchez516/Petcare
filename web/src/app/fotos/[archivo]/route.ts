import { readFile } from "node:fs/promises";
import path from "node:path";
import { CARPETA_FOTOS } from "@/lib/fotos";

const TIPOS: Record<string, string> = { jpg: "image/jpeg", png: "image/png", webp: "image/webp" };

export async function GET(_: Request, { params }: { params: Promise<{ archivo: string }> }) {
  const { archivo } = await params;
  // Solo nombres generados por guardarFoto: evita salir de la carpeta con "../".
  const m = /^[0-9a-f-]{36}\.(jpg|png|webp)$/.exec(archivo);
  if (!m) return new Response("No encontrado", { status: 404 });
  try {
    const datos = await readFile(path.join(CARPETA_FOTOS, archivo));
    return new Response(datos, { headers: { "Content-Type": TIPOS[m[1]] } });
  } catch {
    return new Response("No encontrado", { status: 404 });
  }
}
