# FASE 0 y 1 — Análisis del dominio y diseño conceptual

**Proyecto:** PetCare — Sistema de Gestión Integral para Clínica Veterinaria
**Materia:** Base de Datos
**SGBD:** PostgreSQL 16 (estructura creada manualmente, sin migraciones de framework)

---

## 1. Descripción del dominio

Una clínica veterinaria atiende **animales de compañía** que son llevados por una
persona responsable (tutor o propietario). A diferencia de la medicina humana, en el
dominio veterinario el **paciente no coincide con el cliente**: el paciente es la
mascota, pero la relación contractual, comercial y de contacto se establece con el
tutor. Esta disociación es la primera decisión estructural del modelo y condiciona
todo lo demás.

El ciclo operativo real de la clínica es el siguiente:

```
El tutor solicita un turno
        ↓
Se agenda una CITA (mascota + veterinario + fecha/hora)
        ↓
La mascota es atendida → se registra una CONSULTA
        ↓
Durante la consulta se toman signos vitales y peso
        ↓
El veterinario emite uno o varios DIAGNÓSTICOS
        ↓
Indica uno o varios TRATAMIENTOS
        ↓
Puede emitir una RECETA con varios MEDICAMENTOS (con pauta propia)
        ↓
Puede aplicar VACUNAS (que generan un refuerzo futuro)
        ↓
Se emite una FACTURA al tutor por servicios y productos consumidos
```

Todo lo que ocurre queda acumulado en el **historial clínico de la mascota**, que es
un registro cronológico permanente y legalmente sensible.

---

## 2. Reglas del negocio identificadas

Estas son las reglas que se extraen del análisis y que el modelo debe hacer cumplir.
Se clasifican según dónde deben implementarse.

### 2.1 Reglas estructurales (se resuelven con el modelo relacional)

| # | Regla | Mecanismo |
|---|-------|-----------|
| R01 | Una mascota pertenece a exactamente un tutor | FK obligatoria `mascota.cliente_id` |
| R02 | Una raza pertenece a exactamente una especie | FK obligatoria `raza.especie_id` |
| R03 | La raza de una mascota debe ser de su misma especie | FK compuesta `(especie_id, raza_id)` |
| R04 | Un medicamento puede repetirse en muchas recetas y una receta contiene muchos medicamentos | Entidad asociativa `receta_detalle` |
| R05 | Una vacuna se aplica a muchas mascotas y una mascota recibe muchas vacunas | Entidad asociativa `aplicacion_vacuna` |
| R06 | Una consulta puede generar como máximo una receta | FK `receta.consulta_id` con `UNIQUE` |
| R07 | Una cita atendida genera como máximo una consulta | FK `consulta.cita_id` con `UNIQUE` |
| R08 | Un veterinario puede tener varias especialidades | Entidad asociativa `veterinario_especialidad` |
| R09 | Una consulta puede arrojar varios diagnósticos y un diagnóstico se repite entre consultas | Entidad asociativa `consulta_diagnostico` |
| R10 | Un detalle de factura refiere a un servicio **o** a un medicamento, nunca a ambos | Arco exclusivo con `CHECK` |

### 2.2 Reglas de dominio (se resuelven con `CHECK` / `DOMAIN`)

| # | Regla |
|---|-------|
| R11 | El peso de una mascota debe ser mayor que 0 |
| R12 | Las cantidades facturadas o prescritas deben ser mayores que 0 |
| R13 | Los precios no pueden ser negativos |
| R14 | El stock de un medicamento no puede ser negativo |
| R15 | `fecha_proximo_refuerzo >= fecha_aplicacion` en una vacunación |
| R16 | El estado de una cita ∈ {programada, confirmada, atendida, cancelada, no_asistio} |
| R17 | El estado de una factura ∈ {pendiente, pagada, anulada} |
| R18 | El sexo de una mascota ∈ {M, H} |
| R19 | `subtotal = cantidad × precio_unitario − descuento_linea` |
| R20 | La fecha de nacimiento de una mascota no puede ser futura |
| R21 | Una consulta no puede tener fecha futura |
| R22 | El descuento de una factura no puede superar el subtotal |

