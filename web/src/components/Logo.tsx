/** Marca de PetCare: una huella construida con geometría simple, sin trazos
 *  infantiles. Hereda el color del contexto mediante currentColor. */
export function Logo({ className = "" }: { className?: string }) {
  return (
    <svg viewBox="0 0 32 32" fill="none" className={className} aria-hidden="true">
      <rect width="32" height="32" rx="9" fill="currentColor" opacity="0.1" />
      <ellipse cx="11"   cy="11.5" rx="2.6" ry="3.3" fill="currentColor" />
      <ellipse cx="17.4" cy="9.6"  rx="2.4" ry="3.1" fill="currentColor" />
      <ellipse cx="22.6" cy="13.4" rx="2.2" ry="2.8" fill="currentColor" />
      <path
        d="M16.6 16.4c2.9 0 5.4 2.5 5.4 5.1 0 2-1.6 3.2-3.6 3.2-1.3 0-2-.5-3.2-.5s-1.9.5-3.2.5c-2 0-3.6-1.2-3.6-3.2 0-2.6 2.5-5.1 5.4-5.1h2.8z"
        fill="currentColor"
      />
    </svg>
  );
}
