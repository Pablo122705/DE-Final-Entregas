# Respuestas

## 1. ¿Por qué se pudo consultar el tercer día sin registrar una partición nueva?

Porque la tabla `entregas_db.entregas` no depende de particiones registradas en el catálogo, sino de **partition projection**. En `infraestructura/principal.tf` la tabla tiene `projection.enabled = true` y la regla de la clave `fecha`: tipo `date`, formato `yyyy-MM-dd`, rango `2026-10-01,2026-10-03` e intervalo de 1 día (`DAYS`). También tiene la plantilla `storage.location.template = s3://<bucket>/entregas/fecha=${fecha}/`.

Cuando se ejecuta una consulta, Athena no le pide a Glue la lista de particiones. Calcula los valores posibles de `fecha` a partir del rango (01, 02 y 03 de octubre), reemplaza cada valor en la plantilla y lee directamente el prefijo de S3 correspondiente. Como el 2026-10-03 ya estaba dentro del rango desde el primer `terraform apply`, su ubicación `entregas/fecha=2026-10-03/` ya era "conocida" por la tabla:

- **Antes de subir el archivo**, ese prefijo estaba vacío. Athena simplemente no encontró objetos y en la etapa inicial solo se veían 12 registros (`resultados/inicial/conteo_registros.csv`). La proyección no crea datos ni exige que existan.
- **Después de subir el archivo** (`evidencias/s3_objetos_final.txt`), la siguiente consulta encontró el objeto en esa ruta y leyó sus 6 filas (`resultados/final/verificacion_tercer_dia.csv`). El total pasó a 18 (`resultados/final/verificacion_total_registros.csv`) y los agregados finales coinciden con las referencias (`evidencias/comparacion_final.txt`).

No hizo falta crawler, `MSCK REPAIR TABLE`, `ALTER TABLE ADD PARTITION` ni ningún cambio en Terraform. Solo se subió el archivo y se consultó, como se ve en las ejecuciones con etapa `final` de `evidencias/ejecuciones_athena.csv`.

## 2. Si se subiera un archivo para el 4 de octubre manteniendo la configuración actual, ¿qué resultado se esperaría y qué se debería modificar para incluirlo?

Con la configuración actual, el rango termina en `2026-10-03`. Athena solo genera particiones entre el 01 y el 03 de octubre, así que **nunca construiría la ruta** `entregas/fecha=2026-10-04/`. El archivo quedaría guardado en S3, pero sería invisible para la tabla:

- Las consultas seguirían devolviendo 18 registros, y los agregados de intentos y porcentaje mostrarían solo tres fechas.
- Un `WHERE fecha = '2026-10-04'` no fallaría: devolvería 0 filas, porque esa fecha está fuera de la proyección.
- No habría ningún error que avisara del problema, así que los datos se perderían en silencio para el análisis.

Para incluirlo hay que **ampliar el rango de la proyección en Terraform** y volver a aplicar. Cambiar la propiedad a mano en la consola no se aceptaría, porque la infraestructura debe ser reproducible. Por ejemplo:

- Cambiar `fecha_fin` a `2026-10-04` (o a una fecha futura) en `variables.tf`, o pasar `-var fecha_fin=2026-10-04`, y ejecutar `terraform apply`. Eso actualiza `projection.fecha.range = 2026-10-01,2026-10-04`.
- Si se quiere que cada día nuevo se incluya sin volver a tocar la tabla, usar un rango relativo como `2026-10-01,NOW`. Athena lo resuelve al momento de la consulta.

Después de ese cambio, igual que pasó con el día 3, basta con que el archivo esté en `s3://<bucket>/entregas/fecha=2026-10-04/entregas.csv` y respete el mismo esquema. No hay que registrar particiones.
