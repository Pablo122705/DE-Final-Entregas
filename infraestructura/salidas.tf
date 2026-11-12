output "region" {
  description = "Región del despliegue"
  value       = var.region
}

output "bucket" {
  description = "Nombre del bucket S3 del ejercicio"
  value       = aws_s3_bucket.datos.bucket
}

output "bucket_arn" {
  description = "ARN del bucket S3"
  value       = aws_s3_bucket.datos.arn
}

output "ubicacion_datos" {
  description = "Prefijo S3 de los datos"
  value       = local.ubicacion_datos
}

output "ubicacion_resultados_athena" {
  description = "Prefijo S3 de los resultados de Athena"
  value       = local.ubicacion_results
}

output "base_datos" {
  description = "Base de datos de Glue Data Catalog"
  value       = aws_glue_catalog_database.entregas.name
}

output "tabla" {
  description = "Tabla externa de Glue"
  value       = aws_glue_catalog_table.entregas.name
}

output "tabla_arn" {
  description = "ARN de la tabla de Glue"
  value       = aws_glue_catalog_table.entregas.arn
}

output "plantilla_ubicacion_particiones" {
  description = "storage.location.template usada por partition projection"
  value       = aws_glue_catalog_table.entregas.parameters["storage.location.template"]
}

output "rango_proyeccion" {
  description = "Rango de fechas proyectado"
  value       = aws_glue_catalog_table.entregas.parameters["projection.fecha.range"]
}

output "workgroup" {
  description = "Workgroup de Athena"
  value       = aws_athena_workgroup.entregas.name
}
