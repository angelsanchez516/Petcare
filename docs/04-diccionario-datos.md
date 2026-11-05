# Diccionario de datos — tipos y justificación técnica

Este documento cubre el requisito de la entrega: *"cada atributo deberá tener definido
un tipo de dato apropiado, acompañado de una breve justificación técnica que explique
por qué dicho tipo de dato es adecuado"*.

Se organiza en dos partes:

1. **Criterios de tipificación** — las 12 decisiones de tipo que se aplican
   transversalmente. Justificarlas una vez evita repetir el mismo argumento 200 veces.
2. **Diccionario por entidad** — cada atributo con su tipo y la razón concreta.

---

# Parte 1 — Criterios de tipificación

## C1. Claves primarias: `INTEGER GENERATED ALWAYS AS IDENTITY`

```sql
id INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY
```

**Por qué `INTEGER` (4 bytes):** rango de ±2.147.483.647. Una clínica veterinaria que
registre 1.000 consultas diarias tardaría 5.800 años en agotarlo. `BIGINT` (8 bytes)
duplicaría el espacio de cada clave y de **cada foránea que la referencia** sin ningún
beneficio.

**Por qué `GENERATED ALWAYS AS IDENTITY` y no `SERIAL`:** `IDENTITY` es el estándar
SQL:2003; `SERIAL` es una extensión propietaria de PostgreSQL. Además `ALWAYS` **prohíbe
insertar un valor manualmente**, lo que impide desincronizar la secuencia — el error
clásico de `SERIAL` cuando alguien inserta un `id` explícito y las siguientes inserciones
automáticas fallan por colisión.

## C2. Claves de catálogo: `SMALLINT`

Se aplica a `rol`, `especie`, `especialidad`.

**Por qué:** `SMALLINT` son 2 bytes con rango ±32.767. Estos catálogos tendrán decenas
de filas, nunca miles. El ahorro no está en la tabla catálogo —que es diminuta— sino en
**cada fila que la referencia**: `mascota.especie_id` se repite en cada mascota, y
`usuario.rol_id` en cada usuario. Es una decisión que escala con la tabla grande, no con
la chica.

## C3. Dinero: `NUMERIC(12,2)` — nunca `FLOAT` ni `REAL`

**Por qué NO punto flotante:** `FLOAT` almacena en base 2 y no puede representar
exactamente valores decimales como 0,10. La comprobación

```sql
SELECT 0.1::float8 + 0.2::float8 = 0.3::float8;  -- false
```

devuelve **falso**. En una factura, sumar 300 líneas con este error produce descuadres de
centavos que hacen que `total ≠ SUM(subtotal)` y que el `CHECK` de coherencia falle sin
motivo aparente. Para dinero esto es inaceptable.

**Por qué `NUMERIC`:** aritmética decimal exacta, sin error de redondeo binario.

**Por qué `(12,2)`:** 10 dígitos enteros y 2 decimales — hasta 9.999.999.999,99. Cubre
cualquier moneda, incluidas las de alta denominación, sin desperdicio.

## C4. Peso: `NUMERIC(6,2)`

**Por qué exacto y no flotante:** el peso alimenta el cálculo de dosis. Un error de
redondeo en la dosis de un fármaco es un riesgo clínico real, no un detalle contable.

**Por qué `(6,2)`:** hasta 9.999,99 kg con precisión de 10 gramos. Cubre desde un hámster
de 0,03 kg hasta un equino de 800 kg. La precisión de centésimas es la de una balanza
veterinaria pediátrica.

## C5. `DATE` vs `TIMESTAMPTZ` — la distinción no es cosmética

| Se usa `DATE` cuando… | Se usa `TIMESTAMPTZ` cuando… |
|---|---|
| El dato es un **día del calendario** y la hora no tiene significado | El dato es un **instante** en el tiempo |
| `fecha_aplicacion` de una vacuna, `fecha_nacimiento`, `fecha_emision` | `fecha_hora_inicio` de una cita, `creado_en` |
| 4 bytes | 8 bytes |

Registrar que una vacuna se aplicó "el 20/07/2026 a las 14:32:07" almacena una precisión
que nadie va a consultar y complica las comparaciones: `fecha_aplicacion = '2026-07-20'`
fallaría contra un `TIMESTAMP`, obligando a rangos o a `::date` en cada consulta —
lo que además **inutiliza el índice**.

## C6. `TIMESTAMPTZ` y no `TIMESTAMP`