### 2.3 Reglas de proceso (se resuelven con `TRIGGER` o en el backend)

| # | Regla | Dónde |
|---|-------|-------|
| R23 | El total de una factura se recalcula a partir de sus detalles | `TRIGGER` en `factura_detalle` |
| R24 | Un veterinario no puede tener dos citas solapadas en el tiempo | `EXCLUDE USING gist` |
| R25 | Facturar un medicamento descuenta stock | `TRIGGER` |
| R26 | Una factura anulada no admite modificación de detalles | `TRIGGER` |
| R27 | El número de factura se genera secuencialmente | `SEQUENCE` |

---

## 3. Decisiones de diseño y su justificación

Estas son las decisiones no triviales del modelo. Cada una responde a un problema
concreto detectado durante el análisis.

### D1 — El peso NO es un atributo de la mascota

**Problema.** El requisito pide mostrar el "peso actual" en el perfil y a la vez llevar
un seguimiento de los "cambios de peso" en el historial.

**Análisis.** Si guardamos `mascota.peso_actual` y además el peso en cada consulta,
el mismo dato vive en dos lugares y puede desincronizarse. Además, el peso es una
**serie temporal**: su valor depende de la fecha de medición, no de la mascota.
Guardar un único peso en `mascota` significaría que el atributo no depende solo de la
clave primaria, sino del momento — una violación conceptual de la 2FN aplicada al
tiempo.

**Decisión.** Se crea la entidad `registro_peso (mascota, fecha, peso_kg)`.
El "peso actual" es un dato **derivado**: la medición más reciente. Se expone mediante
una vista (`v_mascota_perfil`), no mediante una columna almacenada.

**Consecuencia.** `consulta` **no** almacena `peso_kg`. Cuando se registra una consulta
con peso, se inserta un `registro_peso` vinculado a esa consulta mediante
`registro_peso.consulta_id`. Un peso también puede registrarse sin consulta (control
en recepción, jornada de vacunación), por eso ese FK es opcional.

> **Nota:** temperatura, frecuencia cardíaca y frecuencia respiratoria **sí** quedan en
> `consulta`. Son signos vitales puntuales del encuentro clínico, no series de
> seguimiento independientes, y no se toman fuera de una consulta.

### D2 — Diagnóstico es un catálogo, no texto libre

**Problema.** Si el diagnóstico se escribe como texto libre en la consulta, escribir
"Gastritis", "gastritis" y "Gastritis aguda" produce tres valores distintos para el
mismo concepto. Los reportes de morbilidad (¿cuáles son las patologías más frecuentes?)
se vuelven imposibles.

**Decisión.** `diagnostico` es una entidad catálogo con código y nombre normalizados.
La relación con `consulta` es **N:M** resuelta con `consulta_diagnostico`, que además
almacena atributos propios de esa asociación: si el diagnóstico es *presuntivo* o
*definitivo*, si es el diagnóstico principal, y notas del caso.

### D3 — Alergias y condiciones crónicas: una sola entidad, no dos

**Problema.** El requisito pide "alergias" y "condiciones importantes" en el perfil.
Guardarlas como texto libre separado por comas viola la 1FN (grupos repetitivos en un
atributo).

**Análisis.** Una alergia y una condición crónica son estructuralmente idénticas:
un concepto médico persistente asociado a la mascota, con severidad y fecha de
detección. Crear dos catálogos separados duplicaría estructura sin ganar nada.

**Decisión.** Una entidad `condicion_medica` con un atributo discriminante
`tipo ∈ {ALERGIA, CRONICA, CONGENITA, OTRA}`, y una asociativa `mascota_condicion`
que guarda severidad, fecha de detección, si sigue activa y notas.

