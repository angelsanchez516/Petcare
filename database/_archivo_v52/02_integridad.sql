-- ============================================================================
--  PETCARE — 02_integridad.sql · Integridad referencial
-- ----------------------------------------------------------------------------
--  90 claves foráneas, agrupadas POR POLÍTICA DE BORRADO en lugar de por tabla.
--  Esa agrupación es deliberada: el enunciado exige no usar cascadas de forma
--  indiscriminada y proteger el historial clínico, y así la decisión queda
--  auditable de un vistazo en vez de dispersa entre 52 CREATE TABLE.
--
--  EL CRITERIO, EN UNA FRASE
--    CASCADE  únicamente cuando la fila hija NO tiene identidad fuera del padre
--             (composición: una línea de factura no existe sin su factura).
--    RESTRICT en todo lo demás, y muy especialmente en el historial clínico:
--             borrar una mascota debe fallar, no llevarse su expediente.
--    SET NULL solo en referencias de trazabilidad, donde perder el «quién»
--             no invalida el hecho registrado.
--
--  Las bajas son LÓGICAS (columna activo). RESTRICT es la red de seguridad que
--  convierte un DELETE accidental en un error en vez de en una pérdida de datos.
-- ============================================================================

SET client_min_messages = WARNING;


-- ============================================================================
--  A. RESTRICT — EL HISTORIAL CLÍNICO NO SE BORRA
-- ----------------------------------------------------------------------------
--  Cualquier intento de eliminar una mascota, un tutor o un profesional con
--  actividad registrada falla. Es el corazón de la protección del expediente.
-- ============================================================================

-- ── La mascota está referenciada por todo su historial ──────────────────────
ALTER TABLE mascota_condicion   ADD CONSTRAINT fk_mascota_condicion_mascota
    FOREIGN KEY (mascota_id) REFERENCES mascota (id) ON DELETE RESTRICT;
ALTER TABLE registro_peso       ADD CONSTRAINT fk_registro_peso_mascota
    FOREIGN KEY (mascota_id) REFERENCES mascota (id) ON DELETE RESTRICT;
ALTER TABLE cita                ADD CONSTRAINT fk_cita_mascota
    FOREIGN KEY (mascota_id) REFERENCES mascota (id) ON DELETE RESTRICT;
ALTER TABLE consulta            ADD CONSTRAINT fk_consulta_mascota
    FOREIGN KEY (mascota_id) REFERENCES mascota (id) ON DELETE RESTRICT;
ALTER TABLE aplicacion_vacuna   ADD CONSTRAINT fk_aplicacion_vacuna_mascota
    FOREIGN KEY (mascota_id) REFERENCES mascota (id) ON DELETE RESTRICT;
ALTER TABLE desparasitacion     ADD CONSTRAINT fk_desparasitacion_mascota
    FOREIGN KEY (mascota_id) REFERENCES mascota (id) ON DELETE RESTRICT;
ALTER TABLE cirugia             ADD CONSTRAINT fk_cirugia_mascota
    FOREIGN KEY (mascota_id) REFERENCES mascota (id) ON DELETE RESTRICT;
ALTER TABLE hospitalizacion     ADD CONSTRAINT fk_hospitalizacion_mascota
    FOREIGN KEY (mascota_id) REFERENCES mascota (id) ON DELETE RESTRICT;

-- ── El tutor: no se elimina si tiene mascotas o facturas ────────────────────
ALTER TABLE mascota ADD CONSTRAINT fk_mascota_cliente
    FOREIGN KEY (cliente_id) REFERENCES cliente (id) ON DELETE RESTRICT;
ALTER TABLE factura ADD CONSTRAINT fk_factura_cliente
    FOREIGN KEY (cliente_id) REFERENCES cliente (id) ON DELETE RESTRICT;

