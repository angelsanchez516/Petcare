-- ============================================================================
--  PETCARE — 04_reglas.sql · Funciones y disparadores
-- ----------------------------------------------------------------------------
--  Aquí viven las reglas que un CHECK no puede expresar, porque necesitan
--  consultar OTRAS filas u OTRAS tablas. Un CHECK solo ve la fila que se está
--  insertando.
--
--  Todo lo de este archivo sigue valiendo aunque la inserción venga por psql,
--  por un script de carga o por un backend con un error.
-- ============================================================================

SET client_min_messages = WARNING;

-- ----------------------------------------------------------------------------
--  1. COLUMNA DERIVADA: FIN DE LA CITA
-- ----------------------------------------------------------------------------
--  La fuente de verdad es duracion_minutos. fecha_hora_fin existe solo para que
--  la restricción EXCLUDE pueda construir un rango con una expresión IMMUTABLE.
--  Calcularla aquí, en cada escritura, hace imposible que se desincronice.
--  make_interval() y no (n || ' minutes')::interval: la segunda depende de
--  IntervalStyle y por eso no es inmutable.
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION fn_cita_fin()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
    NEW.fecha_hora_fin := NEW.fecha_hora_inicio
                        + make_interval(mins => NEW.duracion_minutos);
    RETURN NEW;
END $$;

CREATE TRIGGER tg_cita_fin BEFORE INSERT OR UPDATE ON cita
    FOR EACH ROW EXECUTE FUNCTION fn_cita_fin();


-- ----------------------------------------------------------------------------
--  2. FOLIOS
-- ----------------------------------------------------------------------------
--  Los números de documento son VARCHAR porque llevan prefijo y ceros a la
--  izquierda. La secuencia da el correlativo y el trigger lo formatea, de modo
--  que la aplicación nunca elige un número y por tanto no puede duplicarlo.
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION fn_factura_numero()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
    IF NEW.numero IS NULL OR btrim(NEW.numero) = '' THEN
        NEW.numero := 'F-' || lpad(nextval('seq_factura_numero')::text, 6, '0');
    END IF;
    RETURN NEW;
END $$;

CREATE TRIGGER tg_factura_numero BEFORE INSERT ON factura
    FOR EACH ROW EXECUTE FUNCTION fn_factura_numero();

CREATE OR REPLACE FUNCTION fn_receta_folio()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
    IF NEW.folio IS NULL OR btrim(NEW.folio) = '' THEN
        NEW.folio := 'R-' || lpad(nextval('seq_receta_folio')::text, 6, '0');
    END IF;
    RETURN NEW;
END $$;

CREATE TRIGGER tg_receta_folio BEFORE INSERT ON receta
    FOR EACH ROW EXECUTE FUNCTION fn_receta_folio();


-- ----------------------------------------------------------------------------
--  3. TOTALES DE FACTURA
-- ----------------------------------------------------------------------------
--  factura.total está almacenado a propósito: un documento comercial es
--  inmutable y su importe no puede cambiar porque mañana suba un precio de
--  catálogo. Este trigger es la contrapartida que lo mantiene coherente.
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION fn_factura_recalcular(p_factura_id INTEGER)
RETURNS VOID LANGUAGE plpgsql AS $$
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

COMMENT ON FUNCTION fn_factura_recalcular IS
    'Fuente única de verdad de los totales: los recalcula desde los detalles y '
    'los pagos. La llaman los triggers de factura_detalle y de pago.';


CREATE OR REPLACE FUNCTION fn_trg_factura_detalle()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
    PERFORM fn_factura_recalcular(COALESCE(NEW.factura_id, OLD.factura_id));
    RETURN NULL;
END $$;

CREATE TRIGGER tg_factura_detalle_totales
    AFTER INSERT OR UPDATE OR DELETE ON factura_detalle
    FOR EACH ROW EXECUTE FUNCTION fn_trg_factura_detalle();


CREATE OR REPLACE FUNCTION fn_trg_pago()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
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

CREATE TRIGGER tg_pago AFTER INSERT OR UPDATE OR DELETE ON pago
    FOR EACH ROW EXECUTE FUNCTION fn_trg_pago();


-- Una factura pagada o anulada es un documento cerrado: agregarle o quitarle
-- líneas después rompería la trazabilidad contable.
CREATE OR REPLACE FUNCTION fn_factura_cerrada()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
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

CREATE TRIGGER tg_factura_detalle_cerrada
    BEFORE INSERT OR UPDATE OR DELETE ON factura_detalle
    FOR EACH ROW EXECUTE FUNCTION fn_factura_cerrada();


-- ----------------------------------------------------------------------------
--  4. COHERENCIA CLÍNICA
-- ----------------------------------------------------------------------------

-- Una consulta que nace de una cita tiene que ser de la MISMA mascota y del
-- MISMO veterinario. Sin esto, el turno de Max podría terminar registrado como
-- la consulta de Luna.
CREATE OR REPLACE FUNCTION fn_consulta_coherente()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
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

CREATE TRIGGER tg_consulta_coherente BEFORE INSERT OR UPDATE ON consulta
    FOR EACH ROW EXECUTE FUNCTION fn_consulta_coherente();


-- No se aplica una vacuna canina a un ave. La restricción vive en el modelo
-- (vacuna_especie), pero hace falta un trigger para hacerla cumplir al aplicar.
CREATE OR REPLACE FUNCTION fn_vacuna_apta()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
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

CREATE TRIGGER tg_aplicacion_vacuna_apta BEFORE INSERT OR UPDATE ON aplicacion_vacuna
    FOR EACH ROW EXECUTE FUNCTION fn_vacuna_apta();


-- Calcula la fecha del próximo refuerzo si el catálogo define un intervalo y
-- la aplicación no la trae.
CREATE OR REPLACE FUNCTION fn_refuerzo_automatico()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
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

CREATE TRIGGER tg_refuerzo_automatico BEFORE INSERT ON aplicacion_vacuna
    FOR EACH ROW EXECUTE FUNCTION fn_refuerzo_automatico();


-- ----------------------------------------------------------------------------
--  5. INVENTARIO DE MEDICAMENTOS
-- ----------------------------------------------------------------------------
--  Facturar un medicamento lo descuenta del stock. El CHECK de la tabla impide
--  que el saldo quede negativo, así que una venta sin existencias falla.
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION fn_descontar_stock()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
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

CREATE TRIGGER tg_factura_detalle_stock AFTER INSERT ON factura_detalle
    FOR EACH ROW EXECUTE FUNCTION fn_descontar_stock();
