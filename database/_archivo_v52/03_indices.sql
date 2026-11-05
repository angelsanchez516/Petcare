-- ============================================================================
--  PETCARE — 03_indices.sql · Índices y restricciones parciales
-- ----------------------------------------------------------------------------
--  Tres grupos, por motivo:
--    1. ÍNDICES ÚNICOS PARCIALES: reglas de negocio que no pueden expresarse
--       como CONSTRAINT porque solo aplican a un subconjunto de filas.
--    2. ÍNDICES SOBRE CLAVES FORÁNEAS: PostgreSQL indexa automáticamente las
--       PRIMARY KEY y las UNIQUE, pero NO las FOREIGN KEY. Sin ellos, cada
--       borrado en la tabla padre hace un recorrido secuencial de la hija para
--       verificar el RESTRICT, y todo JOIN por esa columna es lento.
--    3. ÍNDICES DE CONSULTA: los que sostienen las pantallas reales del
--       sistema (agenda del día, vacunas por vencer, búsqueda por nombre).
--
--  No se indexa "por las dudas": cada índice cuesta espacio y ralentiza las
--  escrituras. Los de aquí responden a una consulta concreta del sistema.
-- ============================================================================

SET client_min_messages = WARNING;

-- ============================================================================
--  1. ÍNDICES ÚNICOS PARCIALES — reglas que un CONSTRAINT no puede expresar
-- ============================================================================

-- Un solo diagnóstico principal por consulta. Un UNIQUE (consulta_id) normal
-- impediría tener más de un diagnóstico; el WHERE lo limita a los principales.
CREATE UNIQUE INDEX uq_consulta_diagnostico_principal
    ON consulta_diagnostico (consulta_id)
    WHERE es_principal;

-- Una sola especialidad principal por profesional.
CREATE UNIQUE INDEX uq_vet_especialidad_principal
    ON veterinario_especialidad (veterinario_id)
    WHERE es_principal;

-- Un solo proveedor preferido por producto.
CREATE UNIQUE INDEX uq_proveedor_preferido
    ON proveedor_producto (producto_id)
    WHERE es_preferido;

-- El correo del tutor es único ENTRE LOS NO NULOS. Muchos clientes no tienen
-- correo, y varios NULL no deben colisionar entre sí.
-- (El dominio dom_email ya valida el formato; esto añade la unicidad.)
CREATE UNIQUE INDEX uq_cliente_email_no_nulo
    ON cliente (lower(email))
    WHERE email IS NOT NULL;

CREATE UNIQUE INDEX uq_empleado_email_no_nulo
    ON empleado (lower(email))
    WHERE email IS NOT NULL;

-- El microchip es único entre las mascotas que lo tienen.
CREATE UNIQUE INDEX uq_mascota_microchip_no_nulo
    ON mascota (microchip)
    WHERE microchip IS NOT NULL;

-- Una mascota no puede estar internada dos veces a la vez.
CREATE UNIQUE INDEX uq_hospitalizacion_activa
    ON hospitalizacion (mascota_id)
    WHERE estado = 'activa';


-- ============================================================================
--  2. ÍNDICES SOBRE CLAVES FORÁNEAS
-- ============================================================================

-- ── Bloque A ───────────────────────────────────────────────────────────────
CREATE INDEX ix_empleado_cargo            ON empleado (cargo_id);
CREATE INDEX ix_vet_esp_especialidad      ON veterinario_especialidad (especialidad_id);
CREATE INDEX ix_rol_permiso_permiso       ON rol_permiso (permiso_id);
CREATE INDEX ix_usuario_rol_rol           ON usuario_rol (rol_id);

