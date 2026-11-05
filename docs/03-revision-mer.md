# Revisión crítica del MER y verificación de formas normales

Este documento aplica el punto §5 del enunciado: someter el modelo a una revisión
crítica antes de derivar el modelo relacional. Se listan los **problemas realmente
detectados** durante la revisión del primer borrador y cómo se corrigieron.

---

## Parte 1 — Problemas detectados y corregidos

### ❌ P1. Redundancia transitiva en `receta`

**Borrador inicial:**
```
receta (id, consulta_id, mascota_id, veterinario_id, folio, fecha_emision, ...)
```

**Problema.** `mascota_id` y `veterinario_id` son alcanzables por
`receta → consulta → {mascota, veterinario}`. Existe la dependencia transitiva:

```
receta.id → receta.consulta_id → consulta.mascota_id
```

Un atributo no clave (`mascota_id`) depende de otro atributo no clave (`consulta_id`)
en lugar de depender directamente de la clave. **Esto es exactamente una violación de
la 3FN.** Además abre un estado inconsistente real: una receta cuya `mascota_id` diga
"Luna" mientras su consulta es de "Max".

**Corrección.** Se eliminan ambos atributos de `receta`. Se acceden por JOIN.

---

### ❌ P2. `peso` duplicado entre `mascota` y `consulta`

**Borrador inicial:** `mascota.peso_actual` **y** `consulta.peso_kg`.

**Problema.** El mismo hecho registrado en dos lugares, sin ninguna garantía de que
coincidan. Peor: `mascota.peso_actual` es un atributo **multivaluado en el tiempo**
comprimido a un único valor, lo que destruye el historial que el propio enunciado pide
(§9, "cambios de peso").

**Corrección.** Se crea la entidad `registro_peso`. `mascota` pierde `peso_actual`
(pasa a ser derivado) y `consulta` pierde `peso_kg` (se registra en `registro_peso`
con `consulta_id`). Ver decisión **D1**.

---

### ❌ P3. `alergias` y `condiciones` como texto libre → violación de 1FN

**Borrador inicial:** `mascota.alergias VARCHAR(300)`, `mascota.condiciones VARCHAR(300)`.

**Problema.** En la práctica se cargaría `"Penicilina, Polen, Pollo"`. Un atributo con
múltiples valores en una celda **viola la 1FN**. Consecuencias concretas: no se puede
responder "¿qué mascotas son alérgicas a la penicilina?" sin un `LIKE '%penicilina%'`
que además daría falsos positivos, y no se puede registrar la severidad de cada alergia.

**Corrección.** Catálogo `condicion_medica` + asociativa `mascota_condicion` con
severidad, fecha de detección y estado. Ver decisión **D3**.

---

### ❌ P4. `diagnostico` y `tratamiento` como columnas de texto en `consulta`

**Borrador inicial:** `consulta.diagnostico TEXT`, `consulta.tratamiento TEXT`.

**Problema doble:**
1. El enunciado dice explícitamente *"una consulta puede producir **uno o varios**
   diagnósticos"* → es un atributo multivaluado (viola 1FN).
2. Como texto libre, impide cualquier reporte de morbilidad y produce variantes
   ortográficas del mismo concepto.

**Corrección.**
- `diagnostico` → catálogo + N:M `consulta_diagnostico`.
- `tratamiento` → entidad 1:N dependiente de `consulta` (no catálogo: ver justificación
  en C6 del MER).

---

### ❌ P5. Cardinalidad incorrecta en `cita` ↔ `consulta`

**Borrador inicial:** `cita.consulta_id` (FK desde cita hacia consulta).

**Problema.** La dirección estaba invertida y no expresaba la temporalidad: la cita
existe **antes** que la consulta. Con la FK en `cita`, toda cita programada tendría
`consulta_id = NULL` hasta ser atendida, y nada impediría que dos citas apuntaran a la
misma consulta.

**Corrección.** La FK va en `consulta.cita_id`, `NULL` (hay consultas sin turno previo,
las urgencias) y **`UNIQUE`** (una cita no puede generar dos consultas). Así queda una
1:0..1 correcta y direccionalmente coherente con el flujo del negocio.

---

### ❌ P6. `mascota` podía tener una raza de otra especie

**Borrador inicial:** `mascota.especie_id` → `especie.id` y `mascota.raza_id` → `raza.id`,
como dos FK independientes.

**Problema.** Nada impedía `especie = 'Felino'` con `raza = 'Labrador'`. Las dos FK son
válidas por separado pero la combinación es un absurdo. Es un caso clásico de
integridad no capturada por FK simples.

**Corrección.** Se declara `UNIQUE (id, especie_id)` en `raza` (clave alternativa) y
`mascota` usa una **FK compuesta**:
```sql
FOREIGN KEY (raza_id, especie_id) REFERENCES raza (id, especie_id)
```
Ahora el motor rechaza la combinación imposible. Alternativa descartada: un trigger de
validación — más frágil y más lento que una FK declarativa.

