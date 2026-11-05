--
-- PostgreSQL database dump
--

\restrict 9jW0l9UVrbpawsDMpkSyrsXsLlgnTni5x0WIlaX16pEv0YTDzSvKN3vYFc0cniA

-- Dumped from database version 16.15
-- Dumped by pg_dump version 16.15

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

--
-- Name: btree_gist; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS btree_gist WITH SCHEMA public;


--
-- Name: EXTENSION btree_gist; Type: COMMENT; Schema: -; Owner: -
--

COMMENT ON EXTENSION btree_gist IS 'support for indexing common datatypes in GiST';


--
-- Name: pg_trgm; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS pg_trgm WITH SCHEMA public;


--
-- Name: EXTENSION pg_trgm; Type: COMMENT; Schema: -; Owner: -
--

COMMENT ON EXTENSION pg_trgm IS 'text similarity measurement and index searching based on trigrams';


--
-- Name: unaccent; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS unaccent WITH SCHEMA public;


--
-- Name: EXTENSION unaccent; Type: COMMENT; Schema: -; Owner: -
--

COMMENT ON EXTENSION unaccent IS 'text search dictionary that removes accents';


--
-- Name: dom_dinero; Type: DOMAIN; Schema: public; Owner: -
--

CREATE DOMAIN public.dom_dinero AS numeric(12,2)
	CONSTRAINT dom_dinero_no_negativo CHECK ((VALUE >= (0)::numeric));


--
-- Name: DOMAIN dom_dinero; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON DOMAIN public.dom_dinero IS 'Importe monetario. NUMERIC y jamás FLOAT: el binario no representa decimales exactos y 0.1+0.2 <> 0.3 descuadraría los totales de factura.';


--
-- Name: dom_email; Type: DOMAIN; Schema: public; Owner: -
--

CREATE DOMAIN public.dom_email AS character varying(120)
	CONSTRAINT dom_email_formato CHECK (((VALUE)::text ~ '^[^@[:space:]]+@[^@[:space:]]+\.[A-Za-z]{2,}$'::text));


--
-- Name: dom_telefono; Type: DOMAIN; Schema: public; Owner: -
--

CREATE DOMAIN public.dom_telefono AS character varying(25)
	CONSTRAINT dom_telefono_formato CHECK (((VALUE)::text ~ '^[0-9+()\- ]{6,25}$'::text));


--
-- Name: DOMAIN dom_telefono; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON DOMAIN public.dom_telefono IS 'VARCHAR y no numérico: admite «+», paréntesis y ceros a la izquierda, que un entero destruiría. Nunca se opera aritméticamente con él.';


