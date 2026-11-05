-- ============================================================================
--  PETCARE — 08_pruebas.sql · Batería de pruebas de la base de datos
-- ----------------------------------------------------------------------------
--  FASE 5 del proyecto. No basta con que el esquema se cree: hay que demostrar
--  que las restricciones REALMENTE impiden los datos incorrectos.
--
--  Por eso la mitad de estas pruebas verifican que una operación FALLE. Una
--  restricción que nunca se probó contra un caso inválido no es una garantía,
--  es una suposición.
--
--  Cada prueba imprime OK o FALLA. Todo corre dentro de una transacción que se
--  revierte al final: ejecutarlo NO deja basura en la base.
--
--  Ejecución:  psql -U postgres -d petcare -f database/08_pruebas.sql
-- ============================================================================

\set ON_ERROR_STOP off
SET client_min_messages = WARNING;

BEGIN;

-- ----------------------------------------------------------------------------
-- Infraestructura de pruebas
-- ----------------------------------------------------------------------------
CREATE TEMP TABLE _resultado (
    nro      SERIAL,
    grupo    TEXT,
    caso     TEXT,
    esperado TEXT,
    paso     BOOLEAN,
    detalle  TEXT
);

-- Ejecuta una sentencia que DEBE fallar. Si falla, la prueba pasa.
CREATE OR REPLACE FUNCTION _debe_fallar(p_grupo TEXT, p_caso TEXT, p_sql TEXT)
RETURNS VOID LANGUAGE plpgsql AS $$
BEGIN
    BEGIN
        EXECUTE p_sql;
        INSERT INTO _resultado (grupo, caso, esperado, paso, detalle)
        VALUES (p_grupo, p_caso, 'rechazo', FALSE, 'La sentencia se aceptó cuando debía fallar');
    EXCEPTION WHEN OTHERS THEN
        INSERT INTO _resultado (grupo, caso, esperado, paso, detalle)
        VALUES (p_grupo, p_caso, 'rechazo', TRUE, left(SQLERRM, 90));
    END;
END $$;

-- Ejecuta una sentencia que DEBE funcionar.
CREATE OR REPLACE FUNCTION _debe_pasar(p_grupo TEXT, p_caso TEXT, p_sql TEXT)
RETURNS VOID LANGUAGE plpgsql AS $$
BEGIN
    BEGIN
        EXECUTE p_sql;
        INSERT INTO _resultado (grupo, caso, esperado, paso, detalle)
        VALUES (p_grupo, p_caso, 'aceptación', TRUE, NULL);
    EXCEPTION WHEN OTHERS THEN
        INSERT INTO _resultado (grupo, caso, esperado, paso, detalle)
        VALUES (p_grupo, p_caso, 'aceptación', FALSE, left(SQLERRM, 90));
    END;
END $$;

-- Compara un valor calculado contra el esperado.
CREATE OR REPLACE FUNCTION _debe_valer(p_grupo TEXT, p_caso TEXT, p_sql TEXT, p_esperado TEXT)
RETURNS VOID LANGUAGE plpgsql AS $$
DECLARE v TEXT;
BEGIN
    EXECUTE p_sql INTO v;
    INSERT INTO _resultado (grupo, caso, esperado, paso, detalle)
    VALUES (p_grupo, p_caso, p_esperado, v IS NOT DISTINCT FROM p_esperado,
            'obtenido: ' || COALESCE(v, 'NULL'));
EXCEPTION WHEN OTHERS THEN
    INSERT INTO _resultado (grupo, caso, esperado, paso, detalle)
    VALUES (p_grupo, p_caso, p_esperado, FALSE, left(SQLERRM, 90));
END $$;


-- ============================================================================
--  GRUPO 1 — ESTRUCTURA
-- ============================================================================

SELECT _debe_valer('1. Estructura', 'Se crearon las 52 tablas',
    $$SELECT count(*)::text FROM information_schema.tables
       WHERE table_schema='public' AND table_type='BASE TABLE'$$, '52');

