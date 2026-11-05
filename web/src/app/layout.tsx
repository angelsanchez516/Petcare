import type { Metadata, Viewport } from "next";
import { Figtree, Instrument_Serif } from "next/font/google";
import "./globals.css";

/* La tipografía carga la personalidad: una grotesca geométrica para la interfaz
   y una serif de alto contraste reservada a los titulares del sitio público. */
const ui = Figtree({
  subsets: ["latin"],
  variable: "--fuente-ui",
  display: "swap",
});

const display = Instrument_Serif({
  subsets: ["latin"],
  weight: "400",
  style: ["normal", "italic"],
  variable: "--fuente-display",
  display: "swap",
});

export const metadata: Metadata = {
  title: {
    default: "PetCare · Clínica Veterinaria",
    template: "%s · PetCare",
  },
  description:
    "Clínica veterinaria con atención clínica, cirugía, diagnóstico por imagen " +
    "y medicina preventiva para perros, gatos y animales exóticos.",
};

export const viewport: Viewport = {
  width: "device-width",
  initialScale: 1,
  themeColor: "#14554C",
};

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="es" className={`${ui.variable} ${display.variable}`}>
      <body className="min-h-dvh font-sans">{children}</body>
    </html>
  );
}
