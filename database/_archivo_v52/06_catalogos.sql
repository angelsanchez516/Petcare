-- ============================================================================
--  PETCARE — 06_catalogos.sql · Datos maestros
-- ----------------------------------------------------------------------------
--  Contenido de referencia que el sistema necesita para funcionar: roles,
--  permisos, especies, razas, diagnósticos, servicios, vacunas.
--  NO son datos de prueba: en producción estas filas también existen.
--  Los datos de ejemplo (clientes, mascotas, consultas) van en 07_demo.sql.
-- ============================================================================

SET client_min_messages = WARNING;

-- ============================================================================
--  SEGURIDAD
-- ============================================================================

INSERT INTO cargo (nombre, descripcion) VALUES
 ('Veterinario',    'Profesional habilitado para el acto médico'),
 ('Recepcionista',  'Atención al público, agenda y facturación'),
 ('Auxiliar',       'Asistencia en consultorio y cuidado de internados'),
 ('Administrador',  'Gestión general de la clínica');

INSERT INTO rol (codigo, nombre, descripcion) VALUES
 ('ADMINISTRADOR', 'Administrador', 'Acceso completo al sistema'),
 ('VETERINARIO',   'Veterinario',   'Información clínica y agenda propia'),
 ('RECEPCIONISTA', 'Recepcionista', 'Clientes, mascotas, citas y facturación'),
 ('INVENTARIO',    'Inventario',    'Productos, compras y control de stock');

INSERT INTO permiso (codigo, modulo, descripcion) VALUES
 ('cliente.ver',        'Clientes',    'Consultar tutores'),
 ('cliente.editar',     'Clientes',    'Crear y modificar tutores'),
 ('mascota.ver',        'Mascotas',    'Consultar mascotas'),
 ('mascota.editar',     'Mascotas',    'Crear y modificar mascotas'),
 ('cita.ver',           'Agenda',      'Consultar la agenda'),
 ('cita.editar',        'Agenda',      'Agendar, confirmar y cancelar citas'),
 ('consulta.ver',       'Clinica',     'Consultar el historial clínico'),
 ('consulta.crear',     'Clinica',     'Registrar consultas y diagnósticos'),
 ('receta.crear',       'Clinica',     'Emitir recetas'),
 ('vacuna.aplicar',     'Clinica',     'Registrar aplicaciones de vacuna'),
 ('cirugia.gestionar',  'Clinica',     'Programar y registrar cirugías'),
 ('hospital.gestionar', 'Clinica',     'Gestionar internaciones'),
 ('factura.ver',        'Facturacion', 'Consultar facturas'),
 ('factura.emitir',     'Facturacion', 'Emitir facturas y registrar cobros'),
 ('inventario.ver',     'Inventario',  'Consultar stock'),
 ('inventario.mover',   'Inventario',  'Registrar compras y ajustes de stock'),
 ('reporte.ver',        'Reportes',    'Acceder a los reportes'),
 ('usuario.gestionar',  'Seguridad',   'Administrar usuarios y roles');

-- El administrador recibe todos los permisos.
INSERT INTO rol_permiso (rol_id, permiso_id)
SELECT r.id, p.id FROM rol r CROSS JOIN permiso p WHERE r.codigo = 'ADMINISTRADOR';

-- El veterinario: todo lo clínico, la agenda y los reportes. NO factura.
INSERT INTO rol_permiso (rol_id, permiso_id)
SELECT r.id, p.id FROM rol r JOIN permiso p ON p.codigo IN (
    'cliente.ver','mascota.ver','mascota.editar','cita.ver','cita.editar',
    'consulta.ver','consulta.crear','receta.crear','vacuna.aplicar',
    'cirugia.gestionar','hospital.gestionar','inventario.ver','reporte.ver')
WHERE r.codigo = 'VETERINARIO';

-- El recepcionista: mostrador. Ve el historial pero NO puede crear consultas.
INSERT INTO rol_permiso (rol_id, permiso_id)
SELECT r.id, p.id FROM rol r JOIN permiso p ON p.codigo IN (
    'cliente.ver','cliente.editar','mascota.ver','mascota.editar',
    'cita.ver','cita.editar','consulta.ver','factura.ver','factura.emitir',
    'inventario.ver')
WHERE r.codigo = 'RECEPCIONISTA';

