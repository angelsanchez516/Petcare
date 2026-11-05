# PetCare

Sistema web para la gestión de una clínica veterinaria: agenda, historial clínico, vacunación, facturación e informes, sobre una base de datos PostgreSQL de 29 tablas diseñada y escrita a mano.

Proyecto de la materia **Base de Datos**, docente Edwin Torrado.

**Video de demostración:** https://youtu.be/KULm3711eSk

## Características

- **Sitio público.** Muestra servicios, equipo y cuidados por especie. Los tutores piden cita sin crear cuenta; la solicitud queda en espera hasta que la recepción la convierte en cita.
- **Agenda.** Citas por veterinario. La base de datos rechaza dos citas que se crucen para el mismo profesional.
- **Ficha de la mascota.** Historial clínico, vacunas, evolución del peso con gráfica, condiciones médicas, citas y facturas.
- **Atención clínica.** Consulta con signos vitales, diagnósticos de un catálogo normalizado, tratamientos y receta imprimible. Cada registro solo lo modifica el veterinario que lo firmó o un administrador.
- **Vacunación.** Solo se ofrecen las vacunas indicadas para la especie, y la fecha del próximo refuerzo se calcula sola.
- **Facturación.** Facturas con servicios y medicamentos, descuento automático de inventario, pagos parciales y saldo por cobrar.
- **Informes.** Ingresos mensuales, servicios más usados y diagnósticos más frecuentes, calculados con vistas de la base.
- **Roles y permisos.** Administrador, veterinario y recepcionista; los permisos se comprueban en el servidor en cada página y acción.

## Tecnologías

| Capa | Tecnología |
|---|---|
| Base de datos | PostgreSQL 16 (SQL escrito a mano, sin ORM) |
| Servidor y páginas | Next.js 16, React 19 y TypeScript |
| Estilos | Tailwind CSS |
| Acceso a datos | Librería `pg` de Node.js con consultas parametrizadas |

## Arquitectura

El sistema separa tres capas, y cada operación las recorre en el mismo orden:

**formulario → `acciones.ts` (permiso y validación) → `lib/repos` (SQL) → PostgreSQL**

| Capa | Dónde está |
|---|---|
| Presentación | `web/src/app/` (páginas y formularios) y `web/src/components/` |
| Lógica | `acciones.ts` de cada módulo, `lib/validar.ts`, `lib/permisos.ts` y `lib/auth.ts` |
| Acceso a datos | `lib/db.ts` (conexión y transacciones), `lib/repos/` (todas las consultas SQL) y `database/` |

Si PostgreSQL rechaza un dato, `mensajeDeError` en `lib/db.ts` traduce la restricción a un mensaje claro para el usuario.

## Base de datos

29 tablas, 39 claves foráneas, 56 restricciones `CHECK`, 10 triggers y 10 vistas. Entre las reglas que la base hace cumplir por sí sola:

- Un veterinario no puede tener dos citas cruzadas (restricción `EXCLUDE`).
- La raza de una mascota debe ser de su especie (clave foránea compuesta).
- Una vacuna solo se aplica a las especies indicadas.
- Los totales y el estado de la factura se calculan solos, y no se puede cobrar más que el total.
- Facturar un medicamento descuenta el stock y falla si no alcanza.

El detalle de los scripts está en [database/README.md](database/README.md). El modelo relacional y el diagrama entidad-relación completo están en [entrega/modelos](entrega/modelos).

## Instalación y ejecución

### Requisitos

- Node.js 20 o superior
- PostgreSQL 16

### 1. Crear la base de datos

Desde la carpeta del proyecto:

```bash
psql -U postgres -c "CREATE DATABASE petcare WITH ENCODING 'UTF8' TEMPLATE template0"
```

```bash
psql -U postgres -d petcare -f database/petcare.sql
```

También puedes restaurar el respaldo con los datos de demostración:

```bash
createdb -U postgres -E UTF8 -T template0 petcare
```

```bash
pg_restore -U postgres -d petcare --no-owner entrega/base_datos/petcare.backup
```

Para comprobar la base, `database/08_pruebas.sql` ejecuta 41 pruebas dentro de una transacción que se revierte.

### 2. Configurar la aplicación

En la carpeta `web`, copia `.env.example` con el nombre `.env.local` y cambia `AUTH_SECRET` por un texto largo y aleatorio. La contraseña de PostgreSQL no va en el código: se lee de `pgpass.conf`, o de la variable `PGPASSWORD` si la agregas a `.env.local`.

### 3. Instalar y ejecutar

```bash
cd web
```

```bash
npm install
```

Versión de producción (la compilación necesita internet la primera vez, porque descarga las fuentes):

```bash
npm run build
```

```bash
npm start
```

Para desarrollo basta con `npm run dev`. En ambos casos el sistema queda en http://localhost:3000.

## Usuarios de demostración

La contraseña de todos es `petcare2026`. Solo existe en los datos de demostración.

