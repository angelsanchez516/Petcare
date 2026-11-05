-- ============================================================================
--  PETCARE — 07_demo.sql · Datos de demostración
-- ----------------------------------------------------------------------------
--  Escenario coherente para probar la aplicación y los reportes: personal,
--  tutores, mascotas con historial real, agenda, facturación e inventario.
--
--  NO son datos de producción. Se cargan aparte de los catálogos justamente
--  para poder omitirlos en una instalación real.
--
--  ⚠ CONTRASEÑAS: los password_hash de este archivo son MARCADORES, no hashes
--    válidos. Ningún usuario puede iniciar sesión con ellos. La aplicación debe
--    generar los hashes reales con argon2id o bcrypt en el primer arranque.
--    Ver README.md, sección «Usuarios de prueba».
-- ============================================================================

SET client_min_messages = WARNING;

-- ============================================================================
--  PERSONAL
-- ============================================================================

INSERT INTO empleado (cargo_id, tipo_documento, documento, nombres, apellidos,
                      telefono, email, fecha_contratacion)
SELECT c.id, e.tdoc, e.doc, e.nom, e.ape, e.tel, e.mail, e.fecha
FROM cargo c, (VALUES
 ('Veterinario',  'DNI','30111222','Lucía',   'Ferreyra','+54 11 4555-1001','lucia.ferreyra@petcare.vet',  DATE '2019-03-01'),
 ('Veterinario',  'DNI','28444555','Martín',  'Ocampo',  '+54 11 4555-1002','martin.ocampo@petcare.vet',   DATE '2020-07-15'),
 ('Veterinario',  'DNI','33777888','Sofía',   'Brenner', '+54 11 4555-1003','sofia.brenner@petcare.vet',   DATE '2022-02-01'),
 ('Recepcionista','DNI','35222333','Camila',  'Ruiz',    '+54 11 4555-1010','camila.ruiz@petcare.vet',     DATE '2021-05-10'),
 ('Auxiliar',     'DNI','36999000','Diego',   'Paz',     '+54 11 4555-1011','diego.paz@petcare.vet',       DATE '2023-01-09'),
 ('Administrador','DNI','27333444','Valeria', 'Sandoval','+54 11 4555-1000','valeria.sandoval@petcare.vet',DATE '2018-01-02')
) AS e(cargo, tdoc, doc, nom, ape, tel, mail, fecha)
WHERE c.nombre = e.cargo;

-- Subtipo veterinario: solo para quienes ejercen. Valeria es administradora
-- Y veterinaria a la vez, lo que ejercita los roles múltiples.
INSERT INTO veterinario (empleado_id, matricula, fecha_habilitacion, biografia)
SELECT e.id, v.mat, v.fecha, v.bio
FROM empleado e, (VALUES
 ('30111222','MP-14872', DATE '2018-12-01','Especialista en medicina interna de pequeños animales, con quince años de ejercicio.'),
 ('28444555','MP-11209', DATE '2016-06-20','Cirujano de tejidos blandos. Docente de la cátedra de técnica quirúrgica.'),
 ('33777888','MP-19045', DATE '2021-11-05','Dermatología y animales exóticos.'),
 ('27333444','MP-09876', DATE '2012-03-15','Directora de la clínica. Cardiología veterinaria.')
) AS v(doc, mat, fecha, bio)
WHERE e.documento = v.doc;

INSERT INTO veterinario_especialidad (veterinario_id, especialidad_id, es_principal, certificado_en)
SELECT e.id, esp.id, ve.principal, ve.fecha
FROM empleado e, especialidad esp, (VALUES
 ('30111222','Medicina general',           TRUE,  DATE '2019-01-10'),
 ('30111222','Odontología',                FALSE, DATE '2021-08-01'),
 ('28444555','Cirugía de tejidos blandos', TRUE,  DATE '2017-04-12'),
 ('28444555','Traumatología',              FALSE, DATE '2019-09-30'),
 ('28444555','Anestesiología',             FALSE, DATE '2018-02-20'),
 ('33777888','Dermatología',               TRUE,  DATE '2022-03-15'),
 ('33777888','Animales exóticos',          FALSE, DATE '2023-06-01'),
 ('27333444','Cardiología',                TRUE,  DATE '2014-05-05')
) AS ve(doc, esp, principal, fecha)
WHERE e.documento = ve.doc AND esp.nombre = ve.esp;

-- Usuarios. El hash es un MARCADOR: nadie puede iniciar sesión con él.
INSERT INTO usuario (empleado_id, nombre_usuario, email, password_hash)
SELECT e.id, u.usr, e.email, '$2b$12$MARCADOR.NO.ES.UN.HASH.VALIDO.REEMPLAZAR.EN.EL.PRIMER.ARRANQUE'
FROM empleado e, (VALUES
 ('27333444','vsandoval'), ('30111222','lferreyra'), ('28444555','mocampo'),
 ('33777888','sbrenner'),  ('35222333','cruiz'),     ('36999000','dpaz')
) AS u(doc, usr)
WHERE e.documento = u.doc;

