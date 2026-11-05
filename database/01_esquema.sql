-- ============================================================================
--  PETCARE — Clínica Veterinaria
--  01_esquema.sql · Tablas
-- ----------------------------------------------------------------------------
--  Derivado del MER entregado: 28 entidades + solicitud_cita.
--  Escrito a mano. Ninguna tabla proviene de migraciones de un ORM.
--
--  DIFERENCIAS CON EL MER, DOCUMENTADAS
--    + solicitud_cita           Necesaria para que el sitio público pueda
--                               recibir pedidos de turno de visitantes que
--                               todavía no son clientes.
--    + servicio.descripcion     Campos de presentación que el sitio público
--    + servicio.icono           necesita mostrar y que el MER no contemplaba.
--    + servicio.visible_publico
--    + veterinario.foto_url
--    + veterinario.biografia
--
--  Las claves foráneas van en 02_integridad.sql porque el modelo tiene
--  referencias circulares (registro_peso ↔ consulta, solicitud_cita ↔ cita)
--  que impiden un orden lineal de creación, y porque agruparlas deja la
--  política de borrado auditable de un vistazo.
-- ============================================================================

SET client_min_messages = WARNING;

-- btree_gist permite combinar igualdad con solapamiento en una restricción
-- EXCLUDE: es lo que impide que un veterinario tenga dos citas que se pisen.
CREATE EXTENSION IF NOT EXISTS btree_gist;
CREATE EXTENSION IF NOT EXISTS unaccent;
CREATE EXTENSION IF NOT EXISTS pg_trgm;


-- ----------------------------------------------------------------------------
--  DOMINIOS — declarar la restricción una vez evita olvidarla en alguna columna
-- ----------------------------------------------------------------------------

CREATE DOMAIN dom_dinero AS NUMERIC(12,2)
    CONSTRAINT dom_dinero_no_negativo CHECK (VALUE >= 0);
COMMENT ON DOMAIN dom_dinero IS
    'Importe monetario. NUMERIC y jamás FLOAT: el binario no representa '
    'decimales exactos y 0.1+0.2 <> 0.3 descuadraría los totales de factura.';

CREATE DOMAIN dom_email AS VARCHAR(120)
    CONSTRAINT dom_email_formato
    CHECK (VALUE ~ '^[^@[:space:]]+@[^@[:space:]]+\.[A-Za-z]{2,}$');

CREATE DOMAIN dom_telefono AS VARCHAR(25)
    CONSTRAINT dom_telefono_formato CHECK (VALUE ~ '^[0-9+()\- ]{6,25}$');
COMMENT ON DOMAIN dom_telefono IS
    'VARCHAR y no numérico: admite «+», paréntesis y ceros a la izquierda, '
    'que un entero destruiría. Nunca se opera aritméticamente con él.';


-- ----------------------------------------------------------------------------
--  SECUENCIAS — los folios llevan prefijo, así que la columna es VARCHAR
-- ----------------------------------------------------------------------------
CREATE SEQUENCE seq_factura_numero START 1 MINVALUE 1;
CREATE SEQUENCE seq_receta_folio   START 1 MINVALUE 1;


-- ============================================================================
--  BLOQUE A — SEGURIDAD Y PERSONAS
-- ============================================================================

CREATE TABLE rol (
    id           SMALLINT     GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    nombre       VARCHAR(50)  NOT NULL,
    descripcion  VARCHAR(200),
    CONSTRAINT uq_rol_nombre UNIQUE (nombre)
);
COMMENT ON TABLE rol IS 'Catálogo de perfiles de acceso al sistema.';


CREATE TABLE usuario (
    id              INTEGER       GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    rol_id          SMALLINT      NOT NULL,
    nombre_usuario  VARCHAR(50)   NOT NULL,
    email           dom_email     NOT NULL,
    password_hash   VARCHAR(255)  NOT NULL,
    activo          BOOLEAN       NOT NULL DEFAULT TRUE,
    ultimo_acceso   TIMESTAMPTZ,
    creado_en       TIMESTAMPTZ   NOT NULL DEFAULT now(),

    CONSTRAINT uq_usuario_nombre UNIQUE (nombre_usuario),
    CONSTRAINT uq_usuario_email  UNIQUE (email),
    -- Un hash moderno nunca es corto: bcrypt son 60 caracteres con prefijo.
    CONSTRAINT ck_usuario_hash   CHECK (length(password_hash) >= 20)
);
COMMENT ON TABLE usuario IS 'Credencial de acceso. No representa a una persona del negocio.';
COMMENT ON COLUMN usuario.password_hash IS 'Hash bcrypt o argon2. NUNCA la clave en texto plano.';