INSERT INTO rol_permiso (rol_id, permiso_id)
SELECT r.id, p.id FROM rol r JOIN permiso p ON p.codigo IN (
    'inventario.ver','inventario.mover','reporte.ver')
WHERE r.codigo = 'INVENTARIO';

INSERT INTO especialidad (nombre, descripcion) VALUES
 ('Medicina general',        'Atención clínica general de pequeños animales'),
 ('Cirugía de tejidos blandos', 'Procedimientos abdominales y de partes blandas'),
 ('Traumatología',           'Lesiones óseas y articulares'),
 ('Dermatología',            'Patologías de piel y anexos'),
 ('Cardiología',             'Enfermedades cardiovasculares'),
 ('Oftalmología',            'Patologías oculares'),
 ('Animales exóticos',       'Aves, reptiles y pequeños mamíferos'),
 ('Anestesiología',          'Manejo anestésico y del dolor'),
 ('Odontología',             'Salud bucal y cirugía dental');


-- ============================================================================
--  TAXONOMÍA
-- ============================================================================

INSERT INTO especie (nombre, nombre_cientifico, icono, esperanza_vida_anios) VALUES
 ('Canino',   'Canis lupus familiaris', '🐕', 13),
 ('Felino',   'Felis catus',            '🐈', 15),
 ('Ave',      'Aves',                   '🦜', 20),
 ('Roedor',   'Rodentia',               '🐹',  3),
 ('Conejo',   'Oryctolagus cuniculus',  '🐇',  9),
 ('Reptil',   'Reptilia',               '🦎', 20),
 ('Equino',   'Equus ferus caballus',   '🐴', 28);

-- Razas caninas
INSERT INTO raza (especie_id, nombre, tamanio, predisposiciones)
SELECT e.id, r.nombre, r.tam, r.pred
FROM especie e, (VALUES
 ('Labrador Retriever', 'GRANDE',  'Displasia de cadera, obesidad, otitis'),
 ('Golden Retriever',   'GRANDE',  'Displasia de cadera, neoplasias'),
 ('Pastor Alemán',      'GRANDE',  'Displasia de cadera, mielopatía degenerativa'),
 ('Bulldog Francés',    'PEQUENO', 'Síndrome braquicefálico, dermatitis de pliegues'),
 ('Chihuahua',          'PEQUENO', 'Luxación de rótula, hidrocefalia'),
 ('Poodle',             'MEDIANO', 'Luxación de rótula, atrofia progresiva de retina'),
 ('Beagle',             'MEDIANO', 'Obesidad, epilepsia idiopática'),
 ('Yorkshire Terrier',  'PEQUENO', 'Colapso traqueal, luxación de rótula'),
 ('Rottweiler',         'GRANDE',  'Displasia de codo, cardiopatías'),
 ('Schnauzer',          'MEDIANO', 'Pancreatitis, hiperlipidemia'),
 ('Mestizo',            'MEDIANO', NULL)
) AS r(nombre, tam, pred)
WHERE e.nombre = 'Canino';

-- Razas felinas
INSERT INTO raza (especie_id, nombre, tamanio, predisposiciones)
SELECT e.id, r.nombre, r.tam, r.pred
FROM especie e, (VALUES
 ('Siamés',            'MEDIANO', 'Amiloidosis, asma felino'),
 ('Persa',             'MEDIANO', 'Poliquistosis renal, síndrome braquicefálico'),
 ('Maine Coon',        'GRANDE',  'Cardiomiopatía hipertrófica'),
 ('Angora',            'MEDIANO', NULL),
 ('Bengalí',           'MEDIANO', 'Cardiomiopatía hipertrófica'),
 ('Esfinge',           'MEDIANO', 'Dermatitis, cardiomiopatía'),
 ('Mestizo',           'MEDIANO', NULL)
) AS r(nombre, tam, pred)
WHERE e.nombre = 'Felino';

INSERT INTO raza (especie_id, nombre, tamanio)
SELECT e.id, r.nombre, r.tam
FROM especie e, (VALUES ('Canario','PEQUENO'), ('Periquito','PEQUENO'), ('Loro','MEDIANO'))
  AS r(nombre, tam)
WHERE e.nombre = 'Ave';

INSERT INTO raza (especie_id, nombre, tamanio)
SELECT e.id, r.nombre, r.tam
FROM especie e, (VALUES ('Hámster sirio','PEQUENO'), ('Cobayo','PEQUENO'))
  AS r(nombre, tam)