---

### ❌ P7. `cliente_id` redundante en `cita` y en `consulta`

**Borrador inicial:** `cita (…, mascota_id, cliente_id, veterinario_id, …)`.

**Problema.** `cliente_id` es derivable: `cita → mascota → cliente`. Dependencia
transitiva → **violación de 3FN**, y riesgo de que la cita registre un tutor distinto
al de la mascota.

**Corrección.** Se elimina. El tutor se obtiene por JOIN. *(Se mantiene
`factura.cliente_id` porque la factura se emite al cliente **directamente**, no a través
de una mascota: una factura puede cubrir varias mascotas del mismo tutor. Ahí no hay
transitividad.)*

---

### ❌ P8. PK compuesta inviable en `aplicacion_vacuna`

**Borrador inicial:** PK `(mascota_id, vacuna_id)`.

**Problema.** Impide registrar refuerzos: la segunda dosis de la antirrábica de Max
violaría la PK. La clave natural real incluye la fecha.

**Corrección.** PK surrogate `id` + `UNIQUE (mascota_id, vacuna_id, fecha_aplicacion)`.
Se conserva la regla de negocio sin propagar una clave de tres columnas.

---

### ❌ P9. `factura_detalle` sin control del arco exclusivo

**Borrador inicial:** `servicio_id` y `medicamento_id` ambos nullables, sin restricción.

**Problema.** Estados inválidos posibles: una línea con **ambos** FK cargados (¿qué se
vendió?) o con **ninguno** y `tipo_item = 'SERVICIO'` (inconsistente).

**Corrección.** `CHECK` de arco exclusivo que amarra `tipo_item` con exactamente un FK
no nulo. Ver E3 del MER.

---

### ❌ P10. `subtotal` calculado solo en la aplicación

**Borrador inicial:** `factura_detalle.subtotal NUMERIC(12,2) NOT NULL`, calculado en JS.

**Problema.** El enunciado (§8) es explícito: *"No confiar únicamente en JavaScript"*.
Una inserción por `psql`, un script de carga o un bug del frontend podrían grabar
`cantidad=2, precio=100, subtotal=5`.

**Corrección.** Columna **generada** por PostgreSQL:
```sql
subtotal NUMERIC(12,2) GENERATED ALWAYS AS
  (cantidad * precio_unitario - descuento_linea) STORED
```
Es aritméticamente imposible almacenar un valor incoherente.

---

### ⚠️ P11. Entidad faltante: solicitudes del sitio público

**Detección.** El sitio público debe permitir "agendar cita" (§22), pero `cita` exige
`mascota_id NOT NULL` y `veterinario_id NOT NULL`. Un visitante anónimo no tiene mascota
registrada. **El modelo no soportaba el requisito.**

**Corrección.** Se agrega `solicitud_cita` como zona de cuarentena. Ver decisión **D4**.

---

### ⚠️ P12. Entidad faltante: `vacuna_especie`

**Detección.** El formulario de aplicación de vacunas mostraría el catálogo completo,
permitiendo aplicar una vacuna canina a un ave. Sin la asociación, la validación
quedaría hardcodeada en el frontend.

**Corrección.** N:M `vacuna_especie`. Ver D5 del MER.

---

## Parte 2 — Verificación de formas normales

### 1FN — Todos los atributos son atómicos

| Verificación | Resultado |
|--------------|-----------|
| ¿Grupos repetitivos en alguna columna? | No — corregido en P3 y P4 |
| ¿Listas separadas por comas? | No |
| ¿Columnas tipo `telefono1, telefono2, telefono3`? | No. `cliente` tiene `telefono` y `telefono_alternativo`, que son **roles semánticos distintos** (contacto principal vs. emergencia), no un grupo repetitivo |
| ¿Filas duplicadas? | No — toda tabla tiene PK |

> **Nota sobre `vacuna.enfermedades_previene`:** es texto descriptivo destinado a
> lectura humana en la ficha, no un conjunto sobre el que se consulte ni se filtre.
> No participa de ninguna regla de negocio. Se acepta como atributo atómico de tipo
> "descripción". Si en el futuro se requiriera filtrar por enfermedad, debería
> convertirse en catálogo + N:M.

**✅ Cumple 1FN.**

### 2FN — Sin dependencias parciales de la clave

Solo aplica a las tablas con **PK compuesta**:

| Tabla | PK | Atributos no clave | ¿Dependen de la PK completa? |
|-------|----|--------------------|------------------------------|
| `veterinario_especialidad` | (vet, esp) | `es_principal`, `certificado_en` | ✅ Sí — la certificación es de *ese* profesional en *esa* especialidad |
| `mascota_condicion` | (mascota, condicion) | `severidad`, `fecha_deteccion`, `activa`, `notas` | ✅ Sí — la severidad es de *esa* condición en *esa* mascota |
| `consulta_diagnostico` | (consulta, diagnostico) | `tipo`, `es_principal`, `notas` | ✅ Sí |
| `receta_detalle` | (receta, medicamento) | `dosis`, `frecuencia`, `duracion_dias`, `via`, `cantidad`, `instrucciones` | ✅ Sí — la dosis no es del medicamento ni de la receta, sino de la prescripción concreta |
| `vacuna_especie` | (vacuna, especie) | — | ✅ Trivial (sin atributos no clave) |

