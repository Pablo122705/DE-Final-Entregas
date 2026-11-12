-- Verificación de la nueva fecha 2026-10-03 (sin crawlers, sin MSCK REPAIR, sin ADD PARTITION)

-- 1) Los seis registros del 2026-10-03
SELECT
    fecha,
    id_envio,
    ciudad,
    transportadora,
    estado,
    duracion_minutos
FROM entregas_db.entregas
WHERE fecha = '2026-10-03'
ORDER BY id_envio ASC;

-- 2) Conteo por estado del 2026-10-03
SELECT
    fecha,
    estado,
    COUNT(*) AS total_intentos
FROM entregas_db.entregas
WHERE fecha = '2026-10-03'
GROUP BY fecha, estado
ORDER BY estado ASC;

-- 3) Registros del tercer día y total de la tabla (se esperan 6 y 18)
SELECT
    COUNT_IF(fecha = '2026-10-03') AS registros_2026_10_03,
    COUNT(*) AS total_registros
FROM entregas_db.entregas;