`TIMESTAMP` (sin zona) guarda una lectura de reloj sin referencia absoluta: no se sabe a
qué instante corresponde. `TIMESTAMPTZ` normaliza a UTC internamente y convierte a la
zona del cliente al leer.

**El caso concreto:** una cita agendada a las 09:00 antes de un cambio de horario de
verano. Con `TIMESTAMP`, tras el cambio la cita sigue diciendo 09:00 pero corresponde a
otro instante real. Con `TIMESTAMPTZ`, el instante se preserva. Para una **agenda**, que
es el corazón de este sistema, la diferencia es funcional.

## C7. `VARCHAR(n)` con longitud deliberada, no `TEXT` por defecto

En PostgreSQL `VARCHAR(n)` y `TEXT` tienen **idéntico rendimiento y almacenamiento** —
la diferencia no es técnica sino **semántica**: el `n` documenta y hace cumplir una regla
de negocio.

- `telefono VARCHAR(25)` declara que un teléfono con prefijo internacional entra en 25
  caracteres. Un valor de 300 caracteres es un error de carga y el motor lo rechaza.
- `documento VARCHAR(20)` acota un número de documento.

Se usa `TEXT` **solo** para narrativa clínica sin longitud previsible: `anamnesis`,
`examen_fisico`, `observaciones`. Acotar arbitrariamente el relato de un veterinario a
500 caracteres sería una restricción inventada.

## C8. Enumerados: `VARCHAR(n)` + `CHECK`, no `CREATE TYPE ... AS ENUM`

Un `CHECK` es igual de estricto que un `ENUM` para la integridad, pero:

| | `ENUM` | `VARCHAR + CHECK` |
|---|---|---|
| Agregar un valor | `ALTER TYPE`, no transaccional en versiones antiguas | `ALTER TABLE ... DROP/ADD CONSTRAINT` |
| Quitar un valor | **Imposible** | Trivial |
| Ordenamiento | Fijo por orden de declaración | Alfabético o el que se defina |
| Portabilidad | Sintaxis propietaria | Estándar SQL |

Los estados de cita y factura son conjuntos cerrados pero **revisables**: si mañana la
clínica agrega el estado `reprogramada`, con `CHECK` es una línea.

## C9. `BOOLEAN` y no `CHAR(1)` ni `SMALLINT` como bandera

`BOOLEAN` ocupa 1 byte y admite exactamente tres estados: `true`, `false`, `NULL`. Un
`CHAR(1)` usado como bandera admite `'S'`, `'N'`, `'s'`, `'X'`, `' '` — estados inválidos
que habría que impedir con un `CHECK` adicional. El tipo correcto elimina el problema en
lugar de restringirlo.

## C10. `SMALLINT` para magnitudes acotadas por la biología o el negocio

`frecuencia_cardiaca`, `duracion_dias`, `dosis_numero`, `duracion_minutos`,
`intervalo_refuerzo_meses`, `edad_minima_semanas`.

Ninguna de estas magnitudes puede acercarse a 32.767: no existe un animal con 40.000
pulsaciones por minuto ni un tratamiento de 90 años. `INTEGER` duplicaría el espacio para
representar valores imposibles. El tipo también **documenta el rango esperado**, y se
acompaña de un `CHECK` que acota el rango biológico real.

## C11. `NUMERIC(4,1)` para temperatura

Tres dígitos enteros y una décima: de 0,0 a 999,9. El rango real (37–39 °C en caninos)
está muy dentro, y la décima es la precisión de un termómetro clínico. `NUMERIC(3,1)`
sería suficiente (hasta 99,9) pero deja cero margen; `REAL` reintroduciría el error de
punto flotante en un valor que se compara contra umbrales de fiebre.

## C12. `CHAR(1)` para `sexo`

Único caso de `CHAR` de longitud fija en el modelo, y se justifica porque el dominio son
exactamente dos valores de un carácter (`M`, `H`) fijados por un `CHECK`. `CHAR(1)` no
guarda el prefijo de longitud que `VARCHAR` necesita. Para cualquier otro campo, la
longitud fija rellenaría con espacios y sería un error.

---

# Parte 2 — Diccionario por entidad

Notación: `NN` no nulo · `∅` admite nulo · `PK` primaria · `FK` foránea · `UK` única

## Bloque A — Seguridad y personas

### `rol`
| Atributo | Tipo | Nulo | Justificación técnica |
|---|---|---|---|
| `id` | SMALLINT PK | NN | Catálogo de 3 filas; ver C2 |
| `codigo` | VARCHAR(20) UK | NN | Identificador estable para el código de autorización; 20 caracteres cubren cualquier nombre de rol |
| `nombre` | VARCHAR(50) | NN | Etiqueta visible en la interfaz |
| `descripcion` | VARCHAR(200) | ∅ | Texto de una línea; acotado porque se muestra en una celda de tabla |