**Contraejemplo verificado:** si `receta_detalle` guardara `principio_activo`, ese
atributo dependería solo de `medicamento_id` (dependencia **parcial**) → violaría 2FN.
No está presente. ✅

Las demás tablas tienen PK simple (`id`), por lo que la 2FN se cumple trivialmente.

**✅ Cumple 2FN.**

### 3FN — Sin dependencias transitivas entre atributos no clave

Revisión de los candidatos a transitividad:

| Caso analizado | ¿Transitivo? | Resolución |
|----------------|--------------|------------|
| `receta.mascota_id` vía `consulta_id` | Era transitivo | **Eliminado** (P1) |
| `cita.cliente_id` vía `mascota_id` | Era transitivo | **Eliminado** (P7) |
| `mascota.nombre_especie` | Sería transitivo | Nunca existió: solo `especie_id` |
| `factura_detalle.descripcion` vía `servicio_id` | **Aparente** | Es un **snapshot histórico**, no una copia viva. Cuando el servicio cambia de nombre, la factura antigua debe conservar el nombre vendido. Es un valor propio de la línea, no una dependencia. |
| `factura_detalle.precio_unitario` vía `servicio_id` | **Aparente** | Ídem: precio congelado al momento de la venta |
| `factura.total` vía sus detalles | **Derivado, no transitivo** | Desnormalización deliberada (D6), mantenida por trigger. Un documento fiscal es inmutable. |
| `mascota.raza_id` + `especie_id` | Parece redundante | **No lo es**: `especie_id` es obligatorio y `raza_id` opcional (mestizos). Sin `especie_id` propio, una mascota mestiza no tendría especie. La FK compuesta garantiza la coherencia (P6). |

**✅ Cumple 3FN**, con dos desnormalizaciones deliberadas y documentadas
(`factura.*` totales y `medicamento.stock_actual`), ambas protegidas por triggers y
`CHECK`.

### BCFN — Verificación

Toda tabla en 3FN está en BCFN salvo que exista un determinante que no sea
superclave. Se revisaron las tablas con múltiples claves candidatas:

| Tabla | Claves candidatas | ¿Algún determinante no superclave? |
|-------|-------------------|-------------------------------------|
| `cliente` | `id`, `(tipo_documento, documento)`, `email` | No |
| `usuario` | `id`, `nombre_usuario`, `email` | No |
| `veterinario` | `id`, `matricula`, `(tipo_documento, documento)`, `usuario_id` | No |
| `raza` | `id`, `(especie_id, nombre)`, `(id, especie_id)` | No |
| `factura` | `id`, `numero` | No |
| `receta` | `id`, `folio`, `consulta_id` | No |

En todos los casos los determinantes son claves candidatas completas.

**✅ Cumple BCFN.**

---

## Parte 3 — Checklist final del enunciado §5

| Pregunta del enunciado | Respuesta |
|------------------------|-----------|
| ¿Existen relaciones redundantes? | Se detectaron 2 (P1, P7) y se eliminaron |
| ¿Faltan entidades? | Se detectaron 2 faltantes (P11, P12) y se agregaron |
| ¿Hay atributos que deberían ser entidades? | Sí: `alergias`, `diagnostico`, `tratamiento`, `peso` (P2, P3, P4). Los cuatro se convirtieron en entidades |
| ¿Existen relaciones N:M? | 7 relaciones N:M identificadas |
| ¿Están correctamente resueltas? | Sí, todas con entidad asociativa. 4 de ellas con atributos propios |
| ¿Las cardinalidades tienen sentido? | Se corrigió 1 dirección invertida (P5) |
| ¿Existen dependencias incorrectas? | Se corrigió 1 PK inviable (P8) y se agregó 1 FK compuesta (P6) |
| ¿Hay información duplicada? | Solo desnormalizaciones deliberadas, documentadas y protegidas (D6) |
| ¿Problemas de normalización? | Ninguno pendiente: 1FN, 2FN, 3FN y BCFN verificadas |

---

## Resumen de la revisión

| Categoría | Cantidad |
|-----------|----------|
| Violaciones de normalización corregidas | 5 (P1, P2, P3, P4, P7) |
| Errores de cardinalidad corregidos | 2 (P5, P8) |
| Restricciones de integridad agregadas | 3 (P6, P9, P10) |
| Entidades faltantes detectadas | 2 (P11, P12) |
| **Total de correcciones** | **12** |

El modelo resultante es el que se documenta en [`02-mer.md`](02-mer.md) y el que se
deriva al modelo relacional en la Fase 3.
