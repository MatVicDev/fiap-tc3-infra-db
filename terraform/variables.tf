variable "aws_region" {
  type    = string
  default = "us-east-1"
}

variable "ambiente" {
  description = "homologacao | producao — usado em nomes/tags e para ler os parâmetros SSM certos do repositório fiap-tc3-infra-k8s"
  type        = string
  default     = "homologacao"
}

variable "db_instance_class" {
  description = "Classe da instância RDS. db.t4g.micro cabe no free tier."
  type        = string
  default     = "db.t4g.micro"
}

variable "db_allocated_storage_gb" {
  type    = number
  default = 20
}

variable "db_name" {
  type    = string
  default = "oficina"
}

variable "db_username" {
  description = "Master user do RDS. A aplicação usa este mesmo usuário (ver ADR-004 sobre o trade-off de não criar um usuário de aplicação separado)."
  type        = string
  default     = "oficina_admin"
}

variable "multi_az" {
  description = "Alta disponibilidade (2 AZs). true em produção, false em homologação para reduzir custo."
  type        = bool
  default     = false
}