SELECT _debe_valer('1. Estructura', 'Toda tabla tiene clave primaria',
    $$SELECT count(*)::text FROM information_schema.tables t
       WHERE t.table_schema='public' AND t.table_type='BASE TABLE'
         AND NOT EXISTS (SELECT 1 FROM information_schema.table_constraints tc
                          WHERE tc.table_name=t.table_name
                            AND tc.constraint_type='PRIMARY KEY')$$, '0');

SELECT _debe_valer('1. Estructura', 'Ninguna clave foránea quedó sin índice',
    $$WITH fk AS (
        SELECT c.conrelid, c.conkey
          FROM pg_constraint c JOIN pg_namespace n ON n.oid=c.connamespace
         WHERE c.contype='f' AND n.nspname='public')
      SELECT count(*)::text FROM fk
       WHERE NOT EXISTS (
         SELECT 1 FROM pg_index i
          WHERE i.indrelid=fk.conrelid
            AND (i.indkey::smallint[])[0:array_length(fk.conkey,1)-1] @> fk.conkey)$$, '0');

SELECT _debe_valer('1. Estructura', 'Existen las 2 jerarquías ISA',
    $$SELECT count(*)::text FROM pg_constraint c
       JOIN pg_class t ON t.oid=c.conrelid
       WHERE c.contype='f' AND t.relname IN ('veterinario','medicamento')
         AND c.conname IN ('fk_veterinario_empleado','fk_medicamento_producto')$$, '2');

SELECT _debe_valer('1. Estructura', 'Existen las 2 relaciones recursivas',
    $$SELECT count(*)::text FROM pg_constraint
       WHERE conname IN ('fk_diagnostico_padre','fk_categoria_padre')$$, '2');


-- ============================================================================
--  GRUPO 2 — REGLAS DE DOMINIO (los casos incorrectos del enunciado)
-- ============================================================================

SELECT _debe_fallar('2. Dominio', 'Peso negativo',
    $$INSERT INTO registro_peso (mascota_id, fecha_registro, peso_kg)
      VALUES ((SELECT id FROM mascota LIMIT 1), CURRENT_DATE - 999, -5)$$);

SELECT _debe_fallar('2. Dominio', 'Peso igual a cero',
    $$INSERT INTO registro_peso (mascota_id, fecha_registro, peso_kg)
      VALUES ((SELECT id FROM mascota LIMIT 1), CURRENT_DATE - 998, 0)$$);

SELECT _debe_fallar('2. Dominio', 'Precio de servicio negativo',
    $$INSERT INTO servicio (codigo, nombre, categoria, precio_base)
      VALUES ('TEST-NEG','Servicio inválido','CONSULTA', -1000)$$);

SELECT _debe_fallar('2. Dominio', 'Cantidad facturada igual a cero',
    $$INSERT INTO factura_detalle (factura_id, servicio_id, linea_nro, tipo_item,
                                   descripcion, cantidad, precio_unitario)
      VALUES ((SELECT id FROM factura WHERE estado='pendiente' LIMIT 1),
              (SELECT id FROM servicio LIMIT 1), 99, 'SERVICIO','Prueba', 0, 1000)$$);

SELECT _debe_fallar('2. Dominio', 'Sexo de mascota fuera del dominio',
    $$INSERT INTO mascota (cliente_id, especie_id, nombre, sexo)
      VALUES ((SELECT id FROM cliente LIMIT 1), (SELECT id FROM especie LIMIT 1), 'Test','X')$$);

SELECT _debe_fallar('2. Dominio', 'Estado de cita inexistente',
    $$UPDATE cita SET estado='inventado' WHERE id=(SELECT id FROM cita LIMIT 1)$$);

SELECT _debe_fallar('2. Dominio', 'Temperatura fuera del rango biológico',
    $$INSERT INTO consulta (mascota_id, veterinario_id, motivo, temperatura_c)
      VALUES ((SELECT id FROM mascota LIMIT 1),
              (SELECT empleado_id FROM veterinario LIMIT 1),'Prueba', 60)$$);

SELECT _debe_fallar('2. Dominio', 'Fecha de nacimiento futura',
    $$INSERT INTO mascota (cliente_id, especie_id, nombre, sexo, fecha_nacimiento)
      VALUES ((SELECT id FROM cliente LIMIT 1), (SELECT id FROM especie LIMIT 1),
              'Futuro','M', CURRENT_DATE + 30)$$);

