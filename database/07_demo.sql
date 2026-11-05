-- ============================================================================
--  PETCARE — 07_demo.sql · Datos de demostración
-- ----------------------------------------------------------------------------
--  Escenario coherente para probar la aplicación: personal, tutores, mascotas
--  con historial real, agenda, facturación y solicitudes del sitio público.
--
--  OPCIONAL: comentar la línea \ir 07_demo.sql en petcare.sql para una
--  instalación sin datos de ejemplo.
--
--  ⚠ CONTRASEÑA DE LOS USUARIOS DE PRUEBA: petcare2026
--    El hash es scrypt real (formato scrypt$salt$hash), no un marcador. Sirve
--    únicamente para el entorno de desarrollo: cámbiala antes de cualquier uso
--    real del sistema.
-- ============================================================================

SET client_min_messages = WARNING;

-- ── Usuarios y veterinarios ─────────────────────────────────────────────────
INSERT INTO usuario (rol_id, nombre_usuario, email, password_hash)
SELECT r.id, u.usr, u.mail,
       'scrypt$98e7d81c0bb7b3437fb9b31c0439aa93$1c338005fa6afad5daa3c793b2ffdfbed49fa33c4fb4455a7de6374d694d0f30df9025ae7b63186182a1cdc6521ed1e6ebdf4c26915e0faea3cb85bca51c6d57'
FROM rol r, (VALUES
 ('Administrador','vsandoval','valeria.sandoval@petcare.vet'),
 ('Veterinario',  'lferreyra','lucia.ferreyra@petcare.vet'),
 ('Veterinario',  'mocampo',  'martin.ocampo@petcare.vet'),
 ('Veterinario',  'sbrenner', 'sofia.brenner@petcare.vet'),
 ('Recepcionista','cruiz',    'camila.ruiz@petcare.vet')
) AS u(rol, usr, mail) WHERE r.nombre = u.rol;

INSERT INTO veterinario (usuario_id, documento, matricula, nombres, apellidos,
                         telefono, email, biografia)
SELECT u.id, v.doc, v.mat, v.nom, v.ape, v.tel, u.email, v.bio
FROM usuario u, (VALUES
 ('vsandoval','1020304050','MV-09876','Valeria','Sandoval','+57 310 555 1000',
  'Directora de la clínica. Cardióloga veterinaria con quince años de ejercicio y docente universitaria.'),
 ('lferreyra','1030405060','MV-14872','Lucía','Ferreyra','+57 310 555 1001',
  'Especialista en medicina interna de pequeños animales. Coordina el área de consulta general.'),
 ('mocampo',  '1040506070','MV-11209','Martín','Ocampo','+57 310 555 1002',
  'Cirujano de tejidos blandos y traumatología. Responsable del quirófano.'),
 ('sbrenner', '1050607080','MV-19045','Sofía','Brenner','+57 310 555 1003',
  'Dermatología y pacientes exóticos: aves, reptiles y pequeños mamíferos.')
) AS v(usr, doc, mat, nom, ape, tel, bio)
WHERE u.nombre_usuario = v.usr;

INSERT INTO veterinario_especialidad (veterinario_id, especialidad_id, es_principal)
SELECT v.id, e.id, x.prin
FROM veterinario v, especialidad e, (VALUES
 ('MV-09876','Cardiología',                TRUE),
 ('MV-09876','Medicina general',           FALSE),
 ('MV-14872','Medicina general',           TRUE),
 ('MV-14872','Odontología',                FALSE),
 ('MV-11209','Cirugía de tejidos blandos', TRUE),
 ('MV-11209','Traumatología',              FALSE),
 ('MV-19045','Dermatología',               TRUE),
 ('MV-19045','Animales exóticos',          FALSE)
) AS x(mat, esp, prin)
WHERE v.matricula = x.mat AND e.nombre = x.esp;