### `usuario`
| Atributo | Tipo | Nulo | Justificación técnica |
|---|---|---|---|
| `id` | INTEGER PK | NN | Ver C1 |
| `rol_id` | SMALLINT FK | NN | Coincide con el tipo de `rol.id`: una FK **debe** tipar igual que su referencia o el motor no puede usar el índice |
| `nombre_usuario` | VARCHAR(50) UK | NN | Longitud usual de un login |
| `email` | VARCHAR(120) UK | NN | 120 cubre el máximo práctico de una dirección real (el RFC permite 320, inalcanzable en la práctica) |
| `password_hash` | VARCHAR(255) | NN | 255 aloja cualquier hash moderno con su prefijo de algoritmo y salt: bcrypt usa 60, argon2id ~100. **Nunca almacena la contraseña** |
| `nombre_completo` | VARCHAR(120) | NN | Nombre y apellidos concatenados |
| `telefono` | VARCHAR(25) | ∅ | Ver C7. `VARCHAR` y no numérico: un teléfono no es una cantidad — admite `+`, espacios y ceros a la izquierda que un entero destruiría |
| `avatar_url` | VARCHAR(300) | ∅ | Ruta o URL de imagen |
| `activo` | BOOLEAN | NN | Ver C9. Baja lógica |
| `ultimo_acceso_en` | TIMESTAMPTZ | ∅ | Instante exacto; nulo hasta el primer ingreso. Ver C6 |
| `creado_en` | TIMESTAMPTZ | NN | Ver C6 |
| `actualizado_en` | TIMESTAMPTZ | NN | Mantenido por trigger |

### `cliente`
| Atributo | Tipo | Nulo | Justificación técnica |
|---|---|---|---|
| `id` | INTEGER PK | NN | Ver C1 |
| `tipo_documento` | VARCHAR(10) | NN | Enumerado con `CHECK`; ver C8 |
| `documento` | VARCHAR(20) UK | NN | **`VARCHAR` y no `INTEGER`**: hay documentos con letras (NIE, pasaportes) y con ceros iniciales que un entero eliminaría. Además nunca se opera aritméticamente con él |
| `nombres` | VARCHAR(80) | NN | Admite nombres compuestos |
| `apellidos` | VARCHAR(80) | NN | Ídem |
| `telefono` | VARCHAR(25) | NN | Canal principal; obligatorio para avisar de una urgencia |
| `telefono_alternativo` | VARCHAR(25) | ∅ | Contacto de emergencia |
| `email` | VARCHAR(120) UK | ∅ | Único **entre los no nulos** mediante índice parcial: muchos clientes pueden no tener correo, y varios `NULL` no colisionan |
| `direccion` | VARCHAR(200) | ∅ | Dirección completa en una línea |
| `ciudad` | VARCHAR(80) | ∅ | |
| `fecha_nacimiento` | DATE | ∅ | Día calendario; ver C5 |
| `notas` | TEXT | ∅ | Observaciones de recepción sin longitud previsible; ver C7 |
| `activo` | BOOLEAN | NN | Ver C9 |
| `creado_en` / `actualizado_en` | TIMESTAMPTZ | NN | Ver C6 |

### `especialidad`
| Atributo | Tipo | Nulo | Justificación técnica |
|---|---|---|---|
| `id` | SMALLINT PK | NN | Catálogo pequeño; ver C2 |
| `nombre` | VARCHAR(80) | NN UK | "Medicina interna de pequeños animales" entra holgado |
| `descripcion` | VARCHAR(250) | ∅ | |
| `activo` | BOOLEAN | NN | Ver C9 |

### `veterinario`
| Atributo | Tipo | Nulo | Justificación técnica |
|---|---|---|---|
| `id` | INTEGER PK | NN | Ver C1 |
| `usuario_id` | INTEGER FK UK | ∅ | Nulo porque hay profesionales sin acceso al sistema; `UNIQUE` es lo que convierte la relación en 1:1 |
| `tipo_documento` | VARCHAR(10) | NN | Ver C8 |
| `documento` | VARCHAR(20) | NN UK | Ver justificación en `cliente.documento` |
| `matricula` | VARCHAR(30) | NN UK | **`VARCHAR`**: las matrículas profesionales combinan letras, números y guiones según la jurisdicción |
| `nombres` / `apellidos` | VARCHAR(80) | NN | |
| `telefono` | VARCHAR(25) | ∅ | |
| `email` | VARCHAR(120) UK | ∅ | Índice parcial; ver `cliente.email` |
| `foto_url` | VARCHAR(300) | ∅ | Se publica en el sitio institucional |
| `biografia` | TEXT | ∅ | Reseña de longitud libre; ver C7 |
| `fecha_ingreso` | DATE | ∅ | Día calendario; ver C5 |
| `activo` | BOOLEAN | NN | Ver C9 |