SELECT _debe_fallar('2. Dominio', 'Correo con formato inválido',
    $$INSERT INTO cliente (documento, nombres, apellidos, telefono, email)
      VALUES ('99999901','Test','Correo','+54 11 1111-1111','esto-no-es-un-correo')$$);


-- ============================================================================
--  GRUPO 3 — REGLAS CLÍNICAS
-- ============================================================================

SELECT _debe_fallar('3. Clínicas', 'Refuerzo anterior a la aplicación',
    $$INSERT INTO aplicacion_vacuna (mascota_id, vacuna_id, veterinario_id,
                                     fecha_aplicacion, fecha_proximo_refuerzo, lote)
      VALUES ((SELECT id FROM mascota WHERE nombre='Max'),
              (SELECT id FROM vacuna WHERE nombre='Antirrábica'),
              (SELECT empleado_id FROM veterinario LIMIT 1),
              CURRENT_DATE, CURRENT_DATE - 30, 'LOTE-TEST')$$);

SELECT _debe_fallar('3. Clínicas', 'Vacuna canina aplicada a un felino',
    $$INSERT INTO aplicacion_vacuna (mascota_id, vacuna_id, veterinario_id,
                                     fecha_aplicacion, lote)
      VALUES ((SELECT id FROM mascota WHERE nombre='Luna'),
              (SELECT id FROM vacuna WHERE nombre='Quíntuple canina'),
              (SELECT empleado_id FROM veterinario LIMIT 1),
              CURRENT_DATE - 5, 'LOTE-TEST-2')$$);

SELECT _debe_fallar('3. Clínicas', 'Aplicar la misma vacuna dos veces el mismo día',
    $$INSERT INTO aplicacion_vacuna (mascota_id, vacuna_id, veterinario_id,
                                     fecha_aplicacion, lote)
      SELECT mascota_id, vacuna_id, veterinario_id, fecha_aplicacion, 'DUP'
        FROM aplicacion_vacuna LIMIT 1$$);

SELECT _debe_fallar('3. Clínicas', 'Consulta de una mascota distinta a la de su cita',
    $$INSERT INTO consulta (mascota_id, veterinario_id, cita_id, motivo)
      SELECT (SELECT id FROM mascota WHERE nombre='Mishi'),
             c.veterinario_id, c.id, 'Mascota incorrecta'
        FROM cita c WHERE c.estado='confirmada' LIMIT 1$$);

SELECT _debe_fallar('3. Clínicas', 'Dos pesos oficiales el mismo día',
    $$INSERT INTO registro_peso (mascota_id, fecha_registro, peso_kg)
      SELECT mascota_id, fecha_registro, 99 FROM registro_peso LIMIT 1$$);

SELECT _debe_fallar('3. Clínicas', 'Dos recetas para la misma consulta',
    $$INSERT INTO receta (consulta_id, indicaciones_generales)
      SELECT consulta_id, 'Segunda receta' FROM receta LIMIT 1$$);

SELECT _debe_fallar('3. Clínicas', 'Duración de tratamiento igual a cero',
    $$INSERT INTO receta_detalle (receta_id, medicamento_id, dosis, frecuencia,
                                  duracion_dias, cantidad)
      VALUES ((SELECT id FROM receta LIMIT 1),
              (SELECT producto_id FROM medicamento
                WHERE producto_id NOT IN (SELECT medicamento_id FROM receta_detalle) LIMIT 1),
              '1 comprimido','cada 8 horas', 0, 1)$$);


-- ============================================================================
--  GRUPO 4 — INTEGRIDAD REFERENCIAL Y PROTECCIÓN DEL HISTORIAL
-- ============================================================================

SELECT _debe_fallar('4. Integridad', 'Borrar una mascota con historial clínico',
    $$DELETE FROM mascota WHERE nombre='Max'$$);

SELECT _debe_fallar('4. Integridad', 'Borrar un tutor con mascotas',
    $$DELETE FROM cliente WHERE documento='31456789'$$);

