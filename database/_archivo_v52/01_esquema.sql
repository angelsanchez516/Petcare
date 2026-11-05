-- ============================================================================
--  PETCARE — Sistema de gestión para clínica veterinaria
--  01_esquema.sql · Extensiones, dominios, secuencias y tablas
-- ----------------------------------------------------------------------------
--  Derivado del MER unificado: 52 entidades, 438 atributos.
--  Escrito manualmente. NINGUNA tabla se genera con migraciones de un ORM.
--
--  ORDEN DE ESTE ARCHIVO
--    1. Extensiones y dominios
--    2. Secuencias de folios
--    3. Tablas, agrupadas por bloque del MER (sin claves foráneas)
--
--  Las claves foráneas se declaran aparte, en 02_integridad.sql, por dos
--  razones: el modelo tiene referencias circulares (registro_peso ↔ consulta,
--  solicitud_cita ↔ cita) que impiden un orden lineal de creación, y agrupar
--  las 66 foráneas en un solo lugar deja la política de borrado auditable de
--  un vistazo — que es justo lo que hay que poder defender en un sistema con
--  historia clínica.
-- ============================================================================

SET client_min_messages = WARNING;

-- ----------------------------------------------------------------------------
-- 1. EXTENSIONES
-- ----------------------------------------------------------------------------
-- btree_gist permite combinar igualdad (=) con solapamiento (&&) dentro de una
-- misma restricción EXCLUDE. Sin ella no se puede expresar «este veterinario no
-- puede tener dos citas que se pisen en el tiempo».
CREATE EXTENSION IF NOT EXISTS btree_gist;

-- unaccent y pg_trgm alimentan la búsqueda por nombre de mascota o tutor
-- tolerante a tildes y errores de tipeo.
CREATE EXTENSION IF NOT EXISTS unaccent;
CREATE EXTENSION IF NOT EXISTS pg_trgm;


-- ----------------------------------------------------------------------------
-- 2. DOMINIOS
-- ----------------------------------------------------------------------------
-- Un dominio es un tipo con restricción incorporada. Declarar el importe una
-- sola vez evita repetir CHECK (x >= 0) en las 30 columnas monetarias y, sobre
-- todo, evita olvidarlo en alguna.

CREATE DOMAIN dom_dinero AS NUMERIC(12,2)
    CONSTRAINT dom_dinero_no_negativo CHECK (VALUE >= 0);

COMMENT ON DOMAIN dom_dinero IS
    'Importe monetario. NUMERIC y jamás FLOAT: el binario no representa '
    'decimales exactos y 0.1+0.2 <> 0.3 descuadraría los totales de factura.';

CREATE DOMAIN dom_email AS VARCHAR(120)
    CONSTRAINT dom_email_formato CHECK (VALUE ~ '^[^@[:space:]]+@[^@[:space:]]+\.[A-Za-z]{2,}$');

COMMENT ON DOMAIN dom_email IS
    'Dirección de correo. 120 caracteres cubren el máximo práctico; el RFC '
    'permite 320 pero es inalcanzable en la práctica.';

CREATE DOMAIN dom_telefono AS VARCHAR(25)
    CONSTRAINT dom_telefono_formato CHECK (VALUE ~ '^[0-9+()\- ]{6,25}$');

COMMENT ON DOMAIN dom_telefono IS
    'Teléfono. VARCHAR y no numérico: admite «+», paréntesis, espacios y ceros '
    'a la izquierda, que un entero destruiría. Nunca se opera aritméticamente.';

CREATE DOMAIN dom_estado_activo AS BOOLEAN NOT NULL DEFAULT TRUE;

COMMENT ON DOMAIN dom_estado_activo IS
    'Bandera de baja lógica. BOOLEAN y no CHAR(1): admite exactamente tres '
    'estados, mientras que un CHAR aceptaría ''S'', ''s'', ''X'' o un espacio.';


-- ----------------------------------------------------------------------------
-- 3. SECUENCIAS DE FOLIOS
-- ----------------------------------------------------------------------------
-- Los números de documento son VARCHAR porque llevan prefijo y ceros a la
-- izquierda (F-000001). La secuencia da el correlativo; un trigger lo formatea.

CREATE SEQUENCE seq_factura_numero  START 1 INCREMENT 1 MINVALUE 1;
CREATE SEQUENCE seq_receta_folio    START 1 INCREMENT 1 MINVALUE 1;
CREATE SEQUENCE seq_orden_folio     START 1 INCREMENT 1 MINVALUE 1;


-- ============================================================================
--  BLOQUE A — SEGURIDAD, PERSONAL Y CLIENTES
-- ============================================================================

CREATE TABLE cargo (
    id            SMALLINT      GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    nombre        VARCHAR(60)   NOT NULL,
    descripcion   VARCHAR(250),
    activo        dom_estado_activo,
    CONSTRAINT uq_cargo_nombre UNIQUE (nombre)
);
COMMENT ON TABLE cargo IS
    'Catálogo de puestos de trabajo. Separa el puesto de la persona: si cambia '
    'el nombre del cargo no hay que tocar cada empleado.';


CREATE TABLE empleado (
    id                  INTEGER       GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    cargo_id            SMALLINT      NOT NULL,
    tipo_documento      VARCHAR(10)   NOT NULL DEFAULT 'DNI',
    documento           VARCHAR(20)   NOT NULL,
    nombres             VARCHAR(80)   NOT NULL,
    apellidos           VARCHAR(80)   NOT NULL,
    telefono            dom_telefono,
    email               dom_email,
    direccion           VARCHAR(200),
    fecha_contratacion  DATE,
    foto_url            VARCHAR(300),
    activo              dom_estado_activo,
    creado_en           TIMESTAMPTZ   NOT NULL DEFAULT now(),
    actualizado_en      TIMESTAMPTZ   NOT NULL DEFAULT now(),

    -- La unicidad correcta es la del PAR: un DNI 12345678 y un pasaporte
    -- 12345678 son documentos distintos de personas distintas.
    CONSTRAINT uq_empleado_documento UNIQUE (tipo_documento, documento),
    CONSTRAINT ck_empleado_tipo_doc  CHECK (tipo_documento IN ('DNI','CI','PASAPORTE','RUC','NIT','CE','OTRO')),
    CONSTRAINT ck_empleado_contrato  CHECK (fecha_contratacion IS NULL OR fecha_contratacion <= CURRENT_DATE),
    CONSTRAINT ck_empleado_nombres   CHECK (length(btrim(nombres)) > 0 AND length(btrim(apellidos)) > 0)
);
COMMENT ON TABLE empleado IS
    'SUPERTIPO. Persona que trabaja en la clínica, sea o no profesional '
    'sanitario. Generalización de la que veterinario es una especialización.';


CREATE TABLE veterinario (
    -- La clave primaria ES la clave foránea al supertipo. Esa sola decisión
    -- hace imposible un veterinario sin empleado detrás, y que un empleado
    -- tenga dos filas de subtipo. No hace falta ningún trigger.
    empleado_id         INTEGER      PRIMARY KEY,
    matricula           VARCHAR(30)  NOT NULL,
    fecha_habilitacion  DATE,
    biografia           TEXT,
    firma_url           VARCHAR(300),

    CONSTRAINT uq_veterinario_matricula UNIQUE (matricula),
    CONSTRAINT ck_veterinario_matricula CHECK (length(btrim(matricula)) >= 3)
);
COMMENT ON TABLE veterinario IS
    'SUBTIPO (ISA) de empleado. Solo existe para los empleados habilitados '
    'para el acto médico.';
COMMENT ON COLUMN veterinario.empleado_id IS
    'PK y FK a la vez: implementa la especialización 1:1 sin lógica adicional.';


CREATE TABLE especialidad (
    id           SMALLINT     GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    nombre       VARCHAR(80)  NOT NULL,
    descripcion  VARCHAR(250),
    activo       dom_estado_activo,
    CONSTRAINT uq_especialidad_nombre UNIQUE (nombre)
);
COMMENT ON TABLE especialidad IS 'Catálogo de especialidades veterinarias.';


CREATE TABLE veterinario_especialidad (
    veterinario_id   INTEGER   NOT NULL,
    especialidad_id  SMALLINT  NOT NULL,
    es_principal     BOOLEAN   NOT NULL DEFAULT FALSE,
    certificado_en   DATE,

    CONSTRAINT pk_veterinario_especialidad PRIMARY KEY (veterinario_id, especialidad_id),
    CONSTRAINT ck_vet_esp_certificado CHECK (certificado_en IS NULL OR certificado_en <= CURRENT_DATE)
);
COMMENT ON TABLE veterinario_especialidad IS
    'ASOCIATIVA. Resuelve la N:M entre veterinario y especialidad. La PK '
    'compuesta impide asignar dos veces la misma especialidad al mismo '
    'profesional.';


CREATE TABLE rol (
    id           SMALLINT     GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    codigo       VARCHAR(20)  NOT NULL,
    nombre       VARCHAR(50)  NOT NULL,
    descripcion  VARCHAR(200),
    activo       dom_estado_activo,

    CONSTRAINT uq_rol_codigo UNIQUE (codigo),
    CONSTRAINT ck_rol_codigo CHECK (codigo = upper(codigo))
);
COMMENT ON TABLE rol IS
    'Perfil de acceso. Es tabla y no CHECK porque tiene atributos propios que '
    'se muestran en la interfaz y participa de una N:M con permiso.';