-- ── Bloque B ───────────────────────────────────────────────────────────────
CREATE INDEX ix_raza_especie              ON raza (especie_id);
CREATE INDEX ix_mascota_cliente           ON mascota (cliente_id);
CREATE INDEX ix_mascota_especie           ON mascota (especie_id);
-- Compuesto, no simple: la foránea de mascota apunta al par (raza_id,
-- especie_id), así que el índice debe empezar por esas dos columnas para
-- cubrirla. Parcial porque los mestizos tienen raza_id nulo y nunca
-- participan de la verificación.
CREATE INDEX ix_mascota_raza              ON mascota (raza_id, especie_id)
    WHERE raza_id IS NOT NULL;
CREATE INDEX ix_mascota_condicion_cat     ON mascota_condicion (condicion_medica_id);
CREATE INDEX ix_registro_peso_consulta    ON registro_peso (consulta_id);
CREATE INDEX ix_registro_peso_seguimiento ON registro_peso (seguimiento_id);
CREATE INDEX ix_registro_peso_empleado    ON registro_peso (empleado_id);

-- ── Bloque C ───────────────────────────────────────────────────────────────
CREATE INDEX ix_solicitud_especie         ON solicitud_cita (especie_id);
CREATE INDEX ix_cita_mascota              ON cita (mascota_id);
CREATE INDEX ix_cita_veterinario          ON cita (veterinario_id);
CREATE INDEX ix_cita_servicio             ON cita (servicio_id);
CREATE INDEX ix_cita_usuario              ON cita (usuario_registro_id);
CREATE INDEX ix_consulta_mascota          ON consulta (mascota_id);
CREATE INDEX ix_consulta_veterinario      ON consulta (veterinario_id);
CREATE INDEX ix_diagnostico_padre         ON diagnostico (padre_id);
CREATE INDEX ix_consulta_diag_diagnostico ON consulta_diagnostico (diagnostico_id);
CREATE INDEX ix_protocolo_med_medicamento ON protocolo_medicamento (medicamento_id);
CREATE INDEX ix_tratamiento_consulta      ON tratamiento (consulta_id);
CREATE INDEX ix_tratamiento_protocolo     ON tratamiento (protocolo_id);
CREATE INDEX ix_orden_examen_consulta     ON orden_examen (consulta_id);
CREATE INDEX ix_orden_examen_veterinario  ON orden_examen (veterinario_id);
CREATE INDEX ix_orden_det_examen          ON orden_examen_detalle (examen_id);

-- ── Bloque D ───────────────────────────────────────────────────────────────
CREATE INDEX ix_receta_detalle_medicamento ON receta_detalle (medicamento_id);
CREATE INDEX ix_vacuna_especie_especie     ON vacuna_especie (especie_id);
CREATE INDEX ix_aplicacion_vacuna_mascota  ON aplicacion_vacuna (mascota_id);
CREATE INDEX ix_aplicacion_vacuna_vacuna   ON aplicacion_vacuna (vacuna_id);
CREATE INDEX ix_aplicacion_vacuna_vet      ON aplicacion_vacuna (veterinario_id);
CREATE INDEX ix_aplicacion_vacuna_consulta ON aplicacion_vacuna (consulta_id);
CREATE INDEX ix_desparasitacion_mascota    ON desparasitacion (mascota_id);
CREATE INDEX ix_desparasitacion_producto   ON desparasitacion (producto_id);

-- ── Bloque E ───────────────────────────────────────────────────────────────
CREATE INDEX ix_cirugia_mascota           ON cirugia (mascota_id);
CREATE INDEX ix_cirugia_veterinario       ON cirugia (veterinario_id);
CREATE INDEX ix_cirugia_consulta          ON cirugia (consulta_id);
CREATE INDEX ix_hospitalizacion_mascota   ON hospitalizacion (mascota_id);
CREATE INDEX ix_hospitalizacion_vet       ON hospitalizacion (veterinario_id);
CREATE INDEX ix_hosp_hab_habitacion       ON hospitalizacion_habitacion (habitacion_id);
CREATE INDEX ix_seguimiento_hosp          ON seguimiento_hospitalario (hospitalizacion_id);
CREATE INDEX ix_seguimiento_empleado      ON seguimiento_hospitalario (empleado_id);