SELECT _debe_fallar('4. Integridad', 'Borrar una especie en uso',
    $$DELETE FROM especie WHERE nombre='Canino'$$);

SELECT _debe_fallar('4. Integridad', 'Cita sin mascota',
    $$INSERT INTO cita (mascota_id, veterinario_id, fecha_hora_inicio, motivo)
      VALUES (NULL, (SELECT empleado_id FROM veterinario LIMIT 1),
              now() + INTERVAL '1 day','Sin mascota')$$);

SELECT _debe_fallar('4. Integridad', 'Consulta con veterinario inexistente',
    $$INSERT INTO consulta (mascota_id, veterinario_id, motivo)
      VALUES ((SELECT id FROM mascota LIMIT 1), 999999, 'Veterinario fantasma')$$);

SELECT _debe_fallar('4. Integridad', 'Receta con medicamento inexistente',
    $$INSERT INTO receta_detalle (receta_id, medicamento_id, dosis, frecuencia, duracion_dias, cantidad)
      VALUES ((SELECT id FROM receta LIMIT 1), 999999,'1 comp','cada 8 h', 5, 1)$$);

-- LA PRUEBA CLAVE DE LA FK COMPUESTA
SELECT _debe_fallar('4. Integridad', 'Felino con raza de canino',
    $$INSERT INTO mascota (cliente_id, especie_id, raza_id, nombre, sexo)
      SELECT (SELECT id FROM cliente LIMIT 1),
             (SELECT id FROM especie WHERE nombre='Felino'),
             (SELECT r.id FROM raza r JOIN especie e ON e.id=r.especie_id
               WHERE e.nombre='Canino' AND r.nombre='Labrador Retriever'),
             'Imposible','M'$$);

-- Y el caso que SÍ debe permitirse: mestizo sin raza pero con especie.
SELECT _debe_pasar('4. Integridad', 'Mestizo sin raza pero con especie',
    $$INSERT INTO mascota (cliente_id, especie_id, raza_id, nombre, sexo)
      VALUES ((SELECT id FROM cliente LIMIT 1),
              (SELECT id FROM especie WHERE nombre='Canino'), NULL,'Mestizo test','H')$$);

SELECT _debe_fallar('4. Integridad', 'Subtipo veterinario sin empleado',
    $$INSERT INTO veterinario (empleado_id, matricula) VALUES (999999,'MP-FALSA')$$);

SELECT _debe_fallar('4. Integridad', 'Dos subtipos para el mismo empleado',
    $$INSERT INTO veterinario (empleado_id, matricula)
      SELECT empleado_id,'MP-DUPLICADA' FROM veterinario LIMIT 1$$);


-- ============================================================================
--  GRUPO 5 — AGENDA
-- ============================================================================

SELECT _debe_fallar('5. Agenda', 'Dos citas solapadas del mismo veterinario',
    $$INSERT INTO cita (mascota_id, veterinario_id, fecha_hora_inicio, duracion_minutos, motivo)
      SELECT c.mascota_id, c.veterinario_id,
             c.fecha_hora_inicio + INTERVAL '10 minutes', 30,'Solapada'
        FROM cita c WHERE c.estado IN ('programada','confirmada') LIMIT 1$$);

SELECT _debe_pasar('5. Agenda', 'Dos veterinarios distintos a la misma hora',
    $$INSERT INTO cita (mascota_id, veterinario_id, fecha_hora_inicio, duracion_minutos, motivo)
      SELECT c.mascota_id,
             (SELECT empleado_id FROM veterinario
               WHERE empleado_id <> c.veterinario_id LIMIT 1),
             c.fecha_hora_inicio, 30,'Otro profesional, misma hora'
        FROM cita c WHERE c.estado='confirmada' LIMIT 1$$);

SELECT _debe_fallar('5. Agenda', 'Cancelar una cita sin justificar',
    $$UPDATE cita SET estado='cancelada'
       WHERE id=(SELECT id FROM cita WHERE estado='programada' LIMIT 1)$$);

