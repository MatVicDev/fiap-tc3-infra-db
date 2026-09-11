# Rede provisionada pelo repositório fiap-tc3-infra-k8s (VPC + subnets privadas do
# EKS). Lido via SSM Parameter Store para não acoplar remote state entre repos
# independentes — cada um tem seu próprio pipeline e ciclo de vida.
data "aws_ssm_parameter" "vpc_id" {
  name = "/fiap-tc3/${var.ambiente}/vpc-id"
}

data "aws_ssm_parameter" "private_subnet_ids" {
  name = "/fiap-tc3/${var.ambiente}/private-subnet-ids"
}

data "aws_ssm_parameter" "private_subnets_cidr" {
  name = "/fiap-tc3/${var.ambiente}/private-subnets-cidr"
}

resource "aws_db_subnet_group" "oficina" {
  name       = "fiap-tc3-oficina-${var.ambiente}"
  subnet_ids = split(",", data.aws_ssm_parameter.private_subnet_ids.value)
}

resource "aws_security_group" "rds" {
  name        = "fiap-tc3-rds-${var.ambiente}"
  description = "Permite Postgres (5432) apenas a partir da rede privada do EKS/Lambda"
  vpc_id      = data.aws_ssm_parameter.vpc_id.value

  ingress {
    description = "Postgres a partir das subnets privadas (pods EKS + Lambda de auth)"
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = split(",", data.aws_ssm_parameter.private_subnets_cidr.value)
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_db_instance" "oficina" {
  identifier     = "fiap-tc3-oficina-${var.ambiente}"
  engine         = "postgres"
  engine_version = "16"
  instance_class = var.db_instance_class

  allocated_storage     = var.db_allocated_storage_gb
  max_allocated_storage = var.db_allocated_storage_gb * 3
  storage_encrypted     = true

  db_name  = var.db_name
  username = var.db_username

  # Gerenciado pela própria AWS: cria e faz rotação do secret no Secrets Manager,
  # sem senha em variável de ambiente/state em texto puro.
  manage_master_user_password = true

  db_subnet_group_name   = aws_db_subnet_group.oficina.name
  vpc_security_group_ids = [aws_security_group.rds.id]

  multi_az                  = var.multi_az
  backup_retention_period   = 7
  deletion_protection       = var.ambiente == "producao"
  skip_final_snapshot       = var.ambiente != "producao"
  final_snapshot_identifier = var.ambiente == "producao" ? "fiap-tc3-oficina-${var.ambiente}-final" : null

  tags = {
    ambiente = var.ambiente
    projeto  = "fiap-tc3-oficina"
  }
}

# Publicados para os repositórios fiap-tc3-lambda-auth e fiap-TC1-oficina lerem
# sem precisar de acesso ao state deste repositório.
resource "aws_ssm_parameter" "rds_endpoint" {
  name  = "/fiap-tc3/${var.ambiente}/rds-endpoint"
  type  = "String"
  value = aws_db_instance.oficina.address
}

resource "aws_ssm_parameter" "rds_secret_arn" {
  name  = "/fiap-tc3/${var.ambiente}/rds-secret-arn"
  type  = "String"
  value = aws_db_instance.oficina.master_user_secret[0].secret_arn
}
