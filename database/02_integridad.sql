-- ============================================================================
--  PETCARE — 02_integridad.sql · Claves foráneas
-- ----------------------------------------------------------------------------
--  39 claves foráneas, agrupadas POR POLÍTICA DE BORRADO en vez de por tabla.
--
--  EL CRITERIO, EN UNA FRASE
--    CASCADE  solo cuando la fila hija NO tiene identidad fuera del padre
--             (una línea de factura es una PARTE de la factura, no un ente).
--    RESTRICT en todo lo demás, y sobre todo en el historial clínico: borrar
--             una mascota debe FALLAR, no llevarse su expediente por delante.
--    SET NULL solo en referencias de trazabilidad, donde perder el origen no
--             invalida el hecho registrado.
--
--  Las bajas son LÓGICAS (columna activo). RESTRICT es la red que convierte un
--  DELETE accidental en un error en lugar de una pérdida de datos.
-- ============================================================================

SET client_min_messages = WARNING;

-- ----------------------------------------------------------------------------
--  A. RESTRICT — EL HISTORIAL CLÍNICO NO SE BORRA
-- ----------------------------------------------------------------------------
ALTER TABLE mascota_condicion ADD CONSTRAINT fk_mascota_condicion_mascota
    FOREIGN KEY (mascota_id) REFERENCES mascota (id) ON DELETE RESTRICT;
ALTER TABLE registro_peso ADD CONSTRAINT fk_registro_peso_mascota
    FOREIGN KEY (mascota_id) REFERENCES mascota (id) ON DELETE RESTRICT;
ALTER TABLE cita ADD CONSTRAINT fk_cita_mascota
    FOREIGN KEY (mascota_id) REFERENCES mascota (id) ON DELETE RESTRICT;
ALTER TABLE consulta ADD CONSTRAINT fk_consulta_mascota
    FOREIGN KEY (mascota_id) REFERENCES mascota (id) ON DELETE RESTRICT;
ALTER TABLE aplicacion_vacuna ADD CONSTRAINT fk_aplicacion_mascota
    FOREIGN KEY (mascota_id) REFERENCES mascota (id) ON DELETE RESTRICT;

-- El tutor: no se elimina si tiene mascotas o facturas.
ALTER TABLE mascota ADD CONSTRAINT fk_mascota_cliente
    FOREIGN KEY (cliente_id) REFERENCES cliente (id) ON DELETE RESTRICT;
ALTER TABLE factura ADD CONSTRAINT fk_factura_cliente
    FOREIGN KEY (cliente_id) REFERENCES cliente (id) ON DELETE RESTRICT;

-- El profesional: su firma en un acto médico es permanente.
ALTER TABLE cita ADD CONSTRAINT fk_cita_veterinario
    FOREIGN KEY (veterinario_id) REFERENCES veterinario (id) ON DELETE RESTRICT;
ALTER TABLE consulta ADD CONSTRAINT fk_consulta_veterinario
    FOREIGN KEY (veterinario_id) REFERENCES veterinario (id) ON DELETE RESTRICT;
ALTER TABLE aplicacion_vacuna ADD CONSTRAINT fk_aplicacion_veterinario
    FOREIGN KEY (veterinario_id) REFERENCES veterinario (id) ON DELETE RESTRICT;


-- ----------------------------------------------------------------------------
--  B. RESTRICT — LOS CATÁLOGOS EN USO NO SE BORRAN
-- ----------------------------------------------------------------------------
--  Un catálogo referenciado se da de baja con activo = FALSE, nunca con DELETE:
--  eliminarlo dejaría sin sentido los registros históricos que lo mencionan.
-- ----------------------------------------------------------------------------
ALTER TABLE usuario ADD CONSTRAINT fk_usuario_rol
    FOREIGN KEY (rol_id) REFERENCES rol (id) ON DELETE RESTRICT;
ALTER TABLE veterinario_especialidad ADD CONSTRAINT fk_vet_esp_especialidad
    FOREIGN KEY (especialidad_id) REFERENCES especialidad (id) ON DELETE RESTRICT;
ALTER TABLE raza ADD CONSTRAINT fk_raza_especie
    FOREIGN KEY (especie_id) REFERENCES especie (id) ON DELETE RESTRICT;
ALTER TABLE mascota ADD CONSTRAINT fk_mascota_especie
    FOREIGN KEY (especie_id) REFERENCES especie (id) ON DELETE RESTRICT;

-- ── CLAVE FORÁNEA COMPUESTA ────────────────────────────────────────────────
--  Esta es la restricción que impide el estado imposible «felino de raza
--  labrador». Dos foráneas simples e independientes a especie y a raza serían
--  válidas por separado y absurdas en combinación.
--  Con MATCH SIMPLE (el comportamiento por defecto) la restricción no se aplica
--  si alguna columna es nula: justo lo que se quiere, porque un mestizo tiene
--  raza_id nulo y debe pasar sin problema conservando su especie.
ALTER TABLE mascota ADD CONSTRAINT fk_mascota_raza_especie
    FOREIGN KEY (raza_id, especie_id) REFERENCES raza (id, especie_id) ON DELETE RESTRICT;

ALTER TABLE mascota_condicion ADD CONSTRAINT fk_mascota_condicion_catalogo
    FOREIGN KEY (condicion_medica_id) REFERENCES condicion_medica (id) ON DELETE RESTRICT;