-- ── El profesional: su firma en un acto médico es permanente ────────────────
ALTER TABLE cita              ADD CONSTRAINT fk_cita_veterinario
    FOREIGN KEY (veterinario_id) REFERENCES veterinario (empleado_id) ON DELETE RESTRICT;
ALTER TABLE consulta          ADD CONSTRAINT fk_consulta_veterinario
    FOREIGN KEY (veterinario_id) REFERENCES veterinario (empleado_id) ON DELETE RESTRICT;
ALTER TABLE aplicacion_vacuna ADD CONSTRAINT fk_aplicacion_vacuna_veterinario
    FOREIGN KEY (veterinario_id) REFERENCES veterinario (empleado_id) ON DELETE RESTRICT;
ALTER TABLE orden_examen      ADD CONSTRAINT fk_orden_examen_veterinario
    FOREIGN KEY (veterinario_id) REFERENCES veterinario (empleado_id) ON DELETE RESTRICT;
ALTER TABLE cirugia           ADD CONSTRAINT fk_cirugia_veterinario
    FOREIGN KEY (veterinario_id) REFERENCES veterinario (empleado_id) ON DELETE RESTRICT;
ALTER TABLE hospitalizacion   ADD CONSTRAINT fk_hospitalizacion_veterinario
    FOREIGN KEY (veterinario_id) REFERENCES veterinario (empleado_id) ON DELETE RESTRICT;
ALTER TABLE seguimiento_hospitalario ADD CONSTRAINT fk_seguimiento_empleado
    FOREIGN KEY (empleado_id) REFERENCES empleado (id) ON DELETE RESTRICT;

-- ── La consulta origina documentos que la referencian ───────────────────────
ALTER TABLE orden_examen ADD CONSTRAINT fk_orden_examen_consulta
    FOREIGN KEY (consulta_id) REFERENCES consulta (id) ON DELETE RESTRICT;


-- ============================================================================
--  B. RESTRICT — LOS CATÁLOGOS EN USO NO SE BORRAN
-- ----------------------------------------------------------------------------
--  Un catálogo referenciado se da de baja con activo = FALSE, nunca con DELETE:
--  eliminarlo dejaría sin sentido los registros históricos que lo mencionan.
-- ============================================================================

ALTER TABLE empleado ADD CONSTRAINT fk_empleado_cargo
    FOREIGN KEY (cargo_id) REFERENCES cargo (id) ON DELETE RESTRICT;
ALTER TABLE veterinario_especialidad ADD CONSTRAINT fk_vet_esp_especialidad
    FOREIGN KEY (especialidad_id) REFERENCES especialidad (id) ON DELETE RESTRICT;
ALTER TABLE usuario_rol ADD CONSTRAINT fk_usuario_rol_rol
    FOREIGN KEY (rol_id) REFERENCES rol (id) ON DELETE RESTRICT;

ALTER TABLE raza ADD CONSTRAINT fk_raza_especie
    FOREIGN KEY (especie_id) REFERENCES especie (id) ON DELETE RESTRICT;
ALTER TABLE mascota ADD CONSTRAINT fk_mascota_especie
    FOREIGN KEY (especie_id) REFERENCES especie (id) ON DELETE RESTRICT;

-- ── CLAVE FORÁNEA COMPUESTA ────────────────────────────────────────────────
--  Esta es la restricción que impide el estado imposible «felino de raza
--  labrador». Dos foráneas simples e independientes a especie y a raza serían
--  válidas por separado y absurdas en combinación.
--
--  Con MATCH SIMPLE (el comportamiento por defecto) la restricción NO se aplica
--  si alguna columna es NULL. Eso es exactamente lo que se quiere: un mestizo
--  con raza_id NULL pasa sin problema y conserva su especie.
ALTER TABLE mascota ADD CONSTRAINT fk_mascota_raza_especie
    FOREIGN KEY (raza_id, especie_id) REFERENCES raza (id, especie_id) ON DELETE RESTRICT;