### `veterinario_especialidad`
| Atributo | Tipo | Nulo | Justificación técnica |
|---|---|---|---|
| `veterinario_id` | INTEGER PK FK | NN | Tipa igual que `veterinario.id` |
| `especialidad_id` | SMALLINT PK FK | NN | Tipa igual que `especialidad.id`; ver C2 |
| `es_principal` | BOOLEAN | NN | Ver C9 |
| `certificado_en` | DATE | ∅ | Día calendario de la certificación; ver C5 |

## Bloque B — Mascota y taxonomía

### `especie`
| Atributo | Tipo | Nulo | Justificación técnica |
|---|---|---|---|
| `id` | SMALLINT PK | NN | Ver C2 |
| `nombre` | VARCHAR(50) | NN UK | |
| `nombre_cientifico` | VARCHAR(80) | ∅ | Nomenclatura binomial |
| `icono` | VARCHAR(20) | ∅ | Un emoji ocupa hasta 4 bytes y puede combinarse con modificadores; 20 da margen |
| `esperanza_vida_anios` | SMALLINT | ∅ | Magnitud acotada (una tortuga llega a ~150); ver C10 |
| `activo` | BOOLEAN | NN | Ver C9 |

### `raza`
| Atributo | Tipo | Nulo | Justificación técnica |
|---|---|---|---|
| `id` | INTEGER PK | NN | `INTEGER` y no `SMALLINT`: solo entre perros y gatos hay ~800 razas reconocidas, y el catálogo puede crecer con variantes locales |
| `especie_id` | SMALLINT FK | NN | Tipa igual que `especie.id` |
| `nombre` | VARCHAR(80) | NN | UK compuesta con `especie_id` |
| `tamanio` | VARCHAR(15) | ∅ | Enumerado con `CHECK`; ver C8 |
| `descripcion` | VARCHAR(250) | ∅ | |
| `activo` | BOOLEAN | NN | Ver C9 |

### `mascota`
| Atributo | Tipo | Nulo | Justificación técnica |
|---|---|---|---|
| `id` | INTEGER PK | NN | Ver C1 |
| `cliente_id` | INTEGER FK | NN | Tipa igual que `cliente.id` |
| `especie_id` | SMALLINT FK | NN | Parte de la FK compuesta hacia `raza` |
| `raza_id` | INTEGER FK | ∅ | Nulo para mestizos o raza desconocida |
| `nombre` | VARCHAR(60) | NN | |
| `sexo` | CHAR(1) | NN | Ver C12 |
| `fecha_nacimiento` | DATE | ∅ | Día calendario; la hora de nacimiento no tiene uso clínico. Nulo cuando se desconoce |
| `edad_aproximada_meses` | SMALLINT | ∅ | Alternativa cuando no hay fecha exacta. En meses y no en años: la precisión importa en cachorros. Ver C10 |
| `color` | VARCHAR(60) | ∅ | Descripción libre corta ("atigrado con pecho blanco") |
| `microchip` | VARCHAR(25) | ∅ UK | **`VARCHAR` y no `BIGINT`**: el estándar ISO 11784 son 15 dígitos, que **excede** el rango de `INTEGER` y además puede llevar ceros iniciales significativos. Índice único parcial |
| `esterilizado` | BOOLEAN | NN | Ver C9 |
| `foto_url` | VARCHAR(300) | ∅ | |
| `observaciones` | TEXT | ∅ | Ver C7 |
| `fecha_fallecimiento` | DATE | ∅ | Nulo mientras vive; su presencia marca el cierre del expediente |
| `activo` | BOOLEAN | NN | Baja lógica que protege el historial |

### `condicion_medica`
| Atributo | Tipo | Nulo | Justificación técnica |
|---|---|---|---|
| `id` | INTEGER PK | NN | Ver C1 |
| `nombre` | VARCHAR(100) | NN UK | Nombres clínicos largos |
| `tipo` | VARCHAR(15) | NN | Enumerado con `CHECK`; ver C8 |
| `descripcion` | VARCHAR(300) | ∅ | |
| `activo` | BOOLEAN | NN | Ver C9 |

