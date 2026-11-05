-- ============================================================================
--  PETCARE — 03_indices.sql · Índices
-- ----------------------------------------------------------------------------
--  Tres grupos, por motivo:
--    1. ÚNICOS PARCIALES: reglas de negocio que no pueden expresarse como
--       CONSTRAINT porque solo aplican a un subconjunto de filas.
--    2. SOBRE CLAVES FORÁNEAS: PostgreSQL indexa automáticamente las PRIMARY
--       KEY y las UNIQUE, pero NO las FOREIGN KEY. Sin ellos, cada borrado en
--       la tabla padre recorre la hija entera para verificar el RESTRICT.
--    3. DE CONSULTA: los que sostienen las pantallas reales del sistema.
--
--  No se indexa «por las dudas»: cada índice cuesta espacio y ralentiza las
--  escrituras. Los de aquí responden a una consulta concreta.
-- ============================================================================

SET client_min_messages = WARNING;

-- ----------------------------------------------------------------------------
--  1. ÚNICOS PARCIALES
-- ----------------------------------------------------------------------------

-- Un solo diagnóstico principal por consulta. Un UNIQUE (consulta_id) normal
-- impediría tener más de un diagnóstico; el WHERE lo limita a los principales.
CREATE UNIQUE INDEX uq_consulta_diag_principal
    ON consulta_diagnostico (consulta_id) WHERE es_principal;

-- Una sola especialidad principal por profesional.
CREATE UNIQUE INDEX uq_vet_especialidad_principal
    ON veterinario_especialidad (veterinario_id) WHERE es_principal;

-- El correo es único ENTRE LOS NO NULOS: muchos clientes no tienen correo y
-- varios nulos no deben colisionar entre sí.
CREATE UNIQUE INDEX uq_cliente_email ON cliente (lower(email)) WHERE email IS NOT NULL;
CREATE UNIQUE INDEX uq_veterinario_email ON veterinario (lower(email)) WHERE email IS NOT NULL;

-- El microchip es único entre las mascotas que lo tienen.
CREATE UNIQUE INDEX uq_mascota_microchip ON mascota (microchip) WHERE microchip IS NOT NULL;


-- ----------------------------------------------------------------------------
--  2. SOBRE CLAVES FORÁNEAS
-- ----------------------------------------------------------------------------
CREATE INDEX ix_usuario_rol              ON usuario (rol_id);
CREATE INDEX ix_vet_esp_especialidad     ON veterinario_especialidad (especialidad_id);
CREATE INDEX ix_raza_especie             ON raza (especie_id);
CREATE INDEX ix_mascota_cliente          ON mascota (cliente_id);
CREATE INDEX ix_mascota_especie          ON mascota (especie_id);
-- Compuesto porque la foránea apunta al par (raza_id, especie_id); parcial
-- porque los mestizos tienen raza_id nulo y nunca participan de la verificación.
CREATE INDEX ix_mascota_raza             ON mascota (raza_id, especie_id) WHERE raza_id IS NOT NULL;
CREATE INDEX ix_mascota_cond_catalogo    ON mascota_condicion (condicion_medica_id);
CREATE INDEX ix_registro_peso_consulta   ON registro_peso (consulta_id) WHERE consulta_id IS NOT NULL;
CREATE INDEX ix_cita_mascota             ON cita (mascota_id);
CREATE INDEX ix_cita_veterinario         ON cita (veterinario_id);
CREATE INDEX ix_cita_servicio            ON cita (servicio_id) WHERE servicio_id IS NOT NULL;
CREATE INDEX ix_consulta_mascota         ON consulta (mascota_id);
CREATE INDEX ix_consulta_veterinario     ON consulta (veterinario_id);
CREATE INDEX ix_consulta_diag_catalogo   ON consulta_diagnostico (diagnostico_id);
CREATE INDEX ix_tratamiento_consulta     ON tratamiento (consulta_id);
CREATE INDEX ix_receta_detalle_med       ON receta_detalle (medicamento_id);
CREATE INDEX ix_vacuna_especie_especie   ON vacuna_especie (especie_id);
CREATE INDEX ix_aplicacion_mascota       ON aplicacion_vacuna (mascota_id);
CREATE INDEX ix_aplicacion_vacuna        ON aplicacion_vacuna (vacuna_id);
CREATE INDEX ix_aplicacion_veterinario   ON aplicacion_vacuna (veterinario_id);
CREATE INDEX ix_aplicacion_consulta      ON aplicacion_vacuna (consulta_id) WHERE consulta_id IS NOT NULL;
CREATE INDEX ix_factura_cliente          ON factura (cliente_id);
CREATE INDEX ix_factura_detalle_factura  ON factura_detalle (factura_id);
CREATE INDEX ix_factura_detalle_servicio ON factura_detalle (servicio_id) WHERE servicio_id IS NOT NULL;
CREATE INDEX ix_factura_detalle_med      ON factura_detalle (medicamento_id) WHERE medicamento_id IS NOT NULL;
CREATE INDEX ix_factura_detalle_mascota  ON factura_detalle (mascota_id) WHERE mascota_id IS NOT NULL;
CREATE INDEX ix_pago_factura             ON pago (factura_id);
CREATE INDEX ix_pago_metodo              ON pago (metodo_pago_id);
CREATE INDEX ix_solicitud_especie        ON solicitud_cita (especie_id) WHERE especie_id IS NOT NULL;


