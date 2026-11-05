# FASE 2 — Modelo Entidad-Relación (MER)

**Proyecto:** PetCare — Clínica Veterinaria
**Notación:** Chen extendida / Crow's Foot para el diagrama, con especificación tabular de atributos.

**Leyenda de claves**
`PK` clave primaria · `FK` clave foránea · `UK` clave única (candidata) ·
`NN` no nulo · `D` valor por defecto · `∅` admite nulo

---

## Índice de entidades

### Bloque A — Seguridad y personas
| # | Entidad | Tipo |
|---|---------|------|
| A1 | `rol` | Catálogo |
| A2 | `usuario` | Fuerte |
| A3 | `cliente` | Fuerte |
| A4 | `especialidad` | Catálogo |
| A5 | `veterinario` | Fuerte |
| A6 | `veterinario_especialidad` | **Asociativa (N:M)** |

### Bloque B — Mascota y taxonomía
| # | Entidad | Tipo |
|---|---------|------|
| B1 | `especie` | Catálogo |
| B2 | `raza` | Catálogo dependiente |
| B3 | `mascota` | **Fuerte — núcleo del sistema** |
| B4 | `condicion_medica` | Catálogo |
| B5 | `mascota_condicion` | **Asociativa (N:M)** |
| B6 | `registro_peso` | Débil (dependiente de `mascota`) |

### Bloque C — Agenda y atención clínica
| # | Entidad | Tipo |
|---|---------|------|
| C1 | `solicitud_cita` | Fuerte (cuarentena) |
| C2 | `cita` | Fuerte |
| C3 | `consulta` | Fuerte |
| C4 | `diagnostico` | Catálogo |
| C5 | `consulta_diagnostico` | **Asociativa (N:M)** |
| C6 | `tratamiento` | Débil (dependiente de `consulta`) |

### Bloque D — Prescripción y vacunación
| # | Entidad | Tipo |
|---|---------|------|
| D1 | `receta` | Débil (1:1 con `consulta`) |
| D2 | `medicamento` | Catálogo |
| D3 | `receta_detalle` | **Asociativa (N:M) con atributos** |
| D4 | `vacuna` | Catálogo |
| D5 | `vacuna_especie` | **Asociativa (N:M)** |
| D6 | `aplicacion_vacuna` | **Asociativa (N:M) con atributos** |

### Bloque E — Comercial
| # | Entidad | Tipo |
|---|---------|------|
| E1 | `servicio` | Catálogo |
| E2 | `factura` | Fuerte |
| E3 | `factura_detalle` | **Asociativa (N:M) con atributos** |

---

# BLOQUE A — Seguridad y personas

## A1. `rol`
Catálogo de perfiles de acceso al sistema.

| Atributo | Tipo | Restricción | Descripción |
|----------|------|-------------|-------------|
| `id` | SMALLINT | **PK** | Identificador |
| `codigo` | VARCHAR(20) | **UK**, NN | `ADMINISTRADOR`, `VETERINARIO`, `RECEPCIONISTA` |
| `nombre` | VARCHAR(50) | NN | Nombre visible |
| `descripcion` | VARCHAR(200) | ∅ | Alcance del rol |

> **¿Por qué tabla y no `CHECK`?** Un rol tiene atributos propios (nombre visible,
> descripción) que se muestran en la interfaz. Un `CHECK` no puede almacenar
> descripciones. Además, la FK garantiza integridad sin duplicar el literal en cada fila.

## A2. `usuario`
Credencial de acceso. **No** representa a una persona del negocio, sino a una identidad
de autenticación.

| Atributo | Tipo | Restricción | Descripción |
|----------|------|-------------|-------------|
| `id` | INTEGER | **PK** | |
| `rol_id` | SMALLINT | **FK** → `rol.id`, NN | Perfil de acceso |
| `nombre_usuario` | VARCHAR(50) | **UK**, NN | Login |
| `email` | VARCHAR(120) | **UK**, NN | Formato validado por `CHECK` |
| `password_hash` | VARCHAR(255) | NN | Hash bcrypt/argon2. **Nunca texto plano** |
| `nombre_completo` | VARCHAR(120) | NN | |
| `telefono` | VARCHAR(25) | ∅ | |
| `avatar_url` | VARCHAR(300) | ∅ | |
| `activo` | BOOLEAN | NN, D `true` | Baja lógica |
| `ultimo_acceso_en` | TIMESTAMPTZ | ∅ | |
| `creado_en` | TIMESTAMPTZ | NN, D `now()` | |
| `actualizado_en` | TIMESTAMPTZ | NN, D `now()` | Mantenido por trigger |

## A3. `cliente`
Tutor o propietario responsable de una o más mascotas.

| Atributo | Tipo | Restricción | Descripción |
|----------|------|-------------|-------------|
| `id` | INTEGER | **PK** | |
| `tipo_documento` | VARCHAR(10) | NN, D `'DNI'` | `CHECK ∈ {DNI, CI, PASAPORTE, RUC, NIT, OTRO}` |
| `documento` | VARCHAR(20) | NN | Junto a `tipo_documento` forma **UK compuesta** |
| `nombres` | VARCHAR(80) | NN | |
| `apellidos` | VARCHAR(80) | NN | |
| `telefono` | VARCHAR(25) | NN | Canal principal de contacto |
| `telefono_alternativo` | VARCHAR(25) | ∅ | Contacto de emergencia |
| `email` | VARCHAR(120) | ∅, **UK** parcial | Único entre los no nulos |
| `direccion` | VARCHAR(200) | ∅ | |
| `ciudad` | VARCHAR(80) | ∅ | |
| `fecha_nacimiento` | DATE | ∅ | `CHECK` no futura |
| `notas` | TEXT | ∅ | Observaciones de recepción |
| `activo` | BOOLEAN | NN, D `true` | Baja lógica |
| `creado_en` / `actualizado_en` | TIMESTAMPTZ | NN, D `now()` | Auditoría |