CREATE TABLE permiso (
    id           SMALLINT     GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    codigo       VARCHAR(60)  NOT NULL,
    modulo       VARCHAR(40)  NOT NULL,
    descripcion  VARCHAR(200),

    CONSTRAINT uq_permiso_codigo UNIQUE (codigo),
    -- Formato modulo.accion, por ejemplo consulta.crear
    CONSTRAINT ck_permiso_codigo CHECK (codigo ~ '^[a-z_]+\.[a-z_]+$')
);
COMMENT ON TABLE permiso IS
    'Catálogo de acciones autorizables. Permite cambiar qué puede hacer un rol '
    'sin recompilar la aplicación.';


CREATE TABLE rol_permiso (
    rol_id      SMALLINT  NOT NULL,
    permiso_id  SMALLINT  NOT NULL,
    CONSTRAINT pk_rol_permiso PRIMARY KEY (rol_id, permiso_id)
);
COMMENT ON TABLE rol_permiso IS
    'ASOCIATIVA. Matriz de autorización: resuelve la N:M entre rol y permiso.';


CREATE TABLE usuario (
    id                 INTEGER       GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    empleado_id        INTEGER,
    nombre_usuario     VARCHAR(50)   NOT NULL,
    email              dom_email     NOT NULL,
    password_hash      VARCHAR(255)  NOT NULL,
    mfa_secreto        VARCHAR(120),
    ultimo_acceso_en   TIMESTAMPTZ,
    intentos_fallidos  SMALLINT      NOT NULL DEFAULT 0,
    activo             dom_estado_activo,
    creado_en          TIMESTAMPTZ   NOT NULL DEFAULT now(),
    actualizado_en     TIMESTAMPTZ   NOT NULL DEFAULT now(),

    CONSTRAINT uq_usuario_nombre   UNIQUE (nombre_usuario),
    CONSTRAINT uq_usuario_email    UNIQUE (email),
    -- UNIQUE sobre una columna que admite NULL: varios NULL no colisionan,
    -- así que esto crea exactamente la relación 1:0..1 con empleado.
    CONSTRAINT uq_usuario_empleado UNIQUE (empleado_id),
    CONSTRAINT ck_usuario_intentos CHECK (intentos_fallidos BETWEEN 0 AND 100),
    -- El hash nunca puede parecerse a una contraseña en claro: bcrypt y argon2
    -- producen cadenas largas con prefijo de algoritmo.
    CONSTRAINT ck_usuario_hash     CHECK (length(password_hash) >= 20)
);
COMMENT ON TABLE usuario IS
    'Credencial de acceso. Se separa de empleado porque no todo empleado usa '
    'el sistema y una credencial puede revocarse sin dar de baja a la persona.';
COMMENT ON COLUMN usuario.password_hash IS
    'Hash argon2id o bcrypt con salt. NUNCA la contraseña en claro.';


CREATE TABLE usuario_rol (
    usuario_id   INTEGER      NOT NULL,
    rol_id       SMALLINT     NOT NULL,
    asignado_en  TIMESTAMPTZ  NOT NULL DEFAULT now(),
    CONSTRAINT pk_usuario_rol PRIMARY KEY (usuario_id, rol_id)
);
COMMENT ON TABLE usuario_rol IS
    'ASOCIATIVA. Un usuario puede acumular varios roles: la dueña de la '
    'clínica es administradora y veterinaria a la vez.';


CREATE TABLE cliente (
    id                    INTEGER      GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    tipo_documento        VARCHAR(10)  NOT NULL DEFAULT 'DNI',
    documento             VARCHAR(20)  NOT NULL,
    nombres               VARCHAR(80)  NOT NULL,
    apellidos             VARCHAR(80)  NOT NULL,
    telefono              dom_telefono NOT NULL,
    telefono_alternativo  dom_telefono,
    email                 dom_email,
    direccion             VARCHAR(200),
    ciudad                VARCHAR(80),
    fecha_nacimiento      DATE,
    acepta_recordatorios  BOOLEAN      NOT NULL DEFAULT TRUE,
    notas                 TEXT,
    activo                dom_estado_activo,
    creado_en             TIMESTAMPTZ  NOT NULL DEFAULT now(),
    actualizado_en        TIMESTAMPTZ  NOT NULL DEFAULT now(),

    CONSTRAINT uq_cliente_documento UNIQUE (tipo_documento, documento),
    CONSTRAINT ck_cliente_tipo_doc  CHECK (tipo_documento IN ('DNI','CI','PASAPORTE','RUC','NIT','CE','OTRO')),
    CONSTRAINT ck_cliente_nacimiento CHECK (fecha_nacimiento IS NULL OR fecha_nacimiento <= CURRENT_DATE),
    CONSTRAINT ck_cliente_nombres   CHECK (length(btrim(nombres)) > 0 AND length(btrim(apellidos)) > 0),
    -- Si el tutor pide recordatorios, hace falta un canal para enviárselos.
    CONSTRAINT ck_cliente_recordatorio CHECK (NOT acepta_recordatorios OR email IS NOT NULL OR telefono IS NOT NULL)
);
COMMENT ON TABLE cliente IS
    'Tutor o propietario responsable. Titular del vínculo comercial y de '
    'contacto. El paciente es la mascota; el cliente es quien la lleva.';


-- ============================================================================
--  BLOQUE B — MASCOTA Y TAXONOMÍA
-- ============================================================================

CREATE TABLE especie (
    id                    SMALLINT     GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    nombre                VARCHAR(50)  NOT NULL,
    nombre_cientifico     VARCHAR(80),
    icono                 VARCHAR(20),
    esperanza_vida_anios  SMALLINT,
    activo                dom_estado_activo,

    CONSTRAINT uq_especie_nombre UNIQUE (nombre),
    CONSTRAINT ck_especie_vida   CHECK (esperanza_vida_anios IS NULL OR esperanza_vida_anios > 0)
);
COMMENT ON TABLE especie IS 'Catálogo taxonómico de primer nivel.';


CREATE TABLE raza (
    id               INTEGER      GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    especie_id       SMALLINT     NOT NULL,
    nombre           VARCHAR(80)  NOT NULL,
    tamanio          VARCHAR(15),
    predisposiciones VARCHAR(300),
    activo           dom_estado_activo,

    -- «Persa» puede existir en más de una especie: la unicidad es del par.
    CONSTRAINT uq_raza_especie_nombre UNIQUE (especie_id, nombre),
    -- Clave alternativa técnica. No aporta unicidad nueva (id ya es único),
    -- pero es la que habilita la FK COMPUESTA desde mascota: PostgreSQL exige
    -- que el destino de una foránea tenga un UNIQUE con esas mismas columnas.
    CONSTRAINT uq_raza_id_especie     UNIQUE (id, especie_id),
    CONSTRAINT ck_raza_tamanio CHECK (tamanio IS NULL OR tamanio IN ('PEQUENO','MEDIANO','GRANDE','GIGANTE'))
);
COMMENT ON TABLE raza IS 'Catálogo de segundo nivel, dependiente de especie.';
COMMENT ON CONSTRAINT uq_raza_id_especie ON raza IS
    'Clave alternativa que permite a mascota referenciar (raza_id, especie_id) '
    'y así impedir el estado imposible «felino de raza labrador».';


CREATE TABLE mascota (
    id                     INTEGER      GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    cliente_id             INTEGER      NOT NULL,
    -- especie_id es OBLIGATORIA e independiente de raza_id: un mestizo de raza
    -- desconocida conserva su especie. Esa es la razón de que ambas convivan.
    especie_id             SMALLINT     NOT NULL,
    raza_id                INTEGER,
    nombre                 VARCHAR(60)  NOT NULL,
    sexo                   CHAR(1)      NOT NULL,
    fecha_nacimiento       DATE,
    edad_aproximada_meses  SMALLINT,
    color                  VARCHAR(60),
    microchip              VARCHAR(25),
    esterilizado           BOOLEAN      NOT NULL DEFAULT FALSE,
    temperamento           VARCHAR(15),
    foto_url               VARCHAR(300),
    observaciones          TEXT,
    fecha_fallecimiento    DATE,
    activo                 dom_estado_activo,
    creado_en              TIMESTAMPTZ  NOT NULL DEFAULT now(),
    actualizado_en         TIMESTAMPTZ  NOT NULL DEFAULT now(),

    CONSTRAINT ck_mascota_sexo         CHECK (sexo IN ('M','H')),
    CONSTRAINT ck_mascota_nacimiento   CHECK (fecha_nacimiento IS NULL OR fecha_nacimiento <= CURRENT_DATE),
    CONSTRAINT ck_mascota_edad_aprox   CHECK (edad_aproximada_meses IS NULL OR edad_aproximada_meses BETWEEN 0 AND 1200),
    CONSTRAINT ck_mascota_fallecimiento CHECK (
        fecha_fallecimiento IS NULL
        OR fecha_nacimiento IS NULL
        OR fecha_fallecimiento >= fecha_nacimiento),
    CONSTRAINT ck_mascota_temperamento CHECK (temperamento IS NULL OR temperamento IN ('DOCIL','NERVIOSO','AGRESIVO','DESCONOCIDO')),
    CONSTRAINT ck_mascota_nombre       CHECK (length(btrim(nombre)) > 0),
    -- ISO 11784: 15 dígitos. VARCHAR y no BIGINT porque los ceros iniciales
    -- son significativos y 15 dígitos exceden el rango de INTEGER.
    CONSTRAINT ck_mascota_microchip    CHECK (microchip IS NULL OR microchip ~ '^[0-9A-Za-z]{9,25}$')
);
COMMENT ON TABLE mascota IS
    'NÚCLEO DEL SISTEMA. Paciente y centro del expediente clínico. La edad, el '
    'peso actual y el estado de vacunación son DERIVADOS, no columnas.';