--
-- Name: f_normalizar(text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.f_normalizar(txt text) RETURNS text
    LANGUAGE sql IMMUTABLE STRICT PARALLEL SAFE
    AS $$ SELECT lower(public.unaccent('public.unaccent', txt)) $$;


--
-- Name: fn_cita_fin(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.fn_cita_fin() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    NEW.fecha_hora_fin := NEW.fecha_hora_inicio
                        + make_interval(mins => NEW.duracion_minutos);
    RETURN NEW;
END $$;


--
-- Name: fn_consulta_coherente(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.fn_consulta_coherente() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE v_mascota INTEGER; v_vet INTEGER;
BEGIN
    IF NEW.cita_id IS NULL THEN RETURN NEW; END IF;

    SELECT mascota_id, veterinario_id INTO v_mascota, v_vet
      FROM cita WHERE id = NEW.cita_id;

    IF v_mascota <> NEW.mascota_id THEN
        RAISE EXCEPTION
            'La consulta es de la mascota % pero la cita corresponde a la mascota %',
            NEW.mascota_id, v_mascota USING ERRCODE = 'check_violation';
    END IF;
    IF v_vet <> NEW.veterinario_id THEN
        RAISE EXCEPTION
            'La consulta la firma el veterinario % pero la cita estaba asignada al %',
            NEW.veterinario_id, v_vet USING ERRCODE = 'check_violation';
    END IF;
    RETURN NEW;
END $$;


--
-- Name: fn_descontar_stock(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.fn_descontar_stock() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE v_stock INTEGER; v_nombre TEXT;
BEGIN
    IF NEW.medicamento_id IS NULL THEN RETURN NULL; END IF;

    SELECT stock, nombre INTO v_stock, v_nombre
      FROM medicamento WHERE id = NEW.medicamento_id FOR UPDATE;

    IF v_stock < NEW.cantidad THEN
        RAISE EXCEPTION
            'Stock insuficiente de "%": hay % y se intentan facturar %',
            v_nombre, v_stock, NEW.cantidad USING ERRCODE = 'check_violation';
    END IF;

    UPDATE medicamento SET stock = stock - NEW.cantidad::INTEGER
     WHERE id = NEW.medicamento_id;
    RETURN NULL;
END $$;


--
-- Name: fn_factura_cerrada(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.fn_factura_cerrada() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE v_estado VARCHAR(12);
BEGIN
    SELECT estado INTO v_estado FROM factura
     WHERE id = COALESCE(NEW.factura_id, OLD.factura_id);
    IF v_estado IN ('anulada','pagada') THEN
        RAISE EXCEPTION 'No se pueden modificar los detalles de una factura %', v_estado
            USING ERRCODE = 'check_violation';
    END IF;
    RETURN COALESCE(NEW, OLD);
END $$;


--
-- Name: fn_factura_numero(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.fn_factura_numero() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    IF NEW.numero IS NULL OR btrim(NEW.numero) = '' THEN
        NEW.numero := 'F-' || lpad(nextval('seq_factura_numero')::text, 6, '0');
    END IF;
    RETURN NEW;
END $$;


--
-- Name: fn_factura_recalcular(integer); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.fn_factura_recalcular(p_factura_id integer) RETURNS void
    LANGUAGE plpgsql
    AS $$
DECLARE
    v_sub NUMERIC(12,2); v_pagado NUMERIC(12,2);
    v_desc NUMERIC(12,2); v_imp NUMERIC(12,2);
    v_total NUMERIC(12,2); v_estado VARCHAR(12);
BEGIN
    SELECT descuento, impuesto, estado INTO v_desc, v_imp, v_estado
      FROM factura WHERE id = p_factura_id FOR UPDATE;

    IF NOT FOUND OR v_estado = 'anulada' THEN
        RETURN;                         -- una factura anulada queda congelada
    END IF;

    SELECT COALESCE(sum(subtotal), 0) INTO v_sub
      FROM factura_detalle WHERE factura_id = p_factura_id;
    SELECT COALESCE(sum(monto), 0) INTO v_pagado
      FROM pago WHERE factura_id = p_factura_id;

    -- Si el descuento quedó por encima del nuevo subtotal, se recorta: de otro
    -- modo el CHECK ck_factura_descuento abortaría la operación.
    v_desc  := LEAST(v_desc, v_sub);
    v_total := v_sub - v_desc + v_imp;

    v_estado := CASE
        WHEN v_total = 0            THEN 'pendiente'
        WHEN v_pagado >= v_total    THEN 'pagada'
        WHEN v_pagado > 0           THEN 'parcial'
        ELSE                             'pendiente'
    END;

    UPDATE factura
       SET subtotal = v_sub, descuento = v_desc, total = v_total, estado = v_estado
     WHERE id = p_factura_id;
END $$;


--
-- Name: FUNCTION fn_factura_recalcular(p_factura_id integer); Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON FUNCTION public.fn_factura_recalcular(p_factura_id integer) IS 'Fuente única de verdad de los totales: los recalcula desde los detalles y los pagos. La llaman los triggers de factura_detalle y de pago.';


--
-- Name: fn_receta_folio(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.fn_receta_folio() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    IF NEW.folio IS NULL OR btrim(NEW.folio) = '' THEN
        NEW.folio := 'R-' || lpad(nextval('seq_receta_folio')::text, 6, '0');
    END IF;
    RETURN NEW;
END $$;


--
-- Name: fn_refuerzo_automatico(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.fn_refuerzo_automatico() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE v_meses SMALLINT;
BEGIN
    IF NEW.fecha_proximo_refuerzo IS NULL THEN
        SELECT intervalo_refuerzo_meses INTO v_meses FROM vacuna WHERE id = NEW.vacuna_id;
        IF v_meses IS NOT NULL THEN
            NEW.fecha_proximo_refuerzo := NEW.fecha_aplicacion
                                        + make_interval(months => v_meses);
        END IF;
    END IF;
    RETURN NEW;
END $$;


--
-- Name: fn_trg_factura_detalle(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.fn_trg_factura_detalle() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    PERFORM fn_factura_recalcular(COALESCE(NEW.factura_id, OLD.factura_id));
    RETURN NULL;
END $$;


--
-- Name: fn_trg_pago(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.fn_trg_pago() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
    v_total NUMERIC(12,2); v_pagado NUMERIC(12,2); v_requiere BOOLEAN;
BEGIN
    IF TG_OP <> 'DELETE' THEN
        -- Regla que un CHECK no puede expresar: exige leer metodo_pago.
        SELECT requiere_referencia INTO v_requiere
          FROM metodo_pago WHERE id = NEW.metodo_pago_id;
        IF v_requiere AND (NEW.referencia IS NULL OR btrim(NEW.referencia) = '') THEN
            RAISE EXCEPTION 'El método de pago exige número de referencia'
                USING ERRCODE = 'check_violation';
        END IF;

        -- No se puede cobrar más que el total de la factura.
        SELECT total INTO v_total FROM factura WHERE id = NEW.factura_id;
        SELECT COALESCE(sum(monto), 0) INTO v_pagado
          FROM pago WHERE factura_id = NEW.factura_id AND id <> COALESCE(NEW.id, -1);

        IF v_pagado + NEW.monto > v_total THEN
            RAISE EXCEPTION
                'Los pagos (%) superarían el total de la factura (%)',
                v_pagado + NEW.monto, v_total
                USING ERRCODE = 'check_violation';
        END IF;
    END IF;

    PERFORM fn_factura_recalcular(COALESCE(NEW.factura_id, OLD.factura_id));
    RETURN NULL;
END $$;


--
-- Name: fn_vacuna_apta(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.fn_vacuna_apta() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE v_especie SMALLINT; v_declara BOOLEAN; v_apta BOOLEAN;
        v_vac TEXT; v_esp TEXT;
BEGIN
    SELECT m.especie_id, e.nombre INTO v_especie, v_esp
      FROM mascota m JOIN especie e ON e.id = m.especie_id WHERE m.id = NEW.mascota_id;

    -- Si la vacuna no declara especies se considera universal.
    SELECT EXISTS (SELECT 1 FROM vacuna_especie WHERE vacuna_id = NEW.vacuna_id)
      INTO v_declara;
    IF NOT v_declara THEN RETURN NEW; END IF;

    SELECT EXISTS (SELECT 1 FROM vacuna_especie
                    WHERE vacuna_id = NEW.vacuna_id AND especie_id = v_especie) INTO v_apta;

    IF NOT v_apta THEN
        SELECT nombre INTO v_vac FROM vacuna WHERE id = NEW.vacuna_id;
        RAISE EXCEPTION 'La vacuna "%" no está indicada para la especie %', v_vac, v_esp
            USING ERRCODE = 'check_violation';
    END IF;
    RETURN NEW;
END $$;


SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: aplicacion_vacuna; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.aplicacion_vacuna (
    id integer NOT NULL,
    mascota_id integer NOT NULL,
    vacuna_id integer NOT NULL,
    veterinario_id integer NOT NULL,
    consulta_id integer,
    fecha_aplicacion date DEFAULT CURRENT_DATE NOT NULL,
    fecha_proximo_refuerzo date,
    lote character varying(40) NOT NULL,
    dosis_numero smallint DEFAULT 1 NOT NULL,
    observaciones text,
    CONSTRAINT ck_aplicacion_dosis CHECK (((dosis_numero >= 1) AND (dosis_numero <= 20))),
    CONSTRAINT ck_aplicacion_fecha CHECK ((fecha_aplicacion <= CURRENT_DATE)),
    CONSTRAINT ck_aplicacion_lote CHECK ((length(btrim((lote)::text)) > 0)),
    CONSTRAINT ck_aplicacion_refuerzo CHECK (((fecha_proximo_refuerzo IS NULL) OR (fecha_proximo_refuerzo >= fecha_aplicacion)))
);


--
-- Name: COLUMN aplicacion_vacuna.lote; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.aplicacion_vacuna.lote IS 'Obligatorio por trazabilidad sanitaria: si el laboratorio retira un lote hay que poder localizar a todos los animales que lo recibieron.';


--
-- Name: aplicacion_vacuna_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

ALTER TABLE public.aplicacion_vacuna ALTER COLUMN id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME public.aplicacion_vacuna_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: cita; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.cita (
    id integer NOT NULL,
    mascota_id integer NOT NULL,
    veterinario_id integer NOT NULL,
    servicio_id integer,
    fecha_hora_inicio timestamp with time zone NOT NULL,
    duracion_minutos smallint DEFAULT 30 NOT NULL,
    fecha_hora_fin timestamp with time zone NOT NULL,
    motivo character varying(300) NOT NULL,
    estado character varying(12) DEFAULT 'programada'::character varying NOT NULL,
    motivo_cancelacion character varying(250),
    notas text,
    creado_en timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT ck_cita_cancelacion CHECK (((((estado)::text = 'cancelada'::text) AND (motivo_cancelacion IS NOT NULL)) OR (((estado)::text <> 'cancelada'::text) AND (motivo_cancelacion IS NULL)))),
    CONSTRAINT ck_cita_duracion CHECK (((duracion_minutos >= 10) AND (duracion_minutos <= 480))),
    CONSTRAINT ck_cita_estado CHECK (((estado)::text = ANY ((ARRAY['programada'::character varying, 'confirmada'::character varying, 'atendida'::character varying, 'cancelada'::character varying, 'no_asistio'::character varying])::text[]))),
    CONSTRAINT ck_cita_fin CHECK ((fecha_hora_fin > fecha_hora_inicio))
);


--
-- Name: TABLE cita; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.cita IS 'Turno agendado. El tutor NO se almacena aquí: se deriva por mascota → cliente. Guardarlo sería una dependencia transitiva.';


--
-- Name: cita_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

ALTER TABLE public.cita ALTER COLUMN id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME public.cita_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: cliente; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.cliente (
    id integer NOT NULL,
    tipo_documento character varying(10) DEFAULT 'CC'::character varying NOT NULL,
    documento character varying(20) NOT NULL,
    nombres character varying(80) NOT NULL,
    apellidos character varying(80) NOT NULL,
    telefono public.dom_telefono NOT NULL,
    email public.dom_email,
    direccion character varying(200),
    ciudad character varying(80),
    notas text,
    activo boolean DEFAULT true NOT NULL,
    creado_en timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT ck_cliente_nombres CHECK (((length(btrim((nombres)::text)) > 0) AND (length(btrim((apellidos)::text)) > 0))),
    CONSTRAINT ck_cliente_tipo_doc CHECK (((tipo_documento)::text = ANY ((ARRAY['CC'::character varying, 'CE'::character varying, 'TI'::character varying, 'PASAPORTE'::character varying, 'NIT'::character varying, 'OTRO'::character varying])::text[])))
);


--
-- Name: TABLE cliente; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.cliente IS 'Tutor o propietario responsable. El paciente es la mascota; el cliente es quien la lleva y con quien se establece la relación comercial.';


--
-- Name: cliente_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

ALTER TABLE public.cliente ALTER COLUMN id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME public.cliente_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: condicion_medica; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.condicion_medica (
    id integer NOT NULL,
    nombre character varying(100) NOT NULL,
    tipo character varying(15) NOT NULL,
    descripcion character varying(300),
    CONSTRAINT ck_condicion_tipo CHECK (((tipo)::text = ANY ((ARRAY['ALERGIA'::character varying, 'CRONICA'::character varying, 'CONGENITA'::character varying])::text[])))
);


--
-- Name: TABLE condicion_medica; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.condicion_medica IS 'Catálogo unificado de alergias y condiciones crónicas. El atributo tipo evita mantener tres catálogos con la misma estructura.';


--
-- Name: condicion_medica_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

ALTER TABLE public.condicion_medica ALTER COLUMN id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME public.condicion_medica_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: consulta; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.consulta (
    id integer NOT NULL,
    mascota_id integer NOT NULL,
    veterinario_id integer NOT NULL,
    cita_id integer,
    fecha_hora timestamp with time zone DEFAULT now() NOT NULL,
    tipo character varying(15) DEFAULT 'GENERAL'::character varying NOT NULL,
    motivo character varying(300) NOT NULL,
    anamnesis text,
    temperatura_c numeric(4,1),
    frecuencia_cardiaca smallint,
    frecuencia_respiratoria smallint,
    examen_fisico text,
    observaciones text,
    proxima_revision date,
    creado_en timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT ck_consulta_fc CHECK (((frecuencia_cardiaca IS NULL) OR ((frecuencia_cardiaca >= 20) AND (frecuencia_cardiaca <= 400)))),
    CONSTRAINT ck_consulta_fecha CHECK ((fecha_hora <= now())),
    CONSTRAINT ck_consulta_fr CHECK (((frecuencia_respiratoria IS NULL) OR ((frecuencia_respiratoria >= 5) AND (frecuencia_respiratoria <= 200)))),
    CONSTRAINT ck_consulta_revision CHECK (((proxima_revision IS NULL) OR (proxima_revision >= (fecha_hora)::date))),
    CONSTRAINT ck_consulta_temp CHECK (((temperatura_c IS NULL) OR ((temperatura_c >= 30.0) AND (temperatura_c <= 45.0)))),
    CONSTRAINT ck_consulta_tipo CHECK (((tipo)::text = ANY ((ARRAY['GENERAL'::character varying, 'CONTROL'::character varying, 'URGENCIA'::character varying, 'VACUNACION'::character varying, 'ESTETICA'::character varying])::text[])))
);


--
-- Name: TABLE consulta; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.consulta IS 'Encuentro clínico realizado. NO almacena peso (va a registro_peso) ni diagnóstico en texto libre (va a consulta_diagnostico).';


--
-- Name: consulta_diagnostico; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.consulta_diagnostico (
    consulta_id integer NOT NULL,
    diagnostico_id integer NOT NULL,
    tipo character varying(12) DEFAULT 'PRESUNTIVO'::character varying NOT NULL,
    es_principal boolean DEFAULT false NOT NULL,
    notas text,
    CONSTRAINT ck_consulta_diag_tipo CHECK (((tipo)::text = ANY ((ARRAY['PRESUNTIVO'::character varying, 'DEFINITIVO'::character varying, 'DESCARTADO'::character varying])::text[])))
);


--
-- Name: TABLE consulta_diagnostico; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.consulta_diagnostico IS 'ASOCIATIVA. ÚNICO lugar del modelo donde se registra un diagnóstico.';


--
-- Name: consulta_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

ALTER TABLE public.consulta ALTER COLUMN id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME public.consulta_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: diagnostico; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.diagnostico (
    id integer NOT NULL,
    codigo character varying(15) NOT NULL,
    nombre character varying(120) NOT NULL,
    categoria character varying(50)
);


--
-- Name: TABLE diagnostico; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.diagnostico IS 'Catálogo clínico normalizado. Sin él, «Gastritis» y «gastritis» serían dos patologías distintas y no habría reporte de morbilidad posible.';


--
-- Name: diagnostico_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

ALTER TABLE public.diagnostico ALTER COLUMN id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME public.diagnostico_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: especialidad; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.especialidad (
    id smallint NOT NULL,
    nombre character varying(80) NOT NULL,
    descripcion character varying(200)
);


--
-- Name: especialidad_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

ALTER TABLE public.especialidad ALTER COLUMN id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME public.especialidad_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: especie; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.especie (
    id smallint NOT NULL,
    nombre character varying(50) NOT NULL,
    icono character varying(16),
    esperanza_vida_anios smallint,
    CONSTRAINT ck_especie_vida CHECK (((esperanza_vida_anios IS NULL) OR (esperanza_vida_anios > 0)))
);


--
-- Name: especie_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

ALTER TABLE public.especie ALTER COLUMN id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME public.especie_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: factura; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.factura (
    id integer NOT NULL,
    cliente_id integer NOT NULL,
    numero character varying(20) NOT NULL,
    fecha_emision date DEFAULT CURRENT_DATE NOT NULL,
    subtotal public.dom_dinero DEFAULT 0 NOT NULL,
    descuento public.dom_dinero DEFAULT 0 NOT NULL,
    impuesto public.dom_dinero DEFAULT 0 NOT NULL,
    total public.dom_dinero DEFAULT 0 NOT NULL,
    estado character varying(12) DEFAULT 'pendiente'::character varying NOT NULL,
    observaciones text,
    creado_en timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT ck_factura_descuento CHECK (((descuento)::numeric <= (subtotal)::numeric)),
    CONSTRAINT ck_factura_estado CHECK (((estado)::text = ANY ((ARRAY['pendiente'::character varying, 'parcial'::character varying, 'pagada'::character varying, 'anulada'::character varying])::text[]))),
    CONSTRAINT ck_factura_fecha CHECK ((fecha_emision <= CURRENT_DATE)),
    CONSTRAINT ck_factura_total CHECK (((total)::numeric = (((subtotal)::numeric - (descuento)::numeric) + (impuesto)::numeric)))
);


--
-- Name: TABLE factura; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.factura IS 'Documento emitido al TUTOR, no a la mascota: un mismo documento puede cubrir servicios de varias mascotas del mismo cliente. Los totales se almacenan a propósito y los mantiene un trigger.';


--
-- Name: factura_detalle; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.factura_detalle (
    id integer NOT NULL,
    factura_id integer NOT NULL,
    servicio_id integer,
    medicamento_id integer,
    mascota_id integer,
    linea_nro smallint NOT NULL,
    descripcion character varying(200) NOT NULL,
    cantidad numeric(8,2) NOT NULL,
    precio_unitario public.dom_dinero NOT NULL,
    subtotal numeric(12,2) GENERATED ALWAYS AS ((cantidad * (precio_unitario)::numeric)) STORED,
    CONSTRAINT ck_factura_det_cantidad CHECK ((cantidad > (0)::numeric)),
    CONSTRAINT ck_factura_det_item CHECK ((((servicio_id IS NOT NULL) AND (medicamento_id IS NULL)) OR ((servicio_id IS NULL) AND (medicamento_id IS NOT NULL)))),
    CONSTRAINT ck_factura_det_linea CHECK ((linea_nro > 0))
);


--
-- Name: TABLE factura_detalle; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.factura_detalle IS 'ASOCIATIVA. descripcion y precio_unitario son copia del catálogo al momento de la venta: si mañana el servicio cambia de nombre o de precio, la factura histórica conserva lo que realmente se vendió.';


--
-- Name: factura_detalle_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

ALTER TABLE public.factura_detalle ALTER COLUMN id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME public.factura_detalle_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: factura_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

ALTER TABLE public.factura ALTER COLUMN id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME public.factura_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: mascota; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.mascota (
    id integer NOT NULL,
    cliente_id integer NOT NULL,
    especie_id smallint NOT NULL,
    raza_id integer,
    nombre character varying(60) NOT NULL,
    sexo character(1) NOT NULL,
    fecha_nacimiento date,
    color character varying(60),
    microchip character varying(25),
    esterilizado boolean DEFAULT false NOT NULL,
    foto_url character varying(300),
    observaciones text,
    fecha_fallecimiento date,
    activo boolean DEFAULT true NOT NULL,
    creado_en timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT ck_mascota_deceso CHECK (((fecha_fallecimiento IS NULL) OR (fecha_nacimiento IS NULL) OR (fecha_fallecimiento >= fecha_nacimiento))),
    CONSTRAINT ck_mascota_microchip CHECK (((microchip IS NULL) OR ((microchip)::text ~ '^[0-9A-Za-z]{9,25}$'::text))),
    CONSTRAINT ck_mascota_nacimiento CHECK (((fecha_nacimiento IS NULL) OR (fecha_nacimiento <= CURRENT_DATE))),
    CONSTRAINT ck_mascota_nombre CHECK ((length(btrim((nombre)::text)) > 0)),
    CONSTRAINT ck_mascota_sexo CHECK ((sexo = ANY (ARRAY['M'::bpchar, 'H'::bpchar])))
);


--
-- Name: TABLE mascota; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.mascota IS 'NÚCLEO DEL SISTEMA. La edad, el peso actual y el estado de vacunación son DERIVADOS y se calculan en vistas; no existen como columnas.';


--
-- Name: mascota_condicion; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.mascota_condicion (
    mascota_id integer NOT NULL,
    condicion_medica_id integer NOT NULL,
    severidad character varying(10) DEFAULT 'MEDIA'::character varying NOT NULL,
    fecha_deteccion date,
    notas text,
    CONSTRAINT ck_mascota_cond_fecha CHECK (((fecha_deteccion IS NULL) OR (fecha_deteccion <= CURRENT_DATE))),
    CONSTRAINT ck_mascota_cond_sev CHECK (((severidad)::text = ANY ((ARRAY['LEVE'::character varying, 'MEDIA'::character varying, 'GRAVE'::character varying])::text[])))
);


--
-- Name: TABLE mascota_condicion; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.mascota_condicion IS 'ASOCIATIVA. La severidad es propia del vínculo: la misma alergia es leve en una mascota y grave en otra.';


--
-- Name: mascota_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

ALTER TABLE public.mascota ALTER COLUMN id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME public.mascota_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: medicamento; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.medicamento (
    id integer NOT NULL,
    nombre character varying(120) NOT NULL,
    principio_activo character varying(120) NOT NULL,
    presentacion character varying(20) NOT NULL,
    concentracion character varying(40),
    laboratorio character varying(100),
    requiere_receta boolean DEFAULT true NOT NULL,
    stock integer DEFAULT 0 NOT NULL,
    stock_minimo integer DEFAULT 5 NOT NULL,
    precio public.dom_dinero DEFAULT 0 NOT NULL,
    activo boolean DEFAULT true NOT NULL,
    CONSTRAINT ck_medicamento_pres CHECK (((presentacion)::text = ANY ((ARRAY['COMPRIMIDO'::character varying, 'JARABE'::character varying, 'INYECTABLE'::character varying, 'CREMA'::character varying, 'GOTAS'::character varying, 'SPRAY'::character varying, 'POLVO'::character varying])::text[]))),
    CONSTRAINT ck_medicamento_stock CHECK (((stock >= 0) AND (stock_minimo >= 0)))
);


--
-- Name: COLUMN medicamento.stock; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.medicamento.stock IS 'Entero porque se cuentan unidades. El CHECK impide que quede negativo.';


--
-- Name: medicamento_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

ALTER TABLE public.medicamento ALTER COLUMN id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME public.medicamento_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: metodo_pago; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.metodo_pago (
    id smallint NOT NULL,
    nombre character varying(40) NOT NULL,
    requiere_referencia boolean DEFAULT false NOT NULL,
    activo boolean DEFAULT true NOT NULL
);


--
-- Name: metodo_pago_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

ALTER TABLE public.metodo_pago ALTER COLUMN id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME public.metodo_pago_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: pago; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.pago (
    id integer NOT NULL,
    factura_id integer NOT NULL,
    metodo_pago_id smallint NOT NULL,
    fecha_hora timestamp with time zone DEFAULT now() NOT NULL,
    monto public.dom_dinero NOT NULL,
    referencia character varying(60),
    CONSTRAINT ck_pago_fecha CHECK ((fecha_hora <= now())),
    CONSTRAINT ck_pago_monto CHECK (((monto)::numeric > (0)::numeric))
);


--
-- Name: TABLE pago; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.pago IS 'Entidad propia y no un simple estado de la factura: permite pagos parciales y varios medios de pago sobre un mismo documento.';


--
-- Name: pago_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

ALTER TABLE public.pago ALTER COLUMN id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME public.pago_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: raza; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.raza (
    id integer NOT NULL,
    especie_id smallint NOT NULL,
    nombre character varying(80) NOT NULL,
    tamanio character varying(15),
    CONSTRAINT ck_raza_tamanio CHECK (((tamanio IS NULL) OR ((tamanio)::text = ANY ((ARRAY['PEQUENO'::character varying, 'MEDIANO'::character varying, 'GRANDE'::character varying, 'GIGANTE'::character varying])::text[]))))
);


--
-- Name: raza_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

ALTER TABLE public.raza ALTER COLUMN id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME public.raza_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: receta; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.receta (
    id integer NOT NULL,
    consulta_id integer NOT NULL,
    folio character varying(20) NOT NULL,
    fecha_emision date DEFAULT CURRENT_DATE NOT NULL,
    indicaciones_generales text,
    vigencia_dias smallint DEFAULT 30 NOT NULL,
    CONSTRAINT ck_receta_vigencia CHECK (((vigencia_dias >= 1) AND (vigencia_dias <= 365)))
);


--
-- Name: TABLE receta; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.receta IS 'NO guarda mascota_id ni veterinario_id: ambos se derivan por receta → consulta. Almacenarlos sería redundancia transitiva (violación de 3FN).';


--
-- Name: receta_detalle; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.receta_detalle (
    receta_id integer NOT NULL,
    medicamento_id integer NOT NULL,
    dosis character varying(60) NOT NULL,
    frecuencia character varying(60) NOT NULL,
    duracion_dias smallint NOT NULL,
    via_administracion character varying(15) DEFAULT 'ORAL'::character varying NOT NULL,
    cantidad numeric(8,2) DEFAULT 1 NOT NULL,
    instrucciones character varying(300),
    CONSTRAINT ck_receta_det_cantidad CHECK ((cantidad > (0)::numeric)),
    CONSTRAINT ck_receta_det_duracion CHECK (((duracion_dias >= 1) AND (duracion_dias <= 365))),
    CONSTRAINT ck_receta_det_texto CHECK (((length(btrim((dosis)::text)) > 0) AND (length(btrim((frecuencia)::text)) > 0))),
    CONSTRAINT ck_receta_det_via CHECK (((via_administracion)::text = ANY ((ARRAY['ORAL'::character varying, 'TOPICA'::character varying, 'INTRAMUSCULAR'::character varying, 'SUBCUTANEA'::character varying, 'INTRAVENOSA'::character varying, 'OFTALMICA'::character varying, 'OTICA'::character varying])::text[])))
);


--
-- Name: TABLE receta_detalle; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.receta_detalle IS 'ASOCIATIVA CON ATRIBUTOS. La dosis no es propiedad del fármaco ni de la receta, sino del hecho de prescribir ESE fármaco en ESA receta.';


--
-- Name: receta_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

ALTER TABLE public.receta ALTER COLUMN id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME public.receta_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: registro_peso; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.registro_peso (
    id integer NOT NULL,
    mascota_id integer NOT NULL,
    consulta_id integer,
    fecha_registro date DEFAULT CURRENT_DATE NOT NULL,
    peso_kg numeric(6,2) NOT NULL,
    observacion character varying(200),
    CONSTRAINT ck_registro_fecha CHECK ((fecha_registro <= CURRENT_DATE)),
    CONSTRAINT ck_registro_peso CHECK (((peso_kg > (0)::numeric) AND (peso_kg <= (2000)::numeric)))
);


--
-- Name: TABLE registro_peso; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.registro_peso IS 'ÚNICO lugar del modelo donde se almacena un peso. El «peso actual» de la mascota es la medición más reciente, calculada por vista.';


--
-- Name: registro_peso_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

ALTER TABLE public.registro_peso ALTER COLUMN id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME public.registro_peso_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: rol; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.rol (
    id smallint NOT NULL,
    nombre character varying(50) NOT NULL,
    descripcion character varying(200)
);


--
-- Name: TABLE rol; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.rol IS 'Catálogo de perfiles de acceso al sistema.';


--
-- Name: rol_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

ALTER TABLE public.rol ALTER COLUMN id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME public.rol_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: seq_factura_numero; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.seq_factura_numero
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: seq_receta_folio; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.seq_receta_folio
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: servicio; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.servicio (
    id integer NOT NULL,
    codigo character varying(15) NOT NULL,
    nombre character varying(120) NOT NULL,
    categoria character varying(30) NOT NULL,
    descripcion text,
    precio_base public.dom_dinero NOT NULL,
    duracion_estimada_min smallint,
    icono character varying(16),
    visible_publico boolean DEFAULT true NOT NULL,
    activo boolean DEFAULT true NOT NULL,
    CONSTRAINT ck_servicio_categoria CHECK (((categoria)::text = ANY ((ARRAY['CONSULTA'::character varying, 'CIRUGIA'::character varying, 'DIAGNOSTICO'::character varying, 'ESTETICA'::character varying, 'VACUNACION'::character varying, 'OTRO'::character varying])::text[]))),
    CONSTRAINT ck_servicio_duracion CHECK (((duracion_estimada_min IS NULL) OR (duracion_estimada_min > 0)))
);


--
-- Name: servicio_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

ALTER TABLE public.servicio ALTER COLUMN id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME public.servicio_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: solicitud_cita; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.solicitud_cita (
    id integer NOT NULL,
    cita_id integer,
    especie_id smallint,
    nombre_contacto character varying(120) NOT NULL,
    telefono_contacto public.dom_telefono NOT NULL,
    email_contacto character varying(120),
    nombre_mascota character varying(60),
    motivo character varying(300) NOT NULL,
    fecha_preferida date,
    franja_preferida character varying(12),
    estado character varying(12) DEFAULT 'nueva'::character varying NOT NULL,
    creado_en timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT ck_solicitud_conversion CHECK (((((estado)::text = 'convertida'::text) AND (cita_id IS NOT NULL)) OR (((estado)::text <> 'convertida'::text) AND (cita_id IS NULL)))),
    CONSTRAINT ck_solicitud_estado CHECK (((estado)::text = ANY ((ARRAY['nueva'::character varying, 'contactada'::character varying, 'convertida'::character varying, 'descartada'::character varying])::text[]))),
    CONSTRAINT ck_solicitud_franja CHECK (((franja_preferida IS NULL) OR ((franja_preferida)::text = ANY ((ARRAY['MANANA'::character varying, 'TARDE'::character varying, 'INDIFERENTE'::character varying])::text[]))))
);


--
-- Name: TABLE solicitud_cita; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.solicitud_cita IS 'Zona de cuarentena para los pedidos del sitio público. Impide que un visitante anónimo inserte directamente en las tablas maestras y las llene de registros duplicados o falsos. nombre_mascota es texto libre SIN clave foránea: esa mascota todavía no existe en el sistema.';


--
-- Name: solicitud_cita_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

ALTER TABLE public.solicitud_cita ALTER COLUMN id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME public.solicitud_cita_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: tratamiento; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.tratamiento (
    id integer NOT NULL,
    consulta_id integer NOT NULL,
    descripcion character varying(300) NOT NULL,
    indicaciones text,
    fecha_inicio date DEFAULT CURRENT_DATE NOT NULL,
    fecha_fin_estimada date,
    estado character varying(12) DEFAULT 'activo'::character varying NOT NULL,
    CONSTRAINT ck_tratamiento_estado CHECK (((estado)::text = ANY ((ARRAY['activo'::character varying, 'completado'::character varying, 'suspendido'::character varying])::text[]))),
    CONSTRAINT ck_tratamiento_fechas CHECK (((fecha_fin_estimada IS NULL) OR (fecha_fin_estimada >= fecha_inicio)))
);


--
-- Name: TABLE tratamiento; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.tratamiento IS 'Plan terapéutico de UNA consulta. No es catálogo porque tiene fechas y evolución propias y no se repite entre pacientes.';


--
-- Name: tratamiento_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

ALTER TABLE public.tratamiento ALTER COLUMN id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME public.tratamiento_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: usuario; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.usuario (
    id integer NOT NULL,
    rol_id smallint NOT NULL,
    nombre_usuario character varying(50) NOT NULL,
    email public.dom_email NOT NULL,
    password_hash character varying(255) NOT NULL,
    activo boolean DEFAULT true NOT NULL,
    ultimo_acceso timestamp with time zone,
    creado_en timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT ck_usuario_hash CHECK ((length((password_hash)::text) >= 20))
);


--
-- Name: TABLE usuario; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.usuario IS 'Credencial de acceso. No representa a una persona del negocio.';


--
-- Name: COLUMN usuario.password_hash; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.usuario.password_hash IS 'Hash bcrypt o argon2. NUNCA la clave en texto plano.';


--
-- Name: usuario_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

ALTER TABLE public.usuario ALTER COLUMN id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME public.usuario_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: veterinario; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.veterinario (
    id integer NOT NULL,
    usuario_id integer,
    documento character varying(20) NOT NULL,
    matricula character varying(30) NOT NULL,
    nombres character varying(80) NOT NULL,
    apellidos character varying(80) NOT NULL,
    telefono public.dom_telefono,
    email public.dom_email,
    foto_url character varying(300),
    biografia text,
    activo boolean DEFAULT true NOT NULL,
    CONSTRAINT ck_veterinario_nombres CHECK (((length(btrim((nombres)::text)) > 0) AND (length(btrim((apellidos)::text)) > 0)))
);


--
-- Name: TABLE veterinario; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.veterinario IS 'Profesional que presta la atención clínica.';


--
-- Name: v_agenda; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.v_agenda AS
 SELECT ci.id AS cita_id,
    ci.fecha_hora_inicio,
    ci.fecha_hora_fin,
    ci.duracion_minutos,
    ci.estado,
    ci.motivo,
    ci.notas,
    m.id AS mascota_id,
    m.nombre AS mascota,
    m.foto_url AS mascota_foto,
    e.nombre AS especie,
    e.icono AS especie_icono,
    cl.id AS cliente_id,
    (((cl.nombres)::text || ' '::text) || (cl.apellidos)::text) AS tutor,
    cl.telefono AS tutor_telefono,
    v.id AS veterinario_id,
    (((v.nombres)::text || ' '::text) || (v.apellidos)::text) AS veterinario,
    s.id AS servicio_id,
    s.nombre AS servicio,
    co.id AS consulta_id
   FROM ((((((public.cita ci
     JOIN public.mascota m ON ((m.id = ci.mascota_id)))
     JOIN public.especie e ON ((e.id = m.especie_id)))
     JOIN public.cliente cl ON ((cl.id = m.cliente_id)))
     JOIN public.veterinario v ON ((v.id = ci.veterinario_id)))
     LEFT JOIN public.servicio s ON ((s.id = ci.servicio_id)))
     LEFT JOIN public.consulta co ON ((co.cita_id = ci.id)));


--
-- Name: VIEW v_agenda; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON VIEW public.v_agenda IS 'El tutor se resuelve por JOIN: la cita no almacena cliente_id porque sería una dependencia transitiva vía mascota.';


--
-- Name: v_consulta_diagnosticos; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.v_consulta_diagnosticos AS
 SELECT cd.consulta_id,
    d.id AS diagnostico_id,
    d.codigo,
    d.nombre,
    d.categoria,
    cd.tipo,
    cd.es_principal,
    cd.notas
   FROM (public.consulta_diagnostico cd
     JOIN public.diagnostico d ON ((d.id = cd.diagnostico_id)));


--
-- Name: v_factura_resumen; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.v_factura_resumen AS
 SELECT f.id,
    f.numero,
    f.fecha_emision,
    f.subtotal,
    f.descuento,
    f.impuesto,
    f.total,
    f.estado,
    f.observaciones,
    c.id AS cliente_id,
    (((c.nombres)::text || ' '::text) || (c.apellidos)::text) AS cliente,
    c.documento AS cliente_documento,
    c.telefono AS cliente_telefono,
    COALESCE(p.pagado, (0)::numeric) AS pagado,
    ((f.total)::numeric - COALESCE(p.pagado, (0)::numeric)) AS saldo,
    ( SELECT count(*) AS count
           FROM public.factura_detalle d
          WHERE (d.factura_id = f.id)) AS lineas
   FROM ((public.factura f
     JOIN public.cliente c ON ((c.id = f.cliente_id)))
     LEFT JOIN LATERAL ( SELECT sum((pago.monto)::numeric) AS pagado
           FROM public.pago
          WHERE (pago.factura_id = f.id)) p ON (true));


--
-- Name: VIEW v_factura_resumen; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON VIEW public.v_factura_resumen IS 'El saldo es DERIVADO: total menos la suma de pagos. No se almacena para que no pueda contradecir a los pagos reales.';


--
-- Name: vacuna; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.vacuna (
    id integer NOT NULL,
    nombre character varying(100) NOT NULL,
    laboratorio character varying(100),
    enfermedades_previene character varying(300),
    intervalo_refuerzo_meses smallint,
    edad_minima_semanas smallint,
    precio public.dom_dinero DEFAULT 0 NOT NULL,
    activo boolean DEFAULT true NOT NULL,
    CONSTRAINT ck_vacuna_edad CHECK (((edad_minima_semanas IS NULL) OR (edad_minima_semanas >= 0))),
    CONSTRAINT ck_vacuna_refuerzo CHECK (((intervalo_refuerzo_meses IS NULL) OR (intervalo_refuerzo_meses > 0)))
);


--
-- Name: v_historial_clinico; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.v_historial_clinico AS
 SELECT c.mascota_id,
    (c.fecha_hora)::date AS fecha,
    c.fecha_hora AS momento,
    'CONSULTA'::text AS tipo,
    initcap(lower((c.tipo)::text)) AS titulo,
    c.motivo AS detalle,
    (((v.nombres)::text || ' '::text) || (v.apellidos)::text) AS veterinario,
    c.id AS referencia_id
   FROM (public.consulta c
     JOIN public.veterinario v ON ((v.id = c.veterinario_id)))
UNION ALL
 SELECT av.mascota_id,
    av.fecha_aplicacion AS fecha,
    (av.fecha_aplicacion)::timestamp with time zone AS momento,
    'VACUNA'::text AS tipo,
    vac.nombre AS titulo,
    (('Lote '::text || (av.lote)::text) || COALESCE((' · refuerzo '::text || to_char((av.fecha_proximo_refuerzo)::timestamp with time zone, 'DD/MM/YYYY'::text)), ''::text)) AS detalle,
    (((v.nombres)::text || ' '::text) || (v.apellidos)::text) AS veterinario,
    av.id AS referencia_id
   FROM ((public.aplicacion_vacuna av
     JOIN public.vacuna vac ON ((vac.id = av.vacuna_id)))
     JOIN public.veterinario v ON ((v.id = av.veterinario_id)))
UNION ALL
 SELECT rp.mascota_id,
    rp.fecha_registro AS fecha,
    (rp.fecha_registro)::timestamp with time zone AS momento,
    'PESO'::text AS tipo,
    (rp.peso_kg || ' kg'::text) AS titulo,
    rp.observacion AS detalle,
    NULL::text AS veterinario,
    rp.id AS referencia_id
   FROM public.registro_peso rp
UNION ALL
 SELECT ci.mascota_id,
    (ci.fecha_hora_inicio)::date AS fecha,
    ci.fecha_hora_inicio AS momento,
    'CITA'::text AS tipo,
    initcap((ci.estado)::text) AS titulo,
    ci.motivo AS detalle,
    (((v.nombres)::text || ' '::text) || (v.apellidos)::text) AS veterinario,
    ci.id AS referencia_id
   FROM (public.cita ci
     JOIN public.veterinario v ON ((v.id = ci.veterinario_id)));


--
-- Name: v_ingresos_mensuales; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.v_ingresos_mensuales AS
 SELECT (date_trunc('month'::text, (f.fecha_emision)::timestamp with time zone))::date AS mes,
    count(*) AS facturas,
    sum((f.subtotal)::numeric) AS subtotal,
    sum((f.descuento)::numeric) AS descuentos,
    sum((f.total)::numeric) AS facturado,
    COALESCE(sum(pg.pagado), (0)::numeric) AS cobrado,
    (sum((f.total)::numeric) - COALESCE(sum(pg.pagado), (0)::numeric)) AS por_cobrar
   FROM (public.factura f
     LEFT JOIN LATERAL ( SELECT sum((pago.monto)::numeric) AS pagado
           FROM public.pago
          WHERE (pago.factura_id = f.id)) pg ON (true))
  WHERE ((f.estado)::text <> 'anulada'::text)
  GROUP BY ((date_trunc('month'::text, (f.fecha_emision)::timestamp with time zone))::date);


--
-- Name: v_mascota_perfil; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.v_mascota_perfil AS
 SELECT m.id,
    m.nombre,
    m.sexo,
        CASE m.sexo
            WHEN 'M'::bpchar THEN 'Macho'::text
            ELSE 'Hembra'::text
        END AS sexo_texto,
    e.id AS especie_id,
    e.nombre AS especie,
    e.icono AS especie_icono,
    r.id AS raza_id,
    r.nombre AS raza,
    m.color,
    m.microchip,
    m.esterilizado,
    m.foto_url,
    m.observaciones,
    m.activo,
    m.fecha_nacimiento,
    m.fecha_fallecimiento,
    m.creado_en,
        CASE
            WHEN (m.fecha_nacimiento IS NOT NULL) THEN (date_part('year'::text, age((COALESCE(m.fecha_fallecimiento, CURRENT_DATE))::timestamp with time zone, (m.fecha_nacimiento)::timestamp with time zone)))::integer
            ELSE NULL::integer
        END AS edad_anios,
        CASE
            WHEN (m.fecha_nacimiento IS NOT NULL) THEN (((date_part('year'::text, age((COALESCE(m.fecha_fallecimiento, CURRENT_DATE))::timestamp with time zone, (m.fecha_nacimiento)::timestamp with time zone)) * (12)::double precision) + date_part('month'::text, age((COALESCE(m.fecha_fallecimiento, CURRENT_DATE))::timestamp with time zone, (m.fecha_nacimiento)::timestamp with time zone))))::integer
            ELSE NULL::integer
        END AS edad_meses,
    p.peso_kg AS peso_actual_kg,
    p.fecha_registro AS peso_fecha,
    v.proximo_refuerzo,
        CASE
            WHEN (v.proximo_refuerzo IS NULL) THEN 'SIN_DATOS'::text
            WHEN (v.proximo_refuerzo < CURRENT_DATE) THEN 'VENCIDA'::text
            WHEN (v.proximo_refuerzo <= (CURRENT_DATE + '30 days'::interval)) THEN 'PROXIMA'::text
            ELSE 'VIGENTE'::text
        END AS estado_vacunacion,
    c.id AS cliente_id,
    (((c.nombres)::text || ' '::text) || (c.apellidos)::text) AS tutor,
    c.telefono AS tutor_telefono,
    c.email AS tutor_email
   FROM (((((public.mascota m
     JOIN public.especie e ON ((e.id = m.especie_id)))
     JOIN public.cliente c ON ((c.id = m.cliente_id)))
     LEFT JOIN public.raza r ON ((r.id = m.raza_id)))
     LEFT JOIN LATERAL ( SELECT rp.peso_kg,
            rp.fecha_registro
           FROM public.registro_peso rp
          WHERE (rp.mascota_id = m.id)
          ORDER BY rp.fecha_registro DESC
         LIMIT 1) p ON (true))
     LEFT JOIN LATERAL ( SELECT min(av.fecha_proximo_refuerzo) AS proximo_refuerzo
           FROM public.aplicacion_vacuna av
          WHERE ((av.mascota_id = m.id) AND (av.fecha_proximo_refuerzo IS NOT NULL))) v ON (true));


--
-- Name: v_morbilidad; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.v_morbilidad AS
 SELECT d.id,
    d.codigo,
    d.nombre,
    d.categoria,
    count(*) FILTER (WHERE ((cd.tipo)::text = 'DEFINITIVO'::text)) AS confirmados,
    count(*) AS casos,
    count(DISTINCT c.mascota_id) AS pacientes
   FROM ((public.consulta_diagnostico cd
     JOIN public.diagnostico d ON ((d.id = cd.diagnostico_id)))
     JOIN public.consulta c ON ((c.id = cd.consulta_id)))
  WHERE ((cd.tipo)::text <> 'DESCARTADO'::text)
  GROUP BY d.id, d.codigo, d.nombre, d.categoria;


--
-- Name: VIEW v_morbilidad; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON VIEW public.v_morbilidad IS 'Este reporte es IMPOSIBLE si el diagnóstico se guarda como texto libre: «Gastritis» y «gastritis» serían dos patologías distintas.';


--
-- Name: v_servicios_mas_usados; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.v_servicios_mas_usados AS
 SELECT s.id,
    s.codigo,
    s.nombre,
    s.categoria,
    count(*) AS veces,
    sum(fd.cantidad) AS unidades,
    sum(fd.subtotal) AS ingresos
   FROM ((public.factura_detalle fd
     JOIN public.servicio s ON ((s.id = fd.servicio_id)))
     JOIN public.factura f ON ((f.id = fd.factura_id)))
  WHERE ((f.estado)::text <> 'anulada'::text)
  GROUP BY s.id, s.codigo, s.nombre, s.categoria;


--
-- Name: v_stock_alerta; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.v_stock_alerta AS
 SELECT id,
    nombre,
    principio_activo,
    presentacion,
    concentracion,
    stock,
    stock_minimo,
    precio,
        CASE
            WHEN (stock = 0) THEN 'SIN_STOCK'::text
            ELSE 'BAJO'::text
        END AS estado
   FROM public.medicamento
  WHERE (activo AND (stock <= stock_minimo));


--
-- Name: v_vacunas_pendientes; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.v_vacunas_pendientes AS
 SELECT av.id AS aplicacion_id,
    av.mascota_id,
    m.nombre AS mascota,
    m.foto_url,
    e.nombre AS especie,
    cl.id AS cliente_id,
    (((cl.nombres)::text || ' '::text) || (cl.apellidos)::text) AS tutor,
    cl.telefono,
    cl.email,
    vac.id AS vacuna_id,
    vac.nombre AS vacuna,
    av.fecha_aplicacion AS ultima_aplicacion,
    av.fecha_proximo_refuerzo AS vence,
    (av.fecha_proximo_refuerzo - CURRENT_DATE) AS dias_restantes,
        CASE
            WHEN (av.fecha_proximo_refuerzo < CURRENT_DATE) THEN 'VENCIDA'::text
            WHEN (av.fecha_proximo_refuerzo <= (CURRENT_DATE + '30 days'::interval)) THEN 'PROXIMA'::text
            ELSE 'VIGENTE'::text
        END AS estado
   FROM ((((public.aplicacion_vacuna av
     JOIN public.mascota m ON ((m.id = av.mascota_id)))
     JOIN public.especie e ON ((e.id = m.especie_id)))
     JOIN public.cliente cl ON ((cl.id = m.cliente_id)))
     JOIN public.vacuna vac ON ((vac.id = av.vacuna_id)))
  WHERE ((av.fecha_proximo_refuerzo IS NOT NULL) AND m.activo AND (m.fecha_fallecimiento IS NULL) AND (av.fecha_aplicacion = ( SELECT max(a2.fecha_aplicacion) AS max
           FROM public.aplicacion_vacuna a2
          WHERE ((a2.mascota_id = av.mascota_id) AND (a2.vacuna_id = av.vacuna_id)))));


--
-- Name: vacuna_especie; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.vacuna_especie (
    vacuna_id integer NOT NULL,
    especie_id smallint NOT NULL
);


--
-- Name: TABLE vacuna_especie; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.vacuna_especie IS 'ASOCIATIVA. Su razón de existir es funcional: impide desde el modelo ofrecer una vacuna canina para un felino.';


--
-- Name: vacuna_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

ALTER TABLE public.vacuna ALTER COLUMN id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME public.vacuna_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: veterinario_especialidad; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.veterinario_especialidad (
    veterinario_id integer NOT NULL,
    especialidad_id smallint NOT NULL,
    es_principal boolean DEFAULT false NOT NULL
);


--
-- Name: TABLE veterinario_especialidad; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.veterinario_especialidad IS 'ASOCIATIVA. Resuelve la N:M entre veterinario y especialidad. La clave compuesta impide asignar dos veces la misma especialidad al mismo profesional.';


--
-- Name: veterinario_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

ALTER TABLE public.veterinario ALTER COLUMN id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME public.veterinario_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: aplicacion_vacuna aplicacion_vacuna_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.aplicacion_vacuna
    ADD CONSTRAINT aplicacion_vacuna_pkey PRIMARY KEY (id);


--
-- Name: cita cita_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.cita
    ADD CONSTRAINT cita_pkey PRIMARY KEY (id);


--
-- Name: cliente cliente_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.cliente
    ADD CONSTRAINT cliente_pkey PRIMARY KEY (id);


--
-- Name: condicion_medica condicion_medica_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.condicion_medica
    ADD CONSTRAINT condicion_medica_pkey PRIMARY KEY (id);


--
-- Name: consulta consulta_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.consulta
    ADD CONSTRAINT consulta_pkey PRIMARY KEY (id);


--
-- Name: diagnostico diagnostico_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.diagnostico
    ADD CONSTRAINT diagnostico_pkey PRIMARY KEY (id);


--
-- Name: especialidad especialidad_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.especialidad
    ADD CONSTRAINT especialidad_pkey PRIMARY KEY (id);


--
-- Name: especie especie_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.especie
    ADD CONSTRAINT especie_pkey PRIMARY KEY (id);


--
-- Name: cita ex_cita_sin_solapamiento; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.cita
    ADD CONSTRAINT ex_cita_sin_solapamiento EXCLUDE USING gist (veterinario_id WITH =, tstzrange(fecha_hora_inicio, fecha_hora_fin) WITH &&) WHERE (((estado)::text = ANY ((ARRAY['programada'::character varying, 'confirmada'::character varying, 'atendida'::character varying])::text[])));


--
-- Name: factura_detalle factura_detalle_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.factura_detalle
    ADD CONSTRAINT factura_detalle_pkey PRIMARY KEY (id);


--
-- Name: factura factura_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.factura
    ADD CONSTRAINT factura_pkey PRIMARY KEY (id);


--
-- Name: mascota mascota_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.mascota
    ADD CONSTRAINT mascota_pkey PRIMARY KEY (id);


--
-- Name: medicamento medicamento_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.medicamento
    ADD CONSTRAINT medicamento_pkey PRIMARY KEY (id);


--
-- Name: metodo_pago metodo_pago_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.metodo_pago
    ADD CONSTRAINT metodo_pago_pkey PRIMARY KEY (id);


--
-- Name: pago pago_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.pago
    ADD CONSTRAINT pago_pkey PRIMARY KEY (id);


--
-- Name: consulta_diagnostico pk_consulta_diagnostico; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.consulta_diagnostico
    ADD CONSTRAINT pk_consulta_diagnostico PRIMARY KEY (consulta_id, diagnostico_id);


--
-- Name: mascota_condicion pk_mascota_condicion; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.mascota_condicion
    ADD CONSTRAINT pk_mascota_condicion PRIMARY KEY (mascota_id, condicion_medica_id);


--
-- Name: receta_detalle pk_receta_detalle; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.receta_detalle
    ADD CONSTRAINT pk_receta_detalle PRIMARY KEY (receta_id, medicamento_id);


--
-- Name: vacuna_especie pk_vacuna_especie; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.vacuna_especie
    ADD CONSTRAINT pk_vacuna_especie PRIMARY KEY (vacuna_id, especie_id);


--
-- Name: veterinario_especialidad pk_veterinario_especialidad; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.veterinario_especialidad
    ADD CONSTRAINT pk_veterinario_especialidad PRIMARY KEY (veterinario_id, especialidad_id);


--
-- Name: raza raza_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.raza
    ADD CONSTRAINT raza_pkey PRIMARY KEY (id);


--
-- Name: receta receta_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.receta
    ADD CONSTRAINT receta_pkey PRIMARY KEY (id);


--
-- Name: registro_peso registro_peso_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.registro_peso
    ADD CONSTRAINT registro_peso_pkey PRIMARY KEY (id);


--
-- Name: rol rol_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.rol
    ADD CONSTRAINT rol_pkey PRIMARY KEY (id);


--
-- Name: servicio servicio_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.servicio
    ADD CONSTRAINT servicio_pkey PRIMARY KEY (id);


--
-- Name: solicitud_cita solicitud_cita_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.solicitud_cita
    ADD CONSTRAINT solicitud_cita_pkey PRIMARY KEY (id);


--
-- Name: tratamiento tratamiento_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tratamiento
    ADD CONSTRAINT tratamiento_pkey PRIMARY KEY (id);


--
-- Name: aplicacion_vacuna uq_aplicacion_vacuna; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.aplicacion_vacuna
    ADD CONSTRAINT uq_aplicacion_vacuna UNIQUE (mascota_id, vacuna_id, fecha_aplicacion);


--
-- Name: cliente uq_cliente_documento; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.cliente
    ADD CONSTRAINT uq_cliente_documento UNIQUE (tipo_documento, documento);


--
-- Name: condicion_medica uq_condicion_nombre; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.condicion_medica
    ADD CONSTRAINT uq_condicion_nombre UNIQUE (nombre);


--
-- Name: consulta uq_consulta_cita; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.consulta
    ADD CONSTRAINT uq_consulta_cita UNIQUE (cita_id);


--
-- Name: diagnostico uq_diagnostico_codigo; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.diagnostico
    ADD CONSTRAINT uq_diagnostico_codigo UNIQUE (codigo);


--
-- Name: diagnostico uq_diagnostico_nombre; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.diagnostico
    ADD CONSTRAINT uq_diagnostico_nombre UNIQUE (nombre);


--
-- Name: especialidad uq_especialidad_nombre; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.especialidad
    ADD CONSTRAINT uq_especialidad_nombre UNIQUE (nombre);


--
-- Name: especie uq_especie_nombre; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.especie
    ADD CONSTRAINT uq_especie_nombre UNIQUE (nombre);


--
-- Name: factura_detalle uq_factura_detalle_linea; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.factura_detalle
    ADD CONSTRAINT uq_factura_detalle_linea UNIQUE (factura_id, linea_nro);


--
-- Name: factura uq_factura_numero; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.factura
    ADD CONSTRAINT uq_factura_numero UNIQUE (numero);


--
-- Name: medicamento uq_medicamento_nombre; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.medicamento
    ADD CONSTRAINT uq_medicamento_nombre UNIQUE (nombre, concentracion);


--
-- Name: metodo_pago uq_metodo_pago_nombre; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.metodo_pago
    ADD CONSTRAINT uq_metodo_pago_nombre UNIQUE (nombre);


--
-- Name: raza uq_raza_especie_nombre; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.raza
    ADD CONSTRAINT uq_raza_especie_nombre UNIQUE (especie_id, nombre);


--
-- Name: raza uq_raza_id_especie; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.raza
    ADD CONSTRAINT uq_raza_id_especie UNIQUE (id, especie_id);


--
-- Name: receta uq_receta_consulta; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.receta
    ADD CONSTRAINT uq_receta_consulta UNIQUE (consulta_id);


--
-- Name: receta uq_receta_folio; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.receta
    ADD CONSTRAINT uq_receta_folio UNIQUE (folio);


--
-- Name: registro_peso uq_registro_peso_dia; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.registro_peso
    ADD CONSTRAINT uq_registro_peso_dia UNIQUE (mascota_id, fecha_registro);


--
-- Name: rol uq_rol_nombre; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.rol
    ADD CONSTRAINT uq_rol_nombre UNIQUE (nombre);


--
-- Name: servicio uq_servicio_codigo; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.servicio
    ADD CONSTRAINT uq_servicio_codigo UNIQUE (codigo);


--
-- Name: servicio uq_servicio_nombre; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.servicio
    ADD CONSTRAINT uq_servicio_nombre UNIQUE (nombre);


--
-- Name: solicitud_cita uq_solicitud_cita; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.solicitud_cita
    ADD CONSTRAINT uq_solicitud_cita UNIQUE (cita_id);


--
-- Name: usuario uq_usuario_email; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.usuario
    ADD CONSTRAINT uq_usuario_email UNIQUE (email);


--
-- Name: usuario uq_usuario_nombre; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.usuario
    ADD CONSTRAINT uq_usuario_nombre UNIQUE (nombre_usuario);


--
-- Name: vacuna uq_vacuna_nombre; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.vacuna
    ADD CONSTRAINT uq_vacuna_nombre UNIQUE (nombre);


--
-- Name: veterinario uq_veterinario_documento; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.veterinario
    ADD CONSTRAINT uq_veterinario_documento UNIQUE (documento);


--
-- Name: veterinario uq_veterinario_matricula; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.veterinario
    ADD CONSTRAINT uq_veterinario_matricula UNIQUE (matricula);


--
-- Name: veterinario uq_veterinario_usuario; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.veterinario
    ADD CONSTRAINT uq_veterinario_usuario UNIQUE (usuario_id);


--
-- Name: CONSTRAINT uq_veterinario_usuario ON veterinario; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON CONSTRAINT uq_veterinario_usuario ON public.veterinario IS 'UNIQUE sobre columna que admite nulo: así se implementa la relación 1:0..1 con usuario. Hay profesionales sin acceso al sistema.';


--
-- Name: usuario usuario_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.usuario
    ADD CONSTRAINT usuario_pkey PRIMARY KEY (id);


--
-- Name: vacuna vacuna_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.vacuna
    ADD CONSTRAINT vacuna_pkey PRIMARY KEY (id);


--
-- Name: veterinario veterinario_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.veterinario
    ADD CONSTRAINT veterinario_pkey PRIMARY KEY (id);


--
-- Name: ix_aplicacion_consulta; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_aplicacion_consulta ON public.aplicacion_vacuna USING btree (consulta_id) WHERE (consulta_id IS NOT NULL);


--
-- Name: ix_aplicacion_mascota; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_aplicacion_mascota ON public.aplicacion_vacuna USING btree (mascota_id);


--
-- Name: ix_aplicacion_refuerzo; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_aplicacion_refuerzo ON public.aplicacion_vacuna USING btree (fecha_proximo_refuerzo) WHERE (fecha_proximo_refuerzo IS NOT NULL);


--
-- Name: ix_aplicacion_vacuna; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_aplicacion_vacuna ON public.aplicacion_vacuna USING btree (vacuna_id);


--
-- Name: ix_aplicacion_veterinario; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_aplicacion_veterinario ON public.aplicacion_vacuna USING btree (veterinario_id);


--
-- Name: ix_cita_agenda; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_cita_agenda ON public.cita USING btree (veterinario_id, fecha_hora_inicio) WHERE ((estado)::text = ANY ((ARRAY['programada'::character varying, 'confirmada'::character varying])::text[]));


--
-- Name: ix_cita_fecha; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_cita_fecha ON public.cita USING btree (fecha_hora_inicio);


--
-- Name: ix_cita_mascota; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_cita_mascota ON public.cita USING btree (mascota_id);


--
-- Name: ix_cita_servicio; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_cita_servicio ON public.cita USING btree (servicio_id) WHERE (servicio_id IS NOT NULL);


--
-- Name: ix_cita_veterinario; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_cita_veterinario ON public.cita USING btree (veterinario_id);


--
-- Name: ix_cliente_busqueda; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_cliente_busqueda ON public.cliente USING gin (public.f_normalizar((((nombres)::text || ' '::text) || (apellidos)::text)) public.gin_trgm_ops);


--
-- Name: ix_consulta_diag_catalogo; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_consulta_diag_catalogo ON public.consulta_diagnostico USING btree (diagnostico_id);


--
-- Name: ix_consulta_historial; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_consulta_historial ON public.consulta USING btree (mascota_id, fecha_hora DESC);


--
-- Name: ix_consulta_mascota; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_consulta_mascota ON public.consulta USING btree (mascota_id);


--
-- Name: ix_consulta_veterinario; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_consulta_veterinario ON public.consulta USING btree (veterinario_id);


--
-- Name: ix_diagnostico_busqueda; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_diagnostico_busqueda ON public.diagnostico USING gin (public.f_normalizar((nombre)::text) public.gin_trgm_ops);


--
-- Name: ix_factura_cliente; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_factura_cliente ON public.factura USING btree (cliente_id);


--
-- Name: ix_factura_detalle_factura; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_factura_detalle_factura ON public.factura_detalle USING btree (factura_id);


--
-- Name: ix_factura_detalle_mascota; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_factura_detalle_mascota ON public.factura_detalle USING btree (mascota_id) WHERE (mascota_id IS NOT NULL);


--
-- Name: ix_factura_detalle_med; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_factura_detalle_med ON public.factura_detalle USING btree (medicamento_id) WHERE (medicamento_id IS NOT NULL);


--
-- Name: ix_factura_detalle_servicio; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_factura_detalle_servicio ON public.factura_detalle USING btree (servicio_id) WHERE (servicio_id IS NOT NULL);


--
-- Name: ix_factura_fecha; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_factura_fecha ON public.factura USING btree (fecha_emision) WHERE ((estado)::text <> 'anulada'::text);


--
-- Name: ix_factura_pendientes; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_factura_pendientes ON public.factura USING btree (cliente_id, fecha_emision) WHERE ((estado)::text = ANY ((ARRAY['pendiente'::character varying, 'parcial'::character varying])::text[]));


--
-- Name: ix_mascota_busqueda; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_mascota_busqueda ON public.mascota USING gin (public.f_normalizar((nombre)::text) public.gin_trgm_ops);


--
-- Name: ix_mascota_cliente; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_mascota_cliente ON public.mascota USING btree (cliente_id);


--
-- Name: ix_mascota_cond_catalogo; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_mascota_cond_catalogo ON public.mascota_condicion USING btree (condicion_medica_id);


--
-- Name: ix_mascota_especie; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_mascota_especie ON public.mascota USING btree (especie_id);


--
-- Name: ix_mascota_raza; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_mascota_raza ON public.mascota USING btree (raza_id, especie_id) WHERE (raza_id IS NOT NULL);


--
-- Name: ix_medicamento_busqueda; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_medicamento_busqueda ON public.medicamento USING gin (public.f_normalizar((nombre)::text) public.gin_trgm_ops);


--
-- Name: ix_medicamento_stock; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_medicamento_stock ON public.medicamento USING btree (stock) WHERE activo;


--
-- Name: ix_pago_factura; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_pago_factura ON public.pago USING btree (factura_id);


--
-- Name: ix_pago_metodo; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_pago_metodo ON public.pago USING btree (metodo_pago_id);


--
-- Name: ix_raza_especie; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_raza_especie ON public.raza USING btree (especie_id);


--
-- Name: ix_receta_detalle_med; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_receta_detalle_med ON public.receta_detalle USING btree (medicamento_id);


--
-- Name: ix_registro_peso_consulta; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_registro_peso_consulta ON public.registro_peso USING btree (consulta_id) WHERE (consulta_id IS NOT NULL);


--
-- Name: ix_registro_peso_ultimo; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_registro_peso_ultimo ON public.registro_peso USING btree (mascota_id, fecha_registro DESC);


--
-- Name: ix_solicitud_especie; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_solicitud_especie ON public.solicitud_cita USING btree (especie_id) WHERE (especie_id IS NOT NULL);


--
-- Name: ix_solicitud_pendientes; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_solicitud_pendientes ON public.solicitud_cita USING btree (creado_en) WHERE ((estado)::text = ANY ((ARRAY['nueva'::character varying, 'contactada'::character varying])::text[]));


--
-- Name: ix_tratamiento_consulta; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_tratamiento_consulta ON public.tratamiento USING btree (consulta_id);


--
-- Name: ix_usuario_rol; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_usuario_rol ON public.usuario USING btree (rol_id);


--
-- Name: ix_vacuna_especie_especie; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_vacuna_especie_especie ON public.vacuna_especie USING btree (especie_id);


--
-- Name: ix_vet_esp_especialidad; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_vet_esp_especialidad ON public.veterinario_especialidad USING btree (especialidad_id);


--
-- Name: uq_cliente_email; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX uq_cliente_email ON public.cliente USING btree (lower((email)::text)) WHERE (email IS NOT NULL);


--
-- Name: uq_consulta_diag_principal; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX uq_consulta_diag_principal ON public.consulta_diagnostico USING btree (consulta_id) WHERE es_principal;


--
-- Name: uq_mascota_microchip; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX uq_mascota_microchip ON public.mascota USING btree (microchip) WHERE (microchip IS NOT NULL);


--
-- Name: uq_vet_especialidad_principal; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX uq_vet_especialidad_principal ON public.veterinario_especialidad USING btree (veterinario_id) WHERE es_principal;


--
-- Name: uq_veterinario_email; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX uq_veterinario_email ON public.veterinario USING btree (lower((email)::text)) WHERE (email IS NOT NULL);


--
-- Name: aplicacion_vacuna tg_aplicacion_vacuna_apta; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER tg_aplicacion_vacuna_apta BEFORE INSERT OR UPDATE ON public.aplicacion_vacuna FOR EACH ROW EXECUTE FUNCTION public.fn_vacuna_apta();


--
-- Name: cita tg_cita_fin; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER tg_cita_fin BEFORE INSERT OR UPDATE ON public.cita FOR EACH ROW EXECUTE FUNCTION public.fn_cita_fin();


--
-- Name: consulta tg_consulta_coherente; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER tg_consulta_coherente BEFORE INSERT OR UPDATE ON public.consulta FOR EACH ROW EXECUTE FUNCTION public.fn_consulta_coherente();


--
-- Name: factura_detalle tg_factura_detalle_cerrada; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER tg_factura_detalle_cerrada BEFORE INSERT OR DELETE OR UPDATE ON public.factura_detalle FOR EACH ROW EXECUTE FUNCTION public.fn_factura_cerrada();


--
-- Name: factura_detalle tg_factura_detalle_stock; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER tg_factura_detalle_stock AFTER INSERT ON public.factura_detalle FOR EACH ROW EXECUTE FUNCTION public.fn_descontar_stock();


--
-- Name: factura_detalle tg_factura_detalle_totales; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER tg_factura_detalle_totales AFTER INSERT OR DELETE OR UPDATE ON public.factura_detalle FOR EACH ROW EXECUTE FUNCTION public.fn_trg_factura_detalle();


--
-- Name: factura tg_factura_numero; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER tg_factura_numero BEFORE INSERT ON public.factura FOR EACH ROW EXECUTE FUNCTION public.fn_factura_numero();


--
-- Name: pago tg_pago; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER tg_pago AFTER INSERT OR DELETE OR UPDATE ON public.pago FOR EACH ROW EXECUTE FUNCTION public.fn_trg_pago();


--
-- Name: receta tg_receta_folio; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER tg_receta_folio BEFORE INSERT ON public.receta FOR EACH ROW EXECUTE FUNCTION public.fn_receta_folio();


--
-- Name: aplicacion_vacuna tg_refuerzo_automatico; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER tg_refuerzo_automatico BEFORE INSERT ON public.aplicacion_vacuna FOR EACH ROW EXECUTE FUNCTION public.fn_refuerzo_automatico();


--
-- Name: aplicacion_vacuna fk_aplicacion_consulta; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.aplicacion_vacuna
    ADD CONSTRAINT fk_aplicacion_consulta FOREIGN KEY (consulta_id) REFERENCES public.consulta(id) ON DELETE SET NULL;


--
-- Name: aplicacion_vacuna fk_aplicacion_mascota; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.aplicacion_vacuna
    ADD CONSTRAINT fk_aplicacion_mascota FOREIGN KEY (mascota_id) REFERENCES public.mascota(id) ON DELETE RESTRICT;


--
-- Name: aplicacion_vacuna fk_aplicacion_vacuna; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.aplicacion_vacuna
    ADD CONSTRAINT fk_aplicacion_vacuna FOREIGN KEY (vacuna_id) REFERENCES public.vacuna(id) ON DELETE RESTRICT;


--
-- Name: aplicacion_vacuna fk_aplicacion_veterinario; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.aplicacion_vacuna
    ADD CONSTRAINT fk_aplicacion_veterinario FOREIGN KEY (veterinario_id) REFERENCES public.veterinario(id) ON DELETE RESTRICT;


--
-- Name: cita fk_cita_mascota; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.cita
    ADD CONSTRAINT fk_cita_mascota FOREIGN KEY (mascota_id) REFERENCES public.mascota(id) ON DELETE RESTRICT;


--
-- Name: cita fk_cita_servicio; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.cita
    ADD CONSTRAINT fk_cita_servicio FOREIGN KEY (servicio_id) REFERENCES public.servicio(id) ON DELETE RESTRICT;


--
-- Name: cita fk_cita_veterinario; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.cita
    ADD CONSTRAINT fk_cita_veterinario FOREIGN KEY (veterinario_id) REFERENCES public.veterinario(id) ON DELETE RESTRICT;


--
-- Name: consulta fk_consulta_cita; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.consulta
    ADD CONSTRAINT fk_consulta_cita FOREIGN KEY (cita_id) REFERENCES public.cita(id) ON DELETE SET NULL;


--
-- Name: consulta_diagnostico fk_consulta_diag_catalogo; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.consulta_diagnostico
    ADD CONSTRAINT fk_consulta_diag_catalogo FOREIGN KEY (diagnostico_id) REFERENCES public.diagnostico(id) ON DELETE RESTRICT;


--
-- Name: consulta_diagnostico fk_consulta_diag_consulta; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.consulta_diagnostico
    ADD CONSTRAINT fk_consulta_diag_consulta FOREIGN KEY (consulta_id) REFERENCES public.consulta(id) ON DELETE CASCADE;


--
-- Name: consulta fk_consulta_mascota; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.consulta
    ADD CONSTRAINT fk_consulta_mascota FOREIGN KEY (mascota_id) REFERENCES public.mascota(id) ON DELETE RESTRICT;


--
-- Name: consulta fk_consulta_veterinario; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.consulta
    ADD CONSTRAINT fk_consulta_veterinario FOREIGN KEY (veterinario_id) REFERENCES public.veterinario(id) ON DELETE RESTRICT;


--
-- Name: factura fk_factura_cliente; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.factura
    ADD CONSTRAINT fk_factura_cliente FOREIGN KEY (cliente_id) REFERENCES public.cliente(id) ON DELETE RESTRICT;


--
-- Name: factura_detalle fk_factura_detalle_factura; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.factura_detalle
    ADD CONSTRAINT fk_factura_detalle_factura FOREIGN KEY (factura_id) REFERENCES public.factura(id) ON DELETE CASCADE;


--
-- Name: factura_detalle fk_factura_detalle_mascota; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.factura_detalle
    ADD CONSTRAINT fk_factura_detalle_mascota FOREIGN KEY (mascota_id) REFERENCES public.mascota(id) ON DELETE SET NULL;


--
-- Name: factura_detalle fk_factura_detalle_medicamento; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.factura_detalle
    ADD CONSTRAINT fk_factura_detalle_medicamento FOREIGN KEY (medicamento_id) REFERENCES public.medicamento(id) ON DELETE RESTRICT;


--
-- Name: factura_detalle fk_factura_detalle_servicio; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.factura_detalle
    ADD CONSTRAINT fk_factura_detalle_servicio FOREIGN KEY (servicio_id) REFERENCES public.servicio(id) ON DELETE RESTRICT;


--
-- Name: mascota fk_mascota_cliente; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.mascota
    ADD CONSTRAINT fk_mascota_cliente FOREIGN KEY (cliente_id) REFERENCES public.cliente(id) ON DELETE RESTRICT;


--
-- Name: mascota_condicion fk_mascota_condicion_catalogo; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.mascota_condicion
    ADD CONSTRAINT fk_mascota_condicion_catalogo FOREIGN KEY (condicion_medica_id) REFERENCES public.condicion_medica(id) ON DELETE RESTRICT;


--
-- Name: mascota_condicion fk_mascota_condicion_mascota; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.mascota_condicion
    ADD CONSTRAINT fk_mascota_condicion_mascota FOREIGN KEY (mascota_id) REFERENCES public.mascota(id) ON DELETE RESTRICT;


--
-- Name: mascota fk_mascota_especie; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.mascota
    ADD CONSTRAINT fk_mascota_especie FOREIGN KEY (especie_id) REFERENCES public.especie(id) ON DELETE RESTRICT;


--
-- Name: mascota fk_mascota_raza_especie; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.mascota
    ADD CONSTRAINT fk_mascota_raza_especie FOREIGN KEY (raza_id, especie_id) REFERENCES public.raza(id, especie_id) ON DELETE RESTRICT;


--
-- Name: pago fk_pago_factura; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.pago
    ADD CONSTRAINT fk_pago_factura FOREIGN KEY (factura_id) REFERENCES public.factura(id) ON DELETE RESTRICT;


--
-- Name: pago fk_pago_metodo; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.pago
    ADD CONSTRAINT fk_pago_metodo FOREIGN KEY (metodo_pago_id) REFERENCES public.metodo_pago(id) ON DELETE RESTRICT;


--
-- Name: raza fk_raza_especie; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.raza
    ADD CONSTRAINT fk_raza_especie FOREIGN KEY (especie_id) REFERENCES public.especie(id) ON DELETE RESTRICT;


--
-- Name: receta fk_receta_consulta; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.receta
    ADD CONSTRAINT fk_receta_consulta FOREIGN KEY (consulta_id) REFERENCES public.consulta(id) ON DELETE CASCADE;


--
-- Name: receta_detalle fk_receta_detalle_medicamento; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.receta_detalle
    ADD CONSTRAINT fk_receta_detalle_medicamento FOREIGN KEY (medicamento_id) REFERENCES public.medicamento(id) ON DELETE RESTRICT;


--
-- Name: receta_detalle fk_receta_detalle_receta; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.receta_detalle
    ADD CONSTRAINT fk_receta_detalle_receta FOREIGN KEY (receta_id) REFERENCES public.receta(id) ON DELETE CASCADE;


--
-- Name: registro_peso fk_registro_peso_consulta; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.registro_peso
    ADD CONSTRAINT fk_registro_peso_consulta FOREIGN KEY (consulta_id) REFERENCES public.consulta(id) ON DELETE SET NULL;


--
-- Name: registro_peso fk_registro_peso_mascota; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.registro_peso
    ADD CONSTRAINT fk_registro_peso_mascota FOREIGN KEY (mascota_id) REFERENCES public.mascota(id) ON DELETE RESTRICT;


--
-- Name: solicitud_cita fk_solicitud_cita; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.solicitud_cita
    ADD CONSTRAINT fk_solicitud_cita FOREIGN KEY (cita_id) REFERENCES public.cita(id) ON DELETE SET NULL;


--
-- Name: solicitud_cita fk_solicitud_especie; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.solicitud_cita
    ADD CONSTRAINT fk_solicitud_especie FOREIGN KEY (especie_id) REFERENCES public.especie(id) ON DELETE SET NULL;


--
-- Name: tratamiento fk_tratamiento_consulta; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tratamiento
    ADD CONSTRAINT fk_tratamiento_consulta FOREIGN KEY (consulta_id) REFERENCES public.consulta(id) ON DELETE CASCADE;


--
-- Name: usuario fk_usuario_rol; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.usuario
    ADD CONSTRAINT fk_usuario_rol FOREIGN KEY (rol_id) REFERENCES public.rol(id) ON DELETE RESTRICT;


--
-- Name: vacuna_especie fk_vacuna_especie_especie; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.vacuna_especie
    ADD CONSTRAINT fk_vacuna_especie_especie FOREIGN KEY (especie_id) REFERENCES public.especie(id) ON DELETE RESTRICT;


--
-- Name: vacuna_especie fk_vacuna_especie_vacuna; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.vacuna_especie
    ADD CONSTRAINT fk_vacuna_especie_vacuna FOREIGN KEY (vacuna_id) REFERENCES public.vacuna(id) ON DELETE CASCADE;


--
-- Name: veterinario_especialidad fk_vet_esp_especialidad; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.veterinario_especialidad
    ADD CONSTRAINT fk_vet_esp_especialidad FOREIGN KEY (especialidad_id) REFERENCES public.especialidad(id) ON DELETE RESTRICT;


--
-- Name: veterinario_especialidad fk_vet_esp_veterinario; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.veterinario_especialidad
    ADD CONSTRAINT fk_vet_esp_veterinario FOREIGN KEY (veterinario_id) REFERENCES public.veterinario(id) ON DELETE CASCADE;


--
-- Name: veterinario fk_veterinario_usuario; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.veterinario
    ADD CONSTRAINT fk_veterinario_usuario FOREIGN KEY (usuario_id) REFERENCES public.usuario(id) ON DELETE SET NULL;


--
-- PostgreSQL database dump complete
--

\unrestrict 9jW0l9UVrbpawsDMpkSyrsXsLlgnTni5x0WIlaX16pEv0YTDzSvKN3vYFc0cniA