> **UK compuesta `(tipo_documento, documento)`:** dos personas pueden compartir número
> si el tipo de documento difiere (un DNI 12345678 y un pasaporte 12345678 son
> documentos distintos). La unicidad correcta es la del par, no la del número solo.

## A4. `especialidad`
Catálogo de especialidades veterinarias (Cirugía, Dermatología, Cardiología, Exóticos…).

| Atributo | Tipo | Restricción |
|----------|------|-------------|
| `id` | SMALLINT | **PK** |
| `nombre` | VARCHAR(80) | **UK**, NN |
| `descripcion` | VARCHAR(250) | ∅ |
| `activo` | BOOLEAN | NN, D `true` |

## A5. `veterinario`
Profesional que presta atención clínica.

| Atributo | Tipo | Restricción | Descripción |
|----------|------|-------------|-------------|
| `id` | INTEGER | **PK** | |
| `usuario_id` | INTEGER | **FK** → `usuario.id`, **UK**, ∅ | **Relación 1:0..1**. `ON DELETE SET NULL` |
| `tipo_documento` | VARCHAR(10) | NN, D `'DNI'` | |
| `documento` | VARCHAR(20) | NN | **UK** con `tipo_documento` |
| `matricula` | VARCHAR(30) | **UK**, NN | Registro profesional habilitante |
| `nombres` | VARCHAR(80) | NN | |
| `apellidos` | VARCHAR(80) | NN | |
| `telefono` | VARCHAR(25) | ∅ | |
| `email` | VARCHAR(120) | ∅, **UK** parcial | |
| `foto_url` | VARCHAR(300) | ∅ | Se muestra en el sitio público |
| `biografia` | TEXT | ∅ | Reseña para el sitio público |
| `fecha_ingreso` | DATE | ∅ | |
| `activo` | BOOLEAN | NN, D `true` | |
| `creado_en` / `actualizado_en` | TIMESTAMPTZ | NN, D `now()` | |

## A6. `veterinario_especialidad` — **ASOCIATIVA (N:M)**
Resuelve: *un veterinario puede tener varias especialidades; una especialidad la
poseen varios veterinarios.*

| Atributo | Tipo | Restricción |
|----------|------|-------------|
| `veterinario_id` | INTEGER | **PK / FK** → `veterinario.id`, `ON DELETE CASCADE` |
| `especialidad_id` | SMALLINT | **PK / FK** → `especialidad.id`, `ON DELETE RESTRICT` |
| `es_principal` | BOOLEAN | NN, D `false` |
| `certificado_en` | DATE | ∅ |

**PK compuesta:** `(veterinario_id, especialidad_id)` — impide asignar dos veces la
misma especialidad al mismo profesional.

---

# BLOQUE B — Mascota y taxonomía

## B1. `especie`
Catálogo taxonómico de primer nivel (Canino, Felino, Ave, Roedor, Reptil, Equino…).

| Atributo | Tipo | Restricción | Descripción |
|----------|------|-------------|-------------|
| `id` | SMALLINT | **PK** | |
| `nombre` | VARCHAR(50) | **UK**, NN | |
| `nombre_cientifico` | VARCHAR(80) | ∅ | |
| `icono` | VARCHAR(20) | ∅ | Emoji/clave de ícono para la UI |
| `esperanza_vida_anios` | SMALLINT | ∅ | `CHECK > 0`. Útil para alertas geriátricas |
| `activo` | BOOLEAN | NN, D `true` | |

## B2. `raza`
Catálogo de segundo nivel, **dependiente de especie**.

| Atributo | Tipo | Restricción | Descripción |
|----------|------|-------------|-------------|
| `id` | INTEGER | **PK** | |
| `especie_id` | SMALLINT | **FK** → `especie.id`, NN | `ON DELETE RESTRICT` |
| `nombre` | VARCHAR(80) | NN | **UK** con `especie_id` |
| `tamanio` | VARCHAR(15) | ∅ | `CHECK ∈ {PEQUENO, MEDIANO, GRANDE, GIGANTE}` |
| `descripcion` | VARCHAR(250) | ∅ | |
| `activo` | BOOLEAN | NN, D `true` | |

**Restricciones adicionales:**
- `UNIQUE (especie_id, nombre)` — "Persa" puede existir en Felino y en otra especie.
- `UNIQUE (id, especie_id)` — clave alternativa técnica que habilita la FK compuesta
  desde `mascota` (ver B3).

## B3. `mascota` — **NÚCLEO DEL SISTEMA**

| Atributo | Tipo | Restricción | Descripción |
|----------|------|-------------|-------------|
| `id` | INTEGER | **PK** | |
| `cliente_id` | INTEGER | **FK** → `cliente.id`, NN | Tutor responsable. `ON DELETE RESTRICT` |
| `especie_id` | SMALLINT | **FK** → `especie.id`, NN | `ON DELETE RESTRICT` |
| `raza_id` | INTEGER | **FK** → `raza.id`, ∅ | Nulo = mestizo o desconocida |
| `nombre` | VARCHAR(60) | NN | |
| `sexo` | CHAR(1) | NN | `CHECK ∈ {M, H}` |
| `fecha_nacimiento` | DATE | ∅ | `CHECK <= CURRENT_DATE`. Nulo si se desconoce |
| `edad_aproximada_meses` | SMALLINT | ∅ | Alternativa cuando no se conoce la fecha exacta |
| `color` | VARCHAR(60) | ∅ | |
| `microchip` | VARCHAR(25) | **UK** parcial, ∅ | Único entre los no nulos |
| `esterilizado` | BOOLEAN | NN, D `false` | |
| `foto_url` | VARCHAR(300) | ∅ | |
| `observaciones` | TEXT | ∅ | |
| `fecha_fallecimiento` | DATE | ∅ | `CHECK >= fecha_nacimiento` |
| `activo` | BOOLEAN | NN, D `true` | **Baja lógica** — preserva el historial |
| `creado_en` / `actualizado_en` | TIMESTAMPTZ | NN, D `now()` | |