-- ----------------------------------------------------------------------------
--  3. DE CONSULTA — sostienen pantallas concretas
-- ----------------------------------------------------------------------------

-- Agenda del día: «citas de este veterinario, hoy, ordenadas por hora».
-- El orden de las columnas importa: primero la que se filtra por igualdad.
CREATE INDEX ix_cita_agenda ON cita (veterinario_id, fecha_hora_inicio)
    WHERE estado IN ('programada','confirmada');

CREATE INDEX ix_cita_fecha ON cita (fecha_hora_inicio);

-- Historial clínico de la mascota, en orden cronológico inverso.
CREATE INDEX ix_consulta_historial ON consulta (mascota_id, fecha_hora DESC);

-- «Peso actual»: la última medición de cada mascota.
CREATE INDEX ix_registro_peso_ultimo ON registro_peso (mascota_id, fecha_registro DESC);

-- Panel de refuerzos. El índice parcial excluye las vacunas sin refuerzo, que
-- nunca aparecen en ese panel.
CREATE INDEX ix_aplicacion_refuerzo ON aplicacion_vacuna (fecha_proximo_refuerzo)
    WHERE fecha_proximo_refuerzo IS NOT NULL;

-- Panel de cobranzas: solo mira las facturas impagas.
CREATE INDEX ix_factura_pendientes ON factura (cliente_id, fecha_emision)
    WHERE estado IN ('pendiente','parcial');

-- Reporte de ingresos por período.
CREATE INDEX ix_factura_fecha ON factura (fecha_emision) WHERE estado <> 'anulada';

-- Bandeja de solicitudes web sin atender.
CREATE INDEX ix_solicitud_pendientes ON solicitud_cita (creado_en)
    WHERE estado IN ('nueva','contactada');

-- Alerta de stock bajo.
CREATE INDEX ix_medicamento_stock ON medicamento (stock) WHERE activo;


-- ----------------------------------------------------------------------------
--  4. BÚSQUEDA POR TEXTO
-- ----------------------------------------------------------------------------
--  La recepción busca «max», «MAX» o «máx» y espera encontrar a Max. Los
--  índices trigram con unaccent resuelven las tres variantes y además toleran
--  errores de tipeo, cosa que un LIKE sobre un índice B-tree no puede.
--
--  unaccent no es IMMUTABLE por sí sola (depende de un diccionario), así que
--  se envuelve en una función propia marcada IMMUTABLE. Es la práctica
--  habitual para poder indexarla.
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION f_normalizar(txt TEXT)
RETURNS TEXT LANGUAGE sql IMMUTABLE STRICT PARALLEL SAFE AS
$$ SELECT lower(public.unaccent('public.unaccent', txt)) $$;

CREATE INDEX ix_mascota_busqueda ON mascota USING gin (f_normalizar(nombre) gin_trgm_ops);
CREATE INDEX ix_cliente_busqueda ON cliente
    USING gin (f_normalizar(nombres || ' ' || apellidos) gin_trgm_ops);
CREATE INDEX ix_medicamento_busqueda ON medicamento USING gin (f_normalizar(nombre) gin_trgm_ops);
CREATE INDEX ix_diagnostico_busqueda ON diagnostico USING gin (f_normalizar(nombre) gin_trgm_ops);
