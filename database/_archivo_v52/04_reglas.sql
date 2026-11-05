-- ============================================================================
--  PETCARE — 04_reglas.sql · Funciones y disparadores
-- ----------------------------------------------------------------------------
--  Aquí viven las reglas de negocio que un CHECK no puede expresar, porque
--  necesitan consultar OTRAS filas u OTRAS tablas. Un CHECK solo ve la fila que
--  se está insertando.
--
--  El enunciado es explícito: «No confiar únicamente en JavaScript». Todo lo
--  que hay en este archivo sigue valiéndose aunque la inserción venga por psql,
--  por un script de carga o por un backend con un bug.
--
--  ÍNDICE
--    1. Auditoría          — actualizado_en
--    2. Folios             — numeración de documentos
--    3. Totales            — factura, compra, saldos y estado de cobro
--    4. Coherencia clínica — mascota/cita, vacuna/especie
--    5. Jerarquías         — niveles y detección de ciclos
--    6. Inventario         — kardex automático y stock no negativo
--    7. Inmutabilidad      — documentos anulados
--    8. Capacidad          — habitaciones
-- ============================================================================

SET client_min_messages = WARNING;

-- ============================================================================
--  1. AUDITORÍA
-- ============================================================================

CREATE OR REPLACE FUNCTION fn_set_actualizado_en()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
    NEW.actualizado_en := now();
    RETURN NEW;
END $$;

COMMENT ON FUNCTION fn_set_actualizado_en IS
    'Mantiene actualizado_en. En el motor y no en la aplicación: así ninguna '
    'ruta de escritura puede olvidarse de ponerlo.';

CREATE TRIGGER tg_empleado_actualizado  BEFORE UPDATE ON empleado
    FOR EACH ROW EXECUTE FUNCTION fn_set_actualizado_en();
CREATE TRIGGER tg_usuario_actualizado   BEFORE UPDATE ON usuario
    FOR EACH ROW EXECUTE FUNCTION fn_set_actualizado_en();
CREATE TRIGGER tg_cliente_actualizado   BEFORE UPDATE ON cliente
    FOR EACH ROW EXECUTE FUNCTION fn_set_actualizado_en();
CREATE TRIGGER tg_mascota_actualizado   BEFORE UPDATE ON mascota
    FOR EACH ROW EXECUTE FUNCTION fn_set_actualizado_en();
CREATE TRIGGER tg_cita_actualizado      BEFORE UPDATE ON cita
    FOR EACH ROW EXECUTE FUNCTION fn_set_actualizado_en();
CREATE TRIGGER tg_consulta_actualizado  BEFORE UPDATE ON consulta
    FOR EACH ROW EXECUTE FUNCTION fn_set_actualizado_en();
CREATE TRIGGER tg_producto_actualizado  BEFORE UPDATE ON producto
    FOR EACH ROW EXECUTE FUNCTION fn_set_actualizado_en();
CREATE TRIGGER tg_factura_actualizado   BEFORE UPDATE ON factura
    FOR EACH ROW EXECUTE FUNCTION fn_set_actualizado_en();


-- ── Columna derivada: fin de la cita ───────────────────────────────────────
--  La fuente de verdad es duracion_minutos. fecha_hora_fin existe solo para
--  que la restricción EXCLUDE pueda construir un rango con una expresión
--  IMMUTABLE. Al calcularla aquí, en cada INSERT y cada UPDATE, es imposible
--  que quede desincronizada de la duración.
--  make_interval() y no (n || ' minutes')::interval: la segunda depende de
--  IntervalStyle y por eso no es inmutable.
CREATE OR REPLACE FUNCTION fn_cita_calcular_fin()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
    NEW.fecha_hora_fin := NEW.fecha_hora_inicio
                        + make_interval(mins => NEW.duracion_minutos);
    RETURN NEW;
END $$;