**Restricción de integridad clave — FK compuesta:**
```
FOREIGN KEY (raza_id, especie_id) REFERENCES raza (id, especie_id)
```
Impide el estado inconsistente *"mascota de especie Felino con raza Labrador"*. Una FK
simple a `raza.id` permitiría esa combinación absurda; la compuesta la hace imposible
a nivel de motor.

**Atributos derivados (NO almacenados):**

| Derivado | Cómo se obtiene |
|----------|-----------------|
| `edad` | `AGE(COALESCE(fecha_fallecimiento, CURRENT_DATE), fecha_nacimiento)` |
| `peso_actual` | Último `registro_peso` por `fecha_registro` (ver D1 en el análisis) |
| `estado_vacunacion` | Derivado de `aplicacion_vacuna.fecha_proximo_refuerzo` vs. hoy |

## B4. `condicion_medica`
Catálogo unificado de alergias, enfermedades crónicas y condiciones congénitas.

| Atributo | Tipo | Restricción | Descripción |
|----------|------|-------------|-------------|
| `id` | INTEGER | **PK** | |
| `nombre` | VARCHAR(100) | **UK**, NN | |
| `tipo` | VARCHAR(15) | NN | `CHECK ∈ {ALERGIA, CRONICA, CONGENITA, OTRA}` |
| `descripcion` | VARCHAR(300) | ∅ | |
| `activo` | BOOLEAN | NN, D `true` | |

## B5. `mascota_condicion` — **ASOCIATIVA (N:M)**
Resuelve: *una mascota puede tener varias condiciones; una condición afecta a varias mascotas.*

| Atributo | Tipo | Restricción | Descripción |
|----------|------|-------------|-------------|
| `mascota_id` | INTEGER | **PK / FK** → `mascota.id`, `ON DELETE RESTRICT` | |
| `condicion_medica_id` | INTEGER | **PK / FK** → `condicion_medica.id`, `ON DELETE RESTRICT` | |
| `severidad` | VARCHAR(10) | NN, D `'MEDIA'` | `CHECK ∈ {LEVE, MEDIA, GRAVE}` |
| `fecha_deteccion` | DATE | ∅ | `CHECK <= CURRENT_DATE` |
| `activa` | BOOLEAN | NN, D `true` | Una alergia puede remitir |
| `notas` | TEXT | ∅ | |

## B6. `registro_peso` — **ENTIDAD DÉBIL**
Serie temporal de peso. Existencialmente dependiente de `mascota`.

| Atributo | Tipo | Restricción | Descripción |
|----------|------|-------------|-------------|
| `id` | INTEGER | **PK** | |
| `mascota_id` | INTEGER | **FK** → `mascota.id`, NN | `ON DELETE RESTRICT` |
| `consulta_id` | INTEGER | **FK** → `consulta.id`, ∅ | Origen: nulo si se pesó fuera de consulta |
| `fecha_registro` | DATE | NN, D `CURRENT_DATE` | `CHECK <= CURRENT_DATE` |
| `peso_kg` | NUMERIC(6,2) | NN | **`CHECK > 0`** (regla R11) |
| `observacion` | VARCHAR(200) | ∅ | |
| `creado_en` | TIMESTAMPTZ | NN, D `now()` | |

**Restricción:** `UNIQUE (mascota_id, fecha_registro)` — un solo peso oficial por día.

---

# BLOQUE C — Agenda y atención clínica

## C1. `solicitud_cita`
Zona de cuarentena para pedidos del sitio público (ver D4 en el análisis).

| Atributo | Tipo | Restricción | Descripción |
|----------|------|-------------|-------------|
| `id` | INTEGER | **PK** | |
| `cita_id` | INTEGER | **FK** → `cita.id`, **UK**, ∅ | Se completa al convertirla |
| `especie_id` | SMALLINT | **FK** → `especie.id`, ∅ | Lo que declara el visitante |
| `nombre_contacto` | VARCHAR(120) | NN | |
| `telefono_contacto` | VARCHAR(25) | NN | |
| `email_contacto` | VARCHAR(120) | ∅ | |
| `nombre_mascota` | VARCHAR(60) | ∅ | Texto libre, **sin FK**: aún no es un registro |
| `motivo` | VARCHAR(300) | NN | |
| `fecha_preferida` | DATE | ∅ | `CHECK >= CURRENT_DATE` al insertar |
| `franja_preferida` | VARCHAR(10) | ∅ | `CHECK ∈ {MANANA, TARDE, INDIFERENTE}` |
| `estado` | VARCHAR(12) | NN, D `'nueva'` | `CHECK ∈ {nueva, contactada, convertida, descartada}` |
| `creado_en` | TIMESTAMPTZ | NN, D `now()` | |

## C2. `cita`
Turno agendado. Compromiso futuro entre mascota, veterinario y horario.