-- ── Tutores ─────────────────────────────────────────────────────────────────
INSERT INTO cliente (tipo_documento, documento, nombres, apellidos, telefono, email, direccion, ciudad) VALUES
 ('CC','1012345678','Juan',    'Pérez',   '+57 300 412 3456','juan.perez@correo.com',  'Cra. 15 #93-47',   'Bogotá'),
 ('CC','1023456789','Marcela', 'Gómez',   '+57 301 523 4567','m.gomez@correo.com',     'Cll. 72 #11-20',   'Bogotá'),
 ('CC','1034567890','Andrés',  'Liriano', '+57 302 634 5678', NULL,                    'Cra. 50 #26-15',   'Bogotá'),
 ('CC','1045678901','Beatriz', 'Navarro', '+57 310 745 6789','bnavarro@correo.com',    'Av. Suba #104-33', 'Bogotá'),
 ('CC','1056789012','Tomás',   'Quiroga', '+57 311 856 7890','tquiroga@correo.com',    'Cll. 134 #7-83',   'Bogotá'),
 ('CC','1067890123','Renata',  'Ibáñez',  '+57 312 967 8901','renata.ib@correo.com',   'Cra. 7 #45-12',    'Bogotá'),
 ('CE','CE7788990',  'Karim',  'Haddad',  '+57 313 178 9012','k.haddad@correo.com',    'Cll. 85 #12-40',   'Bogotá');

-- ── Mascotas ────────────────────────────────────────────────────────────────
-- Cada una se inserta explícitamente porque la raza debe resolverse contra su
-- especie: el par (raza, especie) es lo que exige la clave foránea compuesta.
INSERT INTO mascota (cliente_id, especie_id, raza_id, nombre, sexo, fecha_nacimiento,
                     color, microchip, esterilizado, foto_url, observaciones)
SELECT c.id, e.id, r.id, m.nom, m.sexo, m.nac, m.col, m.chip, m.est, m.foto, m.obs
FROM cliente c, especie e, raza r, (VALUES
 ('1012345678','Canino','Labrador Retriever','Max',  'M', DATE '2020-06-15','Dorado',       '900215004871220', TRUE,  '/img/gato-cuadrado.jpg', NULL),
 ('1012345678','Canino','Beagle',            'Toby', 'M', DATE '2018-11-30','Negro y fuego', NULL,             FALSE, NULL, 'Muy sociable con otros perros.'),
 ('1023456789','Felino','Persa',             'Mishi','H', DATE '2019-09-12','Blanco',       '900215004871222', TRUE,  NULL, 'Requiere manejo cuidadoso, se estresa con facilidad.'),
 ('1034567890','Canino','Golden Retriever',  'Nala', 'H', DATE '2017-04-25','Crema',         NULL,             TRUE,  NULL, NULL),
 ('1045678901','Canino','Pastor Alemán',     'Zeus', 'M', DATE '2016-02-14','Negro',         NULL,             FALSE, NULL, 'Paciente renal en seguimiento.'),
 ('1056789012','Ave',   'Periquito',         'Kiwi', 'M', DATE '2023-05-02','Verde',         NULL,             FALSE, NULL, NULL),
 ('1067890123','Roedor','Hámster sirio',     'Copito','H',DATE '2024-02-18','Blanco',        NULL,             FALSE, NULL, NULL),
 ('CE7788990', 'Felino','Maine Coon',        'Simba','M', DATE '2021-08-09','Naranja',      '900215004871223', TRUE,  '/img/gato-cuadrado.jpg', NULL)
) AS m(doc, esp, raza, nom, sexo, nac, col, chip, est, foto, obs)
WHERE c.documento = m.doc AND e.nombre = m.esp
  AND r.nombre = m.raza AND r.especie_id = e.id;

-- Mascota mestiza SIN raza: comprueba que especie_id independiente funciona.
INSERT INTO mascota (cliente_id, especie_id, raza_id, nombre, sexo, fecha_nacimiento,
                     color, esterilizado, observaciones)
SELECT c.id, e.id, NULL, 'Rocco', 'M', DATE '2021-01-20', 'Marrón claro', TRUE,
       'Rescatado de la calle, raza desconocida.'
FROM cliente c, especie e WHERE c.documento = '1023456789' AND e.nombre = 'Canino';

INSERT INTO mascota (cliente_id, especie_id, raza_id, nombre, sexo, fecha_nacimiento,
                     color, esterilizado)
SELECT c.id, e.id, NULL, 'Luna', 'H', DATE '2022-03-08', 'Gris atigrado', TRUE
FROM cliente c, especie e WHERE c.documento = '1012345678' AND e.nombre = 'Felino';

