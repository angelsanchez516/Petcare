# Base de datos PetCare — PostgreSQL 16

Base de datos del sistema de gestión para clínica veterinaria. Derivada del MER
unificado del grupo (52 entidades, 438 atributos, 66 relaciones).

**Escrita a mano.** Ninguna tabla proviene de migraciones automáticas de un ORM.
La aplicación se conecta a un esquema que ya existe y no tiene permiso para
alterarlo.

---

## Instalación

Requiere PostgreSQL 16 y `psql` en el PATH.

```bash
psql -U postgres -c "CREATE DATABASE petcare WITH ENCODING 'UTF8' TEMPLATE template0"
```

```bash
psql -U postgres -d petcare -f database/petcare.sql
```

El script maestro ejecuta los siete archivos en orden dentro de una única
transacción: si algo falla, no queda nada a medio crear.

Para verificar que todo quedó bien:

```bash
psql -U postgres -d petcare -f database/08_pruebas.sql
```

Debe informar **66 pruebas, 66 superadas**. Esa batería corre dentro de una
transacción que se revierte, así que no deja rastros.

### Instalación sin datos de ejemplo

Comentar la línea `\ir 07_demo.sql` en `petcare.sql`. Los catálogos
(`06_catalogos.sql`) sí deben cargarse: el sistema no funciona sin roles,
permisos, especies ni servicios.

---

## Estructura de archivos

| Archivo | Contenido | Sentencias |
|---|---|---|
| `petcare.sql` | Script maestro. Ejecuta todo en orden | — |
| `01_esquema.sql` | Extensiones, dominios, secuencias y las 52 tablas | 124 |
| `02_integridad.sql` | 91 claves foráneas agrupadas por política de borrado | 92 |
| `03_indices.sql` | Índices únicos parciales, sobre foráneas y de consulta | 96 |
| `04_reglas.sql` | 17 funciones y 27 disparadores | 51 |
| `05_vistas.sql` | 10 vistas: aquí viven los atributos derivados | 18 |
| `06_catalogos.sql` | Datos maestros (también existen en producción) | 32 |
| `07_demo.sql` | Datos de ejemplo | 49 |
| `08_pruebas.sql` | 66 casos de prueba | 77 |

### Por qué las foráneas están en un archivo aparte

Dos razones. El modelo tiene **referencias circulares** —`registro_peso` apunta a
`consulta` y `consulta` puede originar un `registro_peso`; `solicitud_cita`
apunta a `cita`— que impiden un orden lineal de creación. Y agrupar las 91
foráneas por política de borrado deja esa decisión **auditable de un vistazo**,
en vez de dispersa entre 52 `CREATE TABLE`.

---

## Lo que verifica el motor

| Objeto | Cantidad |
|---|---|
| Tablas | 52 |
| Vistas | 10 |
| Claves foráneas | 91 |
| Restricciones `CHECK` | 132 |
| Restricciones `UNIQUE` | 41 |
| Restricciones `EXCLUDE` | 2 |
| Índices | 189 |
| Disparadores | 27 |
| Dominios | 4 |

### Política de borrado

El criterio, en una frase:

- **`CASCADE`** únicamente cuando la fila hija no tiene identidad fuera del
  padre. Una línea de factura no es un ente autónomo, es una *parte* de esa
  factura.
- **`RESTRICT`** en todo lo demás, y muy especialmente en el historial clínico.
  Borrar una mascota **falla**: no se lleva su expediente por delante.
- **`SET NULL`** solo en referencias de trazabilidad, donde perder el «quién» no
  invalida el hecho registrado.

Las bajas son **lógicas** (columna `activo`). `RESTRICT` es la red de seguridad
que convierte un `DELETE` accidental en un error en lugar de una pérdida de datos.

### Atributos derivados

Cuatro datos que la interfaz muestra **no son columnas**. Se calculan en vistas
para que no puedan contradecir a su origen:

| Dato | De dónde sale |
|---|---|
| Edad de la mascota | `fecha_nacimiento`, en `v_mascota_perfil` |
| Peso actual | Última fila de `registro_peso` |
| Estado de vacunación | `fecha_proximo_refuerzo` contra la fecha actual |
| Stock actual | `SUM(cantidad)` sobre `movimiento_stock` |

Ese último punto es importante: **no existe una columna de stock que alguien
pueda editar**. El saldo es siempre la suma del kardex, y por eso
`movimiento_stock.cantidad` lleva signo (entradas positivas, salidas negativas).