INSERT INTO usuario_rol (usuario_id, rol_id)
SELECT u.id, r.id
FROM usuario u JOIN empleado e ON e.id = u.empleado_id, rol r
WHERE (e.documento = '27333444' AND r.codigo IN ('ADMINISTRADOR','VETERINARIO'))
   OR (e.documento IN ('30111222','28444555','33777888') AND r.codigo = 'VETERINARIO')
   OR (e.documento = '35222333' AND r.codigo = 'RECEPCIONISTA')
   OR (e.documento = '36999000' AND r.codigo IN ('RECEPCIONISTA','INVENTARIO'));


-- ============================================================================
--  TUTORES Y MASCOTAS
-- ============================================================================

INSERT INTO cliente (tipo_documento, documento, nombres, apellidos, telefono, email, direccion, ciudad) VALUES
 ('DNI','31456789','Juan',    'Pérez',    '+54 11 6123-4567','juan.perez@correo.com',   'Av. Rivadavia 4520',   'Buenos Aires'),
 ('DNI','29876543','Marcela', 'Gómez',    '+54 11 6234-5678','m.gomez@correo.com',      'Calle Mitre 1180',     'Buenos Aires'),
 ('DNI','34567890','Andrés',  'Liriano',  '+54 11 6345-6789',NULL,                      'Pje. Los Álamos 77',   'Lanús'),
 ('DNI','26543210','Beatriz', 'Navarro',  '+54 11 6456-7890','bnavarro@correo.com',     'Av. Belgrano 2310',    'Avellaneda'),
 ('DNI','38901234','Tomás',   'Quiroga',  '+54 11 6567-8901','tquiroga@correo.com',     'Sarmiento 640',        'Buenos Aires'),
 ('DNI','30246813','Renata',  'Ibáñez',   '+54 11 6678-9012','renata.ib@correo.com',    'Güemes 1502',          'Quilmes'),
 ('CE', 'CE778899','Karim',   'Haddad',   '+54 11 6789-0123','k.haddad@correo.com',     'San Martín 88',        'Buenos Aires');

-- Cada mascota se inserta de forma explícita porque la raza debe resolverse
-- contra su especie: el par (raza, especie) es lo que exige la FK compuesta.

-- Mascotas de Juan Pérez
INSERT INTO mascota (cliente_id, especie_id, raza_id, nombre, sexo, fecha_nacimiento, color, microchip, esterilizado, temperamento)
SELECT c.id, e.id, r.id, 'Max', 'M', DATE '2020-06-15', 'Dorado', '900215004871220', TRUE, 'DOCIL'
  FROM cliente c, especie e, raza r
 WHERE c.documento='31456789' AND e.nombre='Canino' AND r.nombre='Labrador Retriever' AND r.especie_id=e.id;

INSERT INTO mascota (cliente_id, especie_id, raza_id, nombre, sexo, fecha_nacimiento, color, microchip, esterilizado, temperamento)
SELECT c.id, e.id, r.id, 'Luna', 'H', DATE '2022-03-08', 'Gris atigrado', '900215004871221', TRUE, 'NERVIOSO'
  FROM cliente c, especie e, raza r
 WHERE c.documento='31456789' AND e.nombre='Felino' AND r.nombre='Siamés' AND r.especie_id=e.id;

INSERT INTO mascota (cliente_id, especie_id, raza_id, nombre, sexo, fecha_nacimiento, color, esterilizado, temperamento)
SELECT c.id, e.id, r.id, 'Toby', 'M', DATE '2018-11-30', 'Negro y fuego', FALSE, 'DOCIL'
  FROM cliente c, especie e, raza r
 WHERE c.documento='31456789' AND e.nombre='Canino' AND r.nombre='Beagle' AND r.especie_id=e.id;

-- Mascota mestiza SIN raza: prueba que especie_id independiente funciona.
INSERT INTO mascota (cliente_id, especie_id, raza_id, nombre, sexo, fecha_nacimiento, color, esterilizado, temperamento, observaciones)
SELECT c.id, e.id, NULL, 'Rocco', 'M', DATE '2021-01-20', 'Marrón claro', TRUE, 'DOCIL',
       'Rescatado de la calle, raza desconocida.'
  FROM cliente c, especie e
 WHERE c.documento='29876543' AND e.nombre='Canino';