-- ── Bloque F ───────────────────────────────────────────────────────────────
CREATE INDEX ix_categoria_padre           ON categoria_producto (padre_id);
CREATE INDEX ix_producto_categoria        ON producto (categoria_id);
CREATE INDEX ix_prov_prod_producto        ON proveedor_producto (producto_id);
CREATE INDEX ix_compra_proveedor          ON compra (proveedor_id);
CREATE INDEX ix_compra_detalle_compra     ON compra_detalle (compra_id);
CREATE INDEX ix_compra_detalle_producto   ON compra_detalle (producto_id);
CREATE INDEX ix_movimiento_producto       ON movimiento_stock (producto_id);
CREATE INDEX ix_movimiento_compra_det     ON movimiento_stock (compra_detalle_id);
CREATE INDEX ix_movimiento_factura_det    ON movimiento_stock (factura_detalle_id);
CREATE INDEX ix_movimiento_aplicacion     ON movimiento_stock (aplicacion_vacuna_id);
CREATE INDEX ix_movimiento_desparasitacion ON movimiento_stock (desparasitacion_id);

-- ── Bloque G ───────────────────────────────────────────────────────────────
CREATE INDEX ix_factura_cliente           ON factura (cliente_id);
CREATE INDEX ix_factura_detalle_factura   ON factura_detalle (factura_id);
CREATE INDEX ix_factura_detalle_servicio  ON factura_detalle (servicio_id);
CREATE INDEX ix_factura_detalle_producto  ON factura_detalle (producto_id);
CREATE INDEX ix_factura_detalle_examen    ON factura_detalle (examen_id);
CREATE INDEX ix_factura_detalle_mascota   ON factura_detalle (mascota_id);
CREATE INDEX ix_factura_detalle_consulta  ON factura_detalle (consulta_id);
CREATE INDEX ix_pago_factura              ON pago (factura_id);
CREATE INDEX ix_pago_metodo               ON pago (metodo_pago_id);

-- ── Foráneas de trazabilidad, opcionales ───────────────────────────────────
--  Estas columnas admiten nulo y la mayoría de las filas lo tienen. Se indexan
--  igual porque toda foránea con ON DELETE RESTRICT o SET NULL obliga a
--  recorrer la tabla hija cuando se borra en la padre.
--  Son índices PARCIALES: la verificación busca «columna = valor», condición
--  que ningún nulo satisface, así que excluirlos no pierde nada y reduce
--  mucho el tamaño del índice.
CREATE INDEX ix_cirugia_anestesista       ON cirugia (anestesista_id)
    WHERE anestesista_id IS NOT NULL;
CREATE INDEX ix_hospitalizacion_consulta  ON hospitalizacion (consulta_id)
    WHERE consulta_id IS NOT NULL;
CREATE INDEX ix_hospitalizacion_cirugia   ON hospitalizacion (cirugia_id)
    WHERE cirugia_id IS NOT NULL;
CREATE INDEX ix_desparasitacion_vet       ON desparasitacion (veterinario_id)
    WHERE veterinario_id IS NOT NULL;
CREATE INDEX ix_desparasitacion_consulta  ON desparasitacion (consulta_id)
    WHERE consulta_id IS NOT NULL;
CREATE INDEX ix_compra_empleado           ON compra (empleado_id)
    WHERE empleado_id IS NOT NULL;
CREATE INDEX ix_movimiento_empleado       ON movimiento_stock (empleado_id)
    WHERE empleado_id IS NOT NULL;
CREATE INDEX ix_factura_usuario_emisor    ON factura (usuario_emisor_id)
    WHERE usuario_emisor_id IS NOT NULL;
CREATE INDEX ix_pago_usuario              ON pago (usuario_id)
    WHERE usuario_id IS NOT NULL;


-- ============================================================================
--  3. ÍNDICES DE CONSULTA — sostienen pantallas concretas del sistema
-- ============================================================================