ALTER TABLE mascota_condicion ADD CONSTRAINT fk_mascota_condicion_catalogo
    FOREIGN KEY (condicion_medica_id) REFERENCES condicion_medica (id) ON DELETE RESTRICT;
ALTER TABLE cita ADD CONSTRAINT fk_cita_servicio
    FOREIGN KEY (servicio_id) REFERENCES servicio (id) ON DELETE RESTRICT;
ALTER TABLE consulta_diagnostico ADD CONSTRAINT fk_consulta_diagnostico_catalogo
    FOREIGN KEY (diagnostico_id) REFERENCES diagnostico (id) ON DELETE RESTRICT;
ALTER TABLE protocolo_medicamento ADD CONSTRAINT fk_protocolo_med_medicamento
    FOREIGN KEY (medicamento_id) REFERENCES medicamento (producto_id) ON DELETE RESTRICT;
ALTER TABLE orden_examen_detalle ADD CONSTRAINT fk_orden_det_examen
    FOREIGN KEY (examen_id) REFERENCES examen (id) ON DELETE RESTRICT;
ALTER TABLE receta_detalle ADD CONSTRAINT fk_receta_detalle_medicamento
    FOREIGN KEY (medicamento_id) REFERENCES medicamento (producto_id) ON DELETE RESTRICT;
ALTER TABLE vacuna_especie ADD CONSTRAINT fk_vacuna_especie_especie
    FOREIGN KEY (especie_id) REFERENCES especie (id) ON DELETE RESTRICT;
ALTER TABLE aplicacion_vacuna ADD CONSTRAINT fk_aplicacion_vacuna_vacuna
    FOREIGN KEY (vacuna_id) REFERENCES vacuna (id) ON DELETE RESTRICT;
ALTER TABLE desparasitacion ADD CONSTRAINT fk_desparasitacion_producto
    FOREIGN KEY (producto_id) REFERENCES producto (id) ON DELETE RESTRICT;
ALTER TABLE hospitalizacion_habitacion ADD CONSTRAINT fk_hosp_hab_habitacion
    FOREIGN KEY (habitacion_id) REFERENCES habitacion (id) ON DELETE RESTRICT;
ALTER TABLE producto ADD CONSTRAINT fk_producto_categoria
    FOREIGN KEY (categoria_id) REFERENCES categoria_producto (id) ON DELETE RESTRICT;
ALTER TABLE proveedor_producto ADD CONSTRAINT fk_proveedor_producto_producto
    FOREIGN KEY (producto_id) REFERENCES producto (id) ON DELETE RESTRICT;
ALTER TABLE compra ADD CONSTRAINT fk_compra_proveedor
    FOREIGN KEY (proveedor_id) REFERENCES proveedor (id) ON DELETE RESTRICT;
ALTER TABLE compra_detalle ADD CONSTRAINT fk_compra_detalle_producto
    FOREIGN KEY (producto_id) REFERENCES producto (id) ON DELETE RESTRICT;
ALTER TABLE movimiento_stock ADD CONSTRAINT fk_movimiento_producto
    FOREIGN KEY (producto_id) REFERENCES producto (id) ON DELETE RESTRICT;
ALTER TABLE factura_detalle ADD CONSTRAINT fk_factura_detalle_servicio
    FOREIGN KEY (servicio_id) REFERENCES servicio (id) ON DELETE RESTRICT;
ALTER TABLE factura_detalle ADD CONSTRAINT fk_factura_detalle_producto
    FOREIGN KEY (producto_id) REFERENCES producto (id) ON DELETE RESTRICT;
ALTER TABLE factura_detalle ADD CONSTRAINT fk_factura_detalle_examen
    FOREIGN KEY (examen_id) REFERENCES examen (id) ON DELETE RESTRICT;
ALTER TABLE pago ADD CONSTRAINT fk_pago_metodo
    FOREIGN KEY (metodo_pago_id) REFERENCES metodo_pago (id) ON DELETE RESTRICT;
