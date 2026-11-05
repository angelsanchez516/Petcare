-- ============================================================================
--  PETCARE — 05_vistas.sql · Vistas
-- ----------------------------------------------------------------------------
--  Aquí viven los ATRIBUTOS DERIVADOS. El modelo decidió no almacenarlos para
--  no duplicar información; estas vistas son donde se calculan:
--
--    edad de la mascota    → de fecha_nacimiento
--    peso actual           → última fila de registro_peso
--    estado de vacunación  → fecha_proximo_refuerzo contra hoy
--    saldo de la factura   → total menos la suma de pagos
--
--  Consultarlos por vista cuesta un poco más que leer una columna. A cambio,
--  es IMPOSIBLE que el dato derivado y su origen se contradigan.
-- ============================================================================

SET client_min_messages = WARNING;

-- ----------------------------------------------------------------------------
--  PERFIL DE MASCOTA — la pantalla central del sistema
-- ----------------------------------------------------------------------------
CREATE OR REPLACE VIEW v_mascota_perfil AS
SELECT
    m.id, m.nombre, m.sexo,
    CASE m.sexo WHEN 'M' THEN 'Macho' ELSE 'Hembra' END        AS sexo_texto,
    e.id    AS especie_id,  e.nombre AS especie,  e.icono      AS especie_icono,
    r.id    AS raza_id,     r.nombre AS raza,
    m.color, m.microchip, m.esterilizado, m.foto_url, m.observaciones,
    m.activo, m.fecha_nacimiento, m.fecha_fallecimiento, m.creado_en,

    -- DERIVADO: edad
    CASE WHEN m.fecha_nacimiento IS NOT NULL THEN
        date_part('year', age(COALESCE(m.fecha_fallecimiento, CURRENT_DATE),
                              m.fecha_nacimiento))::INT END     AS edad_anios,
    CASE WHEN m.fecha_nacimiento IS NOT NULL THEN
        (date_part('year',  age(COALESCE(m.fecha_fallecimiento, CURRENT_DATE), m.fecha_nacimiento)) * 12
       + date_part('month', age(COALESCE(m.fecha_fallecimiento, CURRENT_DATE), m.fecha_nacimiento)))::INT
    END                                                          AS edad_meses,

    -- DERIVADO: peso actual
    p.peso_kg                                                    AS peso_actual_kg,
    p.fecha_registro                                             AS peso_fecha,

    -- DERIVADO: estado de vacunación
    v.proximo_refuerzo,
    CASE
        WHEN v.proximo_refuerzo IS NULL                              THEN 'SIN_DATOS'
        WHEN v.proximo_refuerzo <  CURRENT_DATE                      THEN 'VENCIDA'
        WHEN v.proximo_refuerzo <= CURRENT_DATE + INTERVAL '30 days' THEN 'PROXIMA'
        ELSE                                                              'VIGENTE'
    END                                                          AS estado_vacunacion,

    c.id AS cliente_id,
    c.nombres || ' ' || c.apellidos                              AS tutor,
    c.telefono AS tutor_telefono, c.email AS tutor_email
FROM mascota m
JOIN especie e ON e.id = m.especie_id
JOIN cliente c ON c.id = m.cliente_id
LEFT JOIN raza r ON r.id = m.raza_id
-- LATERAL con LIMIT 1: la forma eficiente de traer «la última fila por grupo».
LEFT JOIN LATERAL (
    SELECT rp.peso_kg, rp.fecha_registro FROM registro_peso rp
     WHERE rp.mascota_id = m.id ORDER BY rp.fecha_registro DESC LIMIT 1) p ON TRUE
LEFT JOIN LATERAL (
    SELECT min(av.fecha_proximo_refuerzo) AS proximo_refuerzo FROM aplicacion_vacuna av
     WHERE av.mascota_id = m.id AND av.fecha_proximo_refuerzo IS NOT NULL) v ON TRUE;


-- ----------------------------------------------------------------------------
--  HISTORIAL CLÍNICO — línea de tiempo unificada
-- ----------------------------------------------------------------------------
--  Reúne en una sola secuencia cronológica hechos que viven en cuatro tablas.
-- ----------------------------------------------------------------------------
CREATE OR REPLACE VIEW v_historial_clinico AS
SELECT c.mascota_id, c.fecha_hora::date AS fecha, c.fecha_hora AS momento,
       'CONSULTA' AS tipo, initcap(lower(c.tipo)) AS titulo, c.motivo AS detalle,
       v.nombres || ' ' || v.apellidos AS veterinario, c.id AS referencia_id
  FROM consulta c JOIN veterinario v ON v.id = c.veterinario_id