-- ── Condiciones médicas ─────────────────────────────────────────────────────
INSERT INTO mascota_condicion (mascota_id, condicion_medica_id, severidad, fecha_deteccion, notas)
SELECT m.id, cm.id, x.sev, x.fecha, x.notas
FROM mascota m, condicion_medica cm, (VALUES
 ('Max',  'Alergia a penicilina',        'GRAVE', DATE '2022-04-10','Edema facial tras una dosis. Usar cefalosporinas.'),
 ('Max',  'Displasia de cadera',         'LEVE',  DATE '2023-06-02','Hallazgo radiográfico incidental.'),
 ('Luna', 'Dermatitis atópica',          'MEDIA', DATE '2023-11-20','Estacional, empeora con el polen.'),
 ('Zeus', 'Insuficiencia renal crónica', 'GRAVE', DATE '2024-01-15','Estadio 2. Dieta renal permanente.'),
 ('Mishi','Alergia a picadura de pulga', 'MEDIA', DATE '2023-03-05', NULL),
 ('Nala', 'Hipotiroidismo',              'MEDIA', DATE '2022-08-11','Levotiroxina de por vida.')
) AS x(masc, cond, sev, fecha, notas)
WHERE m.nombre = x.masc AND cm.nombre = x.cond;

-- ── Historial de peso ───────────────────────────────────────────────────────
INSERT INTO registro_peso (mascota_id, fecha_registro, peso_kg, observacion)
SELECT m.id, x.fecha, x.peso, x.obs
FROM mascota m, (VALUES
 ('Max',   CURRENT_DATE - 400, 26.40,'Control anual'),
 ('Max',   CURRENT_DATE - 210, 27.80, NULL),
 ('Max',   CURRENT_DATE -  95, 29.10,'Sobrepeso leve, se indica dieta'),
 ('Max',   CURRENT_DATE -  20, 28.50,'Responde bien a la dieta'),
 ('Luna',  CURRENT_DATE - 180,  3.90, NULL),
 ('Luna',  CURRENT_DATE -  30,  4.20, NULL),
 ('Toby',  CURRENT_DATE - 150, 12.30, NULL),
 ('Toby',  CURRENT_DATE -  40, 13.10,'Aumento de peso, revisar ración'),
 ('Zeus',  CURRENT_DATE - 200, 38.00, NULL),
 ('Zeus',  CURRENT_DATE -  60, 34.50,'Pérdida de peso asociada a la enfermedad renal'),
 ('Zeus',  CURRENT_DATE -  10, 33.80, NULL),
 ('Nala',  CURRENT_DATE -  75, 31.20, NULL),
 ('Mishi', CURRENT_DATE -  50,  4.60, NULL),
 ('Simba', CURRENT_DATE -  35,  6.80, NULL),
 ('Rocco', CURRENT_DATE -  25, 18.40, NULL),
 ('Kiwi',  CURRENT_DATE -  15,  0.04,'Peso normal para la especie'),
 ('Copito',CURRENT_DATE -  12,  0.13, NULL)
) AS x(masc, fecha, peso, obs) WHERE m.nombre = x.masc;

-- ── Citas atendidas ─────────────────────────────────────────────────────────
INSERT INTO cita (mascota_id, veterinario_id, servicio_id, fecha_hora_inicio,
                  fecha_hora_fin, duracion_minutos, motivo, estado)
SELECT m.id, v.id, s.id, x.ini, x.ini, x.dur, x.mot, 'atendida'
FROM mascota m, veterinario v, servicio s, (VALUES
 ('Max',  'MV-14872','SRV-001',(CURRENT_DATE - 20 + TIME '09:00')::timestamptz, 30,'Vómitos y decaimiento desde ayer'),
 ('Zeus', 'MV-09876','SRV-001',(CURRENT_DATE - 10 + TIME '10:00')::timestamptz, 30,'Control de función renal'),
 ('Luna', 'MV-19045','SRV-001',(CURRENT_DATE - 30 + TIME '11:00')::timestamptz, 30,'Prurito y lesiones en el lomo'),
 ('Toby', 'MV-14872','SRV-010',(CURRENT_DATE - 40 + TIME '15:00')::timestamptz, 20,'Refuerzo anual de vacunas')
) AS x(masc, mat, srv, ini, dur, mot)
WHERE m.nombre = x.masc AND v.matricula = x.mat AND s.codigo = x.srv;

-- ── Citas futuras ───────────────────────────────────────────────────────────
INSERT INTO cita (mascota_id, veterinario_id, servicio_id, fecha_hora_inicio,
                  fecha_hora_fin, duracion_minutos, motivo, estado)