CREATE TABLE condicion_medica (
    id           INTEGER       GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    nombre       VARCHAR(100)  NOT NULL,
    tipo         VARCHAR(15)   NOT NULL,
    descripcion  VARCHAR(300),
    activo       dom_estado_activo,

    CONSTRAINT uq_condicion_nombre UNIQUE (nombre),
    CONSTRAINT ck_condicion_tipo   CHECK (tipo IN ('ALERGIA','CRONICA','CONGENITA','OTRA'))
);
COMMENT ON TABLE condicion_medica IS
    'Catálogo unificado de alergias, enfermedades crónicas y condiciones '
    'congénitas. El atributo discriminante evita mantener tres catálogos con '
    'la misma estructura.';


CREATE TABLE mascota_condicion (
    mascota_id           INTEGER      NOT NULL,
    condicion_medica_id  INTEGER      NOT NULL,
    severidad            VARCHAR(10)  NOT NULL DEFAULT 'MEDIA',
    fecha_deteccion      DATE,
    activa               BOOLEAN      NOT NULL DEFAULT TRUE,
    notas                TEXT,

    CONSTRAINT pk_mascota_condicion PRIMARY KEY (mascota_id, condicion_medica_id),
    CONSTRAINT ck_mascota_cond_severidad CHECK (severidad IN ('LEVE','MEDIA','GRAVE')),
    CONSTRAINT ck_mascota_cond_fecha     CHECK (fecha_deteccion IS NULL OR fecha_deteccion <= CURRENT_DATE)
);
COMMENT ON TABLE mascota_condicion IS
    'ASOCIATIVA. Resuelve la N:M entre mascota y condicion_medica. La severidad '
    'es propia del vínculo: la misma alergia es leve en una mascota y grave en '
    'otra.';


CREATE TABLE registro_peso (
    id              INTEGER       GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    mascota_id      INTEGER       NOT NULL,
    empleado_id     INTEGER,
    consulta_id     INTEGER,
    seguimiento_id  INTEGER,
    fecha_registro  DATE          NOT NULL DEFAULT CURRENT_DATE,
    peso_kg         NUMERIC(6,2)  NOT NULL,
    observacion     VARCHAR(200),
    creado_en       TIMESTAMPTZ   NOT NULL DEFAULT now(),

    -- Un solo peso oficial por día. Esta restricción SOLO funciona con DATE:
    -- con TIMESTAMP cada pesaje tendría hora distinta y nunca se aplicaría.
    CONSTRAINT uq_registro_peso_dia UNIQUE (mascota_id, fecha_registro),
    CONSTRAINT ck_registro_peso_positivo CHECK (peso_kg > 0),
    -- Rango biológico: desde un hámster de 30 g hasta un equino.
    CONSTRAINT ck_registro_peso_rango    CHECK (peso_kg BETWEEN 0.02 AND 2000),
    CONSTRAINT ck_registro_peso_fecha    CHECK (fecha_registro <= CURRENT_DATE),
    -- Un peso proviene de una consulta, de un control de internación o de
    -- ninguno de los dos, pero nunca de ambos a la vez.
    CONSTRAINT ck_registro_peso_origen   CHECK (NOT (consulta_id IS NOT NULL AND seguimiento_id IS NOT NULL))
);
COMMENT ON TABLE registro_peso IS
    'ENTIDAD DÉBIL. ÚNICO lugar del modelo donde se almacena un peso. El «peso '
    'actual» de la mascota es la medición más reciente, calculada por vista.';


-- ============================================================================
--  BLOQUE C — AGENDA, ATENCIÓN CLÍNICA Y DIAGNÓSTICO
-- ============================================================================

CREATE TABLE solicitud_cita (
    id                  INTEGER       GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    cita_id             INTEGER,
    especie_id          SMALLINT,
    nombre_contacto     VARCHAR(120)  NOT NULL,
    telefono_contacto   dom_telefono  NOT NULL,
    email_contacto      VARCHAR(120),
    nombre_mascota      VARCHAR(60),
    motivo              VARCHAR(300)  NOT NULL,
    fecha_preferida     DATE,
    franja_preferida    VARCHAR(12),
    estado              VARCHAR(12)   NOT NULL DEFAULT 'nueva',
    creado_en           TIMESTAMPTZ   NOT NULL DEFAULT now(),

    CONSTRAINT uq_solicitud_cita UNIQUE (cita_id),
    CONSTRAINT ck_solicitud_estado CHECK (estado IN ('nueva','contactada','convertida','descartada')),
    CONSTRAINT ck_solicitud_franja CHECK (franja_preferida IS NULL OR franja_preferida IN ('MANANA','TARDE','INDIFERENTE')),
    -- Coherencia de estado: solo una solicitud convertida tiene cita, y toda
    -- solicitud con cita está convertida.
    CONSTRAINT ck_solicitud_conversion CHECK (
        (estado = 'convertida' AND cita_id IS NOT NULL)
     OR (estado <> 'convertida' AND cita_id IS NULL))
);
COMMENT ON TABLE solicitud_cita IS
    'Zona de cuarentena para pedidos del sitio público. Impide que un visitante '
    'anónimo inserte directamente en las tablas maestras y las llene de '
    'registros duplicados o falsos. El campo nombre_mascota es texto libre SIN '
    'foránea: esa mascota todavía no existe en el sistema.';


CREATE TABLE cita (
    id                       INTEGER       GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    mascota_id               INTEGER       NOT NULL,
    veterinario_id           INTEGER       NOT NULL,
    servicio_id              INTEGER,
    usuario_registro_id      INTEGER,
    fecha_hora_inicio        TIMESTAMPTZ   NOT NULL,
    duracion_minutos         SMALLINT      NOT NULL DEFAULT 30,
    -- Derivada de inicio + duración, mantenida por el trigger tg_cita_fin.
    -- Existe por una razón técnica concreta: la restricción EXCLUDE de más
    -- abajo necesita un rango, y construirlo al vuelo exigiría sumar un
    -- intervalo a un timestamptz. Esa suma es STABLE y no IMMUTABLE (los
    -- cambios de horario de verano dependen de la zona configurada), y
    -- PostgreSQL no admite expresiones no inmutables en un índice.
    -- La fuente de verdad sigue siendo duracion_minutos: nadie escribe esta
    -- columna a mano, la calcula el trigger en cada INSERT y cada UPDATE.
    fecha_hora_fin           TIMESTAMPTZ   NOT NULL,
    motivo                   VARCHAR(300)  NOT NULL,
    estado                   VARCHAR(12)   NOT NULL DEFAULT 'programada',
    motivo_cancelacion       VARCHAR(250),
    recordatorio_enviado_en  TIMESTAMPTZ,
    notas                    TEXT,
    creado_en                TIMESTAMPTZ   NOT NULL DEFAULT now(),
    actualizado_en           TIMESTAMPTZ   NOT NULL DEFAULT now(),

    CONSTRAINT ck_cita_estado    CHECK (estado IN ('programada','confirmada','atendida','cancelada','no_asistio')),
    CONSTRAINT ck_cita_duracion  CHECK (duracion_minutos BETWEEN 10 AND 480),
    -- Cancelar exige justificar. Y una cita no cancelada no puede arrastrar un
    -- motivo de cancelación de una cancelación anterior revertida.
    CONSTRAINT ck_cita_cancelacion CHECK (
        (estado =  'cancelada' AND motivo_cancelacion IS NOT NULL)
     OR (estado <> 'cancelada' AND motivo_cancelacion IS NULL)),

    CONSTRAINT ck_cita_fin CHECK (fecha_hora_fin > fecha_hora_inicio),

    -- Un veterinario no puede tener dos citas que se pisen en el tiempo.
    -- tstzrange() sobre dos columnas sí es IMMUTABLE, que es lo que exige un
    -- índice GiST. Las citas canceladas y las de ausencia liberan el hueco.
    CONSTRAINT ex_cita_sin_solapamiento EXCLUDE USING gist (
        veterinario_id WITH =,
        tstzrange(fecha_hora_inicio, fecha_hora_fin) WITH &&
    ) WHERE (estado IN ('programada','confirmada','atendida'))
);
COMMENT ON TABLE cita IS
    'Compromiso futuro entre mascota, veterinario y horario. El tutor NO se '
    'almacena aquí: se deriva por mascota → cliente. Guardarlo sería una '
    'dependencia transitiva y permitiría que la cita registre un tutor distinto '
    'al de la mascota atendida.';
