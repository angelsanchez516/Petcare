-- ============================================================================
--  PETCARE — 06_catalogos.sql · Datos maestros
-- ----------------------------------------------------------------------------
--  Contenido de referencia que el sistema necesita para funcionar. NO son datos
--  de prueba: en producción estas filas también existen.
-- ============================================================================

SET client_min_messages = WARNING;

-- ── Seguridad ───────────────────────────────────────────────────────────────
INSERT INTO rol (nombre, descripcion) VALUES
 ('Administrador', 'Acceso completo al sistema'),
 ('Veterinario',   'Información clínica, historial y agenda'),
 ('Recepcionista', 'Clientes, mascotas, citas y facturación');

INSERT INTO especialidad (nombre, descripcion) VALUES
 ('Medicina general',          'Atención clínica general de pequeños animales'),
 ('Cirugía de tejidos blandos','Procedimientos abdominales y de partes blandas'),
 ('Traumatología',             'Lesiones óseas y articulares'),
 ('Dermatología',              'Patologías de piel y anexos'),
 ('Cardiología',               'Enfermedades cardiovasculares'),
 ('Oftalmología',              'Patologías oculares'),
 ('Animales exóticos',         'Aves, reptiles y pequeños mamíferos'),
 ('Odontología',               'Salud bucal y cirugía dental');

-- ── Taxonomía ───────────────────────────────────────────────────────────────
INSERT INTO especie (nombre, icono, esperanza_vida_anios) VALUES
 ('Canino', '🐕', 13), ('Felino', '🐈', 15), ('Ave', '🦜', 20),
 ('Roedor', '🐹',  3), ('Conejo', '🐇',  9), ('Reptil', '🦎', 20);

INSERT INTO raza (especie_id, nombre, tamanio)
SELECT e.id, r.nom, r.tam FROM especie e, (VALUES
 ('Labrador Retriever','GRANDE'), ('Golden Retriever','GRANDE'),
 ('Pastor Alemán','GRANDE'),      ('Rottweiler','GRANDE'),
 ('Bulldog Francés','PEQUENO'),   ('Chihuahua','PEQUENO'),
 ('Yorkshire Terrier','PEQUENO'), ('Pug','PEQUENO'),
 ('Poodle','MEDIANO'),            ('Beagle','MEDIANO'),
 ('Schnauzer','MEDIANO'),         ('Border Collie','MEDIANO'),
 ('Criollo','MEDIANO')
) AS r(nom, tam) WHERE e.nombre = 'Canino';

INSERT INTO raza (especie_id, nombre, tamanio)
SELECT e.id, r.nom, r.tam FROM especie e, (VALUES
 ('Siamés','MEDIANO'), ('Persa','MEDIANO'), ('Maine Coon','GRANDE'),
 ('Angora','MEDIANO'), ('Bengalí','MEDIANO'), ('Esfinge','MEDIANO'),
 ('Criollo','MEDIANO')
) AS r(nom, tam) WHERE e.nombre = 'Felino';

INSERT INTO raza (especie_id, nombre, tamanio)
SELECT e.id, r.nom, 'PEQUENO' FROM especie e,
 (VALUES ('Canario'), ('Periquito'), ('Loro')) AS r(nom) WHERE e.nombre = 'Ave';

INSERT INTO raza (especie_id, nombre, tamanio)
SELECT e.id, r.nom, 'PEQUENO' FROM especie e,
 (VALUES ('Hámster sirio'), ('Cobayo')) AS r(nom) WHERE e.nombre = 'Roedor';

-- ── Condiciones médicas ─────────────────────────────────────────────────────
INSERT INTO condicion_medica (nombre, tipo, descripcion) VALUES
 ('Alergia a penicilina',        'ALERGIA',   'Reacción a betalactámicos'),
 ('Alergia alimentaria a pollo', 'ALERGIA',   'Dermatitis y trastorno digestivo'),
 ('Dermatitis atópica',          'ALERGIA',   'Hipersensibilidad ambiental'),
 ('Alergia a picadura de pulga', 'ALERGIA',   'Dermatitis alérgica por pulgas'),
 ('Diabetes mellitus',           'CRONICA',   'Requiere insulina y control glucémico'),
 ('Insuficiencia renal crónica', 'CRONICA',   'Requiere dieta renal y control periódico'),
 ('Epilepsia idiopática',        'CRONICA',   'Convulsiones sin causa estructural'),
 ('Cardiopatía valvular',        'CRONICA',   'Degeneración de la válvula mitral'),
 ('Hipotiroidismo',              'CRONICA',   'Requiere levotiroxina de por vida'),
 ('Displasia de cadera',         'CONGENITA', 'Malformación articular hereditaria'),
 ('Síndrome braquicefálico',     'CONGENITA', 'Obstrucción de vías aéreas superiores');