ALTER TABLE pago ADD CONSTRAINT fk_pago_factura
    FOREIGN KEY (factura_id) REFERENCES factura (id) ON DELETE RESTRICT;


-- ============================================================================
--  C. RESTRICT — JERARQUÍAS RECURSIVAS
-- ----------------------------------------------------------------------------
--  Borrar un nodo con hijos dejaría un árbol roto. Con RESTRICT hay que
--  reasignar los hijos primero, que es la operación correcta.
-- ============================================================================

ALTER TABLE diagnostico ADD CONSTRAINT fk_diagnostico_padre
    FOREIGN KEY (padre_id) REFERENCES diagnostico (id) ON DELETE RESTRICT;
ALTER TABLE categoria_producto ADD CONSTRAINT fk_categoria_padre
    FOREIGN KEY (padre_id) REFERENCES categoria_producto (id) ON DELETE RESTRICT;


-- ============================================================================
--  D. CASCADE — COMPOSICIÓN Y HERENCIA
-- ----------------------------------------------------------------------------
--  Solo aquí. En todos estos casos la fila hija carece de identidad propia
--  fuera del padre: una línea de receta no es un ente autónomo, es una PARTE
--  de esa receta. Y un subtipo ISA no puede sobrevivir a su supertipo.
-- ============================================================================

-- ── Herencia ISA: el subtipo muere con el supertipo ─────────────────────────
ALTER TABLE veterinario ADD CONSTRAINT fk_veterinario_empleado
    FOREIGN KEY (empleado_id) REFERENCES empleado (id) ON DELETE CASCADE;
ALTER TABLE medicamento ADD CONSTRAINT fk_medicamento_producto
    FOREIGN KEY (producto_id) REFERENCES producto (id) ON DELETE CASCADE;

-- ── Detalles de documento: partes, no entes ─────────────────────────────────
ALTER TABLE receta_detalle ADD CONSTRAINT fk_receta_detalle_receta
    FOREIGN KEY (receta_id) REFERENCES receta (id) ON DELETE CASCADE;
ALTER TABLE factura_detalle ADD CONSTRAINT fk_factura_detalle_factura
    FOREIGN KEY (factura_id) REFERENCES factura (id) ON DELETE CASCADE;
ALTER TABLE compra_detalle ADD CONSTRAINT fk_compra_detalle_compra
    FOREIGN KEY (compra_id) REFERENCES compra (id) ON DELETE CASCADE;
ALTER TABLE orden_examen_detalle ADD CONSTRAINT fk_orden_det_orden
    FOREIGN KEY (orden_examen_id) REFERENCES orden_examen (id) ON DELETE CASCADE;

-- ── Contenido de una consulta ──────────────────────────────────────────────
--  La consulta en sí está protegida con RESTRICT desde orden_examen, así que
--  no puede borrarse si tiene estudios pedidos. Estos CASCADE solo actúan si
--  la consulta llegara a eliminarse por una decisión explícita.
ALTER TABLE consulta_diagnostico ADD CONSTRAINT fk_consulta_diagnostico_consulta
    FOREIGN KEY (consulta_id) REFERENCES consulta (id) ON DELETE CASCADE;
ALTER TABLE tratamiento ADD CONSTRAINT fk_tratamiento_consulta
    FOREIGN KEY (consulta_id) REFERENCES consulta (id) ON DELETE CASCADE;
ALTER TABLE receta ADD CONSTRAINT fk_receta_consulta
    FOREIGN KEY (consulta_id) REFERENCES consulta (id) ON DELETE CASCADE;

-- ── Contenido de una internación y de otras agrupaciones ────────────────────
ALTER TABLE hospitalizacion_habitacion ADD CONSTRAINT fk_hosp_hab_hospitalizacion
    FOREIGN KEY (hospitalizacion_id) REFERENCES hospitalizacion (id) ON DELETE CASCADE;