INSERT INTO mascota (cliente_id, especie_id, raza_id, nombre, sexo, fecha_nacimiento, color, microchip, esterilizado, temperamento)
SELECT c.id, e.id, r.id, 'Mishi', 'H', DATE '2019-09-12', 'Blanco', '900215004871222', TRUE, 'AGRESIVO'
  FROM cliente c, especie e, raza r
 WHERE c.documento='29876543' AND e.nombre='Felino' AND r.nombre='Persa' AND r.especie_id=e.id;

INSERT INTO mascota (cliente_id, especie_id, raza_id, nombre, sexo, fecha_nacimiento, color, esterilizado, temperamento)
SELECT c.id, e.id, r.id, 'Nala', 'H', DATE '2017-04-25', 'Crema', TRUE, 'DOCIL'
  FROM cliente c, especie e, raza r
 WHERE c.documento='34567890' AND e.nombre='Canino' AND r.nombre='Golden Retriever' AND r.especie_id=e.id;

INSERT INTO mascota (cliente_id, especie_id, raza_id, nombre, sexo, fecha_nacimiento, color, esterilizado, temperamento)
SELECT c.id, e.id, r.id, 'Zeus', 'M', DATE '2016-02-14', 'Negro', FALSE, 'NERVIOSO'
  FROM cliente c, especie e, raza r
 WHERE c.documento='26543210' AND e.nombre='Canino' AND r.nombre='Pastor Alemán' AND r.especie_id=e.id;

INSERT INTO mascota (cliente_id, especie_id, raza_id, nombre, sexo, fecha_nacimiento, color, esterilizado, temperamento)
SELECT c.id, e.id, r.id, 'Kiwi', 'M', DATE '2023-05-02', 'Verde', FALSE, 'DESCONOCIDO'
  FROM cliente c, especie e, raza r
 WHERE c.documento='38901234' AND e.nombre='Ave' AND r.nombre='Periquito' AND r.especie_id=e.id;

INSERT INTO mascota (cliente_id, especie_id, raza_id, nombre, sexo, fecha_nacimiento, color, esterilizado, temperamento)
SELECT c.id, e.id, r.id, 'Copito', 'H', DATE '2024-02-18', 'Blanco', FALSE, 'DOCIL'
  FROM cliente c, especie e, raza r
 WHERE c.documento='30246813' AND e.nombre='Roedor' AND r.nombre='Hámster sirio' AND r.especie_id=e.id;

INSERT INTO mascota (cliente_id, especie_id, raza_id, nombre, sexo, fecha_nacimiento, color, esterilizado, temperamento)
SELECT c.id, e.id, r.id, 'Simba', 'M', DATE '2021-08-09', 'Naranja', TRUE, 'DOCIL'
  FROM cliente c, especie e, raza r
 WHERE c.documento='CE778899' AND e.nombre='Felino' AND r.nombre='Maine Coon' AND r.especie_id=e.id;

-- Condiciones médicas
INSERT INTO mascota_condicion (mascota_id, condicion_medica_id, severidad, fecha_deteccion, notas)
SELECT m.id, cm.id, x.sev, x.fecha, x.notas
FROM mascota m, condicion_medica cm, (VALUES
 ('Max',  'Alergia a penicilina',       'GRAVE', DATE '2022-04-10','Edema facial tras una dosis. Usar cefalosporinas.'),
 ('Max',  'Displasia de cadera',        'LEVE',  DATE '2023-06-02','Hallazgo radiográfico incidental.'),
 ('Luna', 'Dermatitis atópica',         'MEDIA', DATE '2023-11-20','Estacional, empeora en primavera.'),
 ('Zeus', 'Insuficiencia renal crónica','GRAVE', DATE '2024-01-15','Estadio 2 IRIS. Dieta renal permanente.'),
 ('Mishi','Alergia a picadura de pulga','MEDIA', DATE '2023-03-05',NULL),
 ('Nala', 'Hipotiroidismo',             'MEDIA', DATE '2022-08-11','Levotiroxina de por vida.')
) AS x(mascota, cond, sev, fecha, notas)
WHERE m.nombre = x.mascota AND cm.nombre = x.cond;