| Atributo | Tipo | Restricción | Descripción |
|----------|------|-------------|-------------|
| `id` | INTEGER | **PK** | |
| `mascota_id` | INTEGER | **FK** → `mascota.id`, NN | `ON DELETE RESTRICT` |
| `veterinario_id` | INTEGER | **FK** → `veterinario.id`, NN | `ON DELETE RESTRICT` |
| `servicio_id` | INTEGER | **FK** → `servicio.id`, ∅ | Servicio previsto |
| `usuario_registro_id` | INTEGER | **FK** → `usuario.id`, ∅ | Quién agendó. Trazabilidad |
| `fecha_hora_inicio` | TIMESTAMPTZ | NN | |
| `duracion_minutos` | SMALLINT | NN, D `30` | `CHECK BETWEEN 10 AND 480` |
| `motivo` | VARCHAR(300) | NN | |
| `estado` | VARCHAR(12) | NN, D `'programada'` | `CHECK ∈ {programada, confirmada, atendida, cancelada, no_asistio}` (R16) |
| `motivo_cancelacion` | VARCHAR(250) | ∅ | Obligatorio si `estado = 'cancelada'` |
| `notas` | TEXT | ∅ | |
| `creado_en` / `actualizado_en` | TIMESTAMPTZ | NN, D `now()` | |

**Restricciones destacadas:**
- `CHECK (estado <> 'cancelada' OR motivo_cancelacion IS NOT NULL)` — cancelar exige justificar.
- **`EXCLUDE USING gist`** sobre `(veterinario_id, tstzrange(inicio, inicio + duración))`
  filtrado a estados activos → **impide agendas solapadas** (regla R24) a nivel de motor.
  El tutor de la cita es **derivado** (`mascota → cliente`), no se duplica en `cita`.

## C3. `consulta`
Encuentro clínico efectivamente realizado. **Unidad central del historial.**

| Atributo | Tipo | Restricción | Descripción |
|----------|------|-------------|-------------|
| `id` | INTEGER | **PK** | |
| `mascota_id` | INTEGER | **FK** → `mascota.id`, NN | `ON DELETE RESTRICT` |
| `veterinario_id` | INTEGER | **FK** → `veterinario.id`, NN | `ON DELETE RESTRICT` |
| `cita_id` | INTEGER | **FK** → `cita.id`, **UK**, ∅ | **1:0..1** — nulo si fue sin turno |
| `fecha_hora` | TIMESTAMPTZ | NN, D `now()` | `CHECK <= now()` (R21) |
| `tipo` | VARCHAR(15) | NN, D `'GENERAL'` | `CHECK ∈ {GENERAL, CONTROL, URGENCIA, CIRUGIA, VACUNACION, ESTETICA}` |
| `motivo` | VARCHAR(300) | NN | Razón de la visita |
| `anamnesis` | TEXT | ∅ | Síntomas relatados por el tutor |
| `temperatura_c` | NUMERIC(4,1) | ∅ | `CHECK BETWEEN 30 AND 45` |
| `frecuencia_cardiaca` | SMALLINT | ∅ | `CHECK BETWEEN 20 AND 400` (lpm) |
| `frecuencia_respiratoria` | SMALLINT | ∅ | `CHECK BETWEEN 5 AND 200` (rpm) |
| `examen_fisico` | TEXT | ∅ | Hallazgos objetivos |
| `observaciones` | TEXT | ∅ | |
| `proxima_revision` | DATE | ∅ | `CHECK >= fecha_hora::date` |
| `creado_en` / `actualizado_en` | TIMESTAMPTZ | NN, D `now()` | |

> **El peso NO está aquí.** Va a `registro_peso` con `consulta_id` apuntando a esta
> consulta (decisión D1).
>
> **Coherencia mascota–cita:** un `CHECK` por trigger valida que
> `consulta.mascota_id = cita.mascota_id` cuando `cita_id` no es nulo.

## C4. `diagnostico`
Catálogo clínico normalizado de patologías.

| Atributo | Tipo | Restricción | Descripción |
|----------|------|-------------|-------------|
| `id` | INTEGER | **PK** | |
| `codigo` | VARCHAR(15) | **UK**, NN | Nomenclatura interna, ej. `GASTRO-001` |
| `nombre` | VARCHAR(120) | **UK**, NN | |
| `categoria` | VARCHAR(50) | ∅ | Digestivo, Dermatológico, Traumatológico… |
| `descripcion` | TEXT | ∅ | |
| `activo` | BOOLEAN | NN, D `true` | |

## C5. `consulta_diagnostico` — **ASOCIATIVA (N:M)**
Resuelve: *una consulta produce varios diagnósticos; un diagnóstico aparece en varias consultas.*

| Atributo | Tipo | Restricción | Descripción |
|----------|------|-------------|-------------|
| `consulta_id` | INTEGER | **PK / FK** → `consulta.id`, `ON DELETE CASCADE` | |
| `diagnostico_id` | INTEGER | **PK / FK** → `diagnostico.id`, `ON DELETE RESTRICT` | |
| `tipo` | VARCHAR(12) | NN, D `'PRESUNTIVO'` | `CHECK ∈ {PRESUNTIVO, DEFINITIVO, DESCARTADO}` |
| `es_principal` | BOOLEAN | NN, D `false` | |
| `notas` | TEXT | ∅ | |

**Restricción:** índice único parcial que garantiza **un solo diagnóstico principal por
consulta**: `UNIQUE (consulta_id) WHERE es_principal`.

## C6. `tratamiento` — **ENTIDAD DÉBIL**
Plan terapéutico indicado en una consulta.