ALTER TABLE seguimiento_hospitalario ADD CONSTRAINT fk_seguimiento_hospitalizacion
    FOREIGN KEY (hospitalizacion_id) REFERENCES hospitalizacion (id) ON DELETE CASCADE;
ALTER TABLE protocolo_medicamento ADD CONSTRAINT fk_protocolo_med_protocolo
    FOREIGN KEY (protocolo_id) REFERENCES protocolo_tratamiento (id) ON DELETE CASCADE;
ALTER TABLE vacuna_especie ADD CONSTRAINT fk_vacuna_especie_vacuna
    FOREIGN KEY (vacuna_id) REFERENCES vacuna (id) ON DELETE CASCADE;

-- ── Vínculos de seguridad: quitar un rol o un usuario limpia sus vínculos ───
ALTER TABLE veterinario_especialidad ADD CONSTRAINT fk_vet_esp_veterinario
    FOREIGN KEY (veterinario_id) REFERENCES veterinario (empleado_id) ON DELETE CASCADE;
ALTER TABLE rol_permiso ADD CONSTRAINT fk_rol_permiso_rol
    FOREIGN KEY (rol_id) REFERENCES rol (id) ON DELETE CASCADE;
ALTER TABLE rol_permiso ADD CONSTRAINT fk_rol_permiso_permiso
    FOREIGN KEY (permiso_id) REFERENCES permiso (id) ON DELETE CASCADE;
ALTER TABLE usuario_rol ADD CONSTRAINT fk_usuario_rol_usuario
    FOREIGN KEY (usuario_id) REFERENCES usuario (id) ON DELETE CASCADE;
ALTER TABLE proveedor_producto ADD CONSTRAINT fk_proveedor_producto_proveedor
    FOREIGN KEY (proveedor_id) REFERENCES proveedor (id) ON DELETE CASCADE;


-- ============================================================================
--  E. SET NULL — TRAZABILIDAD Y ORÍGENES OPCIONALES
-- ----------------------------------------------------------------------------
--  Perder el «quién» o el «de dónde salió» no invalida el hecho registrado.
--  Un peso tomado sigue siendo un peso válido aunque se borre la consulta que
--  lo originó; un movimiento de stock ocurrió realmente aunque desaparezca el
--  documento que lo motivó.
-- ============================================================================

ALTER TABLE usuario ADD CONSTRAINT fk_usuario_empleado
    FOREIGN KEY (empleado_id) REFERENCES empleado (id) ON DELETE SET NULL;

ALTER TABLE registro_peso ADD CONSTRAINT fk_registro_peso_empleado
    FOREIGN KEY (empleado_id) REFERENCES empleado (id) ON DELETE SET NULL;
ALTER TABLE registro_peso ADD CONSTRAINT fk_registro_peso_consulta
    FOREIGN KEY (consulta_id) REFERENCES consulta (id) ON DELETE SET NULL;
ALTER TABLE registro_peso ADD CONSTRAINT fk_registro_peso_seguimiento
    FOREIGN KEY (seguimiento_id) REFERENCES seguimiento_hospitalario (id) ON DELETE SET NULL;

ALTER TABLE solicitud_cita ADD CONSTRAINT fk_solicitud_cita
    FOREIGN KEY (cita_id) REFERENCES cita (id) ON DELETE SET NULL;
ALTER TABLE solicitud_cita ADD CONSTRAINT fk_solicitud_especie
    FOREIGN KEY (especie_id) REFERENCES especie (id) ON DELETE SET NULL;
ALTER TABLE cita ADD CONSTRAINT fk_cita_usuario_registro
    FOREIGN KEY (usuario_registro_id) REFERENCES usuario (id) ON DELETE SET NULL;
ALTER TABLE consulta ADD CONSTRAINT fk_consulta_cita
    FOREIGN KEY (cita_id) REFERENCES cita (id) ON DELETE SET NULL;
