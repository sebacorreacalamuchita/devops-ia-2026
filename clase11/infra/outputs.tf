output "web_url" {
  description = "URL de Nginx (accesible solo desde la IP autorizada)"
  value       = "http://${aws_instance.web.public_ip}"
}

output "instance_id" {
  description = "ID de la instancia EC2"
  value       = aws_instance.web.id
}

output "data_bucket" {
  description = "Bucket S3 del lab"
  value       = aws_s3_bucket.data.id
}

output "log_group_name" {
  description = "Log group de CloudWatch"
  value       = aws_cloudwatch_log_group.app.name
}