WHERE e.nombre = 'Roedor';


-- ============================================================================
--  CONDICIONES MÉDICAS
-- ============================================================================

INSERT INTO condicion_medica (nombre, tipo, descripcion) VALUES
 ('Alergia a penicilina',      'ALERGIA',   'Reacción a betalactámicos'),
 ('Alergia alimentaria a pollo','ALERGIA',  'Dermatitis y trastorno digestivo tras ingesta'),
 ('Dermatitis atópica',        'ALERGIA',   'Hipersensibilidad ambiental'),
 ('Alergia a picadura de pulga','ALERGIA',  'Dermatitis alérgica por pulgas'),
 ('Diabetes mellitus',         'CRONICA',   'Requiere insulina y control glucémico'),
 ('Insuficiencia renal crónica','CRONICA',  'Requiere dieta renal y control periódico'),
 ('Epilepsia idiopática',      'CRONICA',   'Convulsiones recurrentes sin causa estructural'),
 ('Cardiopatía valvular',      'CRONICA',   'Degeneración mixomatosa de la mitral'),
 ('Hipotiroidismo',            'CRONICA',   'Requiere levotiroxina de por vida'),
 ('Displasia de cadera',       'CONGENITA', 'Malformación articular hereditaria'),
 ('Síndrome braquicefálico',   'CONGENITA', 'Obstrucción de vías aéreas superiores'),
 ('Soplo cardíaco congénito',  'CONGENITA', 'Detectado en la primera consulta');


-- ============================================================================
--  DIAGNÓSTICOS — jerarquía recursiva de tres niveles
-- ----------------------------------------------------------------------------
--  La columna nivel la calcula el trigger tg_diagnostico_jerarquia.
-- ============================================================================

-- Nivel 1: sistemas
INSERT INTO diagnostico (codigo, nombre, descripcion) VALUES
 ('SIS-DIG', 'Sistema digestivo',    'Patologías del aparato digestivo'),
 ('SIS-DER', 'Sistema tegumentario', 'Patologías de piel y anexos'),
 ('SIS-RES', 'Sistema respiratorio', 'Patologías de vías aéreas y pulmón'),
 ('SIS-LOC', 'Sistema locomotor',    'Patologías óseas, articulares y musculares'),
 ('SIS-URI', 'Sistema urinario',     'Patologías renales y de vías urinarias'),
 ('SIS-CAR', 'Sistema cardiovascular','Patologías del corazón y los vasos'),
 ('SIS-INF', 'Enfermedades infecciosas', 'Origen viral, bacteriano o parasitario');

-- Nivel 2 y 3
INSERT INTO diagnostico (padre_id, codigo, nombre)
SELECT p.id, d.codigo, d.nombre
FROM diagnostico p, (VALUES
 ('SIS-DIG','GAS-001','Gastritis'),
 ('SIS-DIG','GAS-010','Enteritis'),
 ('SIS-DIG','GAS-020','Pancreatitis'),
 ('SIS-DIG','GAS-030','Cuerpo extraño gastrointestinal')
) AS d(padre, codigo, nombre)
WHERE p.codigo = d.padre;

INSERT INTO diagnostico (padre_id, codigo, nombre)
SELECT p.id, d.codigo, d.nombre
FROM diagnostico p, (VALUES
 ('GAS-001','GAS-002','Gastritis aguda'),
 ('GAS-001','GAS-003','Gastritis crónica')
) AS d(padre, codigo, nombre)
WHERE p.codigo = d.padre;

