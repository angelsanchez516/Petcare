-- ============================================================================
--  PETCARE — 05_vistas.sql · Vistas
-- ----------------------------------------------------------------------------
--  Aquí viven los ATRIBUTOS DERIVADOS. El modelo decidió no almacenarlos para
--  no duplicar información; estas vistas son el lugar donde se calculan:
--
--    edad de la mascota      → de fecha_nacimiento
--    peso actual             → última fila de registro_peso
--    estado de vacunación    → fecha_proximo_refuerzo contra hoy
--    stock actual            → SUM(cantidad) sobre movimiento_stock
--
--  Consultarlos por vista cuesta un poco más que leer una columna. A cambio,
--  es IMPOSIBLE que el dato derivado y su origen se contradigan — que es
--  exactamente el defecto que se corrigió al unificar los dos modelos.
-- ============================================================================

SET client_min_messages = WARNING;

-- ============================================================================
--  PERFIL DE MASCOTA — la pantalla central del sistema
-- ============================================================================
CREATE OR REPLACE VIEW v_mascota_perfil AS
SELECT
    m.id,
    m.nombre,
    m.sexo,
    CASE m.sexo WHEN 'M' THEN 'Macho' WHEN 'H' THEN 'Hembra' END AS sexo_texto,
    e.nombre                        AS especie,
    e.icono                         AS especie_icono,
    r.nombre                        AS raza,
    m.color,
    m.microchip,
    m.esterilizado,
    m.temperamento,
    m.foto_url,
    m.activo,
    m.fecha_nacimiento,
    m.fecha_fallecimiento,

    -- ── DERIVADO: edad ──────────────────────────────────────────────────────
    CASE
        WHEN m.fecha_nacimiento IS NOT NULL THEN
            date_part('year', age(COALESCE(m.fecha_fallecimiento, CURRENT_DATE),
                                  m.fecha_nacimiento))::INT
        WHEN m.edad_aproximada_meses IS NOT NULL THEN
            (m.edad_aproximada_meses / 12)::INT
    END                             AS edad_anios,
    CASE
        WHEN m.fecha_nacimiento IS NOT NULL THEN
            (date_part('year', age(COALESCE(m.fecha_fallecimiento, CURRENT_DATE), m.fecha_nacimiento)) * 12
           + date_part('month', age(COALESCE(m.fecha_fallecimiento, CURRENT_DATE), m.fecha_nacimiento)))::INT
        ELSE m.edad_aproximada_meses
    END                             AS edad_meses,

    -- ── DERIVADO: peso actual ───────────────────────────────────────────────
    p.peso_kg                       AS peso_actual_kg,
    p.fecha_registro                AS peso_fecha,

    -- ── DERIVADO: estado de vacunación ──────────────────────────────────────
    v.proximo_refuerzo,
    CASE
        WHEN v.proximo_refuerzo IS NULL                                   THEN 'SIN_DATOS'
        WHEN v.proximo_refuerzo <  CURRENT_DATE                           THEN 'VENCIDA'
        WHEN v.proximo_refuerzo <= CURRENT_DATE + INTERVAL '30 days'      THEN 'PROXIMA'
        ELSE                                                                   'VIGENTE'
    END                             AS estado_vacunacion,

    -- ── Tutor ───────────────────────────────────────────────────────────────
    c.id                            AS cliente_id,
    c.nombres || ' ' || c.apellidos AS tutor,
    c.telefono                      AS tutor_telefono,
    c.email                         AS tutor_email
FROM mascota m
JOIN especie  e ON e.id = m.especie_id
JOIN cliente  c ON c.id = m.cliente_id
LEFT JOIN raza r ON r.id = m.raza_id
-- LATERAL con LIMIT 1: la forma eficiente de traer «la última fila por grupo».
LEFT JOIN LATERAL (
    SELECT rp.peso_kg, rp.fecha_registro
      FROM registro_peso rp
     WHERE rp.mascota_id = m.id
     ORDER BY rp.fecha_registro DESC
     LIMIT 1
) p ON TRUE
LEFT JOIN LATERAL (
    SELECT min(av.fecha_proximo_refuerzo) AS proximo_refuerzo
      FROM aplicacion_vacuna av
     WHERE av.mascota_id = m.id
       AND av.fecha_proximo_refuerzo IS NOT NULL
) v ON TRUE;