CREATE TRIGGER tg_cita_fin BEFORE INSERT OR UPDATE ON cita
    FOR EACH ROW EXECUTE FUNCTION fn_cita_calcular_fin();


-- ============================================================================
--  2. FOLIOS Y NUMERACIÓN
-- ----------------------------------------------------------------------------
--  Los números de documento son VARCHAR porque llevan prefijo y ceros a la
--  izquierda. La secuencia da el correlativo y el trigger lo formatea, de modo
--  que la aplicación nunca elige un número (y por tanto no puede duplicarlo).
-- ============================================================================

CREATE OR REPLACE FUNCTION fn_generar_folio()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
DECLARE
    v_prefijo   TEXT := TG_ARGV[0];
    v_secuencia TEXT := TG_ARGV[1];
    v_columna   TEXT := TG_ARGV[2];
    v_actual    TEXT;
BEGIN
    EXECUTE format('SELECT ($1).%I::text', v_columna) INTO v_actual USING NEW;
    IF v_actual IS NULL OR btrim(v_actual) = '' THEN
        EXECUTE format('SELECT $1 || lpad(nextval(%L)::text, 6, ''0'')', v_secuencia)
            INTO v_actual USING v_prefijo;
        NEW := jsonb_populate_record(NEW, jsonb_build_object(v_columna, v_actual));
    END IF;
    RETURN NEW;
END $$;

COMMENT ON FUNCTION fn_generar_folio IS
    'Genera un folio con prefijo y relleno de ceros (F-000001) si la columna '
    'llega vacía. Parametrizada por TG_ARGV para servir a factura, receta y '
    'orden de examen sin repetir código.';

CREATE TRIGGER tg_factura_numero BEFORE INSERT ON factura
    FOR EACH ROW EXECUTE FUNCTION fn_generar_folio('F-', 'seq_factura_numero', 'numero');

CREATE TRIGGER tg_receta_folio BEFORE INSERT ON receta
    FOR EACH ROW EXECUTE FUNCTION fn_generar_folio('R-', 'seq_receta_folio', 'folio');

CREATE TRIGGER tg_orden_examen_folio BEFORE INSERT ON orden_examen
    FOR EACH ROW EXECUTE FUNCTION fn_generar_folio('OE-', 'seq_orden_folio', 'folio');


-- ============================================================================
--  3. TOTALES DE DOCUMENTOS
-- ----------------------------------------------------------------------------
--  factura.total y compra.total están almacenados a propósito: un documento
--  comercial es inmutable y su importe no puede cambiar porque mañana suba un
--  precio de catálogo. Esta desnormalización es deliberada y ESTOS TRIGGERS SON
--  LA CONTRAPARTIDA que la mantiene coherente.
-- ============================================================================

CREATE OR REPLACE FUNCTION fn_factura_recalcular(p_factura_id INTEGER)
RETURNS VOID LANGUAGE plpgsql AS $$
DECLARE
    v_sub      NUMERIC(12,2);
    v_pagado   NUMERIC(12,2);
    v_desc     NUMERIC(12,2);
    v_pct      NUMERIC(5,2);
    v_imp      NUMERIC(12,2);
    v_total    NUMERIC(12,2);
    v_saldo    NUMERIC(12,2);
    v_estado   VARCHAR(12);