### Reglas que el motor hace cumplir

Algunas que no son obvias:

- Un veterinario **no puede tener dos citas solapadas** (`EXCLUDE USING gist`).
- Una mascota **no puede ser un felino de raza labrador** (clave foránea
  compuesta `(raza_id, especie_id)`).
- Una **vacuna canina no se aplica a un felino** (`vacuna_especie` + disparador).
- El **subtotal de una línea de factura es `GENERATED ALWAYS`**: es
  aritméticamente imposible almacenar un valor incoherente, aunque la inserción
  venga por `psql`.
- **No se puede cobrar más que el total** de la factura.
- Un **diagnóstico no puede formar un ciclo** en su jerarquía.
- El **stock nunca queda negativo** (`CONSTRAINT TRIGGER` sobre la suma).

---

## Conexión desde la aplicación

```
Host:      localhost
Puerto:    5432
Base:      petcare
Esquema:   public
Encoding:  UTF8
```

La aplicación debe conectarse con un usuario **sin privilegios de DDL**. Crear
uno así:

```sql
CREATE ROLE petcare_app LOGIN PASSWORD 'la-que-elijas';
GRANT CONNECT ON DATABASE petcare TO petcare_app;
GRANT USAGE ON SCHEMA public TO petcare_app;
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public TO petcare_app;
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO petcare_app;
```

Sin `CREATE`, el ORM no puede alterar el esquema aunque se lo pida alguien por
error. Es la garantía técnica de que el modelo sigue siendo el diseñado.

---

## Usuarios de prueba

⚠️ **Los `password_hash` de `07_demo.sql` son marcadores, no hashes válidos.**
Ningún usuario puede iniciar sesión con ellos. La aplicación debe generar los
hashes reales con argon2id o bcrypt.

| Usuario | Persona | Roles |
|---|---|---|
| `vsandoval` | Valeria Sandoval | Administrador + Veterinario |
| `lferreyra` | Lucía Ferreyra | Veterinario |
| `mocampo` | Martín Ocampo | Veterinario |
| `sbrenner` | Sofía Brenner | Veterinario |
| `cruiz` | Camila Ruiz | Recepcionista |
| `dpaz` | Diego Paz | Recepcionista + Inventario |

Para asignar una contraseña real a un usuario de prueba, generar el hash con la
librería de la aplicación y actualizarlo:

```sql
UPDATE usuario SET password_hash = '<hash generado>' WHERE nombre_usuario = 'vsandoval';
```

---

## Consultas útiles para verificar

```sql
-- Perfil con los cuatro atributos derivados
SELECT nombre, especie, edad_anios, peso_actual_kg, estado_vacunacion, tutor
  FROM v_mascota_perfil WHERE activo ORDER BY nombre;

-- Historial clínico unificado de una mascota
SELECT fecha, tipo, titulo, veterinario FROM v_historial_clinico
 WHERE mascota_id = (SELECT id FROM mascota WHERE nombre = 'Max')
 ORDER BY fecha DESC;

-- Stock derivado del kardex
SELECT codigo, nombre, stock_actual, estado_stock FROM v_stock_actual
 WHERE estado_stock <> 'OK';

-- Refuerzos de vacuna por vencer
SELECT mascota, tutor, vacuna, vence, dias_restantes, estado
  FROM v_vacunas_pendientes WHERE estado <> 'VIGENTE' ORDER BY vence;

-- Jerarquía recursiva de diagnósticos
SELECT nivel, ruta FROM v_diagnostico_arbol ORDER BY ruta;

-- Agenda de los próximos días
SELECT fecha_hora_inicio, mascota, tutor, veterinario, servicio, estado
  FROM v_agenda WHERE fecha_hora_inicio >= now() ORDER BY fecha_hora_inicio;
```

---

## Si hace falta cambiar el modelo

El orden correcto es:

1. Actualizar el **MER** (`docs/`)
2. Derivar el cambio al **modelo relacional**
3. Recién entonces modificar **estos archivos SQL**

Nunca al revés, y nunca desde el ORM. La aplicación es consecuencia del modelo
de datos, no al contrario.

---

## Reconstruir desde cero

```bash
psql -U postgres -c "DROP DATABASE IF EXISTS petcare"
```

```bash
psql -U postgres -c "CREATE DATABASE petcare WITH ENCODING 'UTF8' TEMPLATE template0"
```

```bash
psql -U postgres -d petcare -f database/petcare.sql
```