| Usuario | Rol | Qué puede hacer |
|---|---|---|
| `vsandoval` | Administrador | Todo el sistema |
| `lferreyra`, `mocampo`, `sbrenner` | Veterinario | Lee el historial de cualquier mascota y modifica solo sus propios registros clínicos y sus citas. No ve facturación ni administración |
| `cruiz` | Recepcionista | Agenda, solicitudes web, tutores, mascotas y facturación. No ve la parte clínica |

Los tutores no tienen cuenta: piden cita desde `/agendar` sin registrarse.

## Recorrido de demostración

Con el usuario `vsandoval`, cada paso muestra una regla real de la base de datos:

1. **Sitio público.** En `/agendar`, envía una solicitud. Todavía no crea una cita.
2. **Solicitud a cita.** En *Solicitudes web*, usa **Convertir en cita**. Las dos operaciones van en una sola transacción.
3. **Choque de horarios.** Agenda otra cita con el mismo veterinario a la misma hora y la base la rechaza.
4. **Ficha de mascota.** Recorre sus pestañas: historial, vacunas, peso y citas.
5. **Regla de especie.** Al registrar una vacuna solo aparecen las indicadas para esa especie.
6. **Atención clínica.** Agenda una cita para hoy a nombre de Valeria Sandoval, ábrela y usa **Atender**. Prueba una temperatura de 60 °C para ver el rechazo. Luego registra la consulta, el diagnóstico, el tratamiento y la receta.
7. **Facturación.** Factura un medicamento y mira cómo baja el stock en *Catálogos → Medicamentos*. Registra un pago parcial y observa el cambio de estado.
8. **Integridad.** En *Catálogos → Especies*, intenta eliminar *Canino*: la clave foránea lo impide.
9. **Permisos.** Ingresa con `cruiz`: el menú cambia y `/admin/consultas` muestra «No tienes acceso».
10. **Reportes.** Con el administrador, abre *Reportes* y filtra por período.

Las citas de demostración ya pasaron, así que *Citas de hoy* sale en cero hasta que agendes una para el día. `database/09_propuestas.sql` contiene cambios opcionales que no se han aplicado.

## Instalador para Windows

En la sección [Releases](../../releases) está `PetCare.exe`, que instala PetCare sin pedir Node, PostgreSQL ni permisos de administrador. Trae su propia base en otro puerto con los datos de demostración y solo escucha en el mismo computador. Como no está firmado, Windows puede mostrar «Windows protegió su PC»: elige **Más información** y luego **Ejecutar de todas formas**.

Para generarlo de nuevo:

```bash
powershell -ExecutionPolicy Bypass -File empaquetado\construir.ps1
```

Para desinstalarlo, cierra PetCare y borra el acceso directo y la carpeta `%LOCALAPPDATA%\PetCare`.

## Estructura del repositorio

```text
database/                 Scripts SQL: esquema, integridad, índices, reglas, vistas y datos
docs/                     Análisis del dominio, MER y diccionario de datos de la etapa de diseño
empaquetado/              Script y programa del instalador para Windows
entrega/                  Documento del proyecto, modelos, esquema y respaldo de la base
web/src/
  app/(publico)/          Sitio público: inicio, servicios, equipo, cuidados, agendar
  app/admin/<modulo>/     Panel: page.tsx muestra los datos, acciones.ts los recibe
  lib/repos/<modulo>.ts   Consultas SQL de cada módulo
  lib/validar.ts          Validación de los formularios
  lib/auth.ts             Sesión y control de acceso
  lib/permisos.ts         Qué puede hacer cada rol
  components/             Piezas visuales compartidas
```

## Documentación

- [Documento del proyecto](entrega/documentacion/descripcion_proyecto.pdf): problema, diseño de la base, arquitectura, CRUD, módulos e informes.
- [Modelo relacional](entrega/modelos/modelo_relacional.pdf) y [diagrama entidad-relación](entrega/modelos/diagrama_er.pdf).
- [Scripts de la base de datos](database/README.md).

## Limitaciones conocidas

- **Medicamentos fuera del catálogo.** La receta solo permite medicamentos registrados, porque `receta_detalle.medicamento_id` es una clave foránea. Solo el administrador puede agregarlos en *Catálogos → Medicamentos*.
- **Alergias y medicamentos.** La alergia se muestra como alerta en la consulta, pero el sistema no impide recetar un medicamento relacionado, porque la base no relaciona condiciones con medicamentos.
- **Mascotas de baja o fallecidas.** Conservan su historial, pero no reciben citas, consultas, vacunas ni pesos nuevos. Sus citas abiertas no se cancelan solas.
- **Cobrado en el tablero y en Reportes.** El tablero suma los pagos recibidos en el mes; Reportes agrupa por mes de emisión de la factura, así que las cifras pueden no coincidir.
- **Límites de intentos.** Tras 5 contraseñas incorrectas, el usuario espera 10 minutos, y `/agendar` acepta 10 solicitudes por hora desde un mismo equipo. Los contadores viven en memoria y se reinician con el servidor.
- **Autorización de datos.** `/agendar` avisa para qué se usan los datos, pero no guarda la autorización del tutor.

## Equipo

- Camilo Ernesto Amaya López
- Miguel Felipe Quintero Santos
- Ángel Jhosep Sánchez Oviedo