SELECT _debe_fallar('5. Agenda', 'Duración de cita fuera de rango',
    $$INSERT INTO cita (mascota_id, veterinario_id, fecha_hora_inicio, duracion_minutos, motivo)
      VALUES ((SELECT id FROM mascota LIMIT 1),
              (SELECT empleado_id FROM veterinario LIMIT 1),
              now() + INTERVAL '60 days', 5,'Muy corta')$$);


-- ============================================================================
--  GRUPO 6 — FACTURACIÓN
-- ============================================================================

-- El subtotal es una columna GENERATED: no se puede escribir.
SELECT _debe_fallar('6. Facturación', 'Escribir un subtotal a mano',
    $$INSERT INTO factura_detalle (factura_id, servicio_id, linea_nro, tipo_item,
                                   descripcion, cantidad, precio_unitario, subtotal)
      VALUES ((SELECT id FROM factura WHERE estado='pendiente' LIMIT 1),
              (SELECT id FROM servicio LIMIT 1), 50,'SERVICIO','Trampa', 2, 100, 5)$$);

SELECT _debe_fallar('6. Facturación', 'Línea con servicio Y producto a la vez',
    $$INSERT INTO factura_detalle (factura_id, servicio_id, producto_id, linea_nro,
                                   tipo_item, descripcion, cantidad, precio_unitario)
      VALUES ((SELECT id FROM factura WHERE estado='pendiente' LIMIT 1),
              (SELECT id FROM servicio LIMIT 1), (SELECT id FROM producto LIMIT 1),
              51,'SERVICIO','Arco roto', 1, 100)$$);

SELECT _debe_fallar('6. Facturación', 'Línea de tipo SERVICIO sin servicio',
    $$INSERT INTO factura_detalle (factura_id, linea_nro, tipo_item, descripcion,
                                   cantidad, precio_unitario)
      VALUES ((SELECT id FROM factura WHERE estado='pendiente' LIMIT 1),
              52,'SERVICIO','Sin referencia', 1, 100)$$);

SELECT _debe_fallar('6. Facturación', 'Cobrar más que el total de la factura',
    $$INSERT INTO pago (factura_id, metodo_pago_id, monto)
      SELECT f.id, (SELECT id FROM metodo_pago WHERE nombre='Efectivo'), f.total + 50000
        FROM factura f WHERE f.estado='pendiente' LIMIT 1$$);

SELECT _debe_fallar('6. Facturación', 'Pago con método que exige referencia, sin referencia',
    $$INSERT INTO pago (factura_id, metodo_pago_id, monto)
      SELECT f.id, (SELECT id FROM metodo_pago WHERE nombre='Transferencia'), 1000
        FROM factura f WHERE f.estado='pendiente' LIMIT 1$$);

SELECT _debe_fallar('6. Facturación', 'Modificar el detalle de una factura pagada',
    $$DELETE FROM factura_detalle
       WHERE factura_id=(SELECT id FROM factura WHERE estado='pagada' LIMIT 1)$$);

-- El trigger de totales: verificar que total = suma de líneas.
SELECT _debe_valer('6. Facturación', 'El total coincide con la suma de sus líneas',
    $$SELECT count(*)::text FROM factura f
       WHERE f.estado <> 'anulada'
         AND f.subtotal <> (SELECT COALESCE(sum(subtotal),0) FROM factura_detalle
                             WHERE factura_id=f.id)$$, '0');

SELECT _debe_valer('6. Facturación', 'El saldo coincide con total menos pagos',
    $$SELECT count(*)::text FROM factura f
       WHERE f.estado <> 'anulada'
         AND f.saldo_pendiente <> GREATEST(f.total -
             (SELECT COALESCE(sum(monto),0) FROM pago
               WHERE factura_id=f.id AND NOT anulado), 0)$$, '0');

SELECT _debe_valer('6. Facturación', 'Se generó una factura numerada automáticamente',
    $$SELECT CASE WHEN count(*) > 0 THEN 'si' ELSE 'no' END
        FROM factura WHERE numero LIKE 'F-%'$$, 'si');


-- ============================================================================
--  GRUPO 7 — INVENTARIO
-- ============================================================================