| Atributo | Tipo | Restricción | Descripción |
|----------|------|-------------|-------------|
| `id` | INTEGER | **PK** | |
| `consulta_id` | INTEGER | **FK** → `consulta.id`, NN | `ON DELETE CASCADE` |
| `descripcion` | VARCHAR(300) | NN | |
| `indicaciones` | TEXT | ∅ | |
| `fecha_inicio` | DATE | NN, D `CURRENT_DATE` | |
| `fecha_fin_estimada` | DATE | ∅ | `CHECK >= fecha_inicio` |
| `estado` | VARCHAR(12) | NN, D `'activo'` | `CHECK ∈ {activo, completado, suspendido}` |

> **¿Por qué no es un catálogo N:M como `diagnostico`?** Un tratamiento no es un
> concepto reutilizable sino un **plan concreto con fechas y evolución propias**,
> irrepetible entre pacientes. Su existencia depende de la consulta que lo indicó.

---

# BLOQUE D — Prescripción y vacunación

## D1. `receta`
Documento de prescripción. **Relación 1:0..1 con `consulta`.**

| Atributo | Tipo | Restricción | Descripción |
|----------|------|-------------|-------------|
| `id` | INTEGER | **PK** | |
| `consulta_id` | INTEGER | **FK** → `consulta.id`, **UK**, NN | `UNIQUE` ⇒ 1:1. `ON DELETE CASCADE` |
| `folio` | VARCHAR(20) | **UK**, NN | Número de receta, generado por secuencia |
| `fecha_emision` | DATE | NN, D `CURRENT_DATE` | |
| `indicaciones_generales` | TEXT | ∅ | |
| `vigencia_dias` | SMALLINT | NN, D `30` | `CHECK > 0` |
| `creado_en` | TIMESTAMPTZ | NN, D `now()` | |

> **Sin `veterinario_id` ni `mascota_id`.** Ambos son **derivables** por
> `receta → consulta → {veterinario, mascota}`. Almacenarlos sería redundancia
> transitiva (violación de 3FN) y abriría la puerta a inconsistencias.

## D2. `medicamento`
Catálogo de fármacos.

| Atributo | Tipo | Restricción | Descripción |
|----------|------|-------------|-------------|
| `id` | INTEGER | **PK** | |
| `nombre` | VARCHAR(120) | NN | **UK** con `concentracion` |
| `principio_activo` | VARCHAR(120) | NN | |
| `presentacion` | VARCHAR(50) | NN | `CHECK ∈ {COMPRIMIDO, JARABE, INYECTABLE, CREMA, GOTAS, SPRAY, POLVO, OTRO}` |
| `concentracion` | VARCHAR(40) | ∅ | ej. `500 mg`, `10 mg/ml` |
| `laboratorio` | VARCHAR(100) | ∅ | |
| `descripcion` | TEXT | ∅ | |
| `requiere_receta` | BOOLEAN | NN, D `true` | |
| `stock_actual` | INTEGER | NN, D `0` | **`CHECK >= 0`** (R14) |
| `stock_minimo` | INTEGER | NN, D `5` | `CHECK >= 0`. Dispara alerta de reposición |
| `precio_venta` | NUMERIC(12,2) | NN, D `0` | **`CHECK >= 0`** (R13) |
| `activo` | BOOLEAN | NN, D `true` | |
| `creado_en` / `actualizado_en` | TIMESTAMPTZ | NN, D `now()` | |

## D3. `receta_detalle` — **ASOCIATIVA (N:M) CON ATRIBUTOS** ⭐
Resuelve la relación pedida explícitamente en los requisitos:
*una receta contiene varios medicamentos; un medicamento aparece en muchas recetas.*
Los atributos de la prescripción **pertenecen a la asociación**, no a ninguna de las
dos entidades: la dosis no es propiedad del medicamento ni de la receta, sino del hecho
de prescribir *ese* medicamento en *esa* receta.

| Atributo | Tipo | Restricción | Descripción |
|----------|------|-------------|-------------|
| `receta_id` | INTEGER | **PK / FK** → `receta.id`, `ON DELETE CASCADE` | |
| `medicamento_id` | INTEGER | **PK / FK** → `medicamento.id`, `ON DELETE RESTRICT` | |
| `dosis` | VARCHAR(60) | NN | ej. `1 comprimido`, `5 ml` |
| `frecuencia` | VARCHAR(60) | NN | ej. `cada 8 horas` |
| `duracion_dias` | SMALLINT | NN | **`CHECK > 0`** (R12) |
| `via_administracion` | VARCHAR(15) | NN, D `'ORAL'` | `CHECK ∈ {ORAL, TOPICA, INTRAMUSCULAR, SUBCUTANEA, INTRAVENOSA, OFTALMICA, OTICA, RECTAL}` |
| `cantidad` | NUMERIC(8,2) | NN, D `1` | **`CHECK > 0`**. Unidades a dispensar |
| `instrucciones` | VARCHAR(300) | ∅ | ej. "administrar con comida" |

**PK compuesta `(receta_id, medicamento_id)`:** impide prescribir dos veces el mismo
fármaco en la misma receta con pautas contradictorias — un riesgo clínico real de
sobredosis.

## D4. `vacuna`
Catálogo de biológicos.

