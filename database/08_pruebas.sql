-- ============================================================================
--  PETCARE — 08_pruebas.sql · Pruebas de la base de datos
-- ----------------------------------------------------------------------------
--  No basta con que el esquema se cree: hay que demostrar que las restricciones
--  REALMENTE impiden los datos incorrectos. Por eso la mayoría de estas pruebas
--  verifican que una operación FALLE.
--
--  Todo corre dentro de una transacción que se revierte: no deja rastros.
--
--  Ejecución:  psql -U postgres -d petcare -f database/08_pruebas.sql
-- ============================================================================

\set ON_ERROR_STOP off
SET client_min_messages = WARNING;

BEGIN;

CREATE TEMP TABLE _r (nro SERIAL, grupo TEXT, caso TEXT, paso BOOLEAN, detalle TEXT);

CREATE OR REPLACE FUNCTION _falla(g TEXT, c TEXT, s TEXT) RETURNS VOID
LANGUAGE plpgsql AS $$
BEGIN
    BEGIN
        EXECUTE s;
        INSERT INTO _r (grupo, caso, paso, detalle)
        VALUES (g, c, FALSE, 'Se aceptó cuando debía ser rechazado');
    EXCEPTION WHEN OTHERS THEN
        INSERT INTO _r (grupo, caso, paso, detalle) VALUES (g, c, TRUE, left(SQLERRM, 80));
    END;
END $$;

CREATE OR REPLACE FUNCTION _pasa(g TEXT, c TEXT, s TEXT) RETURNS VOID
LANGUAGE plpgsql AS $$
BEGIN
    BEGIN
        EXECUTE s;
        INSERT INTO _r (grupo, caso, paso, detalle) VALUES (g, c, TRUE, NULL);
    EXCEPTION WHEN OTHERS THEN
        INSERT INTO _r (grupo, caso, paso, detalle) VALUES (g, c, FALSE, left(SQLERRM, 80));
    END;
END $$;

CREATE OR REPLACE FUNCTION _vale(g TEXT, c TEXT, s TEXT, esp TEXT) RETURNS VOID
LANGUAGE plpgsql AS $$
DECLARE v TEXT;
BEGIN
    EXECUTE s INTO v;
    INSERT INTO _r (grupo, caso, paso, detalle)
    VALUES (g, c, v IS NOT DISTINCT FROM esp, 'esperado ' || esp || ', obtenido ' || COALESCE(v,'NULL'));
EXCEPTION WHEN OTHERS THEN
    INSERT INTO _r (grupo, caso, paso, detalle) VALUES (g, c, FALSE, left(SQLERRM, 80));
END $$;


-- ── 1. ESTRUCTURA ───────────────────────────────────────────────────────────
SELECT _vale('1 Estructura','Se crearon las 29 tablas',
  $$SELECT count(*)::text FROM information_schema.tables
     WHERE table_schema='public' AND table_type='BASE TABLE'$$,'29');

SELECT _vale('1 Estructura','Toda tabla tiene clave primaria',
  $$SELECT count(*)::text FROM information_schema.tables t
     WHERE t.table_schema='public' AND t.table_type='BASE TABLE'
       AND NOT EXISTS (SELECT 1 FROM information_schema.table_constraints tc
                        WHERE tc.table_name=t.table_name AND tc.constraint_type='PRIMARY KEY')$$,'0');

SELECT _vale('1 Estructura','Ninguna clave foránea quedó sin índice',
  $$WITH fk AS (SELECT c.conrelid, c.conkey FROM pg_constraint c
                  JOIN pg_namespace n ON n.oid=c.connamespace
                 WHERE c.contype='f' AND n.nspname='public')
     SELECT count(*)::text FROM fk WHERE NOT EXISTS (
       SELECT 1 FROM pg_index i WHERE i.indrelid=fk.conrelid
        AND (i.indkey::smallint[])[0:array_length(fk.conkey,1)-1] @> fk.conkey)$$,'0');


-- ── 2. REGLAS DE DOMINIO ────────────────────────────────────────────────────
SELECT _falla('2 Dominio','Peso negativo',
  $$INSERT INTO registro_peso (mascota_id, fecha_registro, peso_kg)
    VALUES ((SELECT id FROM mascota LIMIT 1), CURRENT_DATE-999, -5)$$);

SELECT _falla('2 Dominio','Precio de servicio negativo',
  $$INSERT INTO servicio (codigo,nombre,categoria,precio_base)
    VALUES ('T-1','Prueba','CONSULTA',-1000)$$);