BEGIN
    SELECT descuento, porcentaje_impuesto, estado
      INTO v_desc, v_pct, v_estado
      FROM factura WHERE id = p_factura_id FOR UPDATE;

    IF NOT FOUND OR v_estado = 'anulada' THEN
        RETURN;                       -- una factura anulada queda congelada
    END IF;

    SELECT COALESCE(SUM(subtotal), 0) INTO v_sub
      FROM factura_detalle WHERE factura_id = p_factura_id;

    SELECT COALESCE(SUM(monto), 0) INTO v_pagado
      FROM pago WHERE factura_id = p_factura_id AND NOT anulado;

    -- El impuesto se calcula sobre la base ya descontada, y se redondea una
    -- sola vez: redondear dos veces produce descuadres de centavos.
    v_imp   := round((v_sub - v_desc) * v_pct / 100, 2);
    v_total := v_sub - v_desc + v_imp;
    v_saldo := GREATEST(v_total - v_pagado, 0);

    v_estado := CASE
        WHEN v_total = 0    THEN 'pendiente'
        WHEN v_saldo = 0    THEN 'pagada'
        WHEN v_pagado > 0   THEN 'parcial'
        ELSE                     'pendiente'
    END;

    UPDATE factura
       SET subtotal        = v_sub,
           impuesto        = v_imp,
           total           = v_total,
           saldo_pendiente = v_saldo,
           estado          = v_estado
     WHERE id = p_factura_id;
END $$;

COMMENT ON FUNCTION fn_factura_recalcular IS
    'Recalcula subtotal, impuesto, total, saldo y estado de una factura a '
    'partir de sus detalles y sus pagos. Fuente única de verdad de los totales.';


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
    v_total   NUMERIC(12,2);
    v_pagado  NUMERIC(12,2);
    v_requiere BOOLEAN;
BEGIN
    IF TG_OP <> 'DELETE' THEN
        -- Regla que un CHECK no puede expresar: exige leer metodo_pago.
        SELECT requiere_referencia INTO v_requiere
          FROM metodo_pago WHERE id = NEW.metodo_pago_id;
        IF v_requiere AND (NEW.referencia IS NULL OR btrim(NEW.referencia) = '') THEN
            RAISE EXCEPTION
                'El método de pago exige número de referencia (factura %)', NEW.factura_id
                USING ERRCODE = 'check_violation';
        END IF;

        -- No se puede cobrar más que el total de la factura.
        SELECT total INTO v_total FROM factura WHERE id = NEW.factura_id;
        SELECT COALESCE(SUM(monto), 0) INTO v_pagado
          FROM pago
         WHERE factura_id = NEW.factura_id
           AND NOT anulado
           AND id <> COALESCE(NEW.id, -1);

        IF NOT NEW.anulado AND v_pagado + NEW.monto > v_total THEN
            RAISE EXCEPTION
                'Los pagos (%) superarían el total de la factura (%)',
                v_pagado + NEW.monto, v_total
                USING ERRCODE = 'check_violation';
        END IF;
    END IF;

    PERFORM fn_factura_recalcular(COALESCE(NEW.factura_id, OLD.factura_id));
    RETURN NULL;
END $$;

CREATE TRIGGER tg_pago_saldo
    AFTER INSERT OR UPDATE OR DELETE ON pago
    FOR EACH ROW EXECUTE FUNCTION fn_trg_pago();


-- Cambiar el descuento o la tasa de impuesto también rehace los totales.
-- Se hace en un BEFORE y sobre NEW, para no volver a disparar el trigger.
CREATE OR REPLACE FUNCTION fn_factura_before_update()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
DECLARE
    v_pagado NUMERIC(12,2);
BEGIN
    IF NEW.estado = 'anulada' AND OLD.estado <> 'anulada' THEN
        NEW.saldo_pendiente := 0;
        RETURN NEW;
    END IF;

    IF NEW.descuento IS DISTINCT FROM OLD.descuento
       OR NEW.porcentaje_impuesto IS DISTINCT FROM OLD.porcentaje_impuesto THEN
        NEW.impuesto := round((NEW.subtotal - NEW.descuento) * NEW.porcentaje_impuesto / 100, 2);
        NEW.total    := NEW.subtotal - NEW.descuento + NEW.impuesto;

        SELECT COALESCE(SUM(monto), 0) INTO v_pagado
          FROM pago WHERE factura_id = NEW.id AND NOT anulado;

        NEW.saldo_pendiente := GREATEST(NEW.total - v_pagado, 0);
        NEW.estado := CASE
            WHEN NEW.total = 0          THEN 'pendiente'
            WHEN NEW.saldo_pendiente = 0 THEN 'pagada'
            WHEN v_pagado > 0            THEN 'parcial'
            ELSE                              'pendiente'
        END;
    END IF;
    RETURN NEW;