COMMENT ON CONSTRAINT ex_cita_sin_solapamiento ON cita IS
    'Impide agendas solapadas a nivel de motor, no de aplicación.';


CREATE TABLE consulta (
    id                          INTEGER       GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    mascota_id                  INTEGER       NOT NULL,
    veterinario_id              INTEGER       NOT NULL,
    cita_id                     INTEGER,
    fecha_hora                  TIMESTAMPTZ   NOT NULL DEFAULT now(),
    tipo                        VARCHAR(15)   NOT NULL DEFAULT 'GENERAL',
    motivo                      VARCHAR(300)  NOT NULL,
    anamnesis                   TEXT,
    temperatura_c               NUMERIC(4,1),
    frecuencia_cardiaca         SMALLINT,
    frecuencia_respiratoria     SMALLINT,
    tiempo_llenado_capilar_seg  NUMERIC(3,1),
    examen_fisico               TEXT,
    observaciones               TEXT,
    proxima_revision            DATE,
    creado_en                   TIMESTAMPTZ   NOT NULL DEFAULT now(),
    actualizado_en              TIMESTAMPTZ   NOT NULL DEFAULT now(),

    -- UNIQUE sobre columna nullable: crea la 1:0..1 con cita. Nulo en las
    -- urgencias que llegan sin turno previo.
    CONSTRAINT uq_consulta_cita  UNIQUE (cita_id),
    CONSTRAINT ck_consulta_tipo  CHECK (tipo IN ('GENERAL','CONTROL','URGENCIA','PREQUIRURGICA','VACUNACION','ESTETICA')),
    CONSTRAINT ck_consulta_fecha CHECK (fecha_hora <= now()),
    -- Rangos biológicos reales, no arbitrarios.
    CONSTRAINT ck_consulta_temp  CHECK (temperatura_c IS NULL OR temperatura_c BETWEEN 30.0 AND 45.0),
    CONSTRAINT ck_consulta_fc    CHECK (frecuencia_cardiaca IS NULL OR frecuencia_cardiaca BETWEEN 20 AND 400),
    CONSTRAINT ck_consulta_fr    CHECK (frecuencia_respiratoria IS NULL OR frecuencia_respiratoria BETWEEN 5 AND 200),
    CONSTRAINT ck_consulta_tllc  CHECK (tiempo_llenado_capilar_seg IS NULL OR tiempo_llenado_capilar_seg BETWEEN 0 AND 10),
    CONSTRAINT ck_consulta_revision CHECK (proxima_revision IS NULL OR proxima_revision >= fecha_hora::date)
);
COMMENT ON TABLE consulta IS
    'Encuentro clínico realizado. Unidad atómica del historial. NO almacena '
    'peso (va a registro_peso) ni diagnóstico en texto libre (va a '
    'consulta_diagnostico): ambos vivirían duplicados.';


CREATE TABLE diagnostico (
    id           INTEGER       GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    padre_id     INTEGER,
    codigo       VARCHAR(15)   NOT NULL,
    nombre       VARCHAR(120)  NOT NULL,
    nivel        SMALLINT      NOT NULL DEFAULT 1,
    descripcion  TEXT,
    activo       dom_estado_activo,

    CONSTRAINT uq_diagnostico_codigo UNIQUE (codigo),
    CONSTRAINT uq_diagnostico_nombre UNIQUE (nombre),
    CONSTRAINT ck_diagnostico_nivel  CHECK (nivel BETWEEN 1 AND 6),
    -- Una fila no puede ser su propio padre. Los ciclos más largos los detecta
    -- un trigger en 04_reglas.sql: un CHECK no puede recorrer la jerarquía.
    CONSTRAINT ck_diagnostico_no_autopadre CHECK (padre_id IS NULL OR padre_id <> id)
);
COMMENT ON TABLE diagnostico IS
    'Catálogo clínico normalizado CON JERARQUÍA RECURSIVA. Agrupa «Gastritis '
    'aguda» bajo «Trastorno digestivo» y permite reportes de morbilidad por '
    'rama completa. Sin catálogo, «Gastritis» y «gastritis» serían dos '
    'patologías distintas y no habría reporte posible.';
COMMENT ON COLUMN diagnostico.padre_id IS
    'RELACIÓN RECURSIVA hacia la misma tabla. Nulo en los nodos raíz.';


CREATE TABLE consulta_diagnostico (
    consulta_id     INTEGER      NOT NULL,
    diagnostico_id  INTEGER      NOT NULL,
    tipo            VARCHAR(12)  NOT NULL DEFAULT 'PRESUNTIVO',
    es_principal    BOOLEAN      NOT NULL DEFAULT FALSE,
    notas           TEXT,

    CONSTRAINT pk_consulta_diagnostico PRIMARY KEY (consulta_id, diagnostico_id),
    CONSTRAINT ck_consulta_diag_tipo CHECK (tipo IN ('PRESUNTIVO','DEFINITIVO','DESCARTADO'))
    -- «Un solo diagnóstico principal por consulta» se implementa con un índice
    -- único PARCIAL, que no puede declararse como constraint. Ver 03_indices.
);
COMMENT ON TABLE consulta_diagnostico IS
    'ASOCIATIVA. Resuelve la N:M entre consulta y diagnostico. ÚNICO lugar del '
    'modelo donde se registra un diagnóstico.';


CREATE TABLE protocolo_tratamiento (
    id                      INTEGER       GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    nombre                  VARCHAR(120)  NOT NULL,
    descripcion             TEXT,
    indicaciones            TEXT,
    duracion_dias_sugerida  SMALLINT,
    activo                  dom_estado_activo,

    CONSTRAINT uq_protocolo_nombre   UNIQUE (nombre),
    CONSTRAINT ck_protocolo_duracion CHECK (duracion_dias_sugerida IS NULL OR duracion_dias_sugerida > 0)
);
COMMENT ON TABLE protocolo_tratamiento IS
    'Catálogo de protocolos terapéuticos reutilizables. Evita que el '
    'veterinario reescriba desde cero un esquema estándar en cada consulta.';


CREATE TABLE protocolo_medicamento (
    protocolo_id         INTEGER      NOT NULL,
    medicamento_id       INTEGER      NOT NULL,
    dosis_sugerida       VARCHAR(60)  NOT NULL,
    frecuencia_sugerida  VARCHAR(60)  NOT NULL,
    duracion_dias        SMALLINT     NOT NULL,
    via_administracion   VARCHAR(15)  NOT NULL DEFAULT 'ORAL',

    CONSTRAINT pk_protocolo_medicamento PRIMARY KEY (protocolo_id, medicamento_id),
    CONSTRAINT ck_protocolo_med_duracion CHECK (duracion_dias > 0),
    CONSTRAINT ck_protocolo_med_via CHECK (via_administracion IN
        ('ORAL','TOPICA','INTRAMUSCULAR','SUBCUTANEA','INTRAVENOSA','OFTALMICA','OTICA','RECTAL'))
);
COMMENT ON TABLE protocolo_medicamento IS
    'ASOCIATIVA. Medicamentos que componen un protocolo estándar, con su pauta '
    'sugerida.';


CREATE TABLE tratamiento (
    id                  INTEGER       GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    consulta_id         INTEGER       NOT NULL,
    protocolo_id        INTEGER,
    descripcion         VARCHAR(300)  NOT NULL,
    indicaciones        TEXT,
    fecha_inicio        DATE          NOT NULL DEFAULT CURRENT_DATE,
    fecha_fin_estimada  DATE,
    estado              VARCHAR(12)   NOT NULL DEFAULT 'activo',

    CONSTRAINT ck_tratamiento_estado CHECK (estado IN ('activo','completado','suspendido')),
    CONSTRAINT ck_tratamiento_fechas CHECK (fecha_fin_estimada IS NULL OR fecha_fin_estimada >= fecha_inicio)
);
COMMENT ON TABLE tratamiento IS
    'ENTIDAD DÉBIL. Plan terapéutico concreto de UNA consulta, con sus fechas y '
    'su evolución. No es catálogo porque no se repite entre pacientes; puede '
    'instanciarse desde un protocolo o escribirse a medida.';


CREATE TABLE examen (
    id           INTEGER       GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    codigo       VARCHAR(15)   NOT NULL,
    nombre       VARCHAR(120)  NOT NULL,
    tipo         VARCHAR(20)   NOT NULL,
    preparacion  VARCHAR(300),
    precio       dom_dinero    NOT NULL DEFAULT 0,
    activo       dom_estado_activo,

    CONSTRAINT uq_examen_codigo UNIQUE (codigo),
    CONSTRAINT uq_examen_nombre UNIQUE (nombre),
    CONSTRAINT ck_examen_tipo   CHECK (tipo IN ('LABORATORIO','IMAGEN','CITOLOGIA','OTRO'))
);
COMMENT ON TABLE examen IS
    'Catálogo de estudios complementarios: hemograma, radiografía, ecografía.';