UNION ALL
SELECT av.mascota_id, av.fecha_aplicacion, av.fecha_aplicacion::timestamptz,
       'VACUNA', vac.nombre,
       'Lote ' || av.lote || COALESCE(' · refuerzo ' ||
            to_char(av.fecha_proximo_refuerzo, 'DD/MM/YYYY'), ''),
       v.nombres || ' ' || v.apellidos, av.id
  FROM aplicacion_vacuna av
  JOIN vacuna vac ON vac.id = av.vacuna_id
  JOIN veterinario v ON v.id = av.veterinario_id
UNION ALL
SELECT rp.mascota_id, rp.fecha_registro, rp.fecha_registro::timestamptz,
       'PESO', rp.peso_kg || ' kg', rp.observacion, NULL, rp.id
  FROM registro_peso rp
UNION ALL
SELECT ci.mascota_id, ci.fecha_hora_inicio::date, ci.fecha_hora_inicio,
       'CITA', initcap(ci.estado), ci.motivo,
       v.nombres || ' ' || v.apellidos, ci.id
  FROM cita ci JOIN veterinario v ON v.id = ci.veterinario_id;


-- ----------------------------------------------------------------------------
--  DIAGNÓSTICOS DE UNA CONSULTA
-- ----------------------------------------------------------------------------
CREATE OR REPLACE VIEW v_consulta_diagnosticos AS
SELECT cd.consulta_id, d.id AS diagnostico_id, d.codigo, d.nombre, d.categoria,
       cd.tipo, cd.es_principal, cd.notas
  FROM consulta_diagnostico cd JOIN diagnostico d ON d.id = cd.diagnostico_id;


-- ----------------------------------------------------------------------------
--  AGENDA
-- ----------------------------------------------------------------------------
CREATE OR REPLACE VIEW v_agenda AS
SELECT ci.id AS cita_id, ci.fecha_hora_inicio, ci.fecha_hora_fin,
       ci.duracion_minutos, ci.estado, ci.motivo, ci.notas,
       m.id AS mascota_id, m.nombre AS mascota, m.foto_url AS mascota_foto,
       e.nombre AS especie, e.icono AS especie_icono,
       cl.id AS cliente_id, cl.nombres || ' ' || cl.apellidos AS tutor,
       cl.telefono AS tutor_telefono,
       v.id AS veterinario_id, v.nombres || ' ' || v.apellidos AS veterinario,
       s.id AS servicio_id, s.nombre AS servicio,
       co.id AS consulta_id
  FROM cita ci
  JOIN mascota m ON m.id = ci.mascota_id
  JOIN especie e ON e.id = m.especie_id
  JOIN cliente cl ON cl.id = m.cliente_id
  JOIN veterinario v ON v.id = ci.veterinario_id
  LEFT JOIN servicio s ON s.id = ci.servicio_id
  LEFT JOIN consulta co ON co.cita_id = ci.id;

COMMENT ON VIEW v_agenda IS
    'El tutor se resuelve por JOIN: la cita no almacena cliente_id porque sería '
    'una dependencia transitiva vía mascota.';


-- ----------------------------------------------------------------------------
--  REFUERZOS DE VACUNA PENDIENTES
-- ----------------------------------------------------------------------------
CREATE OR REPLACE VIEW v_vacunas_pendientes AS
SELECT av.id AS aplicacion_id, av.mascota_id, m.nombre AS mascota, m.foto_url,
       e.nombre AS especie,
       cl.id AS cliente_id, cl.nombres || ' ' || cl.apellidos AS tutor,
       cl.telefono, cl.email,
       vac.id AS vacuna_id, vac.nombre AS vacuna,
       av.fecha_aplicacion AS ultima_aplicacion,
       av.fecha_proximo_refuerzo AS vence,
       (av.fecha_proximo_refuerzo - CURRENT_DATE) AS dias_restantes,
       CASE
           WHEN av.fecha_proximo_refuerzo <  CURRENT_DATE                      THEN 'VENCIDA'
           WHEN av.fecha_proximo_refuerzo <= CURRENT_DATE + INTERVAL '30 days' THEN 'PROXIMA'
           ELSE                                                                     'VIGENTE'
       END AS estado
  FROM aplicacion_vacuna av
  JOIN mascota m ON m.id = av.mascota_id
  JOIN especie e ON e.id = m.especie_id
  JOIN cliente cl ON cl.id = m.cliente_id
  JOIN vacuna vac ON vac.id = av.vacuna_id
 WHERE av.fecha_proximo_refuerzo IS NOT NULL
   AND m.activo AND m.fecha_fallecimiento IS NULL
   -- Solo la aplicación más reciente de cada par mascota-vacuna: las anteriores
   -- ya fueron reforzadas y no deben aparecer como pendientes.
   AND av.fecha_aplicacion = (SELECT max(a2.fecha_aplicacion) FROM aplicacion_vacuna a2
                               WHERE a2.mascota_id = av.mascota_id
                                 AND a2.vacuna_id = av.vacuna_id);