SELECT m.id, v.id, s.id, x.ini, x.ini, x.dur, x.mot, x.est
FROM mascota m, veterinario v, servicio s, (VALUES
 ('Max',   'MV-14872','SRV-003',(CURRENT_DATE + 2 + TIME '09:00')::timestamptz, 20,'Control posterior al tratamiento','confirmada'),
 ('Mishi', 'MV-19045','SRV-001',(CURRENT_DATE + 1 + TIME '10:30')::timestamptz, 30,'Rascado persistente','programada'),
 ('Simba', 'MV-14872','SRV-010',(CURRENT_DATE + 2 + TIME '11:00')::timestamptz, 20,'Refuerzo de triple felina','programada'),
 ('Nala',  'MV-09876','SRV-022',(CURRENT_DATE + 4 + TIME '14:00')::timestamptz, 30,'Electrocardiograma de control','programada'),
 ('Rocco', 'MV-11209','SRV-031',(CURRENT_DATE + 6 + TIME '08:00')::timestamptz, 90,'Esterilización programada','confirmada'),
 ('Kiwi',  'MV-19045','SRV-001',(CURRENT_DATE + 3 + TIME '16:00')::timestamptz, 30,'Revisión de plumaje','programada'),
 ('Zeus',  'MV-09876','SRV-023',(CURRENT_DATE + 7 + TIME '09:30')::timestamptz, 20,'Perfil renal de seguimiento','programada')
) AS x(masc, mat, srv, ini, dur, mot, est)
WHERE m.nombre = x.masc AND v.matricula = x.mat AND s.codigo = x.srv;

-- ── Consultas derivadas de las citas atendidas ──────────────────────────────
INSERT INTO consulta (mascota_id, veterinario_id, cita_id, fecha_hora, tipo, motivo,
                      anamnesis, temperatura_c, frecuencia_cardiaca,
                      frecuencia_respiratoria, examen_fisico)
SELECT c.mascota_id, c.veterinario_id, c.id, c.fecha_hora_inicio, x.tipo, c.motivo,
       x.anam, x.temp, x.fc, x.fr, x.ef
FROM cita c JOIN mascota m ON m.id = c.mascota_id
JOIN (VALUES
 ('Max','GENERAL','El tutor refiere tres episodios de vómito con contenido alimentario y rechazo del alimento desde ayer por la tarde.',
  39.2,110,28,'Mucosas rosadas, deshidratación leve del 5 %. Dolor a la palpación epigástrica.'),
 ('Zeus','CONTROL','Sin cambios respecto al control anterior. Acepta bien la dieta renal.',
  38.4, 96,24,'Mucosas pálidas. Riñones de tamaño reducido a la palpación.'),
 ('Luna','GENERAL','Rascado intenso desde hace dos semanas, con caída de pelo en el lomo.',
  38.6,180,32,'Eritema y pápulas en región dorsolumbar. Sin ectoparásitos visibles.'),
 ('Toby','VACUNACION','Sin signos clínicos. Concurre al refuerzo anual.',
  38.5,100,22,'Examen físico dentro de parámetros normales.')
) AS x(masc, tipo, anam, temp, fc, fr, ef) ON x.masc = m.nombre
WHERE c.estado = 'atendida';

-- Diagnósticos: ÚNICO lugar donde se registran.
INSERT INTO consulta_diagnostico (consulta_id, diagnostico_id, tipo, es_principal, notas)
SELECT c.id, d.id, x.tipo, x.prin, x.notas
FROM consulta c JOIN mascota m ON m.id = c.mascota_id, diagnostico d, (VALUES
 ('Max', 'GAS-001','DEFINITIVO', TRUE, 'Compatible con indiscreción alimentaria.'),
 ('Zeus','URI-001','DEFINITIVO', TRUE, 'Estadio 2, estable respecto al control previo.'),
 ('Luna','DER-001','PRESUNTIVO', TRUE, 'Se indica tratamiento tópico y control en dos semanas.'),
 ('Luna','DER-030','DESCARTADO', FALSE,'Sin pústulas ni costras al examen.')
) AS x(masc, cod, tipo, prin, notas)
WHERE m.nombre = x.masc AND d.codigo = x.cod;

INSERT INTO tratamiento (consulta_id, descripcion, indicaciones, fecha_inicio,
                         fecha_fin_estimada, estado)