CREATE TABLE especialidad (
    id           SMALLINT     GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    nombre       VARCHAR(80)  NOT NULL,
    descripcion  VARCHAR(200),
    CONSTRAINT uq_especialidad_nombre UNIQUE (nombre)
);


CREATE TABLE veterinario (
    id          INTEGER       GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    usuario_id  INTEGER,
    documento   VARCHAR(20)   NOT NULL,
    matricula   VARCHAR(30)   NOT NULL,
    nombres     VARCHAR(80)   NOT NULL,
    apellidos   VARCHAR(80)   NOT NULL,
    telefono    dom_telefono,
    email       dom_email,
    foto_url    VARCHAR(300),                 -- añadido: sitio público
    biografia   TEXT,                         -- añadido: sitio público
    activo      BOOLEAN       NOT NULL DEFAULT TRUE,

    CONSTRAINT uq_veterinario_usuario   UNIQUE (usuario_id),
    CONSTRAINT uq_veterinario_documento UNIQUE (documento),
    CONSTRAINT uq_veterinario_matricula UNIQUE (matricula),
    CONSTRAINT ck_veterinario_nombres   CHECK (length(btrim(nombres)) > 0
                                           AND length(btrim(apellidos)) > 0)
);
COMMENT ON TABLE veterinario IS 'Profesional que presta la atención clínica.';
COMMENT ON CONSTRAINT uq_veterinario_usuario ON veterinario IS
    'UNIQUE sobre columna que admite nulo: así se implementa la relación 1:0..1 '
    'con usuario. Hay profesionales sin acceso al sistema.';


CREATE TABLE veterinario_especialidad (
    veterinario_id   INTEGER   NOT NULL,
    especialidad_id  SMALLINT  NOT NULL,
    es_principal     BOOLEAN   NOT NULL DEFAULT FALSE,
    CONSTRAINT pk_veterinario_especialidad PRIMARY KEY (veterinario_id, especialidad_id)
);
COMMENT ON TABLE veterinario_especialidad IS
    'ASOCIATIVA. Resuelve la N:M entre veterinario y especialidad. La clave '
    'compuesta impide asignar dos veces la misma especialidad al mismo profesional.';


CREATE TABLE cliente (
    id              INTEGER      GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    tipo_documento  VARCHAR(10)  NOT NULL DEFAULT 'CC',
    documento       VARCHAR(20)  NOT NULL,
    nombres         VARCHAR(80)  NOT NULL,
    apellidos       VARCHAR(80)  NOT NULL,
    telefono        dom_telefono NOT NULL,
    email           dom_email,
    direccion       VARCHAR(200),
    ciudad          VARCHAR(80),
    notas           TEXT,
    activo          BOOLEAN      NOT NULL DEFAULT TRUE,
    creado_en       TIMESTAMPTZ  NOT NULL DEFAULT now(),

    -- La unicidad correcta es la del PAR: una cédula 12345678 y un pasaporte
    -- 12345678 son documentos distintos de personas distintas.
    CONSTRAINT uq_cliente_documento UNIQUE (tipo_documento, documento),
    CONSTRAINT ck_cliente_tipo_doc  CHECK (tipo_documento IN ('CC','CE','TI','PASAPORTE','NIT','OTRO')),
    CONSTRAINT ck_cliente_nombres   CHECK (length(btrim(nombres)) > 0
                                       AND length(btrim(apellidos)) > 0)
);
COMMENT ON TABLE cliente IS
    'Tutor o propietario responsable. El paciente es la mascota; el cliente es '
    'quien la lleva y con quien se establece la relación comercial.';


-- ============================================================================
--  BLOQUE B — MASCOTA Y TAXONOMÍA
-- ============================================================================

CREATE TABLE especie (
    id                    SMALLINT     GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    nombre                VARCHAR(50)  NOT NULL,
    icono                 VARCHAR(16),
    esperanza_vida_anios  SMALLINT,
    CONSTRAINT uq_especie_nombre UNIQUE (nombre),
    CONSTRAINT ck_especie_vida   CHECK (esperanza_vida_anios IS NULL OR esperanza_vida_anios > 0)
);