-- Agenda del día: «citas de este veterinario, hoy, ordenadas por hora».
-- El orden de las columnas importa: primero la que se filtra por igualdad.
CREATE INDEX ix_cita_agenda
    ON cita (veterinario_id, fecha_hora_inicio)
    WHERE estado IN ('programada','confirmada');

-- Vista de agenda general por fecha.
CREATE INDEX ix_cita_fecha ON cita (fecha_hora_inicio);

-- Historial clínico de la mascota, en orden cronológico inverso.
CREATE INDEX ix_consulta_historial ON consulta (mascota_id, fecha_hora DESC);

-- «Peso actual»: la última medición de cada mascota. DESC porque siempre se
-- pide la más reciente.
CREATE INDEX ix_registro_peso_ultimo ON registro_peso (mascota_id, fecha_registro DESC);

-- Panel de vacunas por vencer. El índice parcial excluye las que no llevan
-- refuerzo, que son las que nunca aparecen en ese panel.
CREATE INDEX ix_aplicacion_vacuna_refuerzo
    ON aplicacion_vacuna (fecha_proximo_refuerzo)
    WHERE fecha_proximo_refuerzo IS NOT NULL;

-- Desparasitaciones por vencer, misma lógica.
CREATE INDEX ix_desparasitacion_proxima
    ON desparasitacion (proxima_aplicacion)
    WHERE proxima_aplicacion IS NOT NULL;

-- Facturas impagas: el panel de cobranzas solo mira estas.
CREATE INDEX ix_factura_pendientes
    ON factura (cliente_id, fecha_emision)
    WHERE estado IN ('pendiente','parcial');

-- Reporte de ingresos por período.
CREATE INDEX ix_factura_fecha ON factura (fecha_emision) WHERE estado <> 'anulada';

-- Cálculo del stock: SUM(cantidad) agrupado por producto.
CREATE INDEX ix_movimiento_saldo ON movimiento_stock (producto_id, fecha_hora);

-- Bandeja de solicitudes web sin atender.
CREATE INDEX ix_solicitud_pendientes
    ON solicitud_cita (creado_en)
    WHERE estado IN ('nueva','contactada');

-- Internaciones en curso, para el tablero de hospitalización.
CREATE INDEX ix_hospitalizacion_activas
    ON hospitalizacion (fecha_ingreso)
    WHERE estado = 'activa';


-- ============================================================================
--  4. BÚSQUEDA POR TEXTO
-- ----------------------------------------------------------------------------
--  La recepción busca «max», «MAX» o «máx» y espera encontrar a Max. Los
--  índices trigram con unaccent resuelven las tres variantes y además toleran
--  errores de tipeo, que un LIKE con índice B-tree no puede.
-- ============================================================================

-- unaccent no es IMMUTABLE por defecto (depende de un diccionario), así que no
-- puede usarse directamente en un índice. Se envuelve en una función propia
-- marcada IMMUTABLE, que es la práctica habitual para este caso.
CREATE OR REPLACE FUNCTION f_normalizar(txt TEXT)
RETURNS TEXT
LANGUAGE sql IMMUTABLE STRICT PARALLEL SAFE AS
$$ SELECT lower(public.unaccent('public.unaccent', txt)) $$;

COMMENT ON FUNCTION f_normalizar IS
    'Pasa a minúsculas y quita tildes. Envuelve unaccent para poder indexarla: '
    'unaccent es STABLE y los índices exigen IMMUTABLE.';

CREATE INDEX ix_mascota_nombre_busqueda
    ON mascota USING gin (f_normalizar(nombre) gin_trgm_ops);

CREATE INDEX ix_cliente_nombre_busqueda
    ON cliente USING gin (f_normalizar(nombres || ' ' || apellidos) gin_trgm_ops);

CREATE INDEX ix_producto_nombre_busqueda
    ON producto USING gin (f_normalizar(nombre) gin_trgm_ops);

CREATE INDEX ix_diagnostico_nombre_busqueda
    ON diagnostico USING gin (f_normalizar(nombre) gin_trgm_ops);
