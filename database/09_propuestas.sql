-- ============================================================================
--  PETCARE — 09_propuestas.sql · Cambios PROPUESTOS, todavía NO aplicados
-- ----------------------------------------------------------------------------
--  Este archivo no forma parte de petcare.sql y no se ejecuta solo. Ninguno de
--  estos cambios crea tablas, columnas ni borra información.
--
--  Aplicarlo es opcional:  psql -U postgres -d petcare -f database/09_propuestas.sql
--
--    1. Corrige v_mascota_perfil (columna proximo_refuerzo).
--    2. Cambia la foto de Max: es un labrador y tiene la foto de un gato.
--    3. Agrega citas de demostración para el día en que se ejecute, porque las
--       citas actuales ya quedaron en el pasado y «Citas de hoy» sale en cero.
-- ============================================================================

BEGIN;

-- ----------------------------------------------------------------------------
--  1. Vista: el refuerzo pendiente debe salir de la ÚLTIMA aplicación por vacuna
-- ----------------------------------------------------------------------------
--  La versión actual usa min() sobre todas las aplicaciones. Si una mascota ya
--  recibió su refuerzo, la fecha vieja sigue ganando y aparece como VENCIDA.
--  La aplicación ya calcula bien el estado por su cuenta (lib/repos/mascotas.ts),
--  así que este cambio solo deja la vista coherente con v_vacunas_pendientes.
-- ----------------------------------------------------------------------------
CREATE OR REPLACE VIEW v_mascota_perfil AS
SELECT
    m.id, m.nombre, m.sexo,
    CASE m.sexo WHEN 'M' THEN 'Macho' ELSE 'Hembra' END        AS sexo_texto,
    e.id    AS especie_id,  e.nombre AS especie,  e.icono      AS especie_icono,
    r.id    AS raza_id,     r.nombre AS raza,
    m.color, m.microchip, m.esterilizado, m.foto_url, m.observaciones,
    m.activo, m.fecha_nacimiento, m.fecha_fallecimiento, m.creado_en,
    CASE WHEN m.fecha_nacimiento IS NOT NULL THEN
        date_part('year', age(COALESCE(m.fecha_fallecimiento, CURRENT_DATE),
                              m.fecha_nacimiento))::INT END     AS edad_anios,
    CASE WHEN m.fecha_nacimiento IS NOT NULL THEN
        (date_part('year',  age(COALESCE(m.fecha_fallecimiento, CURRENT_DATE), m.fecha_nacimiento)) * 12
       + date_part('month', age(COALESCE(m.fecha_fallecimiento, CURRENT_DATE), m.fecha_nacimiento)))::INT
    END                                                          AS edad_meses,
    p.peso_kg                                                    AS peso_actual_kg,
    p.fecha_registro                                             AS peso_fecha,
    v.proximo_refuerzo,
    CASE
        WHEN v.proximo_refuerzo IS NULL                              THEN 'SIN_DATOS'
        WHEN v.proximo_refuerzo <  CURRENT_DATE                      THEN 'VENCIDA'
        WHEN v.proximo_refuerzo <= CURRENT_DATE + INTERVAL '30 days' THEN 'PROXIMA'
        ELSE                                                              'VIGENTE'
    END                                                          AS estado_vacunacion,
    c.id AS cliente_id,
    c.nombres || ' ' || c.apellidos                              AS tutor,
    c.telefono AS tutor_telefono, c.email AS tutor_email
FROM mascota m
JOIN especie e ON e.id = m.especie_id
JOIN cliente c ON c.id = m.cliente_id
LEFT JOIN raza r ON r.id = m.raza_id
LEFT JOIN LATERAL (
    SELECT rp.peso_kg, rp.fecha_registro FROM registro_peso rp
     WHERE rp.mascota_id = m.id ORDER BY rp.fecha_registro DESC LIMIT 1) p ON TRUE
LEFT JOIN LATERAL (
    SELECT min(av.fecha_proximo_refuerzo) AS proximo_refuerzo FROM aplicacion_vacuna av
     WHERE av.mascota_id = m.id AND av.fecha_proximo_refuerzo IS NOT NULL
       AND av.fecha_aplicacion = (SELECT max(a2.fecha_aplicacion) FROM aplicacion_vacuna a2
                                   WHERE a2.mascota_id = av.mascota_id
                                     AND a2.vacuna_id = av.vacuna_id)) v ON TRUE;


-- ----------------------------------------------------------------------------
--  2. Foto de Max
-- ----------------------------------------------------------------------------
UPDATE mascota SET foto_url = '/img/perro-2.jpg'
 WHERE nombre = 'Max' AND foto_url = '/img/gato-cuadrado.jpg';


-- ----------------------------------------------------------------------------
--  3. Citas de demostración relativas al día de hoy
-- ----------------------------------------------------------------------------
--  ON CONFLICT DO NOTHING también cubre la restricción de horarios: si una cita
--  se cruza con otra, simplemente no se inserta.
-- ----------------------------------------------------------------------------
INSERT INTO cita (mascota_id, veterinario_id, servicio_id, fecha_hora_inicio, duracion_minutos, motivo, estado)
SELECT m.id, v.id, s.id, x.inicio, x.minutos, x.motivo, x.estado
  FROM (VALUES
        ('Max',   'Valeria', 'Consulta general',    CURRENT_DATE + TIME '09:00', 30, 'Revisión general',        'confirmada'),
        ('Luna',  'Sofía',   'Consulta general',    CURRENT_DATE + TIME '10:30', 30, 'Control de peso',         'confirmada'),
        ('Rocco', 'Martín',  'Consulta de control', CURRENT_DATE + TIME '15:00', 20, 'Control posoperatorio',   'programada'),
        ('Simba', 'Lucía',   'Consulta general',    CURRENT_DATE + 1 + TIME '11:00', 30, 'Refuerzo de vacuna',  'programada'),
        ('Nala',  'Valeria', 'Consulta de control', CURRENT_DATE + 2 + TIME '09:30', 20, 'Control de tratamiento','programada')
       ) AS x(mascota, vet, servicio, inicio, minutos, motivo, estado)
  JOIN mascota m     ON m.nombre = x.mascota
  JOIN veterinario v ON v.nombres = x.vet
  JOIN servicio s    ON s.nombre = x.servicio
ON CONFLICT DO NOTHING;

COMMIT;
