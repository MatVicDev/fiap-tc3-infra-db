output "rds_endpoint" {
  value = aws_db_instance.oficina.address
}

output "rds_secret_arn" {
  value = aws_db_instance.oficina.master_user_secret[0].secret_arn
}

output "db_name" {
  value = aws_db_instance.oficina.db_name
}
