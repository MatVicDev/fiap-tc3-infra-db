# Postgres roda como StatefulSet dentro do próprio cluster EKS, não via RDS:
# este AWS Academy Learner Lab bloqueia rds:CreateDBInstance sem exceção —
# nem RDS clássico nem uma instância dentro de um cluster Aurora passam
# (confirmado via `aws iam simulate-principal-policy` e batendo de frente no
# apply real). O nome deste repositório e os nomes dos parâmetros SSM
# publicados (rds-endpoint, rds-secret-arn) continuam os mesmos para não
# propagar a mudança para fiap-tc3-lambda-auth nem fiap-TC1-oficina.
data "aws_ssm_parameter" "eks_cluster_name" {
  name = "/fiap-tc3/${var.ambiente}/eks-cluster-name"
}

resource "kubernetes_namespace" "database" {
  metadata {
    name = "database"
  }
}

resource "random_password" "db_master" {
  length  = 32
  special = false
}

resource "kubernetes_secret" "postgres_credentials" {
  metadata {
    name      = "postgres-credentials"
    namespace = kubernetes_namespace.database.metadata[0].name
  }

  data = {
    POSTGRES_USER     = var.db_username
    POSTGRES_PASSWORD = random_password.db_master.result
    POSTGRES_DB       = var.db_name
  }
}

resource "kubernetes_stateful_set" "postgres" {
  metadata {
    name      = "postgres"
    namespace = kubernetes_namespace.database.metadata[0].name
    labels    = { app = "postgres" }
  }

  spec {
    service_name = "postgres"
    replicas     = 1

    selector {
      match_labels = { app = "postgres" }
    }

    template {
      metadata {
        labels = { app = "postgres" }
      }

      spec {
        container {
          name  = "postgres"
          image = "postgres:16"

          port {
            container_port = 5432
          }

          env_from {
            secret_ref {
              name = kubernetes_secret.postgres_credentials.metadata[0].name
            }
          }

          env {
            name  = "PGDATA"
            value = "/var/lib/postgresql/data/pgdata"
          }

          volume_mount {
            name       = "data"
            mount_path = "/var/lib/postgresql/data"
          }

          resources {
            requests = {
              cpu    = "250m"
              memory = "512Mi"
            }
            limits = {
              memory = "1Gi"
            }
          }

          readiness_probe {
            exec {
              command = ["pg_isready", "-U", var.db_username]
            }
            initial_delay_seconds = 10
            period_seconds        = 5
          }
        }
      }
    }

    volume_claim_template {
      metadata {
        name = "data"
      }
      spec {
        access_modes       = ["ReadWriteOnce"]
        storage_class_name = "gp3"
        resources {
          requests = {
            storage = "${var.db_storage_gb}Gi"
          }
        }
      }
    }
  }
}

# Headless service: uso interno do cluster (pods da aplicação principal),
# com DNS estável por pod padrão de StatefulSet.
resource "kubernetes_service" "postgres_clusterip" {
  metadata {
    name      = "postgres"
    namespace = kubernetes_namespace.database.metadata[0].name
  }

  spec {
    selector   = { app = "postgres" }
    cluster_ip = "None"

    port {
      port        = 5432
      target_port = 5432
    }
  }
}

# NLB interno: a Lambda de autenticação (fiap-tc3-lambda-auth) roda fora do
# cluster, numa ENI própria na mesma VPC — não alcança um ClusterIP (só
# existe via iptables dos nós). Precisa de um endereço com presença real na
# VPC, daí o Network Load Balancer interno gerenciado pelo AWS Load Balancer
# Controller (já instalado em fiap-tc3-infra-k8s).
resource "kubernetes_service" "postgres_nlb" {
  metadata {
    name      = "postgres-nlb"
    namespace = kubernetes_namespace.database.metadata[0].name
    annotations = {
      "service.beta.kubernetes.io/aws-load-balancer-type"   = "nlb-ip"
      "service.beta.kubernetes.io/aws-load-balancer-scheme" = "internal"
    }
  }

  wait_for_load_balancer = true

  spec {
    type     = "LoadBalancer"
    selector = { app = "postgres" }

    port {
      port        = 5432
      target_port = 5432
    }
  }
}

resource "aws_secretsmanager_secret" "db_credentials" {
  name = "fiap-tc3/${var.ambiente}/db-credentials"
}

resource "aws_secretsmanager_secret_version" "db_credentials" {
  secret_id = aws_secretsmanager_secret.db_credentials.id
  secret_string = jsonencode({
    username = var.db_username
    password = random_password.db_master.result
    dbname   = var.db_name
  })
}

# Publicados para os repositórios fiap-tc3-lambda-auth e fiap-TC1-oficina
# lerem sem precisar de acesso ao state deste repositório — mesmo nome de
# sempre, só o valor por trás mudou de RDS para o NLB do StatefulSet.
resource "aws_ssm_parameter" "rds_endpoint" {
  name  = "/fiap-tc3/${var.ambiente}/rds-endpoint"
  type  = "String"
  value = kubernetes_service.postgres_nlb.status[0].load_balancer[0].ingress[0].hostname
}

resource "aws_ssm_parameter" "rds_secret_arn" {
  name  = "/fiap-tc3/${var.ambiente}/rds-secret-arn"
  type  = "String"
  value = aws_secretsmanager_secret.db_credentials.arn
}