COMMENT ON VIEW v_mascota_perfil IS
    'Ficha completa de la mascota con sus cuatro atributos derivados. Es la '
    'fuente que consume el perfil de la aplicación.';


-- ============================================================================
--  HISTORIAL CLÍNICO — línea de tiempo unificada
-- ----------------------------------------------------------------------------
--  Reúne en una sola secuencia cronológica hechos que viven en seis tablas
--  distintas. Es lo que alimenta el timeline visual del expediente.
-- ============================================================================
CREATE OR REPLACE VIEW v_historial_clinico AS
SELECT mascota_id, fecha, tipo, titulo, detalle, veterinario, referencia_id
FROM (
    SELECT c.mascota_id,
           c.fecha_hora::date              AS fecha,
           'CONSULTA'                      AS tipo,
           initcap(lower(c.tipo))          AS titulo,
           c.motivo                        AS detalle,
           emp.nombres || ' ' || emp.apellidos AS veterinario,
           c.id                            AS referencia_id
      FROM consulta c
      JOIN empleado emp ON emp.id = c.veterinario_id

    UNION ALL
    SELECT av.mascota_id, av.fecha_aplicacion, 'VACUNA', vac.nombre,
           'Lote ' || av.lote ||
           COALESCE(' · refuerzo ' || to_char(av.fecha_proximo_refuerzo, 'DD/MM/YYYY'), ''),
           emp.nombres || ' ' || emp.apellidos, av.id
      FROM aplicacion_vacuna av
      JOIN vacuna   vac ON vac.id = av.vacuna_id
      JOIN empleado emp ON emp.id = av.veterinario_id

    UNION ALL
    SELECT d.mascota_id, d.fecha_aplicacion, 'DESPARASITACION',
           'Desparasitación ' || lower(d.tipo), pr.nombre,
           NULL, d.id
      FROM desparasitacion d
      JOIN producto pr ON pr.id = d.producto_id

    UNION ALL
    SELECT ci.mascota_id, COALESCE(ci.fecha_realizacion, ci.fecha_programada)::date,
           'CIRUGIA', ci.tipo_cirugia, ci.hallazgos,
           emp.nombres || ' ' || emp.apellidos, ci.id
      FROM cirugia ci
      JOIN empleado emp ON emp.id = ci.veterinario_id

    UNION ALL
    SELECT h.mascota_id, h.fecha_ingreso::date, 'HOSPITALIZACION',
           'Internación', h.motivo,
           emp.nombres || ' ' || emp.apellidos, h.id
      FROM hospitalizacion h
      JOIN empleado emp ON emp.id = h.veterinario_id

    UNION ALL
    SELECT rp.mascota_id, rp.fecha_registro, 'PESO',
           rp.peso_kg || ' kg', rp.observacion, NULL, rp.id
      FROM registro_peso rp
) t;

COMMENT ON VIEW v_historial_clinico IS
    'Línea de tiempo del expediente. Ordenar por (mascota_id, fecha DESC) al '
    'consultarla.';


-- ============================================================================
--  DIAGNÓSTICOS DE UNA CONSULTA
-- ============================================================================
CREATE OR REPLACE VIEW v_consulta_diagnosticos AS
SELECT cd.consulta_id,
       d.codigo,
       d.nombre,
       cd.tipo,
       cd.es_principal,
       cd.notas,
       padre.nombre AS categoria_padre
  FROM consulta_diagnostico cd
  JOIN diagnostico d      ON d.id = cd.diagnostico_id
  LEFT JOIN diagnostico padre ON padre.id = d.padre_id;


