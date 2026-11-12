variable "region" {
  description = "Región de AWS donde se despliegan los recursos"
  type        = string
  default     = "us-east-1"
}

variable "prefijo_bucket" {
  description = "Prefijo del bucket; se le agrega el id de la cuenta para que el nombre sea único"
  type        = string
  default     = "de-final-entregas"
}

variable "nombre_base_datos" {
  description = "Nombre de la base de datos de Glue Data Catalog"
  type        = string
  default     = "entregas_db"
}

variable "nombre_tabla" {
  description = "Nombre de la tabla externa de Glue"
  type        = string
  default     = "entregas"
}

variable "nombre_workgroup" {
  description = "Nombre del workgroup de Athena"
  type        = string
  default     = "entregas-wg"
}

variable "fecha_inicio" {
  description = "Primera fecha proyectada (incluida), formato yyyy-MM-dd"
  type        = string
  default     = "2026-10-01"
}

variable "fecha_fin" {
  description = "Última fecha proyectada (incluida), formato yyyy-MM-dd"
  type        = string
  default     = "2026-10-03"
}

variable "etiquetas" {
  description = "Etiquetas comunes para los recursos"
  type        = map(string)
  default = {
    proyecto = "de-final-entregas"
    curso    = "ingenieria-de-datos-eia-2026-2"
  }
}