-- Historial de peso: varias mediciones para poder graficar evolución.
INSERT INTO registro_peso (mascota_id, fecha_registro, peso_kg, observacion)
SELECT m.id, x.fecha, x.peso, x.obs
FROM mascota m, (VALUES
 ('Max',  CURRENT_DATE - 400, 26.40, 'Control anual'),
 ('Max',  CURRENT_DATE - 210, 27.80, NULL),
 ('Max',  CURRENT_DATE -  95, 29.10, 'Sobrepeso leve, se indica dieta'),
 ('Max',  CURRENT_DATE -  20, 28.50, 'Responde a la dieta'),
 ('Luna', CURRENT_DATE - 180,  3.90, NULL),
 ('Luna', CURRENT_DATE -  30,  4.20, NULL),
 ('Toby', CURRENT_DATE - 150, 12.30, NULL),
 ('Toby', CURRENT_DATE -  40, 13.10, 'Aumento de peso, revisar ración'),
 ('Zeus', CURRENT_DATE - 200, 38.00, NULL),
 ('Zeus', CURRENT_DATE -  60, 34.50, 'Pérdida de peso asociada a IRC'),
 ('Zeus', CURRENT_DATE -  10, 33.80, NULL),
 ('Nala', CURRENT_DATE -  75, 31.20, NULL),
 ('Mishi',CURRENT_DATE -  50,  4.60, NULL),
 ('Simba',CURRENT_DATE -  35,  6.80, NULL),
 ('Rocco',CURRENT_DATE -  25, 18.40, NULL),
 ('Kiwi', CURRENT_DATE -  15,  0.04, 'Peso normal para la especie'),
 ('Copito',CURRENT_DATE - 12,  0.13, NULL)
) AS x(mascota, fecha, peso, obs)
WHERE m.nombre = x.mascota;


-- ============================================================================
--  AGENDA Y ATENCIÓN CLÍNICA
-- ============================================================================

-- Citas pasadas ya atendidas
INSERT INTO cita (mascota_id, veterinario_id, servicio_id, fecha_hora_inicio, duracion_minutos, motivo, estado)
SELECT m.id, e.id, s.id, x.inicio, x.dur, x.motivo, x.estado
FROM mascota m, empleado e, servicio s, (VALUES
 ('Max',  '30111222','SRV-001', (CURRENT_DATE - 20 + TIME '09:00')::timestamptz, 30, 'Vómitos y decaimiento desde ayer', 'atendida'),
 ('Zeus', '27333444','SRV-001', (CURRENT_DATE - 10 + TIME '10:00')::timestamptz, 30, 'Control de función renal',         'atendida'),
 ('Luna', '33777888','SRV-001', (CURRENT_DATE - 30 + TIME '11:00')::timestamptz, 30, 'Prurito y lesiones en el lomo',    'atendida'),
 ('Toby', '30111222','SRV-010', (CURRENT_DATE - 40 + TIME '15:00')::timestamptz, 20, 'Refuerzo anual de vacunas',        'atendida')
) AS x(mascota, doc, srv, inicio, dur, motivo, estado)
WHERE m.nombre = x.mascota AND e.documento = x.doc AND s.codigo = x.srv;

-- Citas futuras
INSERT INTO cita (mascota_id, veterinario_id, servicio_id, fecha_hora_inicio, duracion_minutos, motivo, estado)
SELECT m.id, e.id, s.id, x.inicio, x.dur, x.motivo, x.estado
FROM mascota m, empleado e, servicio s, (VALUES
 ('Max',   '30111222','SRV-003', (CURRENT_DATE + 3 + TIME '09:00')::timestamptz, 20, 'Control post-tratamiento',      'confirmada'),
 ('Mishi', '33777888','SRV-001', (CURRENT_DATE + 1 + TIME '10:30')::timestamptz, 30, 'Rascado persistente',           'programada'),
 ('Simba', '30111222','SRV-010', (CURRENT_DATE + 2 + TIME '11:00')::timestamptz, 20, 'Vacuna triple felina',          'programada'),
 ('Nala',  '27333444','SRV-022', (CURRENT_DATE + 5 + TIME '14:00')::timestamptz, 30, 'Electrocardiograma de control', 'programada'),
 ('Rocco', '28444555','SRV-031', (CURRENT_DATE + 7 + TIME '08:00')::timestamptz, 90, 'Castración programada',         'confirmada'),
 ('Kiwi',  '33777888','SRV-001', (CURRENT_DATE + 4 + TIME '16:00')::timestamptz, 30, 'Revisión de plumaje',           'programada')
) AS x(mascota, doc, srv, inicio, dur, motivo, estado)
WHERE m.nombre = x.mascota AND e.documento = x.doc AND s.codigo = x.srv;

-- Consultas derivadas de las citas atendidas.
INSERT INTO consulta (mascota_id, veterinario_id, cita_id, fecha_hora, tipo, motivo,
                      anamnesis, temperatura_c, frecuencia_cardiaca, frecuencia_respiratoria, examen_fisico)
SELECT c.mascota_id, c.veterinario_id, c.id, c.fecha_hora_inicio, x.tipo, c.motivo,
       x.anam, x.temp, x.fc, x.fr, x.ef