-- ── Diagnósticos ────────────────────────────────────────────────────────────
INSERT INTO diagnostico (codigo, nombre, categoria) VALUES
 ('GAS-001','Gastritis aguda',                 'Digestivo'),
 ('GAS-002','Gastritis crónica',               'Digestivo'),
 ('GAS-010','Enteritis',                       'Digestivo'),
 ('GAS-020','Pancreatitis',                    'Digestivo'),
 ('GAS-030','Cuerpo extraño gastrointestinal', 'Digestivo'),
 ('DER-001','Dermatitis alérgica',             'Dermatológico'),
 ('DER-010','Otitis externa',                  'Dermatológico'),
 ('DER-020','Sarna sarcóptica',                'Dermatológico'),
 ('DER-030','Piodermia superficial',           'Dermatológico'),
 ('RES-001','Traqueobronquitis infecciosa',    'Respiratorio'),
 ('RES-010','Neumonía',                        'Respiratorio'),
 ('RES-020','Asma felino',                     'Respiratorio'),
 ('LOC-001','Displasia de cadera',             'Locomotor'),
 ('LOC-010','Luxación de rótula',              'Locomotor'),
 ('LOC-020','Fractura de fémur',               'Locomotor'),
 ('LOC-030','Artrosis',                        'Locomotor'),
 ('URI-001','Insuficiencia renal crónica',     'Urinario'),
 ('URI-010','Cistitis',                        'Urinario'),
 ('URI-020','Urolitiasis',                     'Urinario'),
 ('CAR-001','Insuficiencia cardíaca congestiva','Cardiovascular'),
 ('CAR-010','Cardiomiopatía hipertrófica',     'Cardiovascular'),
 ('INF-001','Parvovirosis canina',             'Infeccioso'),
 ('INF-010','Moquillo canino',                 'Infeccioso'),
 ('INF-020','Leucemia felina',                 'Infeccioso'),
 ('INF-030','Parasitosis intestinal',          'Infeccioso');

-- ── Servicios (precios en pesos colombianos) ────────────────────────────────
INSERT INTO servicio (codigo, nombre, categoria, precio_base, duracion_estimada_min,
                      icono, visible_publico, descripcion) VALUES
 ('SRV-001','Consulta general',       'CONSULTA',     65000,  30, '🩺', TRUE,
  'Examen clínico completo con registro de signos vitales, peso y revisión por sistemas.'),
 ('SRV-002','Consulta de urgencia',   'CONSULTA',    120000,  45, '🚨', TRUE,
  'Atención inmediata sin turno previo para situaciones que no pueden esperar.'),
 ('SRV-003','Consulta de control',    'CONSULTA',     40000,  20, '📋', TRUE,
  'Seguimiento de un tratamiento en curso y verificación de la evolución.'),
 ('SRV-004','Consulta a domicilio',   'CONSULTA',    160000,  60, '🏠', TRUE,
  'Atención en el domicilio, ideal para pacientes geriátricos o de difícil traslado.'),
 ('SRV-010','Vacunación',             'VACUNACION',   55000,  15, '💉', TRUE,
  'Aplicación de biológico con registro de lote y programación del refuerzo.'),
 ('SRV-011','Desparasitación',        'VACUNACION',   38000,  15, '🪱', TRUE,
  'Antiparasitario interno o externo según el peso y la edad del paciente.'),
 ('SRV-020','Ecografía abdominal',    'DIAGNOSTICO', 140000,  40, '🔬', TRUE,
  'Estudio ecográfico de abdomen con informe del especialista.'),
 ('SRV-021','Radiografía',            'DIAGNOSTICO', 110000,  30, '🩻', TRUE,
  'Estudio radiográfico digital, una proyección, con lectura incluida.'),
 ('SRV-022','Electrocardiograma',     'DIAGNOSTICO', 125000,  30, '❤️', TRUE,
  'Trazado electrocardiográfico para evaluación de arritmias.'),
 ('SRV-023','Perfil de laboratorio',  'DIAGNOSTICO',  95000,  20, '🧪', TRUE,
  'Hemograma y bioquímica sanguínea con resultados en 24 horas.'),
 ('SRV-030','Esterilización felina',  'CIRUGIA',     280000,  60, '⚕️', TRUE,
  'Procedimiento quirúrgico con anestesia, monitoreo y medicación posoperatoria.'),
 ('SRV-031','Esterilización canina',  'CIRUGIA',     390000,  90, '⚕️', TRUE,
  'Procedimiento quirúrgico con anestesia, monitoreo y medicación posoperatoria.'),
 ('SRV-032','Cirugía de tejidos blandos','CIRUGIA',  650000, 120, '⚕️', TRUE,
  'Procedimiento abdominal programado con evaluación prequirúrgica.'),
 ('SRV-033','Profilaxis dental',      'CIRUGIA',     240000,  60, '🦷', TRUE,
  'Limpieza dental bajo anestesia con pulido y revisión de piezas.'),
 ('SRV-040','Baño y peluquería',      'ESTETICA',     70000,  60, '🛁', TRUE,
  'Baño con productos hipoalergénicos, secado y corte según la raza.'),
 ('SRV-041','Corte de uñas',          'ESTETICA',     20000,  15, '✂️', TRUE,
  'Recorte de uñas y revisión de almohadillas.');

