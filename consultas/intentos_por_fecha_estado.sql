-- Cantidad de intentos por fecha y estado (todos los intentos, todo el rango proyectado)
SELECT
    fecha,
    estado,
    COUNT(*) AS total_intentos
FROM entregas_db.entregas
GROUP BY fecha, estado
ORDER BY fecha ASC, estado ASC;