ALTER TABLE cita ADD CONSTRAINT fk_cita_servicio
    FOREIGN KEY (servicio_id) REFERENCES servicio (id) ON DELETE RESTRICT;
ALTER TABLE consulta_diagnostico ADD CONSTRAINT fk_consulta_diag_catalogo
    FOREIGN KEY (diagnostico_id) REFERENCES diagnostico (id) ON DELETE RESTRICT;
ALTER TABLE receta_detalle ADD CONSTRAINT fk_receta_detalle_medicamento
    FOREIGN KEY (medicamento_id) REFERENCES medicamento (id) ON DELETE RESTRICT;
ALTER TABLE vacuna_especie ADD CONSTRAINT fk_vacuna_especie_especie
    FOREIGN KEY (especie_id) REFERENCES especie (id) ON DELETE RESTRICT;
ALTER TABLE aplicacion_vacuna ADD CONSTRAINT fk_aplicacion_vacuna
    FOREIGN KEY (vacuna_id) REFERENCES vacuna (id) ON DELETE RESTRICT;
ALTER TABLE factura_detalle ADD CONSTRAINT fk_factura_detalle_servicio
    FOREIGN KEY (servicio_id) REFERENCES servicio (id) ON DELETE RESTRICT;
ALTER TABLE factura_detalle ADD CONSTRAINT fk_factura_detalle_medicamento
    FOREIGN KEY (medicamento_id) REFERENCES medicamento (id) ON DELETE RESTRICT;
ALTER TABLE pago ADD CONSTRAINT fk_pago_metodo
    FOREIGN KEY (metodo_pago_id) REFERENCES metodo_pago (id) ON DELETE RESTRICT;
ALTER TABLE pago ADD CONSTRAINT fk_pago_factura
    FOREIGN KEY (factura_id) REFERENCES factura (id) ON DELETE RESTRICT;


-- ----------------------------------------------------------------------------
--  C. CASCADE — COMPOSICIÓN
-- ----------------------------------------------------------------------------
--  Solo aquí. En todos estos casos la fila hija carece de identidad propia
--  fuera del padre: una línea de receta no es un ente autónomo, es una PARTE.
-- ----------------------------------------------------------------------------
ALTER TABLE receta_detalle ADD CONSTRAINT fk_receta_detalle_receta
    FOREIGN KEY (receta_id) REFERENCES receta (id) ON DELETE CASCADE;
ALTER TABLE factura_detalle ADD CONSTRAINT fk_factura_detalle_factura
    FOREIGN KEY (factura_id) REFERENCES factura (id) ON DELETE CASCADE;
ALTER TABLE consulta_diagnostico ADD CONSTRAINT fk_consulta_diag_consulta
    FOREIGN KEY (consulta_id) REFERENCES consulta (id) ON DELETE CASCADE;
ALTER TABLE tratamiento ADD CONSTRAINT fk_tratamiento_consulta
    FOREIGN KEY (consulta_id) REFERENCES consulta (id) ON DELETE CASCADE;
ALTER TABLE receta ADD CONSTRAINT fk_receta_consulta
    FOREIGN KEY (consulta_id) REFERENCES consulta (id) ON DELETE CASCADE;
ALTER TABLE vacuna_especie ADD CONSTRAINT fk_vacuna_especie_vacuna
    FOREIGN KEY (vacuna_id) REFERENCES vacuna (id) ON DELETE CASCADE;
ALTER TABLE veterinario_especialidad ADD CONSTRAINT fk_vet_esp_veterinario
    FOREIGN KEY (veterinario_id) REFERENCES veterinario (id) ON DELETE CASCADE;


-- ----------------------------------------------------------------------------
--  D. SET NULL — TRAZABILIDAD Y ORÍGENES OPCIONALES
-- ----------------------------------------------------------------------------
--  Perder el origen no invalida el hecho registrado: un peso tomado sigue
--  siendo un peso válido aunque se borre la consulta que lo originó.
-- ----------------------------------------------------------------------------
ALTER TABLE veterinario ADD CONSTRAINT fk_veterinario_usuario
    FOREIGN KEY (usuario_id) REFERENCES usuario (id) ON DELETE SET NULL;
ALTER TABLE registro_peso ADD CONSTRAINT fk_registro_peso_consulta
    FOREIGN KEY (consulta_id) REFERENCES consulta (id) ON DELETE SET NULL;
ALTER TABLE consulta ADD CONSTRAINT fk_consulta_cita
    FOREIGN KEY (cita_id) REFERENCES cita (id) ON DELETE SET NULL;
ALTER TABLE aplicacion_vacuna ADD CONSTRAINT fk_aplicacion_consulta
    FOREIGN KEY (consulta_id) REFERENCES consulta (id) ON DELETE SET NULL;
ALTER TABLE factura_detalle ADD CONSTRAINT fk_factura_detalle_mascota
    FOREIGN KEY (mascota_id) REFERENCES mascota (id) ON DELETE SET NULL;
ALTER TABLE solicitud_cita ADD CONSTRAINT fk_solicitud_cita
    FOREIGN KEY (cita_id) REFERENCES cita (id) ON DELETE SET NULL;
ALTER TABLE solicitud_cita ADD CONSTRAINT fk_solicitud_especie
    FOREIGN KEY (especie_id) REFERENCES especie (id) ON DELETE SET NULL;