CREATE TABLE orden_examen (
    id              INTEGER      GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    consulta_id     INTEGER      NOT NULL,
    veterinario_id  INTEGER      NOT NULL,
    folio           VARCHAR(20)  NOT NULL,
    fecha_orden     DATE         NOT NULL DEFAULT CURRENT_DATE,
    prioridad       VARCHAR(10)  NOT NULL DEFAULT 'RUTINA',
    observaciones   TEXT,
    estado          VARCHAR(12)  NOT NULL DEFAULT 'pendiente',

    CONSTRAINT uq_orden_examen_folio UNIQUE (folio),
    CONSTRAINT ck_orden_prioridad CHECK (prioridad IN ('RUTINA','URGENTE')),
    CONSTRAINT ck_orden_estado    CHECK (estado IN ('pendiente','en_proceso','completada','anulada')),
    CONSTRAINT ck_orden_fecha     CHECK (fecha_orden <= CURRENT_DATE)
);
COMMENT ON TABLE orden_examen IS
    'Solicitud de estudios emitida en una consulta. Agrupa varios exámenes bajo '
    'un mismo pedido.';


CREATE TABLE orden_examen_detalle (
    orden_examen_id  INTEGER        NOT NULL,
    examen_id        INTEGER        NOT NULL,
    precio_unitario  dom_dinero     NOT NULL,
    resultado        TEXT,
    valor_numerico   NUMERIC(12,3),
    unidad           VARCHAR(20),
    fecha_resultado  DATE,
    archivo_url      VARCHAR(300),

    CONSTRAINT pk_orden_examen_detalle PRIMARY KEY (orden_examen_id, examen_id),
    -- Si hay un valor numérico tiene que haber una unidad: «12,5» sin decir de
    -- qué no es un resultado, es un número suelto.
    CONSTRAINT ck_orden_det_unidad CHECK (valor_numerico IS NULL OR unidad IS NOT NULL),
    CONSTRAINT ck_orden_det_fecha  CHECK (fecha_resultado IS NULL OR fecha_resultado <= CURRENT_DATE)
);
COMMENT ON TABLE orden_examen_detalle IS
    'ASOCIATIVA CON ATRIBUTOS. Resuelve la N:M entre orden_examen y examen, y '
    'guarda el resultado, que es propio de esta solicitud concreta.';


-- ============================================================================
--  BLOQUE D — PRESCRIPCIÓN Y MEDICINA PREVENTIVA
-- ============================================================================

CREATE TABLE receta (
    id                      INTEGER      GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    consulta_id             INTEGER      NOT NULL,
    folio                   VARCHAR(20)  NOT NULL,
    fecha_emision           DATE         NOT NULL DEFAULT CURRENT_DATE,
    indicaciones_generales  TEXT,
    vigencia_dias           SMALLINT     NOT NULL DEFAULT 30,
    creado_en               TIMESTAMPTZ  NOT NULL DEFAULT now(),

    -- NOT NULL + UNIQUE: no hay receta sin consulta, y una consulta genera a
    -- lo sumo una receta. Así queda la relación 1:0..1.
    CONSTRAINT uq_receta_consulta UNIQUE (consulta_id),
    CONSTRAINT uq_receta_folio    UNIQUE (folio),
    CONSTRAINT ck_receta_vigencia CHECK (vigencia_dias > 0 AND vigencia_dias <= 365),
    CONSTRAINT ck_receta_fecha    CHECK (fecha_emision <= CURRENT_DATE)
);
COMMENT ON TABLE receta IS
    'Documento de prescripción. NO guarda mascota_id ni veterinario_id: ambos '
    'se derivan por receta → consulta. Almacenarlos sería redundancia '
    'transitiva (violación de 3FN) y permitiría una receta de «Luna» colgando '
    'de una consulta de «Max».';


CREATE TABLE receta_detalle (
    receta_id           INTEGER       NOT NULL,
    medicamento_id      INTEGER       NOT NULL,
    dosis               VARCHAR(60)   NOT NULL,
    frecuencia          VARCHAR(60)   NOT NULL,
    duracion_dias       SMALLINT      NOT NULL,
    via_administracion  VARCHAR(15)   NOT NULL DEFAULT 'ORAL',
    cantidad            NUMERIC(8,2)  NOT NULL DEFAULT 1,
    instrucciones       VARCHAR(300),

    -- La PK compuesta impide prescribir dos veces el mismo fármaco en la misma
    -- receta con pautas contradictorias: un riesgo real de sobredosis.
    CONSTRAINT pk_receta_detalle PRIMARY KEY (receta_id, medicamento_id),
    CONSTRAINT ck_receta_det_duracion CHECK (duracion_dias > 0 AND duracion_dias <= 365),
    CONSTRAINT ck_receta_det_cantidad CHECK (cantidad > 0),
    CONSTRAINT ck_receta_det_via CHECK (via_administracion IN
        ('ORAL','TOPICA','INTRAMUSCULAR','SUBCUTANEA','INTRAVENOSA','OFTALMICA','OTICA','RECTAL')),
    CONSTRAINT ck_receta_det_dosis CHECK (length(btrim(dosis)) > 0 AND length(btrim(frecuencia)) > 0)
);
COMMENT ON TABLE receta_detalle IS
    'ASOCIATIVA CON ATRIBUTOS. La dosis no es propiedad del fármaco ni de la '
    'receta, sino del hecho de prescribir ESE fármaco en ESA receta. dosis y '
    'frecuencia son texto a propósito: el veterinario escribe «1/2 comprimido» '
    'o «0,5 ml por kg», y no existe una unidad común que los numerice.';


CREATE TABLE vacuna (
    id                        INTEGER       GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    producto_id               INTEGER,
    nombre                    VARCHAR(100)  NOT NULL,
    laboratorio               VARCHAR(100),
    enfermedades_previene     VARCHAR(300),
    dosis_ml                  NUMERIC(5,2),
    intervalo_refuerzo_meses  SMALLINT,
    edad_minima_semanas       SMALLINT,
    precio                    dom_dinero    NOT NULL DEFAULT 0,
    activo                    dom_estado_activo,

    CONSTRAINT uq_vacuna_nombre   UNIQUE (nombre),
    CONSTRAINT uq_vacuna_producto UNIQUE (producto_id),
    CONSTRAINT ck_vacuna_dosis    CHECK (dosis_ml IS NULL OR dosis_ml > 0),
    CONSTRAINT ck_vacuna_refuerzo CHECK (intervalo_refuerzo_meses IS NULL OR intervalo_refuerzo_meses > 0),
    CONSTRAINT ck_vacuna_edad     CHECK (edad_minima_semanas IS NULL OR edad_minima_semanas >= 0)
);
COMMENT ON TABLE vacuna IS
    'Catálogo de biológicos. producto_id vincula el biológico con su ítem de '
    'inventario, para que aplicarlo descuente stock.';


CREATE TABLE vacuna_especie (
    vacuna_id   INTEGER   NOT NULL,
    especie_id  SMALLINT  NOT NULL,
    CONSTRAINT pk_vacuna_especie PRIMARY KEY (vacuna_id, especie_id)
);
COMMENT ON TABLE vacuna_especie IS
    'ASOCIATIVA. Resuelve la N:M entre vacuna y especie. Su razón de existir es '
    'funcional: impide desde el modelo ofrecer una vacuna canina para un felino.';


CREATE TABLE aplicacion_vacuna (
    id                      INTEGER      GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    mascota_id              INTEGER      NOT NULL,
    vacuna_id               INTEGER      NOT NULL,
    veterinario_id          INTEGER      NOT NULL,
    consulta_id             INTEGER,
    fecha_aplicacion        DATE         NOT NULL DEFAULT CURRENT_DATE,
    fecha_proximo_refuerzo  DATE,
    lote                    VARCHAR(40)  NOT NULL,
    dosis_numero            SMALLINT     NOT NULL DEFAULT 1,
    via_administracion      VARCHAR(15)  NOT NULL DEFAULT 'SUBCUTANEA',
    reaccion_adversa        TEXT,
    creado_en               TIMESTAMPTZ  NOT NULL DEFAULT now(),

    -- Clave sustituta y no compuesta: la natural (mascota, vacuna) impediría
    -- registrar los refuerzos anuales. La UNIQUE conserva la regla sin
    -- arrastrar una clave de tres columnas por todo el esquema.
    CONSTRAINT uq_aplicacion_vacuna UNIQUE (mascota_id, vacuna_id, fecha_aplicacion),
    CONSTRAINT ck_aplicacion_fecha    CHECK (fecha_aplicacion <= CURRENT_DATE),
    CONSTRAINT ck_aplicacion_refuerzo CHECK (fecha_proximo_refuerzo IS NULL
                                          OR fecha_proximo_refuerzo >= fecha_aplicacion),
    CONSTRAINT ck_aplicacion_dosis    CHECK (dosis_numero > 0 AND dosis_numero <= 20),
    CONSTRAINT ck_aplicacion_lote     CHECK (length(btrim(lote)) > 0),
    CONSTRAINT ck_aplicacion_via CHECK (via_administracion IN
        ('SUBCUTANEA','INTRAMUSCULAR','INTRANASAL','ORAL','INTRADERMICA'))
);
COMMENT ON TABLE aplicacion_vacuna IS
    'ASOCIATIVA CON ATRIBUTOS. Resuelve la N:M entre mascota y vacuna. El lote '
    'es obligatorio por trazabilidad sanitaria: si el laboratorio retira un '
    'lote hay que poder localizar a todos los animales que lo recibieron.';


