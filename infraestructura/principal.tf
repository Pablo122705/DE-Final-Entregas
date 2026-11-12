terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.region

  default_tags {
    tags = var.etiquetas
  }
}

data "aws_caller_identity" "actual" {}

locals {
  # Nombre global único: prefijo + id de la cuenta
  nombre_bucket      = "${var.prefijo_bucket}-${data.aws_caller_identity.actual.account_id}"
  prefijo_datos      = "entregas/"
  prefijo_resultados = "resultados-athena/"
  ubicacion_datos    = "s3://${local.nombre_bucket}/${local.prefijo_datos}"
  ubicacion_results  = "s3://${local.nombre_bucket}/${local.prefijo_resultados}"
}

# ---------------------------------------------------------------
# 1. Bucket S3 privado con bloqueo de acceso público
# ---------------------------------------------------------------
resource "aws_s3_bucket" "datos" {
  bucket        = local.nombre_bucket
  force_destroy = true # permite que terraform destroy elimine el bucket aunque tenga objetos
}

resource "aws_s3_bucket_public_access_block" "datos" {
  bucket                  = aws_s3_bucket.datos.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_ownership_controls" "datos" {
  bucket = aws_s3_bucket.datos.id
  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "datos" {
  bucket = aws_s3_bucket.datos.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# ---------------------------------------------------------------
# 2. Prefijos separados (marcadores vacíos, no son particiones)
# ---------------------------------------------------------------
resource "aws_s3_object" "prefijo_entregas" {
  bucket  = aws_s3_bucket.datos.id
  key     = local.prefijo_datos
  content = ""
}

resource "aws_s3_object" "prefijo_resultados" {
  bucket  = aws_s3_bucket.datos.id
  key     = local.prefijo_resultados
  content = ""
}

# ---------------------------------------------------------------
# 3. Base de datos de Glue Data Catalog
# ---------------------------------------------------------------
resource "aws_glue_catalog_database" "entregas" {
  name        = var.nombre_base_datos
  description = "Base de datos del ejercicio de entregas (final Ingenieria de Datos)"
}

# ---------------------------------------------------------------
# 4. Tabla externa CSV con partition projection por fecha
# ---------------------------------------------------------------
resource "aws_glue_catalog_table" "entregas" {
  name          = var.nombre_tabla
  database_name = aws_glue_catalog_database.entregas.name
  table_type    = "EXTERNAL_TABLE"
  description   = "Intentos de entrega en CSV, particionados por la carpeta fecha=yyyy-MM-dd"

  parameters = {
    "EXTERNAL"               = "TRUE"
    "classification"         = "csv"
    "skip.header.line.count" = "1"

    # Partition projection: Athena calcula las particiones en tiempo de consulta
    "projection.enabled"             = "true"
    "projection.fecha.type"          = "date"
    "projection.fecha.format"        = "yyyy-MM-dd"
    "projection.fecha.range"         = "${var.fecha_inicio},${var.fecha_fin}"
    "projection.fecha.interval"      = "1"
    "projection.fecha.interval.unit" = "DAYS"
    # $${fecha} se escapa para que Terraform no lo interpole; Athena lo reemplaza
    "storage.location.template" = "${local.ubicacion_datos}fecha=$${fecha}/"
  }

  partition_keys {
    name    = "fecha"
    type    = "string"
    comment = "Tomada de la carpeta fecha=yyyy-MM-dd; no es columna del CSV"
  }

  storage_descriptor {
    location      = local.ubicacion_datos
    input_format  = "org.apache.hadoop.mapred.TextInputFormat"
    output_format = "org.apache.hadoop.hive.ql.io.HiveIgnoreKeyTextOutputFormat"

    ser_de_info {
      name                  = "csv-coma"
      serialization_library = "org.apache.hadoop.hive.serde2.lazy.LazySimpleSerDe"
      parameters = {
        "field.delim"          = ","
        "serialization.format" = ","
      }
    }

    columns {
      name = "id_envio"
      type = "string"
    }
    columns {
      name = "ciudad"
      type = "string"
    }
    columns {
      name = "transportadora"
      type = "string"
    }
    columns {
      name = "estado"
      type = "string"
    }
    columns {
      name = "duracion_minutos"
      type = "int"
    }
  }
}

# ---------------------------------------------------------------
# 5. Workgroup de Athena con resultados en resultados-athena/
# ---------------------------------------------------------------
resource "aws_athena_workgroup" "entregas" {
  name          = var.nombre_workgroup
  description   = "Workgroup del ejercicio de entregas"
  force_destroy = true

  configuration {
    enforce_workgroup_configuration    = true
    publish_cloudwatch_metrics_enabled = false

    result_configuration {
      output_location = local.ubicacion_results

      encryption_configuration {
        encryption_option = "SSE_S3"
      }
    }
  }

  depends_on = [aws_s3_object.prefijo_resultados]
}