CREATE TABLE raza (
    id          INTEGER      GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    especie_id  SMALLINT     NOT NULL,
    nombre      VARCHAR(80)  NOT NULL,
    tamanio     VARCHAR(15),

    CONSTRAINT uq_raza_especie_nombre UNIQUE (especie_id, nombre),
    -- Clave alternativa técnica: PostgreSQL exige que el destino de una clave
    -- foránea compuesta tenga un UNIQUE con esas mismas columnas. Es la que
    -- habilita la FK (raza_id, especie_id) desde mascota.
    CONSTRAINT uq_raza_id_especie     UNIQUE (id, especie_id),
    CONSTRAINT ck_raza_tamanio CHECK (tamanio IS NULL OR tamanio IN
        ('PEQUENO','MEDIANO','GRANDE','GIGANTE'))
);


CREATE TABLE mascota (
    id                   INTEGER      GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    cliente_id           INTEGER      NOT NULL,
    -- especie_id es obligatoria e INDEPENDIENTE de raza_id: un mestizo de raza
    -- desconocida conserva su especie. Esa es la razón de que convivan las dos.
    especie_id           SMALLINT     NOT NULL,
    raza_id              INTEGER,
    nombre               VARCHAR(60)  NOT NULL,
    sexo                 CHAR(1)      NOT NULL,
    fecha_nacimiento     DATE,
    color                VARCHAR(60),
    microchip            VARCHAR(25),
    esterilizado         BOOLEAN      NOT NULL DEFAULT FALSE,
    foto_url             VARCHAR(300),
    observaciones        TEXT,
    fecha_fallecimiento  DATE,
    activo               BOOLEAN      NOT NULL DEFAULT TRUE,
    creado_en            TIMESTAMPTZ  NOT NULL DEFAULT now(),

    CONSTRAINT ck_mascota_sexo       CHECK (sexo IN ('M','H')),
    CONSTRAINT ck_mascota_nacimiento CHECK (fecha_nacimiento IS NULL
                                         OR fecha_nacimiento <= CURRENT_DATE),
    CONSTRAINT ck_mascota_deceso     CHECK (fecha_fallecimiento IS NULL
                                         OR fecha_nacimiento IS NULL
                                         OR fecha_fallecimiento >= fecha_nacimiento),
    CONSTRAINT ck_mascota_nombre     CHECK (length(btrim(nombre)) > 0),
    -- ISO 11784 son 15 dígitos: VARCHAR y no BIGINT porque exceden INTEGER y
    -- los ceros a la izquierda son significativos.
    CONSTRAINT ck_mascota_microchip  CHECK (microchip IS NULL
                                         OR microchip ~ '^[0-9A-Za-z]{9,25}$')
);
COMMENT ON TABLE mascota IS
    'NÚCLEO DEL SISTEMA. La edad, el peso actual y el estado de vacunación son '
    'DERIVADOS y se calculan en vistas; no existen como columnas.';


CREATE TABLE condicion_medica (
    id           INTEGER       GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    nombre       VARCHAR(100)  NOT NULL,
    tipo         VARCHAR(15)   NOT NULL,
    descripcion  VARCHAR(300),
    CONSTRAINT uq_condicion_nombre UNIQUE (nombre),
    CONSTRAINT ck_condicion_tipo   CHECK (tipo IN ('ALERGIA','CRONICA','CONGENITA'))
);
COMMENT ON TABLE condicion_medica IS
    'Catálogo unificado de alergias y condiciones crónicas. El atributo tipo '
    'evita mantener tres catálogos con la misma estructura.';


CREATE TABLE mascota_condicion (
    mascota_id           INTEGER      NOT NULL,
    condicion_medica_id  INTEGER      NOT NULL,
    severidad            VARCHAR(10)  NOT NULL DEFAULT 'MEDIA',
    fecha_deteccion      DATE,
    notas                TEXT,

    CONSTRAINT pk_mascota_condicion PRIMARY KEY (mascota_id, condicion_medica_id),
    CONSTRAINT ck_mascota_cond_sev   CHECK (severidad IN ('LEVE','MEDIA','GRAVE')),
    CONSTRAINT ck_mascota_cond_fecha CHECK (fecha_deteccion IS NULL
                                         OR fecha_deteccion <= CURRENT_DATE)
);
COMMENT ON TABLE mascota_condicion IS
    'ASOCIATIVA. La severidad es propia del vínculo: la misma alergia es leve '
    'en una mascota y grave en otra.';