### D4 — Las solicitudes del sitio público no entran directo a las tablas maestras

**Problema.** El sitio público permite "agendar cita". Quien la solicita puede no estar
registrado, y los datos que carga no están verificados.

**Análisis.** Si un visitante anónimo pudiera insertar directamente en `cliente`,
`mascota` y `cita`, las tablas maestras se llenarían de registros duplicados,
incompletos o falsos. La calidad del maestro de clientes se degradaría con cada spam.

**Decisión.** Entidad `solicitud_cita`, con los datos de contacto tal como los escribió
el visitante y estado propio. La recepcionista la revisa y la **convierte** en una cita
real, momento en el cual se enlaza (`solicitud_cita.cita_id`). Es una zona de
cuarentena entre el exterior y el modelo maestro.

### D5 — Relación 1:1 opcional entre `usuario` y `veterinario`

Un veterinario es una **persona con matrícula profesional**; un usuario es una
**credencial de acceso al sistema**. No todo veterinario usa el sistema (puede ser un
profesional externo o de guardia cuyos datos se registran para trazabilidad clínica),
y no todo usuario es veterinario (administrador, recepcionista).

Se modelan como entidades separadas con una relación **1:0..1**: `veterinario.usuario_id`
es opcional y `UNIQUE`. Esto evita columnas nulas masivas en `usuario` y mantiene la
separación entre identidad profesional e identidad de acceso.

### D6 — Desnormalizaciones deliberadas y controladas

Hay dos casos donde el modelo almacena datos derivables. Ambos son decisiones
conscientes, no descuidos:

| Dato | Por qué se almacena | Cómo se protege |
|------|---------------------|-----------------|
| `factura.subtotal`, `descuento`, `impuesto`, `total` | Una factura es un **documento fiscal inmutable**. Si el precio de un servicio cambia mañana, el total de la factura de hoy no debe cambiar. Recalcularlo al vuelo produciría importes históricos incorrectos. | `TRIGGER` que los recalcula ante cualquier cambio en `factura_detalle` |
| `factura_detalle.precio_unitario` | Congela el precio del catálogo en el momento de la venta, por la misma razón | Se copia desde `servicio.precio_base` o `medicamento.precio_venta` al insertar |
| `medicamento.stock_actual` | El requisito pide controlar stock pero **no** pide un kardex de movimientos. Un libro de movimientos completo sería alcance no solicitado. | `CHECK (stock_actual >= 0)` + `TRIGGER` de descuento al facturar |

> Si el proyecto creciera, `medicamento.stock_actual` debería convertirse en un valor
> derivado de una entidad `movimiento_stock`. Se documenta como extensión futura.

### D7 — Política de borrado: el historial clínico es sagrado

El requisito es explícito: eliminar una mascota **no** puede destruir su historial.
Se define esta política de integridad referencial:

| Relación | Acción | Motivo |
|----------|--------|--------|
| `mascota` → `consulta`, `aplicacion_vacuna`, `registro_peso` | `ON DELETE RESTRICT` | El historial clínico bloquea el borrado. Se usa baja lógica (`mascota.activo = false`). |
| `cliente` → `mascota`, `factura` | `ON DELETE RESTRICT` | Un cliente con mascotas o facturas no se elimina |
| `receta` → `receta_detalle` | `ON DELETE CASCADE` | El detalle **no existe** sin su receta: es una parte, no un ente autónomo |
| `factura` → `factura_detalle` | `ON DELETE CASCADE` | Ídem |
| `consulta` → `consulta_diagnostico`, `tratamiento` | `ON DELETE CASCADE` | Ídem |
| Catálogos (`especie`, `raza`, `servicio`, `medicamento`, `vacuna`, `diagnostico`) | `ON DELETE RESTRICT` | Nunca se borra un catálogo referenciado; se marca `activo = false` |
| `usuario` → `veterinario` | `ON DELETE SET NULL` | Quitar el acceso al sistema no elimina al profesional |

