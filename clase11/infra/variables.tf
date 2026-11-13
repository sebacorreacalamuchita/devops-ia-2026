variable "aws_region" {
  description = "Región de AWS"
  type        = string
  default     = "us-east-1"
}

variable "environment" {
  description = "Nombre del entorno (dev, qa)"
  type        = string
  default     = "dev"
}

variable "instance_type" {
  description = "Tipo de instancia EC2"
  type        = string
  default     = "t3.micro"
}

variable "log_retention_days" {
  description = "Días de retención del log group de CloudWatch"
  type        = number
  default     = 7
}

variable "bucket_name" {
  description = "Nombre globalmente único del bucket S3 del lab (LAB_BUCKET_NAME)"
  type        = string
}

variable "http_cidr" {
  description = "IP autorizada para HTTP 80, en formato x.x.x.x/32 (LAB_HTTP_CIDR)"
  type        = string

  validation {
    condition     = can(regex("/32$", var.http_cidr))
    error_message = "http_cidr debe ser una única IP con /32."
  }
}