CREATE TABLE registro_peso (
    id              INTEGER       GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    mascota_id      INTEGER       NOT NULL,
    consulta_id     INTEGER,
    fecha_registro  DATE          NOT NULL DEFAULT CURRENT_DATE,
    peso_kg         NUMERIC(6,2)  NOT NULL,
    observacion     VARCHAR(200),

    -- Un solo peso oficial por día. Esta regla SOLO funciona con DATE: con
    -- TIMESTAMP cada pesaje tendría hora distinta y nunca se aplicaría.
    CONSTRAINT uq_registro_peso_dia UNIQUE (mascota_id, fecha_registro),
    CONSTRAINT ck_registro_peso     CHECK (peso_kg > 0 AND peso_kg <= 2000),
    CONSTRAINT ck_registro_fecha    CHECK (fecha_registro <= CURRENT_DATE)
);
COMMENT ON TABLE registro_peso IS
    'ÚNICO lugar del modelo donde se almacena un peso. El «peso actual» de la '
    'mascota es la medición más reciente, calculada por vista.';


-- ============================================================================
--  BLOQUE C — ATENCIÓN CLÍNICA
-- ============================================================================

CREATE TABLE cita (
    id                  INTEGER       GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    mascota_id          INTEGER       NOT NULL,
    veterinario_id      INTEGER       NOT NULL,
    servicio_id         INTEGER,
    fecha_hora_inicio   TIMESTAMPTZ   NOT NULL,
    duracion_minutos    SMALLINT      NOT NULL DEFAULT 30,
    -- Derivada de inicio + duración, la mantiene el trigger tg_cita_fin.
    -- Existe por una razón técnica: la restricción EXCLUDE necesita un rango,
    -- y sumar un intervalo a un timestamptz no es IMMUTABLE (depende de la
    -- zona horaria), por lo que no puede usarse en un índice.
    fecha_hora_fin      TIMESTAMPTZ   NOT NULL,
    motivo              VARCHAR(300)  NOT NULL,
    estado              VARCHAR(12)   NOT NULL DEFAULT 'programada',
    motivo_cancelacion  VARCHAR(250),
    notas               TEXT,
    creado_en           TIMESTAMPTZ   NOT NULL DEFAULT now(),

    CONSTRAINT ck_cita_estado   CHECK (estado IN
        ('programada','confirmada','atendida','cancelada','no_asistio')),
    CONSTRAINT ck_cita_duracion CHECK (duracion_minutos BETWEEN 10 AND 480),
    CONSTRAINT ck_cita_fin      CHECK (fecha_hora_fin > fecha_hora_inicio),
    -- Cancelar exige justificar, y una cita que no está cancelada no puede
    -- arrastrar el motivo de una cancelación anterior revertida.
    CONSTRAINT ck_cita_cancelacion CHECK (
        (estado =  'cancelada' AND motivo_cancelacion IS NOT NULL)
     OR (estado <> 'cancelada' AND motivo_cancelacion IS NULL)),

    -- Un veterinario no puede tener dos citas que se pisen en el tiempo.
    -- Las canceladas y las de ausencia liberan el hueco de la agenda.
    CONSTRAINT ex_cita_sin_solapamiento EXCLUDE USING gist (
        veterinario_id WITH =,
        tstzrange(fecha_hora_inicio, fecha_hora_fin) WITH &&
    ) WHERE (estado IN ('programada','confirmada','atendida'))
);
COMMENT ON TABLE cita IS
    'Turno agendado. El tutor NO se almacena aquí: se deriva por mascota → '
    'cliente. Guardarlo sería una dependencia transitiva.';