INSERT INTO diagnostico (padre_id, codigo, nombre)
SELECT p.id, d.codigo, d.nombre
FROM diagnostico p, (VALUES
 ('SIS-DER','DER-001','Dermatitis alérgica'),
 ('SIS-DER','DER-010','Otitis externa'),
 ('SIS-DER','DER-020','Sarna sarcóptica'),
 ('SIS-DER','DER-030','Piodermia superficial'),
 ('SIS-RES','RES-001','Traqueobronquitis infecciosa'),
 ('SIS-RES','RES-010','Neumonía'),
 ('SIS-RES','RES-020','Asma felino'),
 ('SIS-LOC','LOC-001','Displasia de cadera'),
 ('SIS-LOC','LOC-010','Luxación de rótula'),
 ('SIS-LOC','LOC-020','Fractura de fémur'),
 ('SIS-LOC','LOC-030','Artrosis'),
 ('SIS-URI','URI-001','Insuficiencia renal crónica'),
 ('SIS-URI','URI-010','Cistitis'),
 ('SIS-URI','URI-020','Urolitiasis'),
 ('SIS-CAR','CAR-001','Insuficiencia cardíaca congestiva'),
 ('SIS-CAR','CAR-010','Cardiomiopatía hipertrófica'),
 ('SIS-INF','INF-001','Parvovirosis canina'),
 ('SIS-INF','INF-010','Moquillo canino'),
 ('SIS-INF','INF-020','Leucemia felina'),
 ('SIS-INF','INF-030','Parasitosis intestinal')
) AS d(padre, codigo, nombre)
WHERE p.codigo = d.padre;


-- ============================================================================
--  SERVICIOS
-- ============================================================================

INSERT INTO servicio (codigo, nombre, categoria, precio_base, duracion_estimada_min, icono, visible_publico, descripcion) VALUES
 ('SRV-001','Consulta general',            'CONSULTA',        35000, 30, '🩺', TRUE,  'Examen clínico completo con signos vitales'),
 ('SRV-002','Consulta de urgencia',        'CONSULTA',        60000, 45, '🚨', TRUE,  'Atención inmediata sin turno previo'),
 ('SRV-003','Consulta de control',         'CONSULTA',        20000, 20, '📋', TRUE,  'Seguimiento de un tratamiento en curso'),
 ('SRV-004','Consulta a domicilio',        'CONSULTA',        85000, 60, '🏠', TRUE,  'Atención en el domicilio del tutor'),
 ('SRV-010','Vacunación',                  'VACUNACION',      25000, 15, '💉', TRUE,  'Aplicación de biológico con registro de lote'),
 ('SRV-011','Desparasitación',             'VACUNACION',      18000, 15, '🪱', TRUE,  'Antiparasitario interno o externo'),
 ('SRV-020','Ecografía abdominal',         'DIAGNOSTICO',     70000, 40, '🔬', TRUE,  'Estudio ecográfico de abdomen'),
 ('SRV-021','Radiografía',                 'DIAGNOSTICO',     55000, 30, '🩻', TRUE,  'Estudio radiográfico, una proyección'),
 ('SRV-022','Electrocardiograma',          'DIAGNOSTICO',     60000, 30, '❤️', TRUE,  'Trazado electrocardiográfico'),
 ('SRV-030','Castración felina',           'CIRUGIA',        180000, 60, '⚕️', TRUE,  'Orquiectomía u ovariohisterectomía en felinos'),
 ('SRV-031','Castración canina',           'CIRUGIA',        250000, 90, '⚕️', TRUE,  'Orquiectomía u ovariohisterectomía en caninos'),
 ('SRV-032','Cirugía de tejidos blandos',  'CIRUGIA',        420000,120, '⚕️', TRUE,  'Procedimiento abdominal programado'),
 ('SRV-033','Limpieza dental',             'CIRUGIA',        160000, 60, '🦷', TRUE,  'Profilaxis dental bajo anestesia'),
 ('SRV-040','Baño y corte',                'ESTETICA',        45000, 60, '🛁', TRUE,  'Higiene y corte de pelo'),
 ('SRV-041','Corte de uñas',               'ESTETICA',        12000, 15, '✂️', TRUE,  'Recorte de uñas y limpieza de almohadillas'),
 -- Duración NULL, no 0: estos servicios se cobran por día y no ocupan un
 -- turno de agenda, así que no tienen duración estimada.
 ('SRV-050','Internación por día',         'HOSPITALIZACION', 95000,  NULL, '🏥', TRUE,  'Hospitalización con controles cada turno'),
 ('SRV-051','Internación en UCI por día',  'HOSPITALIZACION',175000,  NULL, '🏥', FALSE, 'Cuidados intensivos con monitoreo continuo');


-- ============================================================================
--  EXÁMENES
-- ============================================================================