### `mascota_condicion`
| Atributo | Tipo | Nulo | Justificación técnica |
|---|---|---|---|
| `mascota_id` | INTEGER PK FK | NN | |
| `condicion_medica_id` | INTEGER PK FK | NN | |
| `severidad` | VARCHAR(10) | NN | Enumerado con `CHECK`; ver C8 |
| `fecha_deteccion` | DATE | ∅ | Día calendario; ver C5 |
| `activa` | BOOLEAN | NN | Una alergia puede remitir |
| `notas` | TEXT | ∅ | Ver C7 |

### `registro_peso`
| Atributo | Tipo | Nulo | Justificación técnica |
|---|---|---|---|
| `id` | INTEGER PK | NN | Ver C1 |
| `mascota_id` | INTEGER FK | NN | |
| `consulta_id` | INTEGER FK | ∅ | Nulo cuando el peso se tomó fuera de una consulta |
| `fecha_registro` | DATE | NN | Día calendario. La `UNIQUE (mascota_id, fecha_registro)` solo funciona con `DATE`: con `TIMESTAMP` cada pesaje tendría hora distinta y la restricción nunca se aplicaría |
| `peso_kg` | NUMERIC(6,2) | NN | Ver C4 |
| `observacion` | VARCHAR(200) | ∅ | |

## Bloque C — Agenda y atención clínica

### `solicitud_cita`
| Atributo | Tipo | Nulo | Justificación técnica |
|---|---|---|---|
| `id` | INTEGER PK | NN | Ver C1 |
| `cita_id` | INTEGER FK UK | ∅ | Nulo hasta que recepción la convierte |
| `especie_id` | SMALLINT FK | ∅ | Lo que declara el visitante, sin verificar |
| `nombre_contacto` | VARCHAR(120) | NN | |
| `telefono_contacto` | VARCHAR(25) | NN | |
| `email_contacto` | VARCHAR(120) | ∅ | Sin `UNIQUE`: es dato no verificado, no un maestro |
| `nombre_mascota` | VARCHAR(60) | ∅ | **Texto libre sin FK**: la mascota todavía no existe en el sistema |
| `motivo` | VARCHAR(300) | NN | |
| `fecha_preferida` | DATE | ∅ | Preferencia de día, no un compromiso horario |
| `franja_preferida` | VARCHAR(10) | ∅ | Enumerado con `CHECK`; ver C8 |
| `estado` | VARCHAR(12) | NN | Enumerado con `CHECK`; ver C8 |

### `cita`
| Atributo | Tipo | Nulo | Justificación técnica |
|---|---|---|---|
| `id` | INTEGER PK | NN | Ver C1 |
| `mascota_id` | INTEGER FK | NN | |
| `veterinario_id` | INTEGER FK | NN | |
| `servicio_id` | INTEGER FK | ∅ | Servicio previsto, puede no definirse al agendar |
| `usuario_registro_id` | INTEGER FK | ∅ | Trazabilidad de quién agendó |
| `fecha_hora_inicio` | TIMESTAMPTZ | NN | **Instante**, no día. Es el único tipo que permite la restricción de no solapamiento y sobrevive a los cambios de horario de verano; ver C6 |
| `duracion_minutos` | SMALLINT | NN | Acotado con `CHECK BETWEEN 10 AND 480`; ver C10. **Duración y no hora de fin**: derivar el fin de inicio+duración impide que ambos se contradigan |
| `motivo` | VARCHAR(300) | NN | |
| `estado` | VARCHAR(12) | NN | Enumerado con `CHECK`; ver C8 |
| `motivo_cancelacion` | VARCHAR(250) | ∅ | Obligatorio por `CHECK` solo si el estado es `cancelada` |
| `notas` | TEXT | ∅ | Ver C7 |