FROM cita c
JOIN mascota m ON m.id = c.mascota_id
JOIN (VALUES
 ('Max',  'GENERAL', 'El tutor refiere tres episodios de vómito con contenido alimentario y rechazo del alimento desde ayer por la tarde.', 39.2, 110, 28, 'Mucosas rosadas, deshidratación leve del 5 %. Dolor a la palpación epigástrica.'),
 ('Zeus', 'CONTROL', 'Sin cambios respecto al control anterior. Come la dieta renal sin rechazo.', 38.4, 96, 24, 'Mucosas pálidas. Riñones de tamaño reducido a la palpación.'),
 ('Luna', 'GENERAL', 'Rascado intenso desde hace dos semanas, con caída de pelo en el lomo.', 38.6, 180, 32, 'Eritema y pápulas en región dorsolumbar. Sin ectoparásitos visibles.'),
 ('Toby', 'VACUNACION','Sin signos clínicos. Concurre a refuerzo anual.', 38.5, 100, 22, 'Examen físico dentro de parámetros normales.')
) AS x(mascota, tipo, anam, temp, fc, fr, ef) ON x.mascota = m.nombre
WHERE c.estado = 'atendida';

-- El peso tomado en la consulta se registra en registro_peso, NO en consulta.
INSERT INTO registro_peso (mascota_id, consulta_id, fecha_registro, peso_kg, observacion)
SELECT c.mascota_id, c.id, c.fecha_hora::date + 1, x.peso, 'Tomado en consulta'
FROM consulta c JOIN mascota m ON m.id = c.mascota_id,
     (VALUES ('Max', 28.60), ('Zeus', 33.90), ('Luna', 4.15)) AS x(mascota, peso)
WHERE m.nombre = x.mascota
  AND NOT EXISTS (SELECT 1 FROM registro_peso rp
                   WHERE rp.mascota_id = c.mascota_id
                     AND rp.fecha_registro = c.fecha_hora::date + 1);

-- Diagnósticos: ÚNICO lugar donde se registran.
INSERT INTO consulta_diagnostico (consulta_id, diagnostico_id, tipo, es_principal, notas)
SELECT c.id, d.id, x.tipo, x.principal, x.notas
FROM consulta c JOIN mascota m ON m.id = c.mascota_id, diagnostico d, (VALUES
 ('Max',  'GAS-002','DEFINITIVO', TRUE,  'Compatible con indiscreción alimentaria.'),
 ('Zeus', 'URI-001','DEFINITIVO', TRUE,  'Estadio 2 IRIS, estable respecto al control previo.'),
 ('Luna', 'DER-001','PRESUNTIVO', TRUE,  'Se solicita citología para descartar sobreinfección.'),
 ('Luna', 'DER-030','DESCARTADO', FALSE, 'Sin pústulas ni costras al examen.')
) AS x(mascota, cod, tipo, principal, notas)
WHERE m.nombre = x.mascota AND d.codigo = x.cod;

-- Tratamientos, uno de ellos instanciado desde un protocolo.
INSERT INTO tratamiento (consulta_id, protocolo_id, descripcion, indicaciones, fecha_inicio, fecha_fin_estimada, estado)
SELECT c.id, pt.id, x.desc_, x.ind, c.fecha_hora::date, c.fecha_hora::date + x.dias, x.estado
FROM consulta c JOIN mascota m ON m.id = c.mascota_id
LEFT JOIN protocolo_tratamiento pt ON pt.nombre = 'Antibioticoterapia estándar canina',
 (VALUES
 ('Max', 'Ayuno de 12 h, luego dieta blanda fraccionada y antibioticoterapia', 'Fraccionar la comida en cuatro tomas diarias durante cinco días.', 7, 'completado'),
 ('Luna','Baños con clorhexidina y control ambiental de pulgas', 'Bañar dos veces por semana. Tratar a todos los animales del hogar.', 30, 'activo')
) AS x(mascota, desc_, ind, dias, estado)
WHERE m.nombre = x.mascota;

-- Recetas. El folio lo genera el trigger.
INSERT INTO receta (consulta_id, indicaciones_generales, vigencia_dias)
SELECT c.id, 'Completar el ciclo antibiótico aunque los signos remitan. Reconsultar si vuelve a vomitar.', 30
FROM consulta c JOIN mascota m ON m.id = c.mascota_id
WHERE m.nombre = 'Max';

INSERT INTO receta_detalle (receta_id, medicamento_id, dosis, frecuencia, duracion_dias, via_administracion, cantidad, instrucciones)
SELECT r.id, p.id, x.dosis, x.frec, x.dias, x.via, x.cant, x.inst
FROM receta r
JOIN consulta c ON c.id = r.consulta_id
JOIN mascota m  ON m.id = c.mascota_id, producto p, (VALUES
 -- Max es ALÉRGICO A PENICILINA: se prescribe cefalexina, no amoxicilina.
 ('MED-003','1 comprimido','cada 12 horas', 7,'ORAL', 14, 'Administrar con comida'),
 ('MED-010','1,5 ml',      'cada 24 horas', 3,'ORAL',  1, 'Solo si persiste el dolor abdominal')
) AS x(cod, dosis, frec, dias, via, cant, inst)
WHERE m.nombre = 'Max' AND p.codigo = x.cod;