| Atributo | Tipo | Restricción | Descripción |
|----------|------|-------------|-------------|
| `id` | INTEGER | **PK** | |
| `nombre` | VARCHAR(100) | **UK**, NN | ej. Quíntuple canina, Antirrábica |
| `laboratorio` | VARCHAR(100) | ∅ | |
| `enfermedades_previene` | VARCHAR(300) | ∅ | |
| `dosis_ml` | NUMERIC(5,2) | ∅ | `CHECK > 0` |
| `intervalo_refuerzo_meses` | SMALLINT | ∅ | `CHECK > 0`. Calcula el próximo refuerzo |
| `edad_minima_semanas` | SMALLINT | ∅ | `CHECK >= 0` |
| `precio` | NUMERIC(12,2) | NN, D `0` | `CHECK >= 0` |
| `activo` | BOOLEAN | NN, D `true` | |

## D5. `vacuna_especie` — **ASOCIATIVA (N:M)**
Resuelve: *una vacuna puede estar indicada para varias especies; una especie recibe
varias vacunas.*

| Atributo | Tipo | Restricción |
|----------|------|-------------|
| `vacuna_id` | INTEGER | **PK / FK** → `vacuna.id`, `ON DELETE CASCADE` |
| `especie_id` | SMALLINT | **PK / FK** → `especie.id`, `ON DELETE RESTRICT` |

> **Razón funcional:** evita el error clínico de ofrecer una vacuna canina para un
> felino. El formulario de aplicación filtra el catálogo por la especie de la mascota.

## D6. `aplicacion_vacuna` — **ASOCIATIVA (N:M) CON ATRIBUTOS** ⭐
Resuelve: *una mascota recibe muchas vacunas; una vacuna se aplica a muchas mascotas.*

| Atributo | Tipo | Restricción | Descripción |
|----------|------|-------------|-------------|
| `id` | INTEGER | **PK** | Surrogate (ver nota) |
| `mascota_id` | INTEGER | **FK** → `mascota.id`, NN | `ON DELETE RESTRICT` |
| `vacuna_id` | INTEGER | **FK** → `vacuna.id`, NN | `ON DELETE RESTRICT` |
| `veterinario_id` | INTEGER | **FK** → `veterinario.id`, NN | Responsable del acto médico |
| `consulta_id` | INTEGER | **FK** → `consulta.id`, ∅ | Si se aplicó dentro de una consulta |
| `fecha_aplicacion` | DATE | NN, D `CURRENT_DATE` | `CHECK <= CURRENT_DATE` |
| `fecha_proximo_refuerzo` | DATE | ∅ | **`CHECK >= fecha_aplicacion`** (R15) |
| `lote` | VARCHAR(40) | NN | Trazabilidad sanitaria obligatoria |
| `dosis_numero` | SMALLINT | NN, D `1` | `CHECK > 0`. 1ª, 2ª dosis, refuerzo |
| `via_administracion` | VARCHAR(15) | NN, D `'SUBCUTANEA'` | |
| `observaciones` | TEXT | ∅ | Reacciones adversas |
| `creado_en` | TIMESTAMPTZ | NN, D `now()` | |

> **¿Por qué PK surrogate y no compuesta?** La PK natural `(mascota_id, vacuna_id)`
> **no sirve**: una mascota recibe la misma vacuna repetidamente a lo largo de su vida
> (refuerzos anuales). Incluir la fecha daría `(mascota_id, vacuna_id, fecha_aplicacion)`,
> una PK de 3 columnas que se propagaría a cualquier tabla futura que la referencie.
> Se usa `id` surrogate + `UNIQUE (mascota_id, vacuna_id, fecha_aplicacion)` para
> preservar la regla de negocio sin arrastrar una clave ancha.

**Estado de vacunación derivado** (regla de presentación, no columna):

| Estado | Condición |
|--------|-----------|
| 🟢 Vigente | `fecha_proximo_refuerzo > CURRENT_DATE + 30 días` |
| 🟡 Próxima | `fecha_proximo_refuerzo BETWEEN hoy Y hoy + 30 días` |
| 🔴 Vencida | `fecha_proximo_refuerzo < CURRENT_DATE` |

---

# BLOQUE E — Comercial

## E1. `servicio`
Catálogo de prestaciones facturables (consulta general, cirugía, baño, desparasitación,
ecografía, eutanasia…).

| Atributo | Tipo | Restricción | Descripción |
|----------|------|-------------|-------------|
| `id` | INTEGER | **PK** | |
| `codigo` | VARCHAR(15) | **UK**, NN | |
| `nombre` | VARCHAR(120) | **UK**, NN | |
| `categoria` | VARCHAR(30) | NN | `CHECK ∈ {CONSULTA, CIRUGIA, DIAGNOSTICO, ESTETICA, VACUNACION, HOSPITALIZACION, OTRO}` |
| `descripcion` | TEXT | ∅ | |
| `precio_base` | NUMERIC(12,2) | NN | **`CHECK >= 0`** (R13) |
| `duracion_estimada_min` | SMALLINT | ∅ | `CHECK > 0`. Alimenta la agenda |
| `icono` | VARCHAR(20) | ∅ | Para el sitio público |
| `visible_publico` | BOOLEAN | NN, D `true` | Se muestra en la web institucional |
| `activo` | BOOLEAN | NN, D `true` | |

## E2. `factura`
Documento comercial emitido al **cliente** (no a la mascota: quien paga es el tutor).