### `consulta`
| Atributo | Tipo | Nulo | Justificación técnica |
|---|---|---|---|
| `id` | INTEGER PK | NN | Ver C1 |
| `mascota_id` | INTEGER FK | NN | |
| `veterinario_id` | INTEGER FK | NN | |
| `cita_id` | INTEGER FK UK | ∅ | Nulo en urgencias sin turno; `UNIQUE` fuerza la 1:1 |
| `fecha_hora` | TIMESTAMPTZ | NN | Instante del acto médico; ordena el historial cronológico. Ver C6 |
| `tipo` | VARCHAR(15) | NN | Enumerado con `CHECK`; ver C8 |
| `motivo` | VARCHAR(300) | NN | |
| `anamnesis` | TEXT | ∅ | Relato del tutor, longitud imprevisible; ver C7 |
| `temperatura_c` | NUMERIC(4,1) | ∅ | Ver C11 |
| `frecuencia_cardiaca` | SMALLINT | ∅ | Acotada biológicamente con `CHECK BETWEEN 20 AND 400`; ver C10 |
| `frecuencia_respiratoria` | SMALLINT | ∅ | `CHECK BETWEEN 5 AND 200`; ver C10 |
| `examen_fisico` | TEXT | ∅ | Hallazgos objetivos; ver C7 |
| `observaciones` | TEXT | ∅ | Ver C7 |
| `proxima_revision` | DATE | ∅ | Día sugerido, sin hora comprometida |

### `diagnostico`
| Atributo | Tipo | Nulo | Justificación técnica |
|---|---|---|---|
| `id` | INTEGER PK | NN | Ver C1 |
| `codigo` | VARCHAR(15) | NN UK | **`VARCHAR`**: los códigos clínicos son alfanuméricos (`GASTRO-001`) |
| `nombre` | VARCHAR(120) | NN UK | Nombres clínicos completos |
| `categoria` | VARCHAR(50) | ∅ | Agrupa para reportes de morbilidad |
| `descripcion` | TEXT | ∅ | Ver C7 |

### `consulta_diagnostico`
| Atributo | Tipo | Nulo | Justificación técnica |
|---|---|---|---|
| `consulta_id` | INTEGER PK FK | NN | |
| `diagnostico_id` | INTEGER PK FK | NN | |
| `tipo` | VARCHAR(12) | NN | `PRESUNTIVO`/`DEFINITIVO`/`DESCARTADO` con `CHECK`; ver C8 |
| `es_principal` | BOOLEAN | NN | Índice único parcial garantiza uno solo por consulta |
| `notas` | TEXT | ∅ | Ver C7 |

### `tratamiento`
| Atributo | Tipo | Nulo | Justificación técnica |
|---|---|---|---|
| `id` | INTEGER PK | NN | Ver C1 |
| `consulta_id` | INTEGER FK | NN | |
| `descripcion` | VARCHAR(300) | NN | |
| `indicaciones` | TEXT | ∅ | Ver C7 |
| `fecha_inicio` | DATE | NN | Día calendario; ver C5 |
| `fecha_fin_estimada` | DATE | ∅ | `CHECK >= fecha_inicio` |
| `estado` | VARCHAR(12) | NN | Enumerado con `CHECK`; ver C8 |

## Bloque D — Prescripción y vacunación

### `receta`
| Atributo | Tipo | Nulo | Justificación técnica |
|---|---|---|---|
| `id` | INTEGER PK | NN | Ver C1 |
| `consulta_id` | INTEGER FK UK | NN | `NOT NULL` + `UNIQUE`: no hay receta sin consulta, y una consulta genera como mucho una |
| `folio` | VARCHAR(20) | NN UK | **`VARCHAR` y no entero**: el folio lleva prefijo (`R-000123`). Se genera desde una `SEQUENCE` y se formatea |
| `fecha_emision` | DATE | NN | Día calendario; ver C5 |
| `indicaciones_generales` | TEXT | ∅ | Ver C7 |
| `vigencia_dias` | SMALLINT | NN | Magnitud pequeña; ver C10 |

### `medicamento`
| Atributo | Tipo | Nulo | Justificación técnica |
|---|---|---|---|
| `id` | INTEGER PK | NN | Ver C1 |
| `nombre` | VARCHAR(120) | NN | UK compuesta con `concentracion` |
| `principio_activo` | VARCHAR(120) | NN | Permite detectar duplicidad terapéutica entre marcas |
| `presentacion` | VARCHAR(50) | NN | Enumerado con `CHECK`; ver C8 |
| `concentracion` | VARCHAR(40) | ∅ | **`VARCHAR` y no numérico**: el valor lleva unidad y forma variable (`10 mg/ml`, `500 mg`). Separarlo en número y unidad sería más puro pero no aporta a ninguna consulta del sistema |
| `laboratorio` | VARCHAR(100) | ∅ | |
| `descripcion` | TEXT | ∅ | Ver C7 |
| `requiere_receta` | BOOLEAN | NN | Ver C9 |
| `stock_actual` | INTEGER | NN | **Entero y no `NUMERIC`**: se cuentan unidades enteras. `CHECK >= 0` |
| `stock_minimo` | INTEGER | NN | Umbral de reposición |
| `precio_venta` | NUMERIC(12,2) | NN | Ver C3 |
| `activo` | BOOLEAN | NN | Ver C9 |