SELECT _debe_fallar('7. Inventario', 'Dejar el stock en negativo',
    $$INSERT INTO movimiento_stock (producto_id, tipo, cantidad, motivo)
      SELECT id,'SALIDA', -999999,'Prueba de sobregiro' FROM producto LIMIT 1$$);

SELECT _debe_fallar('7. Inventario', 'Salida con cantidad positiva',
    $$INSERT INTO movimiento_stock (producto_id, tipo, cantidad)
      SELECT id,'SALIDA', 10 FROM producto LIMIT 1$$);

SELECT _debe_fallar('7. Inventario', 'Movimiento de cantidad cero',
    $$INSERT INTO movimiento_stock (producto_id, tipo, cantidad, motivo)
      SELECT id,'AJUSTE', 0,'Sin efecto' FROM producto LIMIT 1$$);

SELECT _debe_fallar('7. Inventario', 'Ajuste sin motivo documentado',
    $$INSERT INTO movimiento_stock (producto_id, tipo, cantidad)
      SELECT id,'AJUSTE', 5 FROM producto LIMIT 1$$);

SELECT _debe_valer('7. Inventario', 'La compra recibida ingresó stock',
    $$SELECT CASE WHEN sum(cantidad) > 0 THEN 'si' ELSE 'no' END
        FROM movimiento_stock WHERE tipo='ENTRADA'$$, 'si');

SELECT _debe_valer('7. Inventario', 'Facturar un producto generó su salida',
    $$SELECT CASE WHEN count(*) > 0 THEN 'si' ELSE 'no' END
        FROM movimiento_stock WHERE factura_detalle_id IS NOT NULL$$, 'si');

SELECT _debe_valer('7. Inventario', 'Aplicar una vacuna descontó su frasco',
    $$SELECT CASE WHEN count(*) > 0 THEN 'si' ELSE 'no' END
        FROM movimiento_stock WHERE aplicacion_vacuna_id IS NOT NULL$$, 'si');

SELECT _debe_valer('7. Inventario', 'Ningún producto quedó con stock negativo',
    $$SELECT count(*)::text FROM v_stock_actual WHERE stock_actual < 0$$, '0');


-- ============================================================================
--  GRUPO 8 — JERARQUÍAS RECURSIVAS
-- ============================================================================

SELECT _debe_fallar('8. Jerarquías', 'Un diagnóstico que es su propio padre',
    $$UPDATE diagnostico SET padre_id=id WHERE codigo='GAS-002'$$);

SELECT _debe_fallar('8. Jerarquías', 'Ciclo A→B→C→A en la jerarquía',
    $$UPDATE diagnostico SET padre_id=(SELECT id FROM diagnostico WHERE codigo='GAS-002')
       WHERE codigo='SIS-DIG'$$);

SELECT _debe_fallar('8. Jerarquías', 'Borrar un diagnóstico con hijos',
    $$DELETE FROM diagnostico WHERE codigo='SIS-DIG'$$);

SELECT _debe_valer('8. Jerarquías', 'El nivel se calcula solo (Gastritis aguda = 3)',
    $$SELECT nivel::text FROM diagnostico WHERE codigo='GAS-002'$$, '3');

SELECT _debe_valer('8. Jerarquías', 'La ruta completa se arma con la recursiva',
    $$SELECT ruta FROM v_diagnostico_arbol WHERE codigo='GAS-002'$$,
    'Sistema digestivo › Gastritis › Gastritis aguda');


-- ============================================================================
--  GRUPO 9 — HOSPITALIZACIÓN
-- ============================================================================

SELECT _debe_pasar('9. Hospitalización', 'Internar una mascota',
    $$INSERT INTO hospitalizacion (mascota_id, veterinario_id, motivo)
      VALUES ((SELECT id FROM mascota WHERE nombre='Zeus'),
              (SELECT empleado_id FROM veterinario LIMIT 1),'Descompensación renal')$$);

SELECT _debe_fallar('9. Hospitalización', 'Internar dos veces a la misma mascota',
    $$INSERT INTO hospitalizacion (mascota_id, veterinario_id, motivo)
      VALUES ((SELECT id FROM mascota WHERE nombre='Zeus'),
              (SELECT empleado_id FROM veterinario LIMIT 1),'Segunda internación')$$);