SELECT _falla('2 Dominio','Sexo de mascota fuera del dominio',
  $$INSERT INTO mascota (cliente_id,especie_id,nombre,sexo)
    VALUES ((SELECT id FROM cliente LIMIT 1),(SELECT id FROM especie LIMIT 1),'T','X')$$);

SELECT _falla('2 Dominio','Estado de cita inexistente',
  $$UPDATE cita SET estado='inventado' WHERE id=(SELECT id FROM cita LIMIT 1)$$);

SELECT _falla('2 Dominio','Temperatura fuera del rango biológico',
  $$INSERT INTO consulta (mascota_id,veterinario_id,motivo,temperatura_c)
    VALUES ((SELECT id FROM mascota LIMIT 1),(SELECT id FROM veterinario LIMIT 1),'T',60)$$);

SELECT _falla('2 Dominio','Fecha de nacimiento futura',
  $$INSERT INTO mascota (cliente_id,especie_id,nombre,sexo,fecha_nacimiento)
    VALUES ((SELECT id FROM cliente LIMIT 1),(SELECT id FROM especie LIMIT 1),'T','M',CURRENT_DATE+30)$$);

SELECT _falla('2 Dominio','Correo con formato inválido',
  $$INSERT INTO cliente (documento,nombres,apellidos,telefono,email)
    VALUES ('999999','T','T','+57 300 000 0000','no-es-un-correo')$$);


-- ── 3. REGLAS CLÍNICAS ──────────────────────────────────────────────────────
SELECT _falla('3 Clínicas','Refuerzo anterior a la aplicación',
  $$INSERT INTO aplicacion_vacuna (mascota_id,vacuna_id,veterinario_id,
       fecha_aplicacion,fecha_proximo_refuerzo,lote)
    VALUES ((SELECT id FROM mascota WHERE nombre='Max'),
            (SELECT id FROM vacuna WHERE nombre='Antirrábica'),
            (SELECT id FROM veterinario LIMIT 1), CURRENT_DATE, CURRENT_DATE-30,'L-1')$$);

SELECT _falla('3 Clínicas','Vacuna canina aplicada a un felino',
  $$INSERT INTO aplicacion_vacuna (mascota_id,vacuna_id,veterinario_id,fecha_aplicacion,lote)
    VALUES ((SELECT id FROM mascota WHERE nombre='Mishi'),
            (SELECT id FROM vacuna WHERE nombre='Quíntuple canina'),
            (SELECT id FROM veterinario LIMIT 1), CURRENT_DATE-5,'L-2')$$);

SELECT _falla('3 Clínicas','La misma vacuna dos veces el mismo día',
  $$INSERT INTO aplicacion_vacuna (mascota_id,vacuna_id,veterinario_id,fecha_aplicacion,lote)
    SELECT mascota_id,vacuna_id,veterinario_id,fecha_aplicacion,'DUP'
      FROM aplicacion_vacuna LIMIT 1$$);

SELECT _falla('3 Clínicas','Consulta de una mascota distinta a la de su cita',
  $$INSERT INTO consulta (mascota_id,veterinario_id,cita_id,motivo)
    SELECT (SELECT id FROM mascota WHERE nombre='Mishi'), c.veterinario_id, c.id,'T'
      FROM cita c WHERE c.estado='confirmada' LIMIT 1$$);

SELECT _falla('3 Clínicas','Dos pesos oficiales el mismo día',
  $$INSERT INTO registro_peso (mascota_id,fecha_registro,peso_kg)
    SELECT mascota_id,fecha_registro,99 FROM registro_peso LIMIT 1$$);

SELECT _falla('3 Clínicas','Dos recetas para la misma consulta',
  $$INSERT INTO receta (consulta_id) SELECT consulta_id FROM receta LIMIT 1$$);


-- ── 4. INTEGRIDAD Y PROTECCIÓN DEL HISTORIAL ────────────────────────────────
SELECT _falla('4 Integridad','Borrar una mascota con historial clínico',
  $$DELETE FROM mascota WHERE nombre='Max'$$);

SELECT _falla('4 Integridad','Borrar un tutor con mascotas',
  $$DELETE FROM cliente WHERE documento='1012345678'$$);

SELECT _falla('4 Integridad','Borrar una especie en uso',
  $$DELETE FROM especie WHERE nombre='Canino'$$);

