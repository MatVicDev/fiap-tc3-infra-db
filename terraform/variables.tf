variable "aws_region" {
  type    = string
  default = "us-east-1"
}

variable "ambiente" {
  description = "homologacao | producao — usado em nomes/tags e para ler os parâmetros SSM certos do repositório fiap-tc3-infra-k8s"
  type        = string
  default     = "homologacao"
}

variable "db_storage_gb" {
  description = "Tamanho do EBS (gp3) do PersistentVolumeClaim do Postgres."
  type        = number
  default     = 10
}

variable "db_name" {
  type    = string
  default = "oficina"
}

variable "db_username" {
  description = "Master user do Postgres. A aplicação usa este mesmo usuário (ver ADR-004 sobre o trade-off de não criar um usuário de aplicação separado)."
  type        = string
  default     = "oficina_admin"
}