CREATE TABLE desparasitacion (
    id                  INTEGER      GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    mascota_id          INTEGER      NOT NULL,
    producto_id         INTEGER      NOT NULL,
    veterinario_id      INTEGER,
    consulta_id         INTEGER,
    tipo                VARCHAR(10)  NOT NULL,
    fecha_aplicacion    DATE         NOT NULL DEFAULT CURRENT_DATE,
    proxima_aplicacion  DATE,
    dosis               VARCHAR(60)  NOT NULL,
    observaciones       TEXT,

    CONSTRAINT ck_desparasitacion_tipo  CHECK (tipo IN ('INTERNA','EXTERNA','MIXTA')),
    CONSTRAINT ck_desparasitacion_fecha CHECK (fecha_aplicacion <= CURRENT_DATE),
    CONSTRAINT ck_desparasitacion_prox  CHECK (proxima_aplicacion IS NULL
                                            OR proxima_aplicacion >= fecha_aplicacion)
);
COMMENT ON TABLE desparasitacion IS
    'Entidad propia y no un tratamiento porque genera una fecha de próxima '
    'aplicación que el sistema debe vigilar, igual que una vacuna.';


-- ============================================================================
--  BLOQUE E — HOSPITALIZACIÓN Y CIRUGÍA
-- ============================================================================

CREATE TABLE cirugia (
    id                 INTEGER       GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    mascota_id         INTEGER       NOT NULL,
    consulta_id        INTEGER,
    veterinario_id     INTEGER       NOT NULL,
    anestesista_id     INTEGER,
    tipo_cirugia       VARCHAR(80)   NOT NULL,
    fecha_programada   TIMESTAMPTZ   NOT NULL,
    fecha_realizacion  TIMESTAMPTZ,
    duracion_minutos   SMALLINT,
    tipo_anestesia     VARCHAR(15),
    hallazgos          TEXT,
    complicaciones     TEXT,
    estado             VARCHAR(12)   NOT NULL DEFAULT 'programada',
    creado_en          TIMESTAMPTZ   NOT NULL DEFAULT now(),

    CONSTRAINT ck_cirugia_estado    CHECK (estado IN ('programada','realizada','suspendida','cancelada')),
    CONSTRAINT ck_cirugia_anestesia CHECK (tipo_anestesia IS NULL OR tipo_anestesia IN ('LOCAL','SEDACION','GENERAL')),
    CONSTRAINT ck_cirugia_duracion  CHECK (duracion_minutos IS NULL OR duracion_minutos > 0),
    -- El cirujano y el anestesista no pueden ser la misma persona.
    CONSTRAINT ck_cirugia_equipo    CHECK (anestesista_id IS NULL OR anestesista_id <> veterinario_id),
    -- Una cirugía realizada tiene fecha de realización; una que no lo está, no.
    CONSTRAINT ck_cirugia_realizacion CHECK (
        (estado =  'realizada' AND fecha_realizacion IS NOT NULL)
     OR (estado <> 'realizada' AND fecha_realizacion IS NULL))
);
COMMENT ON TABLE cirugia IS
    'Intervención quirúrgica. Entidad propia porque tiene un ciclo distinto al '
    'de una consulta: se programa, se realiza y registra hallazgos.';


CREATE TABLE habitacion (
    id         SMALLINT     GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    codigo     VARCHAR(15)  NOT NULL,
    tipo       VARCHAR(15)  NOT NULL,
    capacidad  SMALLINT     NOT NULL DEFAULT 1,
    activa     BOOLEAN      NOT NULL DEFAULT TRUE,

    CONSTRAINT uq_habitacion_codigo UNIQUE (codigo),
    CONSTRAINT ck_habitacion_tipo      CHECK (tipo IN ('GENERAL','AISLAMIENTO','UCI','FELINA')),
    CONSTRAINT ck_habitacion_capacidad CHECK (capacidad > 0 AND capacidad <= 20)
);
COMMENT ON TABLE habitacion IS
    'Recurso físico de internación: jaula, box o sala de aislamiento.';


CREATE TABLE hospitalizacion (
    id                  INTEGER       GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    mascota_id          INTEGER       NOT NULL,
    consulta_id         INTEGER,
    cirugia_id          INTEGER,
    veterinario_id      INTEGER       NOT NULL,
    fecha_ingreso       TIMESTAMPTZ   NOT NULL DEFAULT now(),
    fecha_alta          TIMESTAMPTZ,
    motivo              VARCHAR(300)  NOT NULL,
    tipo_alta           VARCHAR(15),
    indicaciones_alta   TEXT,
    estado              VARCHAR(12)   NOT NULL DEFAULT 'activa',

    CONSTRAINT ck_hospitalizacion_estado CHECK (estado IN ('activa','finalizada','cancelada')),
    CONSTRAINT ck_hospitalizacion_fechas CHECK (fecha_alta IS NULL OR fecha_alta > fecha_ingreso),
    CONSTRAINT ck_hospitalizacion_tipo_alta CHECK (tipo_alta IS NULL OR tipo_alta IN
        ('MEJORIA','DERIVACION','VOLUNTARIA','FALLECIMIENTO')),
    -- Una internación finalizada tiene alta y motivo de alta; una activa, no.
    CONSTRAINT ck_hospitalizacion_alta CHECK (
        (estado =  'finalizada' AND fecha_alta IS NOT NULL AND tipo_alta IS NOT NULL)
     OR (estado <> 'finalizada' AND fecha_alta IS NULL))
);
COMMENT ON TABLE hospitalizacion IS
    'Episodio de internación. La fecha de ingreso es TIMESTAMPTZ y no DATE '
    'porque de la hora depende el cómputo de días que se factura.';


CREATE TABLE hospitalizacion_habitacion (
    id                  INTEGER       GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    hospitalizacion_id  INTEGER       NOT NULL,
    habitacion_id       SMALLINT      NOT NULL,
    desde               TIMESTAMPTZ   NOT NULL DEFAULT now(),
    hasta               TIMESTAMPTZ,
    motivo_traslado     VARCHAR(200),

    -- Clave sustituta: el paciente puede volver a la habitación de la que
    -- salió, así que el par (internación, habitación) no es único.
    CONSTRAINT uq_hosp_hab UNIQUE (hospitalizacion_id, habitacion_id, desde),
    CONSTRAINT ck_hosp_hab_periodo CHECK (hasta IS NULL OR hasta > desde),

    -- Una misma internación no puede ocupar dos habitaciones a la vez.
    CONSTRAINT ex_hosp_hab_sin_solape EXCLUDE USING gist (
        hospitalizacion_id WITH =,
        tstzrange(desde, hasta) WITH &&
    )
);
COMMENT ON TABLE hospitalizacion_habitacion IS
    'ASOCIATIVA CON ATRIBUTOS. Una internación puede recorrer varias '
    'habitaciones (de UCI a general) y una habitación aloja muchas '
    'internaciones a lo largo del tiempo. El sobrecupo por capacidad lo '
    'verifica un trigger: EXCLUDE no sabe contar ocupantes.';


CREATE TABLE seguimiento_hospitalario (
    id                       INTEGER       GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    hospitalizacion_id       INTEGER       NOT NULL,
    empleado_id              INTEGER       NOT NULL,
    fecha_hora               TIMESTAMPTZ   NOT NULL DEFAULT now(),
    temperatura_c            NUMERIC(4,1),
    frecuencia_cardiaca      SMALLINT,
    frecuencia_respiratoria  SMALLINT,
    alimentacion             VARCHAR(15),
    hidratacion              VARCHAR(15),
    observaciones            TEXT,

    CONSTRAINT ck_seguimiento_temp CHECK (temperatura_c IS NULL OR temperatura_c BETWEEN 30.0 AND 45.0),
    CONSTRAINT ck_seguimiento_fc   CHECK (frecuencia_cardiaca IS NULL OR frecuencia_cardiaca BETWEEN 20 AND 400),
    CONSTRAINT ck_seguimiento_fr   CHECK (frecuencia_respiratoria IS NULL OR frecuencia_respiratoria BETWEEN 5 AND 200),
    CONSTRAINT ck_seguimiento_alim CHECK (alimentacion IS NULL OR alimentacion IN ('NORMAL','REDUCIDA','NULA','ASISTIDA')),
    CONSTRAINT ck_seguimiento_hidr CHECK (hidratacion IS NULL OR hidratacion IN ('NORMAL','LEVE','MODERADA','SEVERA')),
    CONSTRAINT ck_seguimiento_fecha CHECK (fecha_hora <= now())
);
COMMENT ON TABLE seguimiento_hospitalario IS
    'ENTIDAD DÉBIL. Control periódico durante una internación. Los signos '
    'vitales se repiten cada turno: son una serie temporal, no columnas de '
    'hospitalizacion. El peso tomado en el control va a registro_peso.';


-- ============================================================================
--  BLOQUE F — INVENTARIO, PRODUCTOS Y COMPRAS
-- ============================================================================

CREATE TABLE categoria_producto (
    id           SMALLINT     GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    padre_id     SMALLINT,
    nombre       VARCHAR(80)  NOT NULL,
    descripcion  VARCHAR(250),
    activo       dom_estado_activo,

    CONSTRAINT uq_categoria_nombre UNIQUE (nombre),
    CONSTRAINT ck_categoria_no_autopadre CHECK (padre_id IS NULL OR padre_id <> id)
);
COMMENT ON TABLE categoria_producto IS
    'Catálogo CON JERARQUÍA RECURSIVA: «Alimento» → «Alimento medicado» → '
    '«Renal». Evita crear una tabla por nivel.';