**Criterio general aplicado:** `CASCADE` solo cuando la entidad hija carece de
identidad propia fuera del padre (relación de composición). En cualquier otro caso,
`RESTRICT` + baja lógica.

---

## 4. Alcance: qué queda fuera y por qué

Se descartaron deliberadamente estas entidades por no estar en los requisitos y no ser
necesarias para la coherencia del modelo:

| Entidad descartada | Motivo |
|--------------------|--------|
| `pago` (pagos parciales) | El requisito modela el cobro como un **estado** de la factura (pendiente/pagada/anulada), no como transacciones parciales. Agregarla sería alcance no pedido. |
| `movimiento_stock` (kardex) | No se pidió gestión de inventario. Ver D6. |
| `permiso` + `rol_permiso` | Con tres roles fijos y bien delimitados, una matriz de permisos granular es sobre-ingeniería. La autorización se resuelve por rol. |
| `horario_atencion` del veterinario | La agenda se protege con la restricción de no solapamiento (R24), que cubre el requisito real sin una tabla adicional. |
| `hospitalizacion` / `internacion` | No figura en los requisitos. |
| `transferencia_propiedad` de mascota | No figura en los requisitos. |

---

## 5. Convenciones adoptadas

| Aspecto | Convención | Ejemplo |
|---------|-----------|---------|
| Nombres de tabla | `snake_case`, **singular** | `mascota`, `factura_detalle` |
| Clave primaria | Columna `id`, tipo `INTEGER GENERATED ALWAYS AS IDENTITY` | `mascota.id` |
| Clave foránea | `<entidad_referenciada>_id` | `mascota.cliente_id` |
| PK de entidad asociativa pura | **Compuesta** por las FK que asocia | `receta_detalle (receta_id, medicamento_id)` |
| Booleanos | Prefijo `es_` o nombre afirmativo | `activo`, `es_principal`, `esterilizado` |
| Fechas | `fecha_<evento>` (`DATE`) / `<evento>_en` (`TIMESTAMPTZ`) | `fecha_aplicacion`, `creado_en` |
| Enumerados | `VARCHAR` + `CHECK` (no tipos `ENUM`) | ver D8 |
| Dinero | `NUMERIC(12,2)` — nunca `FLOAT` | `precio_base` |

### D8 — Por qué `VARCHAR + CHECK` y no `CREATE TYPE ... AS ENUM`

Los tipos `ENUM` de PostgreSQL son rígidos: agregar un valor requiere `ALTER TYPE`, no
se pueden eliminar valores, y el ordenamiento queda fijado por el orden de declaración.
Un `CHECK` sobre `VARCHAR` es igual de estricto para la integridad, se modifica con un
simple `ALTER TABLE ... DROP/ADD CONSTRAINT`, y es portable. Para catálogos que pueden
crecer (especialidades, servicios) se usan tablas; para conjuntos cerrados y estables
(estados de cita) se usa `CHECK`.

---

## 6. Resumen del modelo conceptual

El modelo resultante tiene **27 entidades**, de las cuales:

- **13** son entidades fuertes principales
- **6** son entidades catálogo
- **7** son entidades asociativas (resuelven relaciones N:M)
- **1** es una entidad de cuarentena (`solicitud_cita`)

Relaciones por tipo:

| Tipo | Cantidad | Casos |
|------|----------|-------|
| **1:1** (opcional) | 3 | `usuario–veterinario`, `cita–consulta`, `consulta–receta` |
| **1:N** | 22 | ver documento del MER |
| **N:M** | 7 | `veterinario–especialidad`, `mascota–condicion_medica`, `consulta–diagnostico`, `receta–medicamento`, `mascota–vacuna`, `vacuna–especie`, `factura–servicio/medicamento` |

Ver el detalle completo en [`02-mer.md`](02-mer.md).