END $$;

CREATE TRIGGER tg_factura_before_update BEFORE UPDATE ON factura
    FOR EACH ROW EXECUTE FUNCTION fn_factura_before_update();


CREATE OR REPLACE FUNCTION fn_trg_compra_detalle()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
DECLARE
    v_compra_id INTEGER := COALESCE(NEW.compra_id, OLD.compra_id);
    v_sub NUMERIC(12,2);
BEGIN
    SELECT COALESCE(SUM(subtotal), 0) INTO v_sub
      FROM compra_detalle WHERE compra_id = v_compra_id;

    UPDATE compra
       SET subtotal = v_sub,
           total    = v_sub - descuento + impuesto
     WHERE id = v_compra_id;
    RETURN NULL;
END $$;

CREATE TRIGGER tg_compra_detalle_totales
    AFTER INSERT OR UPDATE OR DELETE ON compra_detalle
    FOR EACH ROW EXECUTE FUNCTION fn_trg_compra_detalle();


-- ============================================================================
--  4. COHERENCIA CLÍNICA
-- ============================================================================

-- Una consulta que nace de una cita tiene que ser de la MISMA mascota y del
-- MISMO veterinario que la cita. Sin esto, el turno de Max podría terminar
-- registrado como la consulta de Luna.
CREATE OR REPLACE FUNCTION fn_consulta_coherente_con_cita()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
DECLARE
    v_mascota INTEGER;
    v_vet     INTEGER;
BEGIN
    IF NEW.cita_id IS NULL THEN
        RETURN NEW;
    END IF;

    SELECT mascota_id, veterinario_id INTO v_mascota, v_vet
      FROM cita WHERE id = NEW.cita_id;

    IF v_mascota <> NEW.mascota_id THEN
        RAISE EXCEPTION
            'La consulta es de la mascota % pero la cita % corresponde a la mascota %',
            NEW.mascota_id, NEW.cita_id, v_mascota
            USING ERRCODE = 'check_violation';
    END IF;

    IF v_vet <> NEW.veterinario_id THEN
        RAISE EXCEPTION
            'La consulta la firma el veterinario % pero la cita % estaba asignada al %',
            NEW.veterinario_id, NEW.cita_id, v_vet
            USING ERRCODE = 'check_violation';
    END IF;

    RETURN NEW;
END $$;

CREATE TRIGGER tg_consulta_coherente BEFORE INSERT OR UPDATE ON consulta
    FOR EACH ROW EXECUTE FUNCTION fn_consulta_coherente_con_cita();


-- No se aplica una vacuna canina a un ave. La restricción vive en el modelo
-- (vacuna_especie), pero hace falta un trigger para hacerla cumplir al aplicar.
CREATE OR REPLACE FUNCTION fn_vacuna_apta_para_especie()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
DECLARE
    v_especie   SMALLINT;
    v_declara   BOOLEAN;
    v_apta      BOOLEAN;
    v_nom_vac   TEXT;
    v_nom_esp   TEXT;
BEGIN
    SELECT m.especie_id, e.nombre INTO v_especie, v_nom_esp
      FROM mascota m JOIN especie e ON e.id = m.especie_id
     WHERE m.id = NEW.mascota_id;

    -- Si la vacuna no declara especies, se considera universal.
    SELECT EXISTS (SELECT 1 FROM vacuna_especie WHERE vacuna_id = NEW.vacuna_id)
      INTO v_declara;
    IF NOT v_declara THEN
        RETURN NEW;
    END IF;

    SELECT EXISTS (
        SELECT 1 FROM vacuna_especie
         WHERE vacuna_id = NEW.vacuna_id AND especie_id = v_especie
    ) INTO v_apta;

    IF NOT v_apta THEN
        SELECT nombre INTO v_nom_vac FROM vacuna WHERE id = NEW.vacuna_id;
        RAISE EXCEPTION
            'La vacuna "%" no está indicada para la especie %', v_nom_vac, v_nom_esp
            USING ERRCODE = 'check_violation';
    END IF;

    RETURN NEW;