| Atributo | Tipo | Restricción | Descripción |
|----------|------|-------------|-------------|
| `id` | INTEGER | **PK** | |
| `cliente_id` | INTEGER | **FK** → `cliente.id`, NN | `ON DELETE RESTRICT` |
| `usuario_emisor_id` | INTEGER | **FK** → `usuario.id`, ∅ | Trazabilidad de quién facturó |
| `numero` | VARCHAR(20) | **UK**, NN | Generado por `SEQUENCE`, formato `F-000001` |
| `fecha_emision` | DATE | NN, D `CURRENT_DATE` | |
| `subtotal` | NUMERIC(12,2) | NN, D `0` | `CHECK >= 0`. **Derivado, mantenido por trigger** |
| `descuento` | NUMERIC(12,2) | NN, D `0` | `CHECK >= 0` y `CHECK <= subtotal` (R22) |
| `porcentaje_impuesto` | NUMERIC(5,2) | NN, D `0` | `CHECK BETWEEN 0 AND 100` |
| `impuesto` | NUMERIC(12,2) | NN, D `0` | `CHECK >= 0`. Derivado |
| `total` | NUMERIC(12,2) | NN, D `0` | `CHECK >= 0`. Derivado (R23) |
| `estado` | VARCHAR(10) | NN, D `'pendiente'` | `CHECK ∈ {pendiente, pagada, anulada}` (R17) |
| `metodo_pago` | VARCHAR(15) | ∅ | `CHECK ∈ {EFECTIVO, TARJETA, TRANSFERENCIA, OTRO}` |
| `fecha_pago` | DATE | ∅ | Obligatoria si `estado = 'pagada'` |
| `observaciones` | TEXT | ∅ | |
| `creado_en` / `actualizado_en` | TIMESTAMPTZ | NN, D `now()` | |

**Restricciones destacadas:**
- `CHECK (estado <> 'pagada' OR fecha_pago IS NOT NULL)` — una factura pagada tiene fecha de pago.
- `CHECK (total = subtotal - descuento + impuesto)` — coherencia aritmética verificada por el motor.

## E3. `factura_detalle` — **ASOCIATIVA CON ARCO EXCLUSIVO** ⭐
Cada línea factura **un servicio o un medicamento**, nunca ambos ni ninguno.

| Atributo | Tipo | Restricción | Descripción |
|----------|------|-------------|-------------|
| `id` | INTEGER | **PK** | |
| `factura_id` | INTEGER | **FK** → `factura.id`, NN | `ON DELETE CASCADE` |
| `servicio_id` | INTEGER | **FK** → `servicio.id`, ∅ | `ON DELETE RESTRICT` |
| `medicamento_id` | INTEGER | **FK** → `medicamento.id`, ∅ | `ON DELETE RESTRICT` |
| `mascota_id` | INTEGER | **FK** → `mascota.id`, ∅ | A qué mascota corresponde el ítem |
| `consulta_id` | INTEGER | **FK** → `consulta.id`, ∅ | Vincula la factura al acto clínico |
| `linea_nro` | SMALLINT | NN | **UK** con `factura_id`. `CHECK > 0` |
| `tipo_item` | VARCHAR(12) | NN | `CHECK ∈ {SERVICIO, MEDICAMENTO, OTRO}` |
| `descripcion` | VARCHAR(200) | NN | **Snapshot** del nombre al momento de la venta |
| `cantidad` | NUMERIC(8,2) | NN | **`CHECK > 0`** (R12) |
| `precio_unitario` | NUMERIC(12,2) | NN | **`CHECK >= 0`** (R13). Congelado |
| `descuento_linea` | NUMERIC(12,2) | NN, D `0` | `CHECK >= 0` |
| `subtotal` | NUMERIC(12,2) | **GENERATED ALWAYS** | `cantidad * precio_unitario - descuento_linea` (R19) |

**El arco exclusivo, expresado como `CHECK`:**
```sql
CHECK (
  (tipo_item = 'SERVICIO'    AND servicio_id IS NOT NULL AND medicamento_id IS NULL) OR
  (tipo_item = 'MEDICAMENTO' AND medicamento_id IS NOT NULL AND servicio_id IS NULL) OR
  (tipo_item = 'OTRO'        AND servicio_id IS NULL AND medicamento_id IS NULL)
)
```

> **`subtotal` como columna generada:** PostgreSQL calcula y almacena el valor
> automáticamente; es **imposible** insertar un subtotal incoherente. La regla R19 deja
> de depender del código de aplicación. `descripcion` y `precio_unitario` se guardan
> como *snapshot*: si mañana el catálogo cambia de nombre o de precio, la factura
> histórica conserva lo que realmente se vendió.

---

# Matriz completa de relaciones

## Relaciones 1:1 (opcionales)

| # | Entidad A | Relación | Entidad B | Cardinalidad | Implementación |
|---|-----------|----------|-----------|--------------|----------------|
| 1 | `usuario` | *accede como* | `veterinario` | (0,1) : (0,1) | `veterinario.usuario_id` **UNIQUE**, NULL |
| 2 | `cita` | *se concreta en* | `consulta` | (0,1) : (0,1) | `consulta.cita_id` **UNIQUE**, NULL |
| 3 | `consulta` | *genera* | `receta` | (1,1) : (0,1) | `receta.consulta_id` **UNIQUE**, NOT NULL |

## Relaciones 1:N