SELECT _debe_fallar('9. Hospitalización', 'Superar la capacidad de una habitación',
    $$INSERT INTO hospitalizacion_habitacion (hospitalizacion_id, habitacion_id, desde)
      SELECT h.id, (SELECT id FROM habitacion WHERE codigo='AIS-01'), now()
        FROM hospitalizacion h, generate_series(1,3) g$$);

SELECT _debe_fallar('9. Hospitalización', 'Alta anterior al ingreso',
    $$UPDATE hospitalizacion
         SET estado='finalizada', fecha_alta=fecha_ingreso - INTERVAL '2 days',
             tipo_alta='MEJORIA'
       WHERE estado='activa'$$);


-- ============================================================================
--  GRUPO 10 — VISTAS Y ATRIBUTOS DERIVADOS
-- ============================================================================

SELECT _debe_valer('10. Derivados', 'El peso actual es la última medición',
    $$SELECT peso_actual_kg::text FROM v_mascota_perfil WHERE nombre='Max'$$, '28.60');

SELECT _debe_valer('10. Derivados', 'La edad se calcula sin almacenarse',
    $$SELECT CASE WHEN edad_anios IS NOT NULL THEN 'si' ELSE 'no' END
        FROM v_mascota_perfil WHERE nombre='Max'$$, 'si');

SELECT _debe_valer('10. Derivados', 'El estado de vacunación se deriva del refuerzo',
    $$SELECT CASE WHEN estado_vacunacion IN ('VIGENTE','PROXIMA','VENCIDA','SIN_DATOS')
                  THEN 'ok' END FROM v_mascota_perfil WHERE nombre='Max'$$, 'ok');

SELECT _debe_valer('10. Derivados', 'El historial clínico reúne todas las fuentes',
    $$SELECT CASE WHEN count(DISTINCT tipo) >= 3 THEN 'si' ELSE 'no' END
        FROM v_historial_clinico
       WHERE mascota_id=(SELECT id FROM mascota WHERE nombre='Max')$$, 'si');

SELECT _debe_valer('10. Derivados', 'El reporte de morbilidad agrupa por catálogo',
    $$SELECT CASE WHEN count(*) > 0 THEN 'si' ELSE 'no' END FROM v_morbilidad$$, 'si');


-- ============================================================================
--  INFORME
-- ============================================================================

\echo ''
\echo '================================================================'
\echo '  RESULTADO DE LAS PRUEBAS'
\echo '================================================================'

SELECT lpad(nro::text, 3, '0')                AS "#",
       grupo                                  AS "Grupo",
       caso                                   AS "Caso de prueba",
       CASE WHEN paso THEN 'OK' ELSE 'FALLA' END AS "Resultado"
  FROM _resultado
 ORDER BY nro;

\echo ''
\echo '--- Resumen por grupo ---'

SELECT grupo                                   AS "Grupo",
       count(*)                                AS "Pruebas",
       count(*) FILTER (WHERE paso)            AS "OK",
       count(*) FILTER (WHERE NOT paso)        AS "Fallas"
  FROM _resultado
 GROUP BY grupo
 ORDER BY grupo;

\echo ''
\echo '--- Total ---'

SELECT count(*)                         AS "Total",
       count(*) FILTER (WHERE paso)     AS "Superadas",
       count(*) FILTER (WHERE NOT paso) AS "Fallidas",
       CASE WHEN count(*) FILTER (WHERE NOT paso) = 0
            THEN 'TODAS LAS PRUEBAS PASARON'
            ELSE 'HAY PRUEBAS FALLIDAS — revisar el detalle'
       END                              AS "Estado"
  FROM _resultado;

\echo ''
\echo '--- Detalle de las que fallaron (vacío si todo pasó) ---'

SELECT nro AS "#", grupo AS "Grupo", caso AS "Caso", detalle AS "Motivo"
  FROM _resultado WHERE NOT paso ORDER BY nro;

-- Todo lo que hizo esta batería se revierte: la base queda como estaba.
ROLLBACK;

\echo ''
\echo 'Transacción revertida: la base de datos queda sin cambios.'