END $$;

CREATE TRIGGER tg_aplicacion_vacuna_especie BEFORE INSERT OR UPDATE ON aplicacion_vacuna
    FOR EACH ROW EXECUTE FUNCTION fn_vacuna_apta_para_especie();


-- ============================================================================
--  5. JERARQUÍAS RECURSIVAS
-- ----------------------------------------------------------------------------
--  El CHECK de la tabla impide que una fila sea su propio padre, pero no puede
--  detectar un ciclo A → B → C → A: eso exige recorrer el árbol.
-- ============================================================================

CREATE OR REPLACE FUNCTION fn_diagnostico_jerarquia()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
DECLARE
    v_nivel SMALLINT;
BEGIN
    IF NEW.padre_id IS NULL THEN
        NEW.nivel := 1;
        RETURN NEW;
    END IF;

    -- Detección de ciclos: si NEW.id ya aparece entre los ancestros del padre,
    -- cerrar el vínculo crearía un bucle infinito.
    IF TG_OP = 'UPDATE' AND EXISTS (
        WITH RECURSIVE ancestros AS (
            SELECT id, padre_id FROM diagnostico WHERE id = NEW.padre_id
            UNION ALL
            SELECT d.id, d.padre_id
              FROM diagnostico d JOIN ancestros a ON d.id = a.padre_id
        )
        SELECT 1 FROM ancestros WHERE id = NEW.id
    ) THEN
        RAISE EXCEPTION
            'La jerarquía de diagnósticos quedaría en ciclo (% no puede colgar de %)',
            NEW.id, NEW.padre_id
            USING ERRCODE = 'check_violation';
    END IF;

    SELECT nivel INTO v_nivel FROM diagnostico WHERE id = NEW.padre_id;
    NEW.nivel := v_nivel + 1;
    RETURN NEW;
END $$;

CREATE TRIGGER tg_diagnostico_jerarquia BEFORE INSERT OR UPDATE ON diagnostico
    FOR EACH ROW EXECUTE FUNCTION fn_diagnostico_jerarquia();


CREATE OR REPLACE FUNCTION fn_categoria_sin_ciclo()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
    IF NEW.padre_id IS NULL THEN
        RETURN NEW;
    END IF;

    IF TG_OP = 'UPDATE' AND EXISTS (
        WITH RECURSIVE ancestros AS (
            SELECT id, padre_id FROM categoria_producto WHERE id = NEW.padre_id
            UNION ALL
            SELECT c.id, c.padre_id
              FROM categoria_producto c JOIN ancestros a ON c.id = a.padre_id
        )
        SELECT 1 FROM ancestros WHERE id = NEW.id
    ) THEN
        RAISE EXCEPTION 'La jerarquía de categorías quedaría en ciclo'
            USING ERRCODE = 'check_violation';
    END IF;
    RETURN NEW;
END $$;

CREATE TRIGGER tg_categoria_sin_ciclo BEFORE INSERT OR UPDATE ON categoria_producto
    FOR EACH ROW EXECUTE FUNCTION fn_categoria_sin_ciclo();


-- ============================================================================
--  6. INVENTARIO
-- ----------------------------------------------------------------------------
--  El stock es un DERIVADO: SUM(cantidad) sobre movimiento_stock. No existe
--  columna de stock que alguien pueda editar a mano. Estos triggers generan los
--  movimientos automáticamente y vigilan que el saldo nunca quede negativo.
-- ============================================================================

CREATE OR REPLACE FUNCTION fn_stock_actual(p_producto_id INTEGER)
RETURNS NUMERIC LANGUAGE sql STABLE AS $$
    SELECT COALESCE(SUM(cantidad), 0)
      FROM movimiento_stock WHERE producto_id = p_producto_id;