-- ----------------------------------------------------------------------------
--  FACTURACIÓN
-- ----------------------------------------------------------------------------
CREATE OR REPLACE VIEW v_factura_resumen AS
SELECT f.id, f.numero, f.fecha_emision, f.subtotal, f.descuento, f.impuesto,
       f.total, f.estado, f.observaciones,
       c.id AS cliente_id, c.nombres || ' ' || c.apellidos AS cliente,
       c.documento AS cliente_documento, c.telefono AS cliente_telefono,
       COALESCE(p.pagado, 0)                        AS pagado,
       f.total - COALESCE(p.pagado, 0)              AS saldo,   -- DERIVADO
       (SELECT count(*) FROM factura_detalle d WHERE d.factura_id = f.id) AS lineas
  FROM factura f
  JOIN cliente c ON c.id = f.cliente_id
  LEFT JOIN LATERAL (SELECT sum(monto) AS pagado FROM pago
                      WHERE factura_id = f.id) p ON TRUE;

COMMENT ON VIEW v_factura_resumen IS
    'El saldo es DERIVADO: total menos la suma de pagos. No se almacena para '
    'que no pueda contradecir a los pagos reales.';


CREATE OR REPLACE VIEW v_ingresos_mensuales AS
SELECT date_trunc('month', f.fecha_emision)::date AS mes,
       count(*) AS facturas, sum(f.subtotal) AS subtotal,
       sum(f.descuento) AS descuentos, sum(f.total) AS facturado,
       COALESCE(sum(pg.pagado), 0) AS cobrado,
       sum(f.total) - COALESCE(sum(pg.pagado), 0) AS por_cobrar
  FROM factura f
  LEFT JOIN LATERAL (SELECT sum(monto) AS pagado FROM pago
                      WHERE factura_id = f.id) pg ON TRUE
 WHERE f.estado <> 'anulada'
 GROUP BY 1;


CREATE OR REPLACE VIEW v_servicios_mas_usados AS
SELECT s.id, s.codigo, s.nombre, s.categoria,
       count(*) AS veces, sum(fd.cantidad) AS unidades, sum(fd.subtotal) AS ingresos
  FROM factura_detalle fd
  JOIN servicio s ON s.id = fd.servicio_id
  JOIN factura f  ON f.id = fd.factura_id
 WHERE f.estado <> 'anulada'
 GROUP BY s.id, s.codigo, s.nombre, s.categoria;


-- ----------------------------------------------------------------------------
--  MORBILIDAD — imposible sin el catálogo de diagnósticos
-- ----------------------------------------------------------------------------
CREATE OR REPLACE VIEW v_morbilidad AS
SELECT d.id, d.codigo, d.nombre, d.categoria,
       count(*) FILTER (WHERE cd.tipo = 'DEFINITIVO') AS confirmados,
       count(*)                                        AS casos,
       count(DISTINCT c.mascota_id)                    AS pacientes
  FROM consulta_diagnostico cd
  JOIN diagnostico d ON d.id = cd.diagnostico_id
  JOIN consulta c    ON c.id = cd.consulta_id
 WHERE cd.tipo <> 'DESCARTADO'
 GROUP BY d.id, d.codigo, d.nombre, d.categoria;

COMMENT ON VIEW v_morbilidad IS
    'Este reporte es IMPOSIBLE si el diagnóstico se guarda como texto libre: '
    '«Gastritis» y «gastritis» serían dos patologías distintas.';


-- ----------------------------------------------------------------------------
--  STOCK BAJO
-- ----------------------------------------------------------------------------
CREATE OR REPLACE VIEW v_stock_alerta AS
SELECT id, nombre, principio_activo, presentacion, concentracion,
       stock, stock_minimo, precio,
       CASE WHEN stock = 0 THEN 'SIN_STOCK' ELSE 'BAJO' END AS estado
  FROM medicamento
 WHERE activo AND stock <= stock_minimo;
