import type { NextConfig } from "next";

const config: NextConfig = {
  reactStrictMode: true,
  poweredByHeader: false,
  // El driver pg es nativo de Node: no debe empaquetarse para el navegador.
  serverExternalPackages: ["pg"],
  // Las fotos de mascotas se suben por server actions (límite por defecto: 1 MB).
  experimental: { serverActions: { bodySizeLimit: "4mb" } },
  // Cabeceras básicas: nadie puede meter el panel en un marco de otra página.
  async headers() {
    return [{
      source: "/:ruta*",
      headers: [
        { key: "X-Frame-Options", value: "DENY" },
        { key: "X-Content-Type-Options", value: "nosniff" },
        { key: "Referrer-Policy", value: "strict-origin-when-cross-origin" },
      ],
    }];
  },
};

export default config;
