-- ============================================================================
--
--   ██████╗ ███████╗████████╗ ██████╗ █████╗ ██████╗ ███████╗
--   ██╔══██╗██╔════╝╚══██╔══╝██╔════╝██╔══██╗██╔══██╗██╔════╝
--   ██████╔╝█████╗     ██║   ██║     ███████║██████╔╝█████╗
--   ██╔═══╝ ██╔══╝     ██║   ██║     ██╔══██║██╔══██╗██╔══╝
--   ██║     ███████╗   ██║   ╚██████╗██║  ██║██║  ██║███████╗
--   ╚═╝     ╚══════╝   ╚═╝    ╚═════╝╚═╝  ╚═╝╚═╝  ╚═╝╚══════╝
--
--   Sistema de gestión integral para clínica veterinaria
--   Script maestro de creación de la base de datos
--
--   Materia:  Base de Datos
--   SGBD:     PostgreSQL 16
--   Origen:   Derivado del MER unificado del grupo (52 entidades, 438
--             atributos, 66 relaciones). Ver docs/MER-PetCare-unificado.pdf
--
-- ----------------------------------------------------------------------------
--   IMPORTANTE
--
--   Esta base de datos está escrita A MANO. Ninguna tabla proviene de las
--   migraciones automáticas de un ORM. La aplicación se conecta a un esquema
--   que ya existe y NO tiene permiso para alterarlo.
--
--   Si durante el desarrollo hiciera falta una tabla, una relación o un
--   atributo nuevo, el orden correcto es: actualizar el MER, derivar el cambio
--   al modelo relacional y recién entonces modificar estos archivos. Nunca al
--   revés.
--
-- ----------------------------------------------------------------------------
--   CÓMO EJECUTARLO
--
--   1. Crear la base (una sola vez, desde una sesión conectada a 'postgres'):
--
--        CREATE DATABASE petcare
--          WITH ENCODING 'UTF8'
--               LC_COLLATE 'es-ES'
--               LC_CTYPE   'es-ES'
--               TEMPLATE   template0;
--
--   2. Ejecutar este script conectado a la base recién creada:
--
--        psql -U postgres -d petcare -f database/petcare.sql
--
--   El script usa \ir (include relativo), así que debe ejecutarse con psql y
--   la ruta puede ser relativa al directorio actual.
--
-- ----------------------------------------------------------------------------
--   ORDEN DE LOS ARCHIVOS Y POR QUÉ
--
--     01_esquema.sql     Extensiones, dominios, secuencias y las 52 tablas.
--                        Sin claves foráneas: el modelo tiene referencias
--                        circulares que impiden un orden lineal de creación.
--
--     02_integridad.sql  Las 90 claves foráneas, agrupadas POR POLÍTICA DE
--                        BORRADO en vez de por tabla, para que la decisión
--                        quede auditable de un vistazo.
--
--     03_indices.sql     Índices únicos parciales (reglas que un CONSTRAINT no
--                        puede expresar), índices sobre foráneas y los que
--                        sostienen las consultas reales del sistema.
--
--     04_reglas.sql      Funciones y disparadores: las reglas de negocio que
--                        necesitan consultar otras filas u otras tablas, cosa
--                        que un CHECK no puede hacer.
--
--     05_vistas.sql      Los atributos derivados: edad, peso actual, estado de
--                        vacunación y stock. No se almacenan para que no puedan
--                        contradecir a su origen.
--
--     06_catalogos.sql   Datos maestros: roles, permisos, especies, razas,
--                        diagnósticos, servicios, vacunas, productos.
--                        En producción también existen.
--
--     07_demo.sql        Datos de ejemplo. OPCIONAL: comentar la línea para
--                        una instalación limpia.
--
--   Para probar el esquema contra casos válidos e inválidos, ejecutar después:
--
--        psql -U postgres -d petcare -f database/08_pruebas.sql
--
-- ============================================================================

\set ON_ERROR_STOP on
\timing off

BEGIN;

\echo ''
\echo '=============================================================='
\echo '  PETCARE — creación de la base de datos'
\echo '=============================================================='
\echo ''

\echo '[1/7] Esquema: extensiones, dominios y 52 tablas...'
\ir 01_esquema.sql

\echo '[2/7] Integridad referencial: 90 claves foráneas...'
\ir 02_integridad.sql

\echo '[3/7] Índices y restricciones parciales...'
\ir 03_indices.sql

\echo '[4/7] Reglas de negocio: funciones y disparadores...'
\ir 04_reglas.sql

\echo '[5/7] Vistas y atributos derivados...'
\ir 05_vistas.sql

\echo '[6/7] Catálogos maestros...'
\ir 06_catalogos.sql

-- Comentar la línea siguiente para una instalación sin datos de ejemplo.
\echo '[7/7] Datos de demostración...'
\ir 07_demo.sql

COMMIT;

\echo ''
\echo '=============================================================='
\echo '  Instalación completada'
\echo '=============================================================='

-- Resumen de lo creado, para verificar de un vistazo que todo está en su sitio.
SELECT 'Tablas'      AS objeto, count(*) AS cantidad
  FROM information_schema.tables
 WHERE table_schema = 'public' AND table_type = 'BASE TABLE'
UNION ALL
SELECT 'Vistas',      count(*) FROM information_schema.views
 WHERE table_schema = 'public'
UNION ALL
SELECT 'Claves foráneas', count(*) FROM information_schema.table_constraints
 WHERE constraint_schema = 'public' AND constraint_type = 'FOREIGN KEY'
UNION ALL
SELECT 'Restricciones CHECK', count(*) FROM pg_constraint c
  JOIN pg_namespace n ON n.oid = c.connamespace
 WHERE n.nspname = 'public' AND c.contype = 'c'
UNION ALL
SELECT 'Restricciones UNIQUE', count(*) FROM pg_constraint c
  JOIN pg_namespace n ON n.oid = c.connamespace
 WHERE n.nspname = 'public' AND c.contype = 'u'
UNION ALL
SELECT 'Restricciones EXCLUDE', count(*) FROM pg_constraint c
  JOIN pg_namespace n ON n.oid = c.connamespace
 WHERE n.nspname = 'public' AND c.contype = 'x'
UNION ALL
SELECT 'Índices',     count(*) FROM pg_indexes WHERE schemaname = 'public'
UNION ALL
SELECT 'Disparadores', count(*) FROM pg_trigger t
  JOIN pg_class cl ON cl.oid = t.tgrelid
  JOIN pg_namespace n ON n.oid = cl.relnamespace
 WHERE n.nspname = 'public' AND NOT t.tgisinternal
UNION ALL
SELECT 'Funciones',   count(*) FROM pg_proc p
  JOIN pg_namespace n ON n.oid = p.pronamespace
 WHERE n.nspname = 'public'
UNION ALL
SELECT 'Dominios',    count(*) FROM information_schema.domains
 WHERE domain_schema = 'public';