-- ============================================================================
--  ÁRBOL DE DIAGNÓSTICOS — recorrido de la jerarquía recursiva
-- ============================================================================
CREATE OR REPLACE VIEW v_diagnostico_arbol AS
WITH RECURSIVE arbol AS (
    SELECT id, padre_id, codigo, nombre, nivel,
           nombre::TEXT                       AS ruta,
           ARRAY[id]                          AS camino
      FROM diagnostico
     WHERE padre_id IS NULL

    UNION ALL

    SELECT d.id, d.padre_id, d.codigo, d.nombre, d.nivel,
           a.ruta || ' › ' || d.nombre,
           a.camino || d.id
      FROM diagnostico d
      JOIN arbol a ON d.padre_id = a.id
)
SELECT id, padre_id, codigo, nombre, nivel, ruta, camino[1] AS raiz_id
  FROM arbol;

COMMENT ON VIEW v_diagnostico_arbol IS
    'Recorre la relación recursiva diagnostico.padre_id y arma la ruta completa '
    '(«Digestivo › Gastritis › Gastritis aguda»). Permite reportes de '
    'morbilidad por rama entera.';


-- ============================================================================
--  INVENTARIO — el stock, que es un derivado
-- ============================================================================
CREATE OR REPLACE VIEW v_stock_actual AS
SELECT p.id                                   AS producto_id,
       p.codigo,
       p.nombre,
       cat.nombre                             AS categoria,
       p.unidad_medida,
       p.precio_venta,
       p.stock_minimo,
       COALESCE(sum(ms.cantidad), 0)          AS stock_actual,
       (p.es_medicamento)                     AS es_medicamento,
       CASE
           WHEN COALESCE(sum(ms.cantidad), 0) <= 0              THEN 'SIN_STOCK'
           WHEN COALESCE(sum(ms.cantidad), 0) <= p.stock_minimo THEN 'BAJO'
           ELSE                                                      'OK'
       END                                    AS estado_stock
  FROM producto p
  JOIN categoria_producto cat ON cat.id = p.categoria_id
  LEFT JOIN movimiento_stock ms ON ms.producto_id = p.id
 WHERE p.activo
 GROUP BY p.id, p.codigo, p.nombre, cat.nombre, p.unidad_medida,
          p.precio_venta, p.stock_minimo, p.es_medicamento;

COMMENT ON VIEW v_stock_actual IS
    'Saldo de inventario derivado del kardex. No existe columna de stock que '
    'alguien pueda editar: el saldo es siempre la suma de los movimientos.';


-- ============================================================================
--  AGENDA
-- ============================================================================
CREATE OR REPLACE VIEW v_agenda AS
SELECT ci.id                                  AS cita_id,
       ci.fecha_hora_inicio,
       ci.fecha_hora_fin,
       ci.duracion_minutos,
       ci.estado,
       ci.motivo,
       m.id                                   AS mascota_id,
       m.nombre                               AS mascota,
       e.nombre                               AS especie,
       cl.id                                  AS cliente_id,
       cl.nombres || ' ' || cl.apellidos      AS tutor,
       cl.telefono                            AS tutor_telefono,
       emp.id                                 AS veterinario_id,
       emp.nombres || ' ' || emp.apellidos    AS veterinario,
       s.nombre                               AS servicio
  FROM cita ci
  JOIN mascota m   ON m.id  = ci.mascota_id
  JOIN especie e   ON e.id  = m.especie_id
  JOIN cliente cl  ON cl.id = m.cliente_id
  JOIN empleado emp ON emp.id = ci.veterinario_id
  LEFT JOIN servicio s ON s.id = ci.servicio_id;

COMMENT ON VIEW v_agenda IS
    'Agenda con el tutor resuelto por JOIN. La cita no almacena cliente_id: '
    'sería una dependencia transitiva vía mascota.';