$$;

COMMENT ON FUNCTION fn_stock_actual IS
    'Saldo de inventario de un producto. Es una suma porque la cantidad del '
    'kardex lleva signo: las entradas son positivas y las salidas negativas.';


CREATE OR REPLACE FUNCTION fn_stock_no_negativo()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
DECLARE
    v_prod   INTEGER := COALESCE(NEW.producto_id, OLD.producto_id);
    v_saldo  NUMERIC;
    v_nombre TEXT;
BEGIN
    v_saldo := fn_stock_actual(v_prod);
    IF v_saldo < 0 THEN
        SELECT nombre INTO v_nombre FROM producto WHERE id = v_prod;
        RAISE EXCEPTION
            'El stock de "%" quedaría en % (no puede ser negativo)', v_nombre, v_saldo
            USING ERRCODE = 'check_violation';
    END IF;
    RETURN NULL;
END $$;

CREATE CONSTRAINT TRIGGER tg_stock_no_negativo
    AFTER INSERT OR UPDATE OR DELETE ON movimiento_stock
    DEFERRABLE INITIALLY IMMEDIATE
    FOR EACH ROW EXECUTE FUNCTION fn_stock_no_negativo();

COMMENT ON TRIGGER tg_stock_no_negativo ON movimiento_stock IS
    'CONSTRAINT TRIGGER y no un CHECK porque la regla depende de la SUMA de '
    'todas las filas del producto, no de la fila insertada. Es DEFERRABLE para '
    'permitir reordenar movimientos dentro de una transacción.';


-- Facturar un producto lo saca del inventario.
CREATE OR REPLACE FUNCTION fn_movimiento_desde_factura()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
    IF NEW.tipo_item = 'PRODUCTO' AND NEW.producto_id IS NOT NULL THEN
        INSERT INTO movimiento_stock (producto_id, tipo, cantidad, factura_detalle_id, motivo)
        VALUES (NEW.producto_id, 'SALIDA', -NEW.cantidad, NEW.id, 'Venta facturada');
    END IF;
    RETURN NULL;
END $$;

CREATE TRIGGER tg_factura_detalle_stock AFTER INSERT ON factura_detalle
    FOR EACH ROW EXECUTE FUNCTION fn_movimiento_desde_factura();


-- Aplicar una vacuna consume el frasco correspondiente.
CREATE OR REPLACE FUNCTION fn_movimiento_desde_vacuna()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
DECLARE
    v_producto INTEGER;
BEGIN
    SELECT producto_id INTO v_producto FROM vacuna WHERE id = NEW.vacuna_id;
    IF v_producto IS NOT NULL THEN
        INSERT INTO movimiento_stock (producto_id, tipo, cantidad,
                                      aplicacion_vacuna_id, motivo, lote)
        VALUES (v_producto, 'SALIDA', -1, NEW.id, 'Aplicación de vacuna', NEW.lote);
    END IF;
    RETURN NULL;
END $$;

CREATE TRIGGER tg_aplicacion_vacuna_stock AFTER INSERT ON aplicacion_vacuna
    FOR EACH ROW EXECUTE FUNCTION fn_movimiento_desde_vacuna();


-- Desparasitar también consume producto. A diferencia de la vacuna, aquí el
-- producto es obligatorio, así que el movimiento se genera siempre.
CREATE OR REPLACE FUNCTION fn_movimiento_desde_desparasitacion()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
    INSERT INTO movimiento_stock (producto_id, empleado_id, tipo, cantidad,
                                  desparasitacion_id, motivo)
    VALUES (NEW.producto_id, NEW.veterinario_id, 'SALIDA', -1, NEW.id,
            'Desparasitación ' || lower(NEW.tipo));
    RETURN NULL;
END $$;

