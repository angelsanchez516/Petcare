# Base de datos de PetCare

Base de datos de PostgreSQL 16 escrita a mano, sin migraciones de ORM. Tiene 29 tablas: las 28 del MER y `solicitud_cita`.

## Archivos

| Archivo | Contenido |
|---|---|
| `petcare.sql` | Script maestro: ejecuta del 01 al 07 en orden |
| `01_esquema.sql` | Tablas, dominios, secuencias y restricciones `CHECK` |
| `02_integridad.sql` | Claves foráneas |
| `03_indices.sql` | Índices |
| `04_reglas.sql` | Funciones y triggers: totales, folios, stock, coherencia clínica |
| `05_vistas.sql` | Vistas con los datos derivados: edad, peso actual, saldo, etc. |
| `06_catalogos.sql` | Datos de referencia |
| `07_demo.sql` | Datos de demostración |
| `08_pruebas.sql` | 41 pruebas. Corren en una transacción que se revierte |
| `09_propuestas.sql` | Cambios propuestos. **No se han aplicado** |
| `_archivo_v52/` | Versión anterior de 52 tablas. No se usa |

## Crear la base desde cero

Solo hace falta en un computador nuevo. Tu base `petcare` ya existe.

```bash
psql -U postgres -c "CREATE DATABASE petcare WITH ENCODING 'UTF8' TEMPLATE template0"
```

```bash
psql -U postgres -d petcare -f database/petcare.sql
```

## Comprobar que todo está bien

Esta prueba no deja cambios en la base:

```bash
psql -U postgres -d petcare -f database/08_pruebas.sql
```

## Reglas que cumple la base por sí sola

- Un veterinario no puede tener dos citas cruzadas (`EXCLUDE` en `cita`).
- La raza debe ser de la especie de la mascota (clave foránea compuesta).
- Una vacuna solo se aplica a las especies indicadas (trigger).
- El subtotal, el total y el estado de la factura se calculan solos (columna generada y triggers).
- Facturar un medicamento descuenta el stock y falla si no alcanza (trigger).
- No se puede cobrar más que el total de la factura (trigger).
- El número de factura y el folio de receta los pone la base (trigger y secuencia).

## Reglas que cumple la aplicación

La base no las cubre, así que están en `web/src/lib/repos/`:

- Devolver el stock al quitar una línea de factura o al anularla.
- No aceptar pagos en una factura anulada.
- Facturar medicamentos solo en unidades enteras.
- Exigir que una factura o una receta nazca con su primera línea.
- Respetar la edad mínima de cada vacuna.

## Diferencias con el MER entregado

El PDF del MER no tiene nada que falte en la base, pero la base sí tiene elementos que no están en el PDF:

| Tabla | Elementos que no están en el MER |
|---|---|
| Tabla nueva | `solicitud_cita` |
| `aplicacion_vacuna` | `observaciones` |
| `cita` | `creado_en`, `fecha_hora_fin`, `notas` |
| `cliente` | `ciudad`, `creado_en`, `notas` |
| `consulta` | `creado_en`, `observaciones` |
| `consulta_diagnostico` | `notas` |
| `especie` | `icono` |
| `factura` | `creado_en`, `observaciones` |
| `mascota` | `creado_en`, `fecha_fallecimiento`, `observaciones` |
| `mascota_condicion` | `notas` |
| `medicamento` | `activo` |
| `metodo_pago` | `activo` |
| `registro_peso` | `observacion` |
| `servicio` | `descripcion`, `icono`, `visible_publico` |
| `usuario` | `creado_en`, `ultimo_acceso` |
| `vacuna` | `activo` |
| `veterinario` | `biografia`, `foto_url` |
