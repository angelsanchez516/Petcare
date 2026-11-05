-- ============================================================================
--   PETCARE — Sistema de gestión para clínica veterinaria
--   Script maestro de creación de la base de datos
--
--   Materia : Base de Datos
--   Docente : Edwin Torrado
--   SGBD    : PostgreSQL 16
--   Origen  : MER del grupo (28 entidades) + solicitud_cita
--
-- ----------------------------------------------------------------------------
--   La base de datos está escrita A MANO. Ninguna tabla proviene de las
--   migraciones automáticas de un ORM. La aplicación se conecta a un esquema
--   que ya existe y no tiene permiso para alterarlo.
--
--   Si hiciera falta una tabla, relación o atributo nuevo, el orden correcto
--   es: actualizar el MER, derivar el cambio al modelo relacional y recién
--   entonces modificar estos archivos. Nunca al revés.
--
-- ----------------------------------------------------------------------------
--   CÓMO EJECUTARLO
--
--     psql -U postgres -c "CREATE DATABASE petcare WITH ENCODING 'UTF8' TEMPLATE template0"
--     psql -U postgres -d petcare -f database/petcare.sql
--
--   Para verificar que todo quedó bien:
--
--     psql -U postgres -d petcare -f database/08_pruebas.sql
--
-- ----------------------------------------------------------------------------
--   DIFERENCIAS CON EL MER ENTREGADO, DOCUMENTADAS
--
--     + solicitud_cita           El sitio público necesita recibir pedidos de
--                                turno de visitantes que aún no son clientes;
--                                cita exige mascota_id y veterinario_id.
--     + servicio.descripcion     Campos de presentación que el sitio público
--     + servicio.icono           necesita mostrar y que el MER no contemplaba.
--     + servicio.visible_publico
--     + veterinario.foto_url
--     + veterinario.biografia
--     + cita.fecha_hora_fin      Derivada de inicio + duración, mantenida por
--                                trigger. Necesaria porque la restricción
--                                EXCLUDE exige una expresión IMMUTABLE.
--
--   La versión anterior de 52 tablas quedó archivada en database/_archivo_v52/
-- ============================================================================

\set ON_ERROR_STOP on
\timing off

BEGIN;

\echo ''
\echo '================================================================'
\echo '  PETCARE — creación de la base de datos'
\echo '================================================================'

\echo '[1/6] Esquema: extensiones, dominios y 29 tablas...'
\ir 01_esquema.sql

\echo '[2/6] Integridad referencial: 39 claves foráneas...'
\ir 02_integridad.sql

\echo '[3/6] Índices...'
\ir 03_indices.sql

\echo '[4/6] Reglas de negocio: funciones y disparadores...'
\ir 04_reglas.sql

\echo '[5/6] Vistas y atributos derivados...'
\ir 05_vistas.sql

\echo '[6/6] Catálogos maestros...'
\ir 06_catalogos.sql

-- Comentar la línea siguiente para una instalación sin datos de ejemplo.
\echo '      Datos de demostración...'
\ir 07_demo.sql

COMMIT;

\echo ''
\echo '================================================================'
\echo '  Instalación completada'
\echo '================================================================'

SELECT 'Tablas' AS objeto, count(*)::text AS cantidad
  FROM information_schema.tables
 WHERE table_schema = 'public' AND table_type = 'BASE TABLE'
UNION ALL SELECT 'Vistas', count(*)::text FROM information_schema.views
 WHERE table_schema = 'public'
UNION ALL SELECT 'Claves foráneas', count(*)::text FROM pg_constraint c
  JOIN pg_namespace n ON n.oid = c.connamespace
 WHERE n.nspname = 'public' AND c.contype = 'f'
UNION ALL SELECT 'Restricciones CHECK', count(*)::text FROM pg_constraint c
  JOIN pg_namespace n ON n.oid = c.connamespace
 WHERE n.nspname = 'public' AND c.contype = 'c'
UNION ALL SELECT 'Restricciones UNIQUE', count(*)::text FROM pg_constraint c
  JOIN pg_namespace n ON n.oid = c.connamespace
 WHERE n.nspname = 'public' AND c.contype = 'u'
UNION ALL SELECT 'Restricciones EXCLUDE', count(*)::text FROM pg_constraint c
  JOIN pg_namespace n ON n.oid = c.connamespace
 WHERE n.nspname = 'public' AND c.contype = 'x'
UNION ALL SELECT 'Índices', count(*)::text FROM pg_indexes WHERE schemaname = 'public'
UNION ALL SELECT 'Disparadores', count(*)::text FROM pg_trigger t
  JOIN pg_class cl ON cl.oid = t.tgrelid
  JOIN pg_namespace n ON n.oid = cl.relnamespace
 WHERE n.nspname = 'public' AND NOT t.tgisinternal
UNION ALL SELECT 'Filas cargadas', COALESCE(sum(n_live_tup), 0)::text
  FROM pg_stat_user_tables;