-- Orden de exámenes para Luna
INSERT INTO orden_examen (consulta_id, veterinario_id, prioridad, observaciones, estado)
SELECT c.id, c.veterinario_id, 'RUTINA', 'Descartar sobreinfección bacteriana', 'completada'
FROM consulta c JOIN mascota m ON m.id = c.mascota_id
WHERE m.nombre = 'Luna';

INSERT INTO orden_examen_detalle (orden_examen_id, examen_id, precio_unitario, resultado, fecha_resultado)
SELECT o.id, ex.id, ex.precio, x.res, CURRENT_DATE - 28
FROM orden_examen o
JOIN consulta c ON c.id = o.consulta_id
JOIN mascota m  ON m.id = c.mascota_id, examen ex, (VALUES
 ('EX-020','Presencia de cocos en baja cantidad. Compatible con sobreinfección leve.'),
 ('EX-021','Sin ácaros ni hongos observados.')
) AS x(cod, res)
WHERE m.nombre = 'Luna' AND ex.codigo = x.cod;


-- ============================================================================
--  INVENTARIO — compra recibida que ingresa stock
-- ============================================================================

INSERT INTO proveedor (tipo_documento, documento, razon_social, nombre_contacto, telefono, email) VALUES
 ('RUC','30712345678','Distribuidora Veterinaria del Sur SA','Gustavo Méndez','+54 11 4300-2200','ventas@dvsur.com'),
 ('RUC','30798765432','Insumos Pet Mayorista SRL',           'Nadia Corrales','+54 11 4300-3311','pedidos@insumospet.com');

INSERT INTO proveedor_producto (proveedor_id, producto_id, precio_compra, tiempo_entrega_dias, es_preferido)
SELECT pr.id, p.id, round(p.precio_venta * 0.62, 2), 3, TRUE
FROM proveedor pr, producto p
WHERE pr.documento = '30712345678' AND p.codigo LIKE 'MED-%';

INSERT INTO proveedor_producto (proveedor_id, producto_id, precio_compra, tiempo_entrega_dias, es_preferido)
SELECT pr.id, p.id, round(p.precio_venta * 0.58, 2), 5, TRUE
FROM proveedor pr, producto p
WHERE pr.documento = '30798765432' AND p.codigo LIKE 'BIO-%';

INSERT INTO compra (proveedor_id, empleado_id, numero_factura, fecha_compra, impuesto)
SELECT pr.id, e.id, 'A-0001-00012345', CURRENT_DATE - 15, 0
FROM proveedor pr, empleado e
WHERE pr.documento = '30712345678' AND e.documento = '36999000';

INSERT INTO compra_detalle (compra_id, producto_id, linea_nro, cantidad, precio_unitario, lote, fecha_vencimiento)
SELECT co.id, p.id, x.linea, x.cant, round(p.precio_venta * 0.62, 2), x.lote, CURRENT_DATE + 540
FROM compra co, producto p, (VALUES
 (1,'MED-001', 40, 'AMX-2025-11'),
 (2,'MED-003', 30, 'CFX-2025-07'),
 (3,'MED-010', 20, 'MLX-2025-04'),
 (4,'MED-020', 50, 'PZQ-2025-09'),
 (5,'MED-021', 60, 'FPR-2025-22'),
 (6,'MED-022', 40, 'FPR-2025-23')
) AS x(linea, cod, cant, lote)
WHERE co.numero_factura = 'A-0001-00012345' AND p.codigo = x.cod;

-- Compra de biológicos
INSERT INTO compra (proveedor_id, empleado_id, numero_factura, fecha_compra, impuesto)
SELECT pr.id, e.id, 'B-0002-00000987', CURRENT_DATE - 12, 0
FROM proveedor pr, empleado e
WHERE pr.documento = '30798765432' AND e.documento = '36999000';

INSERT INTO compra_detalle (compra_id, producto_id, linea_nro, cantidad, precio_unitario, lote, fecha_vencimiento)
SELECT co.id, p.id, x.linea, x.cant, round(p.precio_venta * 0.58, 2), x.lote, CURRENT_DATE + 400
FROM compra co, producto p, (VALUES
 (1,'BIO-001', 25, 'QC-2025-0233'),
 (2,'BIO-002', 30, 'AR-2025-0455'),
 (3,'BIO-003', 20, 'TF-2025-0118'),
 (4,'BIO-004', 15, 'LF-2025-0044'),
 (5,'BIO-005', 15, 'TP-2025-0301')
) AS x(linea, cod, cant, lote)
WHERE co.numero_factura = 'B-0002-00000987' AND p.codigo = x.cod;

-- Recibir las compras dispara el trigger que genera los movimientos de ENTRADA.
UPDATE compra SET estado = 'recibida'
 WHERE numero_factura IN ('A-0001-00012345','B-0002-00000987');