CREATE TABLE consulta (
    id                       INTEGER       GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    mascota_id               INTEGER       NOT NULL,
    veterinario_id           INTEGER       NOT NULL,
    cita_id                  INTEGER,
    fecha_hora               TIMESTAMPTZ   NOT NULL DEFAULT now(),
    tipo                     VARCHAR(15)   NOT NULL DEFAULT 'GENERAL',
    motivo                   VARCHAR(300)  NOT NULL,
    anamnesis                TEXT,
    temperatura_c            NUMERIC(4,1),
    frecuencia_cardiaca      SMALLINT,
    frecuencia_respiratoria  SMALLINT,
    examen_fisico            TEXT,
    observaciones            TEXT,
    proxima_revision         DATE,
    creado_en                TIMESTAMPTZ   NOT NULL DEFAULT now(),

    -- UNIQUE sobre columna nullable: crea la relación 1:0..1 con cita. Nulo en
    -- las urgencias que llegan sin turno previo.
    CONSTRAINT uq_consulta_cita UNIQUE (cita_id),
    CONSTRAINT ck_consulta_tipo CHECK (tipo IN
        ('GENERAL','CONTROL','URGENCIA','VACUNACION','ESTETICA')),
    CONSTRAINT ck_consulta_fecha CHECK (fecha_hora <= now()),
    -- Rangos biológicos reales, no arbitrarios.
    CONSTRAINT ck_consulta_temp  CHECK (temperatura_c IS NULL
                                     OR temperatura_c BETWEEN 30.0 AND 45.0),
    CONSTRAINT ck_consulta_fc    CHECK (frecuencia_cardiaca IS NULL
                                     OR frecuencia_cardiaca BETWEEN 20 AND 400),
    CONSTRAINT ck_consulta_fr    CHECK (frecuencia_respiratoria IS NULL
                                     OR frecuencia_respiratoria BETWEEN 5 AND 200),
    CONSTRAINT ck_consulta_revision CHECK (proxima_revision IS NULL
                                        OR proxima_revision >= fecha_hora::date)
);
COMMENT ON TABLE consulta IS
    'Encuentro clínico realizado. NO almacena peso (va a registro_peso) ni '
    'diagnóstico en texto libre (va a consulta_diagnostico).';


CREATE TABLE diagnostico (
    id         INTEGER       GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    codigo     VARCHAR(15)   NOT NULL,
    nombre     VARCHAR(120)  NOT NULL,
    categoria  VARCHAR(50),
    CONSTRAINT uq_diagnostico_codigo UNIQUE (codigo),
    CONSTRAINT uq_diagnostico_nombre UNIQUE (nombre)
);
COMMENT ON TABLE diagnostico IS
    'Catálogo clínico normalizado. Sin él, «Gastritis» y «gastritis» serían dos '
    'patologías distintas y no habría reporte de morbilidad posible.';


CREATE TABLE consulta_diagnostico (
    consulta_id     INTEGER      NOT NULL,
    diagnostico_id  INTEGER      NOT NULL,
    tipo            VARCHAR(12)  NOT NULL DEFAULT 'PRESUNTIVO',
    es_principal    BOOLEAN      NOT NULL DEFAULT FALSE,
    notas           TEXT,

    CONSTRAINT pk_consulta_diagnostico PRIMARY KEY (consulta_id, diagnostico_id),
    CONSTRAINT ck_consulta_diag_tipo CHECK (tipo IN
        ('PRESUNTIVO','DEFINITIVO','DESCARTADO'))
    -- «Un solo diagnóstico principal por consulta» se implementa con un índice
    -- único PARCIAL, que no puede declararse como restricción. Ver 03_indices.
);
COMMENT ON TABLE consulta_diagnostico IS
    'ASOCIATIVA. ÚNICO lugar del modelo donde se registra un diagnóstico.';


CREATE TABLE tratamiento (
    id                  INTEGER       GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    consulta_id         INTEGER       NOT NULL,
    descripcion         VARCHAR(300)  NOT NULL,
    indicaciones        TEXT,
    fecha_inicio        DATE          NOT NULL DEFAULT CURRENT_DATE,
    fecha_fin_estimada  DATE,
    estado              VARCHAR(12)   NOT NULL DEFAULT 'activo',

    CONSTRAINT ck_tratamiento_estado CHECK (estado IN ('activo','completado','suspendido')),
    CONSTRAINT ck_tratamiento_fechas CHECK (fecha_fin_estimada IS NULL
                                         OR fecha_fin_estimada >= fecha_inicio)
);
COMMENT ON TABLE tratamiento IS
    'Plan terapéutico de UNA consulta. No es catálogo porque tiene fechas y '
    'evolución propias y no se repite entre pacientes.';


-- ============================================================================
--  BLOQUE D — PRESCRIPCIÓN Y VACUNACIÓN
-- ============================================================================

CREATE TABLE receta (
    id                      INTEGER      GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    consulta_id             INTEGER      NOT NULL,
    folio                   VARCHAR(20)  NOT NULL,
    fecha_emision           DATE         NOT NULL DEFAULT CURRENT_DATE,
    indicaciones_generales  TEXT,
    vigencia_dias           SMALLINT     NOT NULL DEFAULT 30,

    -- NOT NULL + UNIQUE: no hay receta sin consulta, y cada consulta genera a
    -- lo sumo una. Así queda la relación 1:0..1.
    CONSTRAINT uq_receta_consulta UNIQUE (consulta_id),
    CONSTRAINT uq_receta_folio    UNIQUE (folio),
    CONSTRAINT ck_receta_vigencia CHECK (vigencia_dias BETWEEN 1 AND 365)
);
COMMENT ON TABLE receta IS
    'NO guarda mascota_id ni veterinario_id: ambos se derivan por receta → '
    'consulta. Almacenarlos sería redundancia transitiva (violación de 3FN).';