INSERT INTO examen (codigo, nombre, tipo, precio, preparacion) VALUES
 ('EX-001','Hemograma completo',        'LABORATORIO', 45000, NULL),
 ('EX-002','Perfil bioquímico',         'LABORATORIO', 68000, 'Ayuno de 8 horas'),
 ('EX-003','Función renal (urea/creatinina)','LABORATORIO', 38000, 'Ayuno de 8 horas'),
 ('EX-004','Función hepática',          'LABORATORIO', 42000, 'Ayuno de 8 horas'),
 ('EX-005','Glucemia',                  'LABORATORIO', 15000, 'Ayuno de 8 horas'),
 ('EX-006','Coprológico',               'LABORATORIO', 22000, 'Muestra fresca de menos de 12 horas'),
 ('EX-007','Urianálisis',               'LABORATORIO', 28000, NULL),
 ('EX-008','Test de leucemia felina',   'LABORATORIO', 55000, NULL),
 ('EX-010','Radiografía de tórax',      'IMAGEN',      55000, NULL),
 ('EX-011','Radiografía de abdomen',    'IMAGEN',      55000, 'Ayuno de 12 horas'),
 ('EX-012','Ecografía abdominal',       'IMAGEN',      70000, 'Ayuno de 12 horas, vejiga llena'),
 ('EX-013','Ecocardiograma',            'IMAGEN',     110000, NULL),
 ('EX-020','Citología cutánea',         'CITOLOGIA',   35000, NULL),
 ('EX-021','Raspado de piel',           'CITOLOGIA',   30000, 'No bañar al animal 48 horas antes');


-- ============================================================================
--  INVENTARIO — categorías, productos y medicamentos
-- ============================================================================

INSERT INTO categoria_producto (nombre, descripcion) VALUES
 ('Medicamentos', 'Productos con acción farmacológica'),
 ('Biológicos',   'Vacunas y sueros'),
 ('Alimento',     'Alimento balanceado y dietas'),
 ('Accesorios',   'Collares, correas, juguetes'),
 ('Insumos',      'Material descartable de consultorio');

INSERT INTO categoria_producto (padre_id, nombre)
SELECT p.id, c.nombre FROM categoria_producto p, (VALUES
 ('Medicamentos','Antibióticos'),
 ('Medicamentos','Antiparasitarios'),
 ('Medicamentos','Antiinflamatorios'),
 ('Medicamentos','Dermatológicos'),
 ('Alimento','Alimento medicado')
) AS c(padre, nombre)
WHERE p.nombre = c.padre;

INSERT INTO categoria_producto (padre_id, nombre)
SELECT p.id, 'Dieta renal' FROM categoria_producto p WHERE p.nombre = 'Alimento medicado';

-- Productos. es_medicamento marca cuáles tendrán fila en el subtipo.
INSERT INTO producto (categoria_id, codigo, nombre, unidad_medida, precio_venta, stock_minimo, es_medicamento)
SELECT c.id, p.codigo, p.nombre, p.unidad, p.precio, p.minimo, p.es_med
FROM categoria_producto c, (VALUES
 ('Antibióticos',    'MED-001','Amoxicilina 500 mg x 10 comprimidos', 'CAJA',   28000, 10, TRUE),
 ('Antibióticos',    'MED-002','Enrofloxacina 50 mg/ml x 20 ml',      'FRASCO', 42000,  5, TRUE),
 ('Antibióticos',    'MED-003','Cefalexina 300 mg x 12 comprimidos',  'CAJA',   34000,  8, TRUE),
 ('Antiinflamatorios','MED-010','Meloxicam 1,5 mg/ml x 10 ml',        'FRASCO', 38000,  6, TRUE),
 ('Antiinflamatorios','MED-011','Carprofeno 50 mg x 14 comprimidos',  'CAJA',   46000,  6, TRUE),
 ('Antiparasitarios','MED-020','Antiparasitario interno x 4 comprimidos','CAJA',24000, 15, TRUE),
 ('Antiparasitarios','MED-021','Pipeta antipulgas 2-10 kg',           'UNIDAD', 19000, 20, TRUE),
 ('Antiparasitarios','MED-022','Pipeta antipulgas 10-25 kg',          'UNIDAD', 23000, 20, TRUE),
 ('Dermatológicos',  'MED-030','Shampoo con clorhexidina x 250 ml',   'FRASCO', 32000,  6, TRUE),
 ('Dermatológicos',  'MED-031','Otológico con antibiótico x 15 ml',   'FRASCO', 27000,  8, TRUE),
 ('Medicamentos',    'MED-040','Insulina veterinaria x 10 ml',        'FRASCO',120000,  3, TRUE),
 ('Biológicos',      'BIO-001','Vacuna quíntuple canina',             'AMPOLLA',32000, 10, FALSE),
 ('Biológicos',      'BIO-002','Vacuna antirrábica',                  'AMPOLLA',24000, 15, FALSE),
 ('Biológicos',      'BIO-003','Vacuna triple felina',                'AMPOLLA',30000, 10, FALSE),
 ('Biológicos',      'BIO-004','Vacuna contra leucemia felina',       'AMPOLLA',38000,  8, FALSE),
 ('Biológicos',      'BIO-005','Vacuna contra tos de las perreras',   'AMPOLLA',28000,  8, FALSE),
 ('Dieta renal',     'ALI-001','Alimento renal canino x 2 kg',        'KG',     78000,  4, FALSE),
 ('Dieta renal',     'ALI-002','Alimento renal felino x 1,5 kg',      'KG',     72000,  4, FALSE),
 ('Alimento',        'ALI-010','Alimento adulto canino x 15 kg',      'KG',     95000,  6, FALSE),
 ('Accesorios',      'ACC-001','Collar isabelino mediano',            'UNIDAD', 18000, 10, FALSE),
 ('Insumos',         'INS-001','Jeringa 5 ml estéril',                'UNIDAD',   900,100, FALSE),
 ('Insumos',         'INS-002','Gasa estéril 10x10',                  'UNIDAD',  1200,100, FALSE)
) AS p(categoria, codigo, nombre, unidad, precio, minimo, es_med)
WHERE c.nombre = p.categoria;