-- Stock inicial del resto del catálogo, como ajuste de inventario documentado.
INSERT INTO movimiento_stock (producto_id, empleado_id, tipo, cantidad, motivo)
SELECT p.id, e.id, 'AJUSTE', 25, 'Carga de inventario inicial'
FROM producto p, empleado e
WHERE e.documento = '36999000'
  AND p.codigo NOT LIKE 'MED-%'
  AND p.codigo NOT LIKE 'BIO-%';


-- ============================================================================
--  VACUNACIÓN Y DESPARASITACIÓN
-- ============================================================================

INSERT INTO aplicacion_vacuna (mascota_id, vacuna_id, veterinario_id, fecha_aplicacion,
                               fecha_proximo_refuerzo, lote, dosis_numero)
SELECT m.id, v.id, e.id, x.fecha, x.fecha + INTERVAL '12 months', x.lote, x.dosis
FROM mascota m, vacuna v, empleado e, (VALUES
 ('Max',  'Quíntuple canina',  '30111222', CURRENT_DATE - 300, 'QC-2024-0871', 3),
 ('Max',  'Antirrábica',       '30111222', CURRENT_DATE - 300, 'AR-2024-1120', 3),
 ('Toby', 'Quíntuple canina',  '30111222', CURRENT_DATE -  40, 'QC-2025-0233', 5),
 ('Toby', 'Antirrábica',       '30111222', CURRENT_DATE -  40, 'AR-2025-0455', 5),
 ('Luna', 'Triple felina',     '33777888', CURRENT_DATE - 340, 'TF-2024-0612', 2),
 ('Nala', 'Quíntuple canina',  '27333444', CURRENT_DATE - 355, 'QC-2024-0790', 6),
 ('Zeus', 'Antirrábica',       '27333444', CURRENT_DATE - 200, 'AR-2024-1301', 7),
 ('Simba','Triple felina',     '33777888', CURRENT_DATE - 370, 'TF-2024-0501', 2),
 ('Mishi','Triple felina',     '33777888', CURRENT_DATE - 120, 'TF-2025-0118', 4)
) AS x(mascota, vac, doc, fecha, lote, dosis)
WHERE m.nombre = x.mascota AND v.nombre = x.vac AND e.documento = x.doc;

INSERT INTO desparasitacion (mascota_id, producto_id, veterinario_id, tipo, fecha_aplicacion, proxima_aplicacion, dosis)
SELECT m.id, p.id, e.id, x.tipo, x.fecha, x.fecha + INTERVAL '3 months', x.dosis
FROM mascota m, producto p, empleado e, (VALUES
 ('Max',  'MED-020','30111222','INTERNA', CURRENT_DATE - 60, '3 comprimidos'),
 ('Toby', 'MED-020','30111222','INTERNA', CURRENT_DATE - 40, '2 comprimidos'),
 ('Mishi','MED-021','33777888','EXTERNA', CURRENT_DATE - 50, '1 pipeta'),
 ('Rocco','MED-022','30111222','MIXTA',   CURRENT_DATE - 25, '1 pipeta')
) AS x(mascota, cod, doc, tipo, fecha, dosis)
WHERE m.nombre = x.mascota AND p.codigo = x.cod AND e.documento = x.doc;


-- ============================================================================
--  FACTURACIÓN
-- ============================================================================

-- Factura pagada: consulta + medicamentos de Max.
INSERT INTO factura (cliente_id, usuario_emisor_id, fecha_emision, porcentaje_impuesto)
SELECT c.id, u.id, CURRENT_DATE - 20, 0
FROM cliente c, usuario u
WHERE c.documento = '31456789' AND u.nombre_usuario = 'cruiz';

INSERT INTO factura_detalle (factura_id, servicio_id, producto_id, mascota_id, consulta_id,
                             linea_nro, tipo_item, descripcion, cantidad, precio_unitario)
SELECT f.id,
       CASE WHEN x.tipo='SERVICIO' THEN s.id END,
       CASE WHEN x.tipo='PRODUCTO' THEN p.id END,
       m.id, co.id, x.linea, x.tipo, x.desc_, x.cant,
       CASE WHEN x.tipo='SERVICIO' THEN s.precio_base ELSE p.precio_venta END
FROM factura f
JOIN cliente cl ON cl.id = f.cliente_id
JOIN mascota m  ON m.nombre = 'Max'
JOIN consulta co ON co.mascota_id = m.id
LEFT JOIN servicio s ON s.codigo = 'SRV-001'
LEFT JOIN producto p ON p.codigo = 'MED-003',
 (VALUES (1,'SERVICIO','Consulta general', 1.0),
         (2,'PRODUCTO','Cefalexina 300 mg x 12 comprimidos', 2.0)) AS x(linea, tipo, desc_, cant)