CREATE TABLE medicamento (
    id                INTEGER       GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    nombre            VARCHAR(120)  NOT NULL,
    principio_activo  VARCHAR(120)  NOT NULL,
    presentacion      VARCHAR(20)   NOT NULL,
    concentracion     VARCHAR(40),
    laboratorio       VARCHAR(100),
    requiere_receta   BOOLEAN       NOT NULL DEFAULT TRUE,
    stock             INTEGER       NOT NULL DEFAULT 0,
    stock_minimo      INTEGER       NOT NULL DEFAULT 5,
    precio            dom_dinero    NOT NULL DEFAULT 0,
    activo            BOOLEAN       NOT NULL DEFAULT TRUE,

    CONSTRAINT uq_medicamento_nombre UNIQUE (nombre, concentracion),
    CONSTRAINT ck_medicamento_pres   CHECK (presentacion IN
        ('COMPRIMIDO','JARABE','INYECTABLE','CREMA','GOTAS','SPRAY','POLVO')),
    CONSTRAINT ck_medicamento_stock  CHECK (stock >= 0 AND stock_minimo >= 0)
);
COMMENT ON COLUMN medicamento.stock IS
    'Entero porque se cuentan unidades. El CHECK impide que quede negativo.';


CREATE TABLE receta_detalle (
    receta_id           INTEGER       NOT NULL,
    medicamento_id      INTEGER       NOT NULL,
    dosis               VARCHAR(60)   NOT NULL,
    frecuencia          VARCHAR(60)   NOT NULL,
    duracion_dias       SMALLINT      NOT NULL,
    via_administracion  VARCHAR(15)   NOT NULL DEFAULT 'ORAL',
    cantidad            NUMERIC(8,2)  NOT NULL DEFAULT 1,
    instrucciones       VARCHAR(300),

    -- La clave compuesta impide prescribir dos veces el mismo fármaco en la
    -- misma receta con pautas contradictorias: un riesgo real de sobredosis.
    CONSTRAINT pk_receta_detalle PRIMARY KEY (receta_id, medicamento_id),
    CONSTRAINT ck_receta_det_duracion CHECK (duracion_dias BETWEEN 1 AND 365),
    CONSTRAINT ck_receta_det_cantidad CHECK (cantidad > 0),
    CONSTRAINT ck_receta_det_via CHECK (via_administracion IN
        ('ORAL','TOPICA','INTRAMUSCULAR','SUBCUTANEA','INTRAVENOSA','OFTALMICA','OTICA')),
    CONSTRAINT ck_receta_det_texto CHECK (length(btrim(dosis)) > 0
                                       AND length(btrim(frecuencia)) > 0)
);
COMMENT ON TABLE receta_detalle IS
    'ASOCIATIVA CON ATRIBUTOS. La dosis no es propiedad del fármaco ni de la '
    'receta, sino del hecho de prescribir ESE fármaco en ESA receta.';


CREATE TABLE vacuna (
    id                        INTEGER       GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    nombre                    VARCHAR(100)  NOT NULL,
    laboratorio               VARCHAR(100),
    enfermedades_previene     VARCHAR(300),
    intervalo_refuerzo_meses  SMALLINT,
    edad_minima_semanas       SMALLINT,
    precio                    dom_dinero    NOT NULL DEFAULT 0,
    activo                    BOOLEAN       NOT NULL DEFAULT TRUE,

    CONSTRAINT uq_vacuna_nombre   UNIQUE (nombre),
    CONSTRAINT ck_vacuna_refuerzo CHECK (intervalo_refuerzo_meses IS NULL
                                      OR intervalo_refuerzo_meses > 0),
    CONSTRAINT ck_vacuna_edad     CHECK (edad_minima_semanas IS NULL
                                      OR edad_minima_semanas >= 0)
);