CREATE TABLE producto (
    id              INTEGER        GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    categoria_id    SMALLINT       NOT NULL,
    codigo          VARCHAR(20)    NOT NULL,
    codigo_barras   VARCHAR(20),
    nombre          VARCHAR(120)   NOT NULL,
    descripcion     TEXT,
    unidad_medida   VARCHAR(15)    NOT NULL DEFAULT 'UNIDAD',
    precio_venta    dom_dinero     NOT NULL DEFAULT 0,
    stock_minimo    NUMERIC(10,2)  NOT NULL DEFAULT 0,
    es_medicamento  BOOLEAN        NOT NULL DEFAULT FALSE,
    activo          dom_estado_activo,
    creado_en       TIMESTAMPTZ    NOT NULL DEFAULT now(),
    actualizado_en  TIMESTAMPTZ    NOT NULL DEFAULT now(),

    CONSTRAINT uq_producto_codigo  UNIQUE (codigo),
    CONSTRAINT uq_producto_barras  UNIQUE (codigo_barras),
    CONSTRAINT ck_producto_unidad  CHECK (unidad_medida IN ('UNIDAD','CAJA','FRASCO','KG','LITRO','AMPOLLA','SOBRE')),
    CONSTRAINT ck_producto_minimo  CHECK (stock_minimo >= 0),
    -- EAN-13: trece dígitos donde el cero inicial forma parte del código.
    CONSTRAINT ck_producto_barras  CHECK (codigo_barras IS NULL OR codigo_barras ~ '^[0-9]{8,20}$')
);
COMMENT ON TABLE producto IS
    'SUPERTIPO comercial: todo lo que se compra, almacena y vende. NO tiene '
    'columna de stock: el saldo se deriva sumando movimiento_stock, de modo '
    'que nadie puede editarlo directamente.';


CREATE TABLE medicamento (
    -- Igual que veterinario: la PK es la FK al supertipo.
    producto_id         INTEGER       PRIMARY KEY,
    principio_activo    VARCHAR(120)  NOT NULL,
    concentracion       VARCHAR(40),
    presentacion        VARCHAR(20)   NOT NULL,
    via_administracion  VARCHAR(15)   NOT NULL DEFAULT 'ORAL',
    requiere_receta     BOOLEAN       NOT NULL DEFAULT TRUE,
    contraindicaciones  TEXT,
    laboratorio         VARCHAR(100),

    CONSTRAINT ck_medicamento_presentacion CHECK (presentacion IN
        ('COMPRIMIDO','JARABE','INYECTABLE','CREMA','GOTAS','SPRAY','POLVO','SOBRE','OTRO')),
    CONSTRAINT ck_medicamento_via CHECK (via_administracion IN
        ('ORAL','TOPICA','INTRAMUSCULAR','SUBCUTANEA','INTRAVENOSA','OFTALMICA','OTICA','RECTAL')),
    CONSTRAINT ck_medicamento_principio CHECK (length(btrim(principio_activo)) > 0)
);
COMMENT ON TABLE medicamento IS
    'SUBTIPO (ISA) de producto. Al ser una especialización y no una entidad '
    'aparte, recetar y vender operan sobre el MISMO ítem de inventario: '
    'prescribir descuenta stock.';


CREATE TABLE proveedor (
    id              INTEGER       GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    tipo_documento  VARCHAR(10)   NOT NULL DEFAULT 'RUC',
    documento       VARCHAR(20)   NOT NULL,
    razon_social    VARCHAR(150)  NOT NULL,
    nombre_contacto VARCHAR(120),
    telefono        dom_telefono  NOT NULL,
    email           dom_email,
    direccion       VARCHAR(200),
    activo          dom_estado_activo,

    CONSTRAINT uq_proveedor_documento UNIQUE (tipo_documento, documento),
    CONSTRAINT ck_proveedor_tipo_doc  CHECK (tipo_documento IN ('RUC','NIT','CUIT','DNI','OTRO')),
    CONSTRAINT ck_proveedor_razon     CHECK (length(btrim(razon_social)) > 0)
);
COMMENT ON TABLE proveedor IS 'Empresa que abastece a la clínica.';


CREATE TABLE proveedor_producto (
    proveedor_id         INTEGER      NOT NULL,
    producto_id          INTEGER      NOT NULL,
    codigo_proveedor     VARCHAR(40),
    precio_compra        dom_dinero   NOT NULL,
    tiempo_entrega_dias  SMALLINT,
    es_preferido         BOOLEAN      NOT NULL DEFAULT FALSE,

    CONSTRAINT pk_proveedor_producto PRIMARY KEY (proveedor_id, producto_id),
    CONSTRAINT ck_prov_prod_entrega CHECK (tiempo_entrega_dias IS NULL OR tiempo_entrega_dias >= 0)
);
COMMENT ON TABLE proveedor_producto IS
    'ASOCIATIVA CON ATRIBUTOS. El precio de compra es propio de la asociación: '
    'cada proveedor cotiza distinto el mismo producto.';


CREATE TABLE compra (
    id              INTEGER      GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    proveedor_id    INTEGER      NOT NULL,
    empleado_id     INTEGER,
    numero_factura  VARCHAR(30)  NOT NULL,
    fecha_compra    DATE         NOT NULL DEFAULT CURRENT_DATE,
    subtotal        dom_dinero   NOT NULL DEFAULT 0,
    impuesto        dom_dinero   NOT NULL DEFAULT 0,
    descuento       dom_dinero   NOT NULL DEFAULT 0,
    total           dom_dinero   NOT NULL DEFAULT 0,
    estado          VARCHAR(12)  NOT NULL DEFAULT 'pendiente',
    creado_en       TIMESTAMPTZ  NOT NULL DEFAULT now(),

    -- El número de factura es único POR PROVEEDOR: dos proveedores distintos
    -- pueden emitir su factura 001.
    CONSTRAINT uq_compra_factura UNIQUE (proveedor_id, numero_factura),
    CONSTRAINT ck_compra_estado    CHECK (estado IN ('pendiente','recibida','anulada')),
    CONSTRAINT ck_compra_fecha     CHECK (fecha_compra <= CURRENT_DATE),
    CONSTRAINT ck_compra_descuento CHECK (descuento <= subtotal),
    CONSTRAINT ck_compra_total     CHECK (total = subtotal - descuento + impuesto)
);
COMMENT ON TABLE compra IS
    'Documento de ingreso de mercadería. Los totales se almacenan porque un '
    'documento comercial es inmutable: si mañana cambia el precio de catálogo, '
    'el total de la compra de hoy no debe cambiar con él.';


CREATE TABLE compra_detalle (
    id                 INTEGER        GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    compra_id          INTEGER        NOT NULL,
    producto_id        INTEGER        NOT NULL,
    linea_nro          SMALLINT       NOT NULL,
    cantidad           NUMERIC(10,2)  NOT NULL,
    precio_unitario    dom_dinero     NOT NULL,
    lote               VARCHAR(40),
    fecha_vencimiento  DATE,
    -- El motor calcula y almacena el valor: es imposible insertar un subtotal
    -- incoherente, aunque la inserción venga por psql y no por la aplicación.
    subtotal           NUMERIC(12,2)  GENERATED ALWAYS AS (cantidad * precio_unitario) STORED,

    CONSTRAINT uq_compra_detalle_linea UNIQUE (compra_id, linea_nro),
    CONSTRAINT ck_compra_det_linea    CHECK (linea_nro > 0),
    CONSTRAINT ck_compra_det_cantidad CHECK (cantidad > 0)
);
COMMENT ON TABLE compra_detalle IS
    'ASOCIATIVA CON ATRIBUTOS. Líneas de la compra. El vencimiento del lote '
    'permite alertar productos por vencer.';


CREATE TABLE movimiento_stock (
    id                    INTEGER        GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    producto_id           INTEGER        NOT NULL,
    empleado_id           INTEGER,
    tipo                  VARCHAR(15)    NOT NULL,
    cantidad              NUMERIC(10,2)  NOT NULL,
    fecha_hora            TIMESTAMPTZ    NOT NULL DEFAULT now(),
    compra_detalle_id     INTEGER,
    factura_detalle_id    INTEGER,
    aplicacion_vacuna_id  INTEGER,
    desparasitacion_id    INTEGER,
    motivo                VARCHAR(200),
    lote                  VARCHAR(40),

    CONSTRAINT ck_movimiento_tipo CHECK (tipo IN ('ENTRADA','SALIDA','AJUSTE','MERMA','DEVOLUCION')),
    -- Un movimiento de cero no mueve nada: es ruido en el kardex.
    CONSTRAINT ck_movimiento_cantidad CHECK (cantidad <> 0),
    -- El signo tiene que concordar con el tipo. Es lo que permite que el saldo
    -- sea una sola suma en lugar de una resta condicionada.
    CONSTRAINT ck_movimiento_signo CHECK (
        (tipo IN ('ENTRADA','DEVOLUCION') AND cantidad > 0)
     OR (tipo IN ('SALIDA','MERMA')       AND cantidad < 0)
     OR (tipo =  'AJUSTE')),
    -- Un ajuste o una merma sin explicación es un agujero en la auditoría.
    CONSTRAINT ck_movimiento_motivo CHECK (
        tipo NOT IN ('AJUSTE','MERMA') OR motivo IS NOT NULL),
    -- Un movimiento tiene como mucho un origen documental. Cero orígenes es
    -- válido: un ajuste de inventario no proviene de ningún documento.
    CONSTRAINT ck_movimiento_origen CHECK (
        (CASE WHEN compra_detalle_id    IS NOT NULL THEN 1 ELSE 0 END
       + CASE WHEN factura_detalle_id   IS NOT NULL THEN 1 ELSE 0 END
       + CASE WHEN aplicacion_vacuna_id IS NOT NULL THEN 1 ELSE 0 END
       + CASE WHEN desparasitacion_id   IS NOT NULL THEN 1 ELSE 0 END) <= 1)
);
COMMENT ON TABLE movimiento_stock IS
    'KARDEX. Toda entrada y salida deja rastro. El stock actual es SUM(cantidad) '
    'sobre esta tabla, no una columna editable: por eso la cantidad lleva signo.';