WHERE cl.documento = '31456789' AND f.fecha_emision = CURRENT_DATE - 20;

INSERT INTO pago (factura_id, metodo_pago_id, usuario_id, monto, fecha_hora)
SELECT f.id, mp.id, u.id, f.total, (CURRENT_DATE - 20 + TIME '10:15')::timestamptz
FROM factura f, metodo_pago mp, usuario u, cliente c
WHERE f.cliente_id = c.id AND c.documento = '31456789'
  AND f.fecha_emision = CURRENT_DATE - 20
  AND mp.nombre = 'Efectivo' AND u.nombre_usuario = 'cruiz';

-- Factura con pago parcial: control de Zeus.
INSERT INTO factura (cliente_id, usuario_emisor_id, fecha_emision, porcentaje_impuesto)
SELECT c.id, u.id, CURRENT_DATE - 10, 0
FROM cliente c, usuario u
WHERE c.documento = '26543210' AND u.nombre_usuario = 'cruiz';

INSERT INTO factura_detalle (factura_id, servicio_id, examen_id, mascota_id,
                             linea_nro, tipo_item, descripcion, cantidad, precio_unitario)
SELECT f.id,
       CASE WHEN x.tipo='SERVICIO' THEN s.id END,
       CASE WHEN x.tipo='EXAMEN'   THEN ex.id END,
       m.id, x.linea, x.tipo, x.desc_, 1.0,
       CASE WHEN x.tipo='SERVICIO' THEN s.precio_base ELSE ex.precio END
FROM factura f
JOIN cliente cl ON cl.id = f.cliente_id
JOIN mascota m  ON m.nombre = 'Zeus'
LEFT JOIN servicio s ON s.codigo = 'SRV-001'
LEFT JOIN examen  ex ON ex.codigo = 'EX-003',
 (VALUES (1,'SERVICIO','Consulta general'),
         (2,'EXAMEN','Función renal (urea/creatinina)')) AS x(linea, tipo, desc_)
WHERE cl.documento = '26543210' AND f.fecha_emision = CURRENT_DATE - 10;

INSERT INTO pago (factura_id, metodo_pago_id, usuario_id, monto, referencia, fecha_hora)
SELECT f.id, mp.id, u.id, 40000, 'TRF-889231', (CURRENT_DATE - 10 + TIME '11:00')::timestamptz
FROM factura f, metodo_pago mp, usuario u, cliente c
WHERE f.cliente_id = c.id AND c.documento = '26543210'
  AND f.fecha_emision = CURRENT_DATE - 10
  AND mp.nombre = 'Transferencia' AND u.nombre_usuario = 'cruiz';

-- Factura impaga: vacunación de Toby.
INSERT INTO factura (cliente_id, usuario_emisor_id, fecha_emision, porcentaje_impuesto)
SELECT c.id, u.id, CURRENT_DATE - 40, 0
FROM cliente c, usuario u
WHERE c.documento = '31456789' AND u.nombre_usuario = 'cruiz';

INSERT INTO factura_detalle (factura_id, servicio_id, mascota_id, linea_nro, tipo_item,
                             descripcion, cantidad, precio_unitario)
SELECT f.id, s.id, m.id, 1, 'SERVICIO', 'Vacunación', 2.0, s.precio_base
FROM factura f
JOIN cliente cl ON cl.id = f.cliente_id
JOIN mascota m ON m.nombre = 'Toby', servicio s
WHERE cl.documento = '31456789' AND f.fecha_emision = CURRENT_DATE - 40
  AND s.codigo = 'SRV-010';


-- ============================================================================
--  SOLICITUDES DEL SITIO PÚBLICO
-- ============================================================================

INSERT INTO solicitud_cita (especie_id, nombre_contacto, telefono_contacto, email_contacto,
                            nombre_mascota, motivo, fecha_preferida, franja_preferida, estado)
SELECT e.id, x.nom, x.tel, x.mail, x.mascota, x.motivo, x.fecha, x.franja, x.estado
FROM especie e, (VALUES
 ('Canino','Federico Alsina','+54 11 6900-1122','falsina@correo.com','Rocky',
  'Cojera de la pata trasera derecha desde hace dos días', CURRENT_DATE + 2,'MANANA','nueva'),
 ('Felino','Paula Duarte',   '+54 11 6900-3344', NULL,               'Nube',
  'Consulta por primera vez, gatita de 3 meses',            CURRENT_DATE + 4,'TARDE','contactada'),
 ('Canino','Ignacio Vera',   '+54 11 6900-5566','ivera@correo.com',  NULL,
  'Quiero cotizar una castración',                          NULL,            'INDIFERENTE','nueva')
) AS x(esp, nom, tel, mail, mascota, motivo, fecha, franja, estado)
WHERE e.nombre = x.esp;