CREATE TABLE vacuna_especie (
    vacuna_id   INTEGER   NOT NULL,
    especie_id  SMALLINT  NOT NULL,
    CONSTRAINT pk_vacuna_especie PRIMARY KEY (vacuna_id, especie_id)
);
COMMENT ON TABLE vacuna_especie IS
    'ASOCIATIVA. Su razón de existir es funcional: impide desde el modelo '
    'ofrecer una vacuna canina para un felino.';


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
    observaciones           TEXT,

    -- Clave sustituta y no compuesta: la natural (mascota, vacuna) impediría
    -- registrar los refuerzos anuales. La UNIQUE conserva la regla.
    CONSTRAINT uq_aplicacion_vacuna UNIQUE (mascota_id, vacuna_id, fecha_aplicacion),
    CONSTRAINT ck_aplicacion_fecha    CHECK (fecha_aplicacion <= CURRENT_DATE),
    CONSTRAINT ck_aplicacion_refuerzo CHECK (fecha_proximo_refuerzo IS NULL
                                          OR fecha_proximo_refuerzo >= fecha_aplicacion),
    CONSTRAINT ck_aplicacion_dosis    CHECK (dosis_numero BETWEEN 1 AND 20),
    CONSTRAINT ck_aplicacion_lote     CHECK (length(btrim(lote)) > 0)
);
COMMENT ON COLUMN aplicacion_vacuna.lote IS
    'Obligatorio por trazabilidad sanitaria: si el laboratorio retira un lote '
    'hay que poder localizar a todos los animales que lo recibieron.';


-- ============================================================================
--  BLOQUE E — FACTURACIÓN
-- ============================================================================

CREATE TABLE servicio (
    id                     INTEGER       GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    codigo                 VARCHAR(15)   NOT NULL,
    nombre                 VARCHAR(120)  NOT NULL,
    categoria              VARCHAR(30)   NOT NULL,
    descripcion            TEXT,                    -- añadido: sitio público
    precio_base            dom_dinero    NOT NULL,
    duracion_estimada_min  SMALLINT,
    icono                  VARCHAR(16),             -- añadido: sitio público
    visible_publico        BOOLEAN       NOT NULL DEFAULT TRUE,  -- añadido
    activo                 BOOLEAN       NOT NULL DEFAULT TRUE,

    CONSTRAINT uq_servicio_codigo UNIQUE (codigo),
    CONSTRAINT uq_servicio_nombre UNIQUE (nombre),
    CONSTRAINT ck_servicio_categoria CHECK (categoria IN
        ('CONSULTA','CIRUGIA','DIAGNOSTICO','ESTETICA','VACUNACION','OTRO')),
    CONSTRAINT ck_servicio_duracion CHECK (duracion_estimada_min IS NULL
                                        OR duracion_estimada_min > 0)
);


CREATE TABLE factura (
    id             INTEGER      GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    cliente_id     INTEGER      NOT NULL,
    numero         VARCHAR(20)  NOT NULL,
    fecha_emision  DATE         NOT NULL DEFAULT CURRENT_DATE,
    subtotal       dom_dinero   NOT NULL DEFAULT 0,
    descuento      dom_dinero   NOT NULL DEFAULT 0,
    impuesto       dom_dinero   NOT NULL DEFAULT 0,
    total          dom_dinero   NOT NULL DEFAULT 0,
    estado         VARCHAR(12)  NOT NULL DEFAULT 'pendiente',
    observaciones  TEXT,
    creado_en      TIMESTAMPTZ  NOT NULL DEFAULT now(),

    CONSTRAINT uq_factura_numero UNIQUE (numero),
    CONSTRAINT ck_factura_estado CHECK (estado IN ('pendiente','parcial','pagada','anulada')),
    CONSTRAINT ck_factura_descuento CHECK (descuento <= subtotal),
    -- Coherencia aritmética verificada por el motor, no por la aplicación.
    CONSTRAINT ck_factura_total  CHECK (total = subtotal - descuento + impuesto),
    CONSTRAINT ck_factura_fecha  CHECK (fecha_emision <= CURRENT_DATE)
);
COMMENT ON TABLE factura IS
    'Documento emitido al TUTOR, no a la mascota: un mismo documento puede '
    'cubrir servicios de varias mascotas del mismo cliente. Los totales se '
    'almacenan a propósito y los mantiene un trigger.';