-- ============================================================================
--  BLOQUE G — FACTURACIÓN Y COBROS
-- ============================================================================

CREATE TABLE servicio (
    id                     INTEGER       GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    codigo                 VARCHAR(15)   NOT NULL,
    nombre                 VARCHAR(120)  NOT NULL,
    categoria              VARCHAR(30)   NOT NULL,
    descripcion            TEXT,
    precio_base            dom_dinero    NOT NULL,
    duracion_estimada_min  SMALLINT,
    icono                  VARCHAR(20),
    visible_publico        BOOLEAN       NOT NULL DEFAULT TRUE,
    activo                 dom_estado_activo,

    CONSTRAINT uq_servicio_codigo UNIQUE (codigo),
    CONSTRAINT uq_servicio_nombre UNIQUE (nombre),
    CONSTRAINT ck_servicio_categoria CHECK (categoria IN
        ('CONSULTA','CIRUGIA','DIAGNOSTICO','ESTETICA','VACUNACION','HOSPITALIZACION','OTRO')),
    CONSTRAINT ck_servicio_duracion CHECK (duracion_estimada_min IS NULL OR duracion_estimada_min > 0)
);
COMMENT ON TABLE servicio IS
    'Catálogo de prestaciones facturables. visible_publico separa el catálogo '
    'interno del que se publica en el sitio institucional.';


CREATE TABLE factura (
    id                   INTEGER      GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    cliente_id           INTEGER      NOT NULL,
    usuario_emisor_id    INTEGER,
    numero               VARCHAR(20)  NOT NULL,
    fecha_emision        DATE         NOT NULL DEFAULT CURRENT_DATE,
    subtotal             dom_dinero   NOT NULL DEFAULT 0,
    descuento            dom_dinero   NOT NULL DEFAULT 0,
    porcentaje_impuesto  NUMERIC(5,2) NOT NULL DEFAULT 0,
    impuesto             dom_dinero   NOT NULL DEFAULT 0,
    total                dom_dinero   NOT NULL DEFAULT 0,
    saldo_pendiente      dom_dinero   NOT NULL DEFAULT 0,
    estado               VARCHAR(12)  NOT NULL DEFAULT 'pendiente',
    observaciones        TEXT,
    creado_en            TIMESTAMPTZ  NOT NULL DEFAULT now(),
    actualizado_en       TIMESTAMPTZ  NOT NULL DEFAULT now(),

    CONSTRAINT uq_factura_numero  UNIQUE (numero),
    CONSTRAINT ck_factura_estado  CHECK (estado IN ('pendiente','parcial','pagada','anulada')),
    CONSTRAINT ck_factura_impuesto_pct CHECK (porcentaje_impuesto BETWEEN 0 AND 100),
    CONSTRAINT ck_factura_descuento    CHECK (descuento <= subtotal),
    -- Coherencia aritmética verificada por el motor, no por la aplicación.
    CONSTRAINT ck_factura_total   CHECK (total = subtotal - descuento + impuesto),
    CONSTRAINT ck_factura_saldo   CHECK (saldo_pendiente <= total),
    CONSTRAINT ck_factura_fecha   CHECK (fecha_emision <= CURRENT_DATE),
    -- Coherencia entre estado y saldo: una factura pagada no debe nada, y una
    -- pendiente debe todo.
    CONSTRAINT ck_factura_estado_saldo CHECK (
        (estado = 'pagada'    AND saldo_pendiente = 0)
     OR (estado = 'anulada')
     OR (estado = 'parcial'   AND saldo_pendiente > 0 AND saldo_pendiente < total)
     OR (estado = 'pendiente' AND saldo_pendiente = total))
);
COMMENT ON TABLE factura IS
    'Documento fiscal inmutable emitido al TUTOR, no a la mascota: un mismo '
    'documento puede cubrir servicios de varias mascotas del mismo cliente. Los '
    'totales se almacenan a propósito y los mantiene un trigger.';


CREATE TABLE factura_detalle (
    id               INTEGER        GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    factura_id       INTEGER        NOT NULL,
    servicio_id      INTEGER,
    producto_id      INTEGER,
    examen_id        INTEGER,
    mascota_id       INTEGER,
    consulta_id      INTEGER,
    linea_nro        SMALLINT       NOT NULL,
    tipo_item        VARCHAR(12)    NOT NULL,
    descripcion      VARCHAR(200)   NOT NULL,
    cantidad         NUMERIC(8,2)   NOT NULL,
    precio_unitario  dom_dinero     NOT NULL,
    descuento_linea  dom_dinero     NOT NULL DEFAULT 0,
    subtotal         NUMERIC(12,2)  GENERATED ALWAYS AS
                       (cantidad * precio_unitario - descuento_linea) STORED,

    CONSTRAINT uq_factura_detalle_linea UNIQUE (factura_id, linea_nro),
    CONSTRAINT ck_factura_det_linea    CHECK (linea_nro > 0),
    CONSTRAINT ck_factura_det_cantidad CHECK (cantidad > 0),
    CONSTRAINT ck_factura_det_tipo CHECK (tipo_item IN ('SERVICIO','PRODUCTO','EXAMEN','OTRO')),
    CONSTRAINT ck_factura_det_descuento CHECK (descuento_linea <= cantidad * precio_unitario),

    -- ARCO EXCLUSIVO: cada línea apunta a un servicio, un producto o un examen,
    -- exactamente uno, y el tipo_item concuerda con cuál. Sin esto, una línea
    -- podría tener las tres foráneas cargadas —¿qué se vendió?— o ninguna con
    -- tipo_item = 'SERVICIO'.
    CONSTRAINT ck_factura_det_arco CHECK (
        (tipo_item = 'SERVICIO' AND servicio_id IS NOT NULL AND producto_id IS NULL     AND examen_id IS NULL)
     OR (tipo_item = 'PRODUCTO' AND producto_id IS NOT NULL AND servicio_id IS NULL     AND examen_id IS NULL)
     OR (tipo_item = 'EXAMEN'   AND examen_id   IS NOT NULL AND servicio_id IS NULL     AND producto_id IS NULL)
     OR (tipo_item = 'OTRO'     AND servicio_id IS NULL     AND producto_id IS NULL     AND examen_id IS NULL))
);
COMMENT ON TABLE factura_detalle IS
    'ASOCIATIVA CON ARCO EXCLUSIVO. descripcion y precio_unitario son SNAPSHOT '
    'del catálogo al momento de la venta: si mañana el servicio se renombra o '
    'cambia de precio, la factura histórica conserva lo que realmente se vendió.';


CREATE TABLE metodo_pago (
    id                   SMALLINT     GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    nombre               VARCHAR(40)  NOT NULL,
    requiere_referencia  BOOLEAN      NOT NULL DEFAULT FALSE,
    activo               dom_estado_activo,

    CONSTRAINT uq_metodo_pago_nombre UNIQUE (nombre)
);
COMMENT ON TABLE metodo_pago IS 'Catálogo de formas de cobro.';


CREATE TABLE pago (
    id              INTEGER      GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    factura_id      INTEGER      NOT NULL,
    metodo_pago_id  SMALLINT     NOT NULL,
    usuario_id      INTEGER,
    fecha_hora      TIMESTAMPTZ  NOT NULL DEFAULT now(),
    monto           dom_dinero   NOT NULL,
    referencia      VARCHAR(60),
    anulado         BOOLEAN      NOT NULL DEFAULT FALSE,

    CONSTRAINT ck_pago_monto CHECK (monto > 0),
    CONSTRAINT ck_pago_fecha CHECK (fecha_hora <= now())
    -- «Si el método exige referencia, el pago debe traerla» necesita consultar
    -- metodo_pago: un CHECK no puede leer otra tabla. Va como trigger.
    -- «La suma de pagos no puede exceder el total» también, por el mismo motivo.
);
COMMENT ON TABLE pago IS
    'Cobro aplicado a una factura. Entidad propia y no un simple estado: '
    'permite pagos parciales y varios medios en una misma factura. Un pago '
    'nunca se borra, se marca anulado.';