| # | Lado 1 | Relación | Lado N | Cardinalidad |
|---|--------|----------|--------|--------------|
| 4 | `rol` | *clasifica a* | `usuario` | (1,1) : (0,N) |
| 5 | `cliente` | *es tutor de* | `mascota` | (1,1) : (0,N) |
| 6 | `especie` | *agrupa* | `raza` | (1,1) : (0,N) |
| 7 | `especie` | *clasifica a* | `mascota` | (1,1) : (0,N) |
| 8 | `raza` | *clasifica a* | `mascota` | (0,1) : (0,N) |
| 9 | `mascota` | *tiene* | `registro_peso` | (1,1) : (0,N) |
| 10 | `mascota` | *tiene* | `cita` | (1,1) : (0,N) |
| 11 | `mascota` | *tiene* | `consulta` | (1,1) : (0,N) |
| 12 | `veterinario` | *atiende* | `cita` | (1,1) : (0,N) |
| 13 | `veterinario` | *realiza* | `consulta` | (1,1) : (0,N) |
| 14 | `veterinario` | *aplica* | `aplicacion_vacuna` | (1,1) : (0,N) |
| 15 | `consulta` | *indica* | `tratamiento` | (1,1) : (0,N) |
| 16 | `consulta` | *origina* | `registro_peso` | (0,1) : (0,N) |
| 17 | `consulta` | *incluye* | `aplicacion_vacuna` | (0,1) : (0,N) |
| 18 | `receta` | *contiene* | `receta_detalle` | (1,1) : (1,N) |
| 19 | `cliente` | *recibe* | `factura` | (1,1) : (0,N) |
| 20 | `factura` | *se compone de* | `factura_detalle` | (1,1) : (1,N) |
| 21 | `servicio` | *se factura en* | `factura_detalle` | (0,1) : (0,N) |
| 22 | `medicamento` | *se factura en* | `factura_detalle` | (0,1) : (0,N) |
| 23 | `servicio` | *se reserva en* | `cita` | (0,1) : (0,N) |
| 24 | `usuario` | *registra* | `cita` | (0,1) : (0,N) |
| 25 | `usuario` | *emite* | `factura` | (0,1) : (0,N) |
| 26 | `cita` | *proviene de* | `solicitud_cita` | (0,1) : (0,1) |
| 27 | `mascota` | *se factura en* | `factura_detalle` | (0,1) : (0,N) |

## Relaciones N:M y su entidad asociativa

| # | Entidad A | ↔ | Entidad B | Entidad asociativa | Atributos propios de la asociación |
|---|-----------|---|-----------|--------------------|------------------------------------|
| 28 | `veterinario` | ↔ | `especialidad` | `veterinario_especialidad` | `es_principal`, `certificado_en` |
| 29 | `mascota` | ↔ | `condicion_medica` | `mascota_condicion` | `severidad`, `fecha_deteccion`, `activa`, `notas` |
| 30 | `consulta` | ↔ | `diagnostico` | `consulta_diagnostico` | `tipo`, `es_principal`, `notas` |
| 31 | `receta` | ↔ | `medicamento` | **`receta_detalle`** | `dosis`, `frecuencia`, `duracion_dias`, `via_administracion`, `cantidad`, `instrucciones` |
| 32 | `mascota` | ↔ | `vacuna` | **`aplicacion_vacuna`** | `fecha_aplicacion`, `fecha_proximo_refuerzo`, `lote`, `dosis_numero`, `via`, `observaciones` |
| 33 | `vacuna` | ↔ | `especie` | `vacuna_especie` | — (asociación pura) |
| 34 | `factura` | ↔ | `servicio` / `medicamento` | **`factura_detalle`** | `cantidad`, `precio_unitario`, `descuento_linea`, `subtotal` |

---

# Trazabilidad: requisito → modelo

Verificación de que **cada** relación pedida en el enunciado está cubierta.

| Requisito del enunciado (§6) | Resuelto por |
|------------------------------|--------------|
| Un CLIENTE puede tener múltiples MASCOTAS | Rel. 5 — `mascota.cliente_id` |
| Una MASCOTA pertenece a un CLIENTE | Rel. 5 — FK `NOT NULL` |
| Una ESPECIE puede tener múltiples RAZAS | Rel. 6 — `raza.especie_id` |
| Una RAZA pertenece a una ESPECIE | Rel. 6 — FK `NOT NULL` |
| Una MASCOTA puede tener múltiples CONSULTAS | Rel. 11 |
| Una CONSULTA pertenece a una MASCOTA | Rel. 11 — FK `NOT NULL` |
| Una CONSULTA es realizada por un VETERINARIO | Rel. 13 |
| Un VETERINARIO realiza múltiples CONSULTAS | Rel. 13 |
| Una CONSULTA puede producir varios DIAGNÓSTICOS | Rel. 30 — N:M `consulta_diagnostico` |
| Una CONSULTA puede tener varios TRATAMIENTOS | Rel. 15 |
| Una CONSULTA puede generar una RECETA | Rel. 3 — 1:0..1 con `UNIQUE` |
| Una RECETA contiene múltiples MEDICAMENTOS | Rel. 31 |
| Un MEDICAMENTO aparece en múltiples RECETAS | Rel. 31 |
| RECETA↔MEDICAMENTO con dosis, frecuencia, duración, vía, instrucciones | **`receta_detalle`** — los 5 atributos presentes |
| Una MASCOTA recibe múltiples VACUNAS | Rel. 32 |
| Una VACUNA se aplica a múltiples MASCOTAS | Rel. 32 |
| La aplicación guarda información propia | **`aplicacion_vacuna`** — fecha, refuerzo, lote, dosis, observaciones |
| Una MASCOTA puede tener múltiples CITAS | Rel. 10 |
| Un VETERINARIO puede tener múltiples CITAS | Rel. 12 |
| Un CLIENTE puede tener múltiples FACTURAS | Rel. 19 |
| Una FACTURA tiene múltiples DETALLES | Rel. 20 |
| El detalle registra cantidad, precio unitario, subtotal | **`factura_detalle`** — `subtotal` es columna **generada** |
| Los SERVICIOS participan en la facturación | Rel. 21 + arco exclusivo |

**Cobertura: 23/23 requisitos relacionales.** ✅

---

Siguiente documento: [`03-revision-mer.md`](03-revision-mer.md) — revisión crítica y
verificación de formas normales.