-- Subtipo medicamento: solo para los productos marcados como tales.
INSERT INTO medicamento (producto_id, principio_activo, concentracion, presentacion,
                         via_administracion, requiere_receta, contraindicaciones, laboratorio)
SELECT p.id, m.principio, m.conc, m.pres, m.via, m.receta, m.contra, m.lab
FROM producto p, (VALUES
 ('MED-001','Amoxicilina',   '500 mg',    'COMPRIMIDO','ORAL',       TRUE, 'Hipersensibilidad a betalactámicos','Laboratorio Vet SA'),
 ('MED-002','Enrofloxacina', '50 mg/ml',  'INYECTABLE','SUBCUTANEA', TRUE, 'No usar en cachorros en crecimiento','Laboratorio Vet SA'),
 ('MED-003','Cefalexina',    '300 mg',    'COMPRIMIDO','ORAL',       TRUE, 'Hipersensibilidad a cefalosporinas','Bio Animal'),
 ('MED-010','Meloxicam',     '1,5 mg/ml', 'JARABE',    'ORAL',       TRUE, 'Insuficiencia renal, úlcera gástrica','Bio Animal'),
 ('MED-011','Carprofeno',    '50 mg',     'COMPRIMIDO','ORAL',       TRUE, 'Hepatopatías, uso conjunto con corticoides','Laboratorio Vet SA'),
 ('MED-020','Praziquantel + Pirantel', NULL,'COMPRIMIDO','ORAL',    FALSE, NULL,'Pet Health'),
 ('MED-021','Fipronil',      '67 mg',     'GOTAS',     'TOPICA',    FALSE, 'No aplicar sobre piel lesionada','Pet Health'),
 ('MED-022','Fipronil',      '134 mg',    'GOTAS',     'TOPICA',    FALSE, 'No aplicar sobre piel lesionada','Pet Health'),
 ('MED-030','Clorhexidina',  '2%',        'SPRAY',     'TOPICA',    FALSE, 'Evitar contacto con los ojos','Derma Vet'),
 ('MED-031','Gentamicina + Betametasona', NULL,'GOTAS','OTICA',      TRUE, 'Perforación timpánica','Derma Vet'),
 ('MED-040','Insulina porcina','40 UI/ml','INYECTABLE','SUBCUTANEA', TRUE, 'Hipoglucemia','Laboratorio Vet SA')
) AS m(codigo, principio, conc, pres, via, receta, contra, lab)
WHERE p.codigo = m.codigo;


-- ============================================================================
--  VACUNAS — enlazadas a su producto de inventario
-- ============================================================================

