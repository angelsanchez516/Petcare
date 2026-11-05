import type { Config } from "tailwindcss";

/** Los colores se declaran como canales RGB en globals.css para poder usarlos
 *  con opacidad desde Tailwind: bg-verde-700/10, text-tinta/60, etc. */
const c = (v: string) => `rgb(var(${v}) / <alpha-value>)`;

export default {
  content: ["./src/**/*.{ts,tsx}"],
  // El tono de una insignia se arma con una variable en ui.tsx, así que Tailwind
  // no ve estos nombres al revisar el código.
  safelist: ["insignia-neutra", "insignia-verde", "insignia-ambar", "insignia-roja", "insignia-azul", "insignia-marca"],
  theme: {
    extend: {
      colors: {
        verde: {
          900: c("--verde-900"), 800: c("--verde-800"), 700: c("--verde-700"),
          600: c("--verde-600"), 500: c("--verde-500"), 200: c("--verde-200"),
          100: c("--verde-100"), 50:  c("--verde-50"),
        },
        ambar:  { 600: c("--ambar-600"), 500: c("--ambar-500"), 100: c("--ambar-100") },
        exito:  { 600: c("--exito-600"), 100: c("--exito-100") },
        alerta: { 600: c("--alerta-600"), 100: c("--alerta-100") },
        error:  { 600: c("--error-600"), 100: c("--error-100") },
        info:   { 600: c("--info-600"),  100: c("--info-100") },
        gris: {
          700: c("--gris-700"), 600: c("--gris-600"), 400: c("--gris-400"),
          300: c("--gris-300"), 200: c("--gris-200"), 100: c("--gris-100"),
        },
        tinta: c("--tinta"),
        papel: c("--papel"),
      },
      fontFamily: {
        sans:    ["var(--fuente-ui)", "system-ui", "sans-serif"],
        display: ["var(--fuente-display)", "Georgia", "serif"],
      },
      boxShadow: {
        suave:  "var(--sombra-sm)",
        media:  "var(--sombra)",
        alta:   "var(--sombra-md)",
      },
      borderRadius: { xl: "var(--radio)" },
      keyframes: {
        aparecer: { from: { opacity: "0", transform: "translateY(4px)" },
                    to:   { opacity: "1", transform: "none" } },
      },
      animation: { aparecer: "aparecer .18s ease-out" },
    },
  },
  plugins: [],
} satisfies Config;