SELECT c.id, x.desc_, x.ind, c.fecha_hora::date, c.fecha_hora::date + x.dias, x.est
FROM consulta c JOIN mascota m ON m.id = c.mascota_id, (VALUES
 ('Max', 'Ayuno de 12 horas, luego dieta blanda fraccionada y antibioticoterapia',
  'Fraccionar la comida en cuatro tomas diarias durante cinco días.', 7,'completado'),
 ('Luna','Baños con clorhexidina y control ambiental de pulgas',
  'Bañar dos veces por semana. Tratar a todos los animales del hogar.', 30,'activo'),
 ('Zeus','Dieta renal estricta y control analítico trimestral',
  'No ofrecer premios ni alimento comercial común.', 90,'activo')
) AS x(masc, desc_, ind, dias, est) WHERE m.nombre = x.masc;

-- ── Receta ──────────────────────────────────────────────────────────────────
INSERT INTO receta (consulta_id, indicaciones_generales, vigencia_dias)
SELECT c.id, 'Completar el ciclo antibiótico aunque los signos remitan. Reconsultar si vuelve a vomitar.', 30
FROM consulta c JOIN mascota m ON m.id = c.mascota_id WHERE m.nombre = 'Max';

-- Max es ALÉRGICO A PENICILINA: se prescribe cefalexina, no amoxicilina.
INSERT INTO receta_detalle (receta_id, medicamento_id, dosis, frecuencia, duracion_dias,
                            via_administracion, cantidad, instrucciones)
SELECT r.id, med.id, x.dosis, x.frec, x.dias, x.via, x.cant, x.inst
FROM receta r JOIN consulta c ON c.id = r.consulta_id
JOIN mascota m ON m.id = c.mascota_id, medicamento med, (VALUES
 ('Cefalexina 300 mg','1 comprimido','cada 12 horas', 7,'ORAL',14,'Administrar con comida'),
 ('Meloxicam oral',   '1,5 ml',      'cada 24 horas', 3,'ORAL', 1,'Solo si persiste el dolor abdominal')
) AS x(nom, dosis, frec, dias, via, cant, inst)
WHERE m.nombre = 'Max' AND med.nombre = x.nom;

-- ── Vacunación ──────────────────────────────────────────────────────────────
-- El trigger calcula fecha_proximo_refuerzo desde el intervalo del catálogo.
INSERT INTO aplicacion_vacuna (mascota_id, vacuna_id, veterinario_id, fecha_aplicacion,
                               lote, dosis_numero)
SELECT m.id, vac.id, v.id, x.fecha, x.lote, x.dosis
FROM mascota m, vacuna vac, veterinario v, (VALUES
 ('Max',  'Quíntuple canina','MV-14872', CURRENT_DATE - 300,'QC-2025-0871', 3),
 ('Max',  'Antirrábica',     'MV-14872', CURRENT_DATE - 300,'AR-2025-1120', 3),
 ('Toby', 'Quíntuple canina','MV-14872', CURRENT_DATE -  40,'QC-2026-0233', 5),
 ('Toby', 'Antirrábica',     'MV-14872', CURRENT_DATE -  40,'AR-2026-0455', 5),
 ('Luna', 'Triple felina',   'MV-19045', CURRENT_DATE - 340,'TF-2025-0612', 2),
 ('Nala', 'Quíntuple canina','MV-09876', CURRENT_DATE - 355,'QC-2025-0790', 6),
 ('Zeus', 'Antirrábica',     'MV-09876', CURRENT_DATE - 200,'AR-2025-1301', 7),
 ('Simba','Triple felina',   'MV-19045', CURRENT_DATE - 370,'TF-2025-0501', 2),
 ('Mishi','Triple felina',   'MV-19045', CURRENT_DATE - 120,'TF-2026-0118', 4)
) AS x(masc, vac, mat, fecha, lote, dosis)
WHERE m.nombre = x.masc AND vac.nombre = x.vac AND v.matricula = x.mat;

-- ── Facturación ─────────────────────────────────────────────────────────────
-- Factura pagada: consulta + medicamentos de Max.
INSERT INTO factura (cliente_id, fecha_emision)
SELECT id, CURRENT_DATE - 20 FROM cliente WHERE documento = '1012345678';

INSERT INTO factura_detalle (factura_id, servicio_id, medicamento_id, mascota_id,
                             linea_nro, descripcion, cantidad, precio_unitario)