INSERT INTO vacuna (producto_id, nombre, laboratorio, enfermedades_previene,
                    dosis_ml, intervalo_refuerzo_meses, edad_minima_semanas, precio)
SELECT p.id, v.nombre, v.lab, v.previene, v.dosis, v.refuerzo, v.edad, v.precio
FROM producto p, (VALUES
 ('BIO-001','Quíntuple canina','Zoetis Vet','Moquillo, hepatitis, parvovirosis, parainfluenza y leptospirosis', 1.0, 12,  6, 45000),
 ('BIO-002','Antirrábica','Zoetis Vet','Rabia',                                                                  1.0, 12, 12, 38000),
 ('BIO-003','Triple felina','Bio Animal','Panleucopenia, rinotraqueítis y calicivirus',                           1.0, 12,  8, 42000),
 ('BIO-004','Leucemia felina','Bio Animal','Virus de la leucemia felina',                                         1.0, 12,  9, 52000),
 ('BIO-005','Tos de las perreras','Zoetis Vet','Bordetella bronchiseptica y parainfluenza',                       0.5, 12,  8, 40000)
) AS v(codigo, nombre, lab, previene, dosis, refuerzo, edad, precio)
WHERE p.codigo = v.codigo;

-- Qué vacuna sirve para qué especie. Esta es la tabla que impide aplicar una
-- vacuna canina a un felino.
INSERT INTO vacuna_especie (vacuna_id, especie_id)
SELECT v.id, e.id FROM vacuna v, especie e
WHERE (v.nombre IN ('Quíntuple canina','Tos de las perreras') AND e.nombre = 'Canino')
   OR (v.nombre IN ('Triple felina','Leucemia felina')        AND e.nombre = 'Felino')
   OR (v.nombre = 'Antirrábica' AND e.nombre IN ('Canino','Felino'));


-- ============================================================================
--  PROTOCOLOS DE TRATAMIENTO
-- ============================================================================

INSERT INTO protocolo_tratamiento (nombre, descripcion, indicaciones, duracion_dias_sugerida) VALUES
 ('Antibioticoterapia estándar canina',
  'Esquema de primera línea para infección bacteriana no complicada',
  'Administrar con alimento. Completar el ciclo aunque los signos remitan.', 7),
 ('Manejo del dolor postoperatorio',
  'Analgesia tras cirugía de tejidos blandos',
  'Controlar apetito y actividad. Suspender ante vómitos.', 5),
 ('Protocolo dermatológico antipulgas',
  'Tratamiento de dermatitis alérgica por picadura de pulga',
  'Tratar simultáneamente a todos los animales del hogar y el ambiente.', 30);

INSERT INTO protocolo_medicamento (protocolo_id, medicamento_id, dosis_sugerida,
                                   frecuencia_sugerida, duracion_dias, via_administracion)
SELECT pt.id, p.id, pm.dosis, pm.frec, pm.dias, pm.via
FROM protocolo_tratamiento pt, producto p, (VALUES
 ('Antibioticoterapia estándar canina','MED-001','1 comprimido cada 10 kg','cada 12 horas', 7,'ORAL'),
 ('Manejo del dolor postoperatorio','MED-010','0,1 ml por kg','cada 24 horas', 5,'ORAL'),
 ('Protocolo dermatológico antipulgas','MED-021','1 pipeta','dosis única mensual',30,'TOPICA'),
 ('Protocolo dermatológico antipulgas','MED-030','Aplicar y dejar actuar 10 min','2 veces por semana',30,'TOPICA')
) AS pm(protocolo, codigo, dosis, frec, dias, via)
WHERE pt.nombre = pm.protocolo AND p.codigo = pm.codigo;


-- ============================================================================
--  HABITACIONES Y MÉTODOS DE PAGO
-- ============================================================================

INSERT INTO habitacion (codigo, tipo, capacidad) VALUES
 ('GEN-01','GENERAL',      4),
 ('GEN-02','GENERAL',      4),
 ('FEL-01','FELINA',       3),
 ('AIS-01','AISLAMIENTO',  1),
 ('UCI-01','UCI',          2);

INSERT INTO metodo_pago (nombre, requiere_referencia) VALUES
 ('Efectivo',            FALSE),
 ('Tarjeta de débito',   TRUE),
 ('Tarjeta de crédito',  TRUE),
 ('Transferencia',       TRUE),
 ('Billetera virtual',   TRUE);