-- ============================================================================
--  ALERTAS DE MEDICINA PREVENTIVA
-- ============================================================================
CREATE OR REPLACE VIEW v_vacunas_pendientes AS
SELECT av.mascota_id,
       m.nombre                               AS mascota,
       cl.nombres || ' ' || cl.apellidos      AS tutor,
       cl.telefono,
       cl.email,
       cl.acepta_recordatorios,
       v.nombre                               AS vacuna,
       av.fecha_aplicacion                    AS ultima_aplicacion,
       av.fecha_proximo_refuerzo              AS vence,
       (av.fecha_proximo_refuerzo - CURRENT_DATE) AS dias_restantes,
       CASE
           WHEN av.fecha_proximo_refuerzo <  CURRENT_DATE                     THEN 'VENCIDA'
           WHEN av.fecha_proximo_refuerzo <= CURRENT_DATE + INTERVAL '30 days' THEN 'PROXIMA'
           ELSE                                                                    'VIGENTE'
       END                                    AS estado
  FROM aplicacion_vacuna av
  JOIN mascota m  ON m.id  = av.mascota_id
  JOIN cliente cl ON cl.id = m.cliente_id
  JOIN vacuna v   ON v.id  = av.vacuna_id
 WHERE av.fecha_proximo_refuerzo IS NOT NULL
   AND m.activo
   AND m.fecha_fallecimiento IS NULL
   -- Solo la aplicación más reciente de cada par mascota-vacuna: las anteriores
   -- ya fueron reforzadas y no deben aparecer como pendientes.
   AND av.fecha_aplicacion = (
        SELECT max(a2.fecha_aplicacion) FROM aplicacion_vacuna a2
         WHERE a2.mascota_id = av.mascota_id AND a2.vacuna_id = av.vacuna_id);

COMMENT ON VIEW v_vacunas_pendientes IS
    'Panel de refuerzos. Solo considera la última aplicación de cada vacuna por '
    'mascota: las anteriores ya fueron reforzadas.';


-- ============================================================================
--  REPORTES COMERCIALES
-- ============================================================================
CREATE OR REPLACE VIEW v_ingresos_mensuales AS
SELECT date_trunc('month', f.fecha_emision)::date AS mes,
       count(*)                                   AS facturas,
       sum(f.subtotal)                            AS subtotal,
       sum(f.descuento)                           AS descuentos,
       sum(f.impuesto)                            AS impuestos,
       sum(f.total)                               AS total_facturado,
       sum(f.total - f.saldo_pendiente)           AS total_cobrado,
       sum(f.saldo_pendiente)                     AS por_cobrar
  FROM factura f
 WHERE f.estado <> 'anulada'
 GROUP BY 1;


CREATE OR REPLACE VIEW v_servicios_mas_usados AS
SELECT s.id, s.codigo, s.nombre, s.categoria,
       count(*)                     AS veces_facturado,
       sum(fd.cantidad)             AS unidades,
       sum(fd.subtotal)             AS ingresos
  FROM factura_detalle fd
  JOIN servicio s ON s.id = fd.servicio_id
  JOIN factura  f ON f.id = fd.factura_id
 WHERE f.estado <> 'anulada'
 GROUP BY s.id, s.codigo, s.nombre, s.categoria;


CREATE OR REPLACE VIEW v_morbilidad AS
SELECT d.id, d.codigo, d.nombre,
       COALESCE(padre.nombre, d.nombre) AS categoria,
       count(*) FILTER (WHERE cd.tipo = 'DEFINITIVO') AS casos_confirmados,
       count(*)                                       AS casos_totales,
       count(DISTINCT c.mascota_id)                   AS pacientes
  FROM consulta_diagnostico cd
  JOIN diagnostico d ON d.id = cd.diagnostico_id
  JOIN consulta    c ON c.id = cd.consulta_id
  LEFT JOIN diagnostico padre ON padre.id = d.padre_id
 WHERE cd.tipo <> 'DESCARTADO'
 GROUP BY d.id, d.codigo, d.nombre, COALESCE(padre.nombre, d.nombre);

COMMENT ON VIEW v_morbilidad IS
    'Patologías más frecuentes. Este reporte es IMPOSIBLE si el diagnóstico se '
    'guarda como texto libre: «Gastritis» y «gastritis» serían dos filas.';