SELECT _falla('4 Integridad','Consulta con veterinario inexistente',
  $$INSERT INTO consulta (mascota_id,veterinario_id,motivo)
    VALUES ((SELECT id FROM mascota LIMIT 1), 999999,'T')$$);

-- LA PRUEBA CLAVE DE LA CLAVE FORÁNEA COMPUESTA
SELECT _falla('4 Integridad','Felino con raza de canino',
  $$INSERT INTO mascota (cliente_id,especie_id,raza_id,nombre,sexo)
    SELECT (SELECT id FROM cliente LIMIT 1),
           (SELECT id FROM especie WHERE nombre='Felino'),
           (SELECT r.id FROM raza r JOIN especie e ON e.id=r.especie_id
             WHERE e.nombre='Canino' AND r.nombre='Labrador Retriever'),'Imposible','M'$$);

SELECT _pasa('4 Integridad','Mestizo sin raza pero con especie',
  $$INSERT INTO mascota (cliente_id,especie_id,raza_id,nombre,sexo)
    VALUES ((SELECT id FROM cliente LIMIT 1),
            (SELECT id FROM especie WHERE nombre='Canino'),NULL,'Mestizo test','H')$$);


-- ── 5. AGENDA ───────────────────────────────────────────────────────────────
SELECT _falla('5 Agenda','Dos citas solapadas del mismo veterinario',
  $$INSERT INTO cita (mascota_id,veterinario_id,fecha_hora_inicio,fecha_hora_fin,
                      duracion_minutos,motivo)
    SELECT c.mascota_id,c.veterinario_id,c.fecha_hora_inicio+INTERVAL '10 minutes',
           c.fecha_hora_inicio+INTERVAL '40 minutes',30,'Solapada'
      FROM cita c WHERE c.estado IN ('programada','confirmada') LIMIT 1$$);

SELECT _pasa('5 Agenda','Dos veterinarios distintos a la misma hora',
  $$INSERT INTO cita (mascota_id,veterinario_id,fecha_hora_inicio,fecha_hora_fin,
                      duracion_minutos,motivo)
    SELECT c.mascota_id,
           (SELECT id FROM veterinario WHERE id <> c.veterinario_id LIMIT 1),
           c.fecha_hora_inicio,c.fecha_hora_inicio+INTERVAL '30 minutes',30,'Otro profesional'
      FROM cita c WHERE c.estado='confirmada' LIMIT 1$$);

SELECT _falla('5 Agenda','Cancelar una cita sin justificar',
  $$UPDATE cita SET estado='cancelada'
     WHERE id=(SELECT id FROM cita WHERE estado='programada' LIMIT 1)$$);


-- ── 6. FACTURACIÓN ──────────────────────────────────────────────────────────
SELECT _falla('6 Facturación','Escribir un subtotal a mano',
  $$INSERT INTO factura_detalle (factura_id,servicio_id,linea_nro,descripcion,
                                 cantidad,precio_unitario,subtotal)
    VALUES ((SELECT id FROM factura WHERE estado='pendiente' LIMIT 1),
            (SELECT id FROM servicio LIMIT 1),50,'Trampa',2,100,5)$$);

SELECT _falla('6 Facturación','Línea con servicio Y medicamento a la vez',
  $$INSERT INTO factura_detalle (factura_id,servicio_id,medicamento_id,linea_nro,
                                 descripcion,cantidad,precio_unitario)
    VALUES ((SELECT id FROM factura WHERE estado='pendiente' LIMIT 1),
            (SELECT id FROM servicio LIMIT 1),(SELECT id FROM medicamento LIMIT 1),
            51,'Ambos',1,100)$$);

SELECT _falla('6 Facturación','Línea sin servicio ni medicamento',
  $$INSERT INTO factura_detalle (factura_id,linea_nro,descripcion,cantidad,precio_unitario)
    VALUES ((SELECT id FROM factura WHERE estado='pendiente' LIMIT 1),52,'Ninguno',1,100)$$);

SELECT _falla('6 Facturación','Cobrar más que el total de la factura',
  $$INSERT INTO pago (factura_id,metodo_pago_id,monto)
    SELECT f.id,(SELECT id FROM metodo_pago WHERE nombre='Efectivo'),f.total+50000
      FROM factura f WHERE f.estado='pendiente' LIMIT 1$$);

SELECT _falla('6 Facturación','Pago sin referencia cuando el método la exige',
  $$INSERT INTO pago (factura_id,metodo_pago_id,monto)
    SELECT f.id,(SELECT id FROM metodo_pago WHERE nombre='Transferencia'),1000
      FROM factura f WHERE f.estado='pendiente' LIMIT 1$$);