### `receta_detalle`
| Atributo | Tipo | Nulo | Justificación técnica |
|---|---|---|---|
| `receta_id` | INTEGER PK FK | NN | |
| `medicamento_id` | INTEGER PK FK | NN | |
| `dosis` | VARCHAR(60) | NN | **`VARCHAR` deliberadamente**: la dosis se expresa como la escribe el veterinario (`1/2 comprimido`, `0,5 ml por kg`). Forzarla a numérica obligaría a inventar una unidad común inexistente |
| `frecuencia` | VARCHAR(60) | NN | Ídem (`cada 8 horas`, `una vez al día en ayunas`) |
| `duracion_dias` | SMALLINT | NN | **Sí es numérico**: se opera con él para calcular la fecha de fin y la cantidad a dispensar. `CHECK > 0`; ver C10 |
| `via_administracion` | VARCHAR(15) | NN | Enumerado con `CHECK`; ver C8 |
| `cantidad` | NUMERIC(8,2) | NN | Decimal porque se dispensan medias unidades. `CHECK > 0` |
| `instrucciones` | VARCHAR(300) | ∅ | |

### `vacuna`
| Atributo | Tipo | Nulo | Justificación técnica |
|---|---|---|---|
| `id` | INTEGER PK | NN | Ver C1 |
| `nombre` | VARCHAR(100) | NN UK | |
| `laboratorio` | VARCHAR(100) | ∅ | |
| `enfermedades_previene` | VARCHAR(300) | ∅ | Texto descriptivo para la ficha, no un conjunto consultable |
| `dosis_ml` | NUMERIC(5,2) | ∅ | Exacto: es una dosis. Hasta 999,99 ml |
| `intervalo_refuerzo_meses` | SMALLINT | ∅ | Calcula `fecha_proximo_refuerzo`; ver C10 |
| `edad_minima_semanas` | SMALLINT | ∅ | **En semanas y no en meses**: la precisión importa en cachorros, donde el calendario vacunal se mide en semanas |
| `precio` | NUMERIC(12,2) | NN | Ver C3 |
| `activo` | BOOLEAN | NN | Ver C9 |

### `vacuna_especie`
| Atributo | Tipo | Nulo | Justificación técnica |
|---|---|---|---|
| `vacuna_id` | INTEGER PK FK | NN | |
| `especie_id` | SMALLINT PK FK | NN | Tipa igual que `especie.id`; ver C2 |

### `aplicacion_vacuna`
| Atributo | Tipo | Nulo | Justificación técnica |
|---|---|---|---|
| `id` | INTEGER PK | NN | Surrogate; ver C1 y la justificación de PK en el MER |
| `mascota_id` | INTEGER FK | NN | |
| `vacuna_id` | INTEGER FK | NN | |
| `veterinario_id` | INTEGER FK | NN | Responsable legal del acto médico |
| `consulta_id` | INTEGER FK | ∅ | Nulo si se aplicó fuera de consulta |
| `fecha_aplicacion` | DATE | NN | Día calendario. Participa de la `UNIQUE` que permite refuerzos; ver C5 |
| `fecha_proximo_refuerzo` | DATE | ∅ | `CHECK >= fecha_aplicacion`. Nulo si la vacuna no lleva refuerzo |
| `lote` | VARCHAR(40) | NN | **`VARCHAR`**: los lotes son alfanuméricos. Obligatorio por trazabilidad sanitaria ante un retiro de producto |
| `dosis_numero` | SMALLINT | NN | 1ª, 2ª, refuerzo; ver C10 |
| `via_administracion` | VARCHAR(15) | NN | Enumerado con `CHECK`; ver C8 |
| `observaciones` | TEXT | ∅ | Reacciones adversas; ver C7 |

## Bloque E — Comercial

### `servicio`
| Atributo | Tipo | Nulo | Justificación técnica |
|---|---|---|---|
| `id` | INTEGER PK | NN | Ver C1 |
| `codigo` | VARCHAR(15) | NN UK | Alfanumérico |
| `nombre` | VARCHAR(120) | NN UK | |
| `categoria` | VARCHAR(30) | NN | Enumerado con `CHECK`; ver C8 |
| `descripcion` | TEXT | ∅ | Ver C7 |
| `precio_base` | NUMERIC(12,2) | NN | Ver C3 |
| `duracion_estimada_min` | SMALLINT | ∅ | Alimenta la duración por defecto de la cita; ver C10 |
| `icono` | VARCHAR(20) | ∅ | |
| `visible_publico` | BOOLEAN | NN | Ver C9 |
| `activo` | BOOLEAN | NN | Ver C9 |