CREATE TABLE factura_detalle (
    id               INTEGER        GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    factura_id       INTEGER        NOT NULL,
    servicio_id      INTEGER,
    medicamento_id   INTEGER,
    mascota_id       INTEGER,
    linea_nro        SMALLINT       NOT NULL,
    descripcion      VARCHAR(200)   NOT NULL,
    cantidad         NUMERIC(8,2)   NOT NULL,
    precio_unitario  dom_dinero     NOT NULL,
    -- El motor calcula y almacena el valor: es IMPOSIBLE insertar un subtotal
    -- incoherente, aunque la inserción venga por psql y no por la aplicación.
    subtotal         NUMERIC(12,2)  GENERATED ALWAYS AS (cantidad * precio_unitario) STORED,

    CONSTRAINT uq_factura_detalle_linea UNIQUE (factura_id, linea_nro),
    CONSTRAINT ck_factura_det_linea    CHECK (linea_nro > 0),
    CONSTRAINT ck_factura_det_cantidad CHECK (cantidad > 0),
    -- Cada línea factura un servicio O un medicamento, exactamente uno.
    -- Sin esto, una línea podría tener los dos cargados —¿qué se vendió?— o
    -- ninguno de los dos.
    CONSTRAINT ck_factura_det_item CHECK (
        (servicio_id IS NOT NULL AND medicamento_id IS NULL)
     OR (servicio_id IS NULL     AND medicamento_id IS NOT NULL))
);
COMMENT ON TABLE factura_detalle IS
    'ASOCIATIVA. descripcion y precio_unitario son copia del catálogo al momento '
    'de la venta: si mañana el servicio cambia de nombre o de precio, la factura '
    'histórica conserva lo que realmente se vendió.';


CREATE TABLE metodo_pago (
    id                   SMALLINT     GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    nombre               VARCHAR(40)  NOT NULL,
    requiere_referencia  BOOLEAN      NOT NULL DEFAULT FALSE,
    activo               BOOLEAN      NOT NULL DEFAULT TRUE,
    CONSTRAINT uq_metodo_pago_nombre UNIQUE (nombre)
);


CREATE TABLE pago (
    id              INTEGER      GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    factura_id      INTEGER      NOT NULL,
    metodo_pago_id  SMALLINT     NOT NULL,
    fecha_hora      TIMESTAMPTZ  NOT NULL DEFAULT now(),
    monto           dom_dinero   NOT NULL,
    referencia      VARCHAR(60),

    CONSTRAINT ck_pago_monto CHECK (monto > 0),
    CONSTRAINT ck_pago_fecha CHECK (fecha_hora <= now())
    -- «Si el método exige referencia, el pago debe traerla» y «la suma de pagos
    -- no puede superar el total» necesitan consultar otras tablas: un CHECK no
    -- puede hacerlo, así que van como trigger en 04_reglas.sql.
);
COMMENT ON TABLE pago IS
    'Entidad propia y no un simple estado de la factura: permite pagos parciales '
    'y varios medios de pago sobre un mismo documento.';


-- ============================================================================
--  AÑADIDA — SOLICITUDES DEL SITIO PÚBLICO
-- ============================================================================

CREATE TABLE solicitud_cita (
    id                 INTEGER       GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    cita_id            INTEGER,
    especie_id         SMALLINT,
    nombre_contacto    VARCHAR(120)  NOT NULL,
    telefono_contacto  dom_telefono  NOT NULL,
    email_contacto     VARCHAR(120),
    nombre_mascota     VARCHAR(60),
    motivo             VARCHAR(300)  NOT NULL,
    fecha_preferida    DATE,
    franja_preferida   VARCHAR(12),
    estado             VARCHAR(12)   NOT NULL DEFAULT 'nueva',
    creado_en          TIMESTAMPTZ   NOT NULL DEFAULT now(),

    CONSTRAINT uq_solicitud_cita   UNIQUE (cita_id),
    CONSTRAINT ck_solicitud_estado CHECK (estado IN
        ('nueva','contactada','convertida','descartada')),
    CONSTRAINT ck_solicitud_franja CHECK (franja_preferida IS NULL
        OR franja_preferida IN ('MANANA','TARDE','INDIFERENTE')),
    -- Coherencia: solo una solicitud convertida tiene cita, y toda solicitud
    -- con cita está convertida.
    CONSTRAINT ck_solicitud_conversion CHECK (
        (estado =  'convertida' AND cita_id IS NOT NULL)
     OR (estado <> 'convertida' AND cita_id IS NULL))
);
COMMENT ON TABLE solicitud_cita IS
    'Zona de cuarentena para los pedidos del sitio público. Impide que un '
    'visitante anónimo inserte directamente en las tablas maestras y las llene '
    'de registros duplicados o falsos. nombre_mascota es texto libre SIN clave '
    'foránea: esa mascota todavía no existe en el sistema.';