SELECT f.id, s.id, NULL, m.id, 1, s.nombre, 1, s.precio_base
FROM factura f JOIN cliente c ON c.id = f.cliente_id, servicio s, mascota m
WHERE c.documento = '1012345678' AND f.fecha_emision = CURRENT_DATE - 20
  AND s.codigo = 'SRV-001' AND m.nombre = 'Max';

INSERT INTO factura_detalle (factura_id, servicio_id, medicamento_id, mascota_id,
                             linea_nro, descripcion, cantidad, precio_unitario)
SELECT f.id, NULL, med.id, m.id, 2, med.nombre, 2, med.precio
FROM factura f JOIN cliente c ON c.id = f.cliente_id, medicamento med, mascota m
WHERE c.documento = '1012345678' AND f.fecha_emision = CURRENT_DATE - 20
  AND med.nombre = 'Cefalexina 300 mg' AND m.nombre = 'Max';

INSERT INTO pago (factura_id, metodo_pago_id, monto, fecha_hora)
SELECT f.id, mp.id, f.total, (CURRENT_DATE - 20 + TIME '10:15')::timestamptz
FROM factura f JOIN cliente c ON c.id = f.cliente_id, metodo_pago mp
WHERE c.documento = '1012345678' AND f.fecha_emision = CURRENT_DATE - 20
  AND mp.nombre = 'Efectivo';

-- Factura con pago parcial: control de Zeus.
INSERT INTO factura (cliente_id, fecha_emision)
SELECT id, CURRENT_DATE - 10 FROM cliente WHERE documento = '1045678901';

INSERT INTO factura_detalle (factura_id, servicio_id, mascota_id, linea_nro,
                             descripcion, cantidad, precio_unitario)
SELECT f.id, s.id, m.id, x.linea, s.nombre, 1, s.precio_base
FROM factura f JOIN cliente c ON c.id = f.cliente_id, servicio s, mascota m,
     (VALUES (1,'SRV-001'), (2,'SRV-023')) AS x(linea, cod)
WHERE c.documento = '1045678901' AND f.fecha_emision = CURRENT_DATE - 10
  AND s.codigo = x.cod AND m.nombre = 'Zeus';

INSERT INTO pago (factura_id, metodo_pago_id, monto, referencia, fecha_hora)
SELECT f.id, mp.id, 80000, 'TRF-889231', (CURRENT_DATE - 10 + TIME '11:00')::timestamptz
FROM factura f JOIN cliente c ON c.id = f.cliente_id, metodo_pago mp
WHERE c.documento = '1045678901' AND f.fecha_emision = CURRENT_DATE - 10
  AND mp.nombre = 'Transferencia';

-- Factura impaga: vacunación de Toby.
INSERT INTO factura (cliente_id, fecha_emision)
SELECT id, CURRENT_DATE - 40 FROM cliente WHERE documento = '1012345678';

INSERT INTO factura_detalle (factura_id, servicio_id, mascota_id, linea_nro,
                             descripcion, cantidad, precio_unitario)
SELECT f.id, s.id, m.id, 1, s.nombre, 2, s.precio_base
FROM factura f JOIN cliente c ON c.id = f.cliente_id, servicio s, mascota m
WHERE c.documento = '1012345678' AND f.fecha_emision = CURRENT_DATE - 40
  AND s.codigo = 'SRV-010' AND m.nombre = 'Toby';

-- ── Solicitudes del sitio público ───────────────────────────────────────────
INSERT INTO solicitud_cita (especie_id, nombre_contacto, telefono_contacto,
                            email_contacto, nombre_mascota, motivo, fecha_preferida,
                            franja_preferida, estado)
SELECT e.id, x.nom, x.tel, x.mail, x.masc, x.mot, x.fecha, x.franja, x.est
FROM especie e, (VALUES
 ('Canino','Federico Alsina','+57 320 900 1122','falsina@correo.com','Rocky',
  'Cojera de la pata trasera derecha desde hace dos días', CURRENT_DATE + 2,'MANANA','nueva'),
 ('Felino','Paula Duarte',   '+57 321 900 3344', NULL,               'Nube',
  'Primera consulta, gatita de tres meses', CURRENT_DATE + 4,'TARDE','contactada'),
 ('Canino','Ignacio Vera',   '+57 322 900 5566','ivera@correo.com',  NULL,
  'Quiero cotizar una esterilización', NULL,'INDIFERENTE','nueva')
) AS x(esp, nom, tel, mail, masc, mot, fecha, franja, est)
WHERE e.nombre = x.esp;