### `factura`
| Atributo | Tipo | Nulo | Justificación técnica |
|---|---|---|---|
| `id` | INTEGER PK | NN | Ver C1 |
| `cliente_id` | INTEGER FK | NN | |
| `usuario_emisor_id` | INTEGER FK | ∅ | Trazabilidad |
| `numero` | VARCHAR(20) | NN UK | **`VARCHAR` y no entero**: el número fiscal lleva prefijo y ceros a la izquierda (`F-000001`) que un entero destruiría. Se genera desde una `SEQUENCE` |
| `fecha_emision` | DATE | NN | Día calendario: la hora no tiene efecto fiscal |
| `subtotal` | NUMERIC(12,2) | NN | Ver C3 |
| `descuento` | NUMERIC(12,2) | NN | **Importe y no porcentaje**: evita el redondeo doble de calcular un porcentaje sobre un total ya redondeado |
| `porcentaje_impuesto` | NUMERIC(5,2) | NN | Sí es porcentaje: hasta 999,99 con dos decimales para tasas como 10,50 % |
| `impuesto` | NUMERIC(12,2) | NN | Importe resultante, congelado |
| `total` | NUMERIC(12,2) | NN | Ver C3. `CHECK (total = subtotal - descuento + impuesto)` |
| `estado` | VARCHAR(10) | NN | Enumerado con `CHECK`; ver C8 |
| `metodo_pago` | VARCHAR(15) | ∅ | Enumerado con `CHECK`; ver C8 |
| `fecha_pago` | DATE | ∅ | Obligatoria por `CHECK` si el estado es `pagada` |
| `observaciones` | TEXT | ∅ | Ver C7 |

### `factura_detalle`
| Atributo | Tipo | Nulo | Justificación técnica |
|---|---|---|---|
| `id` | INTEGER PK | NN | Ver C1 |
| `factura_id` | INTEGER FK | NN | |
| `servicio_id` | INTEGER FK | ∅ | Arco exclusivo con `medicamento_id` |
| `medicamento_id` | INTEGER FK | ∅ | Ídem |
| `mascota_id` | INTEGER FK | ∅ | Imputa el ítem a una mascota del tutor |
| `consulta_id` | INTEGER FK | ∅ | Vincula el cobro al acto clínico |
| `linea_nro` | SMALLINT | NN | Una factura no tendrá 32.767 líneas; ver C10 |
| `tipo_item` | VARCHAR(12) | NN | Enumerado con `CHECK`; ver C8 |
| `descripcion` | VARCHAR(200) | NN | **Snapshot** del nombre al vender: si el catálogo se renombra, la factura histórica conserva lo vendido |
| `cantidad` | NUMERIC(8,2) | NN | **Decimal y no entero**: se facturan fracciones (0,5 h de quirófano, 2,5 ml). `CHECK > 0` |
| `precio_unitario` | NUMERIC(12,2) | NN | Ver C3. Congelado al momento de la venta |
| `descuento_linea` | NUMERIC(12,2) | NN | Importe; misma razón que en `factura.descuento` |
| `subtotal` | NUMERIC(12,2) | NN | **Columna `GENERATED ALWAYS ... STORED`**: el motor la calcula, es imposible almacenar un valor incoherente |

---

## Resumen de tipos utilizados

| Tipo | Bytes | Dónde se usa | Criterio |
|---|---|---|---|
| `SMALLINT` | 2 | PK de catálogos, magnitudes acotadas | C2, C10 |
| `INTEGER` | 4 | PK generales, FK, stock | C1 |
| `NUMERIC(12,2)` | var. | Todo importe monetario | C3 |
| `NUMERIC(6,2)` | var. | Peso | C4 |
| `NUMERIC(8,2)` | var. | Cantidades fraccionables | C3 |
| `NUMERIC(4,1)` | var. | Temperatura | C11 |
| `CHAR(1)` | 1 | `sexo` | C12 |
| `VARCHAR(n)` | var. | Texto acotado por regla de negocio | C7, C8 |
| `TEXT` | var. | Narrativa clínica libre | C7 |
| `BOOLEAN` | 1 | Banderas | C9 |
| `DATE` | 4 | Días de calendario | C5 |
| `TIMESTAMPTZ` | 8 | Instantes y auditoría | C5, C6 |