SELECT _falla('6 Facturación','Modificar el detalle de una factura pagada',
  $$DELETE FROM factura_detalle
     WHERE factura_id=(SELECT id FROM factura WHERE estado='pagada' LIMIT 1)$$);

SELECT _vale('6 Facturación','El total coincide con la suma de sus líneas',
  $$SELECT count(*)::text FROM factura f WHERE f.estado<>'anulada'
     AND f.subtotal <> (SELECT COALESCE(sum(subtotal),0) FROM factura_detalle
                         WHERE factura_id=f.id)$$,'0');

SELECT _vale('6 Facturación','Se numeró automáticamente con el prefijo F-',
  $$SELECT CASE WHEN count(*)>0 THEN 'si' ELSE 'no' END FROM factura
     WHERE numero LIKE 'F-%'$$,'si');


-- ── 7. INVENTARIO ───────────────────────────────────────────────────────────
SELECT _falla('7 Inventario','Facturar más unidades de las que hay en stock',
  $$INSERT INTO factura_detalle (factura_id,medicamento_id,linea_nro,descripcion,
                                 cantidad,precio_unitario)
    SELECT (SELECT id FROM factura WHERE estado='pendiente' LIMIT 1),
           m.id,60,m.nombre,m.stock+100,m.precio FROM medicamento m LIMIT 1$$);

SELECT _vale('7 Inventario','Ningún medicamento quedó con stock negativo',
  $$SELECT count(*)::text FROM medicamento WHERE stock < 0$$,'0');


-- ── 8. VISTAS Y DERIVADOS ───────────────────────────────────────────────────
SELECT _vale('8 Derivados','El peso actual es la última medición',
  $$SELECT peso_actual_kg::text FROM v_mascota_perfil WHERE nombre='Max'$$,'28.50');

SELECT _vale('8 Derivados','La edad se calcula sin almacenarse',
  $$SELECT CASE WHEN edad_anios IS NOT NULL THEN 'si' ELSE 'no' END
      FROM v_mascota_perfil WHERE nombre='Max'$$,'si');

SELECT _vale('8 Derivados','El mestizo conserva su especie sin tener raza',
  $$SELECT especie FROM v_mascota_perfil WHERE nombre='Rocco'$$,'Canino');

SELECT _vale('8 Derivados','El saldo de la factura se deriva de los pagos',
  $$SELECT count(*)::text FROM v_factura_resumen
     WHERE estado<>'anulada' AND saldo <> total - pagado$$,'0');

SELECT _vale('8 Derivados','El historial clínico reúne varias fuentes',
  $$SELECT CASE WHEN count(DISTINCT tipo)>=3 THEN 'si' ELSE 'no' END
      FROM v_historial_clinico
     WHERE mascota_id=(SELECT id FROM mascota WHERE nombre='Max')$$,'si');

SELECT _vale('8 Derivados','El refuerzo se calculó automáticamente',
  $$SELECT CASE WHEN count(*)>0 THEN 'si' ELSE 'no' END FROM aplicacion_vacuna
     WHERE fecha_proximo_refuerzo IS NOT NULL$$,'si');


-- ── INFORME ─────────────────────────────────────────────────────────────────
\echo ''
\echo '================================================================'
\echo '  RESULTADO DE LAS PRUEBAS'
\echo '================================================================'

SELECT lpad(nro::text,2,'0') AS "#", grupo AS "Grupo", caso AS "Caso",
       CASE WHEN paso THEN 'OK' ELSE 'FALLA' END AS "Resultado"
  FROM _r ORDER BY nro;

\echo ''
SELECT count(*) AS "Total", count(*) FILTER (WHERE paso) AS "Superadas",
       count(*) FILTER (WHERE NOT paso) AS "Fallidas",
       CASE WHEN count(*) FILTER (WHERE NOT paso)=0
            THEN 'TODAS LAS PRUEBAS PASARON'
            ELSE 'HAY PRUEBAS FALLIDAS' END AS "Estado"
  FROM _r;

\echo ''
\echo '--- Detalle de las fallidas (vacío si todo pasó) ---'
SELECT nro AS "#", grupo AS "Grupo", caso AS "Caso", detalle AS "Motivo"
  FROM _r WHERE NOT paso ORDER BY nro;

ROLLBACK;

\echo ''
\echo 'Transacción revertida: la base queda sin cambios.'