CREATE TRIGGER tg_desparasitacion_stock AFTER INSERT ON desparasitacion
    FOR EACH ROW EXECUTE FUNCTION fn_movimiento_desde_desparasitacion();


-- Recibir una compra ingresa la mercadería. Se dispara al pasar a 'recibida',
-- no al crear la compra: mientras está pendiente, la mercadería no llegó.
CREATE OR REPLACE FUNCTION fn_movimiento_desde_compra()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
    IF NEW.estado = 'recibida' AND OLD.estado <> 'recibida' THEN
        INSERT INTO movimiento_stock (producto_id, empleado_id, tipo, cantidad,
                                      compra_detalle_id, motivo, lote)
        SELECT cd.producto_id, NEW.empleado_id, 'ENTRADA', cd.cantidad,
               cd.id, 'Recepción de compra ' || NEW.numero_factura, cd.lote
          FROM compra_detalle cd
         WHERE cd.compra_id = NEW.id;
    END IF;
    RETURN NULL;
END $$;

CREATE TRIGGER tg_compra_recepcion AFTER UPDATE ON compra
    FOR EACH ROW EXECUTE FUNCTION fn_movimiento_desde_compra();


-- ============================================================================
--  7. INMUTABILIDAD DE DOCUMENTOS ANULADOS
-- ----------------------------------------------------------------------------
--  Una factura anulada es un documento cerrado. Permitir que se le agreguen o
--  quiten líneas después de anulada rompería la trazabilidad contable.
-- ============================================================================

CREATE OR REPLACE FUNCTION fn_factura_anulada_inmutable()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
DECLARE
    v_estado VARCHAR(12);
    v_id     INTEGER := COALESCE(NEW.factura_id, OLD.factura_id);
BEGIN
    SELECT estado INTO v_estado FROM factura WHERE id = v_id;
    IF v_estado IN ('anulada', 'pagada') THEN
        RAISE EXCEPTION
            'No se pueden modificar los detalles de una factura %', v_estado
            USING ERRCODE = 'check_violation';
    END IF;
    RETURN COALESCE(NEW, OLD);
END $$;

CREATE TRIGGER tg_factura_detalle_inmutable
    BEFORE INSERT OR UPDATE OR DELETE ON factura_detalle
    FOR EACH ROW EXECUTE FUNCTION fn_factura_anulada_inmutable();


-- ============================================================================
--  8. CAPACIDAD DE HABITACIONES
-- ----------------------------------------------------------------------------
--  EXCLUDE impide que una internación ocupe dos habitaciones a la vez, pero no
--  sabe CONTAR: no puede verificar que una habitación de capacidad 3 no reciba
--  un cuarto paciente. Eso requiere una agregación.
-- ============================================================================

CREATE OR REPLACE FUNCTION fn_habitacion_capacidad()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
DECLARE
    v_capacidad SMALLINT;
    v_ocupantes INTEGER;
    v_codigo    TEXT;
BEGIN
    SELECT capacidad, codigo INTO v_capacidad, v_codigo
      FROM habitacion WHERE id = NEW.habitacion_id;

    SELECT count(*) INTO v_ocupantes
      FROM hospitalizacion_habitacion hh
     WHERE hh.habitacion_id = NEW.habitacion_id
       AND hh.id <> COALESCE(NEW.id, -1)
       AND tstzrange(hh.desde, hh.hasta) && tstzrange(NEW.desde, NEW.hasta);

    IF v_ocupantes >= v_capacidad THEN
        RAISE EXCEPTION
            'La habitación % ya tiene % ocupantes y su capacidad es %',
            v_codigo, v_ocupantes, v_capacidad
            USING ERRCODE = 'check_violation';
    END IF;
    RETURN NEW;
END $$;

CREATE TRIGGER tg_habitacion_capacidad
    BEFORE INSERT OR UPDATE ON hospitalizacion_habitacion
    FOR EACH ROW EXECUTE FUNCTION fn_habitacion_capacidad();