ALTER TABLE tratamiento ADD CONSTRAINT fk_tratamiento_protocolo
    FOREIGN KEY (protocolo_id) REFERENCES protocolo_tratamiento (id) ON DELETE SET NULL;

ALTER TABLE vacuna ADD CONSTRAINT fk_vacuna_producto
    FOREIGN KEY (producto_id) REFERENCES producto (id) ON DELETE SET NULL;
ALTER TABLE aplicacion_vacuna ADD CONSTRAINT fk_aplicacion_vacuna_consulta
    FOREIGN KEY (consulta_id) REFERENCES consulta (id) ON DELETE SET NULL;
ALTER TABLE desparasitacion ADD CONSTRAINT fk_desparasitacion_veterinario
    FOREIGN KEY (veterinario_id) REFERENCES veterinario (empleado_id) ON DELETE SET NULL;
ALTER TABLE desparasitacion ADD CONSTRAINT fk_desparasitacion_consulta
    FOREIGN KEY (consulta_id) REFERENCES consulta (id) ON DELETE SET NULL;

ALTER TABLE cirugia ADD CONSTRAINT fk_cirugia_consulta
    FOREIGN KEY (consulta_id) REFERENCES consulta (id) ON DELETE SET NULL;
ALTER TABLE cirugia ADD CONSTRAINT fk_cirugia_anestesista
    FOREIGN KEY (anestesista_id) REFERENCES veterinario (empleado_id) ON DELETE SET NULL;
ALTER TABLE hospitalizacion ADD CONSTRAINT fk_hospitalizacion_consulta
    FOREIGN KEY (consulta_id) REFERENCES consulta (id) ON DELETE SET NULL;
ALTER TABLE hospitalizacion ADD CONSTRAINT fk_hospitalizacion_cirugia
    FOREIGN KEY (cirugia_id) REFERENCES cirugia (id) ON DELETE SET NULL;

ALTER TABLE compra ADD CONSTRAINT fk_compra_empleado
    FOREIGN KEY (empleado_id) REFERENCES empleado (id) ON DELETE SET NULL;
ALTER TABLE movimiento_stock ADD CONSTRAINT fk_movimiento_empleado
    FOREIGN KEY (empleado_id) REFERENCES empleado (id) ON DELETE SET NULL;
ALTER TABLE movimiento_stock ADD CONSTRAINT fk_movimiento_compra_detalle
    FOREIGN KEY (compra_detalle_id) REFERENCES compra_detalle (id) ON DELETE SET NULL;
ALTER TABLE movimiento_stock ADD CONSTRAINT fk_movimiento_factura_detalle
    FOREIGN KEY (factura_detalle_id) REFERENCES factura_detalle (id) ON DELETE SET NULL;
ALTER TABLE movimiento_stock ADD CONSTRAINT fk_movimiento_aplicacion_vacuna
    FOREIGN KEY (aplicacion_vacuna_id) REFERENCES aplicacion_vacuna (id) ON DELETE SET NULL;
ALTER TABLE movimiento_stock ADD CONSTRAINT fk_movimiento_desparasitacion
    FOREIGN KEY (desparasitacion_id) REFERENCES desparasitacion (id) ON DELETE SET NULL;

ALTER TABLE factura ADD CONSTRAINT fk_factura_usuario_emisor
    FOREIGN KEY (usuario_emisor_id) REFERENCES usuario (id) ON DELETE SET NULL;
ALTER TABLE factura_detalle ADD CONSTRAINT fk_factura_detalle_mascota
    FOREIGN KEY (mascota_id) REFERENCES mascota (id) ON DELETE SET NULL;
ALTER TABLE factura_detalle ADD CONSTRAINT fk_factura_detalle_consulta
    FOREIGN KEY (consulta_id) REFERENCES consulta (id) ON DELETE SET NULL;
ALTER TABLE pago ADD CONSTRAINT fk_pago_usuario
    FOREIGN KEY (usuario_id) REFERENCES usuario (id) ON DELETE SET NULL;