-- ── Medicamentos ────────────────────────────────────────────────────────────
INSERT INTO medicamento (nombre, principio_activo, presentacion, concentracion,
                         laboratorio, requiere_receta, stock, stock_minimo, precio) VALUES
 ('Amoxicilina 500 mg','Amoxicilina','COMPRIMIDO','500 mg','Vetlab', TRUE, 40, 10, 32000),
 ('Cefalexina 300 mg','Cefalexina','COMPRIMIDO','300 mg','Bio Animal', TRUE, 35,  8, 38000),
 ('Enrofloxacina inyectable','Enrofloxacina','INYECTABLE','50 mg/ml','Vetlab', TRUE, 18,  5, 46000),
 ('Meloxicam oral','Meloxicam','JARABE','1,5 mg/ml','Bio Animal', TRUE, 22,  6, 42000),
 ('Carprofeno 50 mg','Carprofeno','COMPRIMIDO','50 mg','Vetlab', TRUE, 20,  6, 51000),
 ('Antiparasitario interno','Praziquantel + Pirantel','COMPRIMIDO',NULL,'Pet Health', FALSE, 60, 15, 27000),
 ('Pipeta antipulgas 2-10 kg','Fipronil','GOTAS','67 mg','Pet Health', FALSE, 45, 20, 22000),
 ('Pipeta antipulgas 10-25 kg','Fipronil','GOTAS','134 mg','Pet Health', FALSE, 38, 20, 26000),
 ('Shampoo con clorhexidina','Clorhexidina','SPRAY','2%','Derma Vet', FALSE, 15,  6, 35000),
 ('Otológico con antibiótico','Gentamicina + Betametasona','GOTAS',NULL,'Derma Vet', TRUE, 12,  8, 31000),
 ('Insulina veterinaria','Insulina porcina','INYECTABLE','40 UI/ml','Vetlab', TRUE,  6,  3,135000),
 ('Levotiroxina 0,5 mg','Levotiroxina sódica','COMPRIMIDO','0,5 mg','Bio Animal', TRUE, 25,  8, 29000);

-- ── Vacunas ─────────────────────────────────────────────────────────────────
INSERT INTO vacuna (nombre, laboratorio, enfermedades_previene,
                    intervalo_refuerzo_meses, edad_minima_semanas, precio) VALUES
 ('Quíntuple canina','Zoetis Vet',
  'Moquillo, hepatitis, parvovirosis, parainfluenza y leptospirosis', 12,  6, 52000),
 ('Antirrábica','Zoetis Vet','Rabia',                                  12, 12, 45000),
 ('Triple felina','Bio Animal',
  'Panleucopenia, rinotraqueítis y calicivirus',                       12,  8, 48000),
 ('Leucemia felina','Bio Animal','Virus de la leucemia felina',        12,  9, 62000),
 ('Tos de las perreras','Zoetis Vet',
  'Bordetella bronchiseptica y parainfluenza',                         12,  8, 46000);

-- Qué vacuna sirve para qué especie. Esta es la tabla que impide aplicar una
-- vacuna canina a un felino.
INSERT INTO vacuna_especie (vacuna_id, especie_id)
SELECT v.id, e.id FROM vacuna v, especie e
WHERE (v.nombre IN ('Quíntuple canina','Tos de las perreras') AND e.nombre = 'Canino')
   OR (v.nombre IN ('Triple felina','Leucemia felina')        AND e.nombre = 'Felino')
   OR (v.nombre = 'Antirrábica' AND e.nombre IN ('Canino','Felino'));

-- ── Métodos de pago ─────────────────────────────────────────────────────────
INSERT INTO metodo_pago (nombre, requiere_referencia) VALUES
 ('Efectivo',           FALSE),
 ('Tarjeta de débito',  TRUE),
 ('Tarjeta de crédito', TRUE),
 ('Transferencia',      TRUE),
 ('Nequi / Daviplata',  TRUE);
