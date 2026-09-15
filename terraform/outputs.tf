output "rds_endpoint" {
  value = kubernetes_service.postgres_nlb.status[0].load_balancer[0].ingress[0].hostname
}

output "rds_secret_arn" {
  value = aws_secretsmanager_secret.db_credentials.arn
}

output "db_name" {
  value = var.db_name
}
