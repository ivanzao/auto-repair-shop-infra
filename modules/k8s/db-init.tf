resource "kubernetes_secret" "db_init_credentials" {
  metadata {
    name      = "db-init-credentials"
    namespace = local.app_namespace
  }
  data = {
    POSTGRES_PASSWORD   = var.db_master_password
    GRAFANA_DB_PASSWORD = var.grafana_db_password
    APP_DB_PASSWORD     = var.db_app_password
  }
  type       = "Opaque"
  depends_on = [kubernetes_namespace.app]
}

resource "kubernetes_job_v1" "db_init" {
  metadata {
    // Hash the credential triggers into the name so password rotations create
    // a fresh job (otherwise the existing Job is immutable and won't re-run).
    name      = "db-init-${substr(sha1("${var.db_master_password}${var.grafana_db_password}${var.db_app_password}${var.rds_endpoint}"), 0, 8)}"
    namespace = local.app_namespace
  }

  spec {
    backoff_limit              = 5
    ttl_seconds_after_finished = 3600

    template {
      metadata {}
      spec {
        restart_policy = "OnFailure"

        container {
          name  = "psql"
          image = "postgres:16-alpine"

          env {
            name  = "PGHOST"
            value = var.rds_endpoint
          }
          env {
            name  = "PGUSER"
            value = "postgres"
          }
          env {
            name = "PGPASSWORD"
            value_from {
              secret_key_ref {
                name = kubernetes_secret.db_init_credentials.metadata[0].name
                key  = "POSTGRES_PASSWORD"
              }
            }
          }
          env {
            name = "GRAFANA_PW"
            value_from {
              secret_key_ref {
                name = kubernetes_secret.db_init_credentials.metadata[0].name
                key  = "GRAFANA_DB_PASSWORD"
              }
            }
          }
          env {
            name = "APP_PW"
            value_from {
              secret_key_ref {
                name = kubernetes_secret.db_init_credentials.metadata[0].name
                key  = "APP_DB_PASSWORD"
              }
            }
          }
          env {
            name  = "ENV"
            value = var.environment
          }

          command = ["sh", "-c"]
          args = [<<-EOT
            set -e
            echo "Initializing DBs for env $ENV..."

            # Roles — idempotent via DO blocks.
            psql <<SQL
            DO \$\$
            BEGIN
              IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'grafana_$ENV') THEN
                EXECUTE format('CREATE ROLE grafana_%I WITH LOGIN PASSWORD %L', '$ENV', '$GRAFANA_PW');
              ELSE
                EXECUTE format('ALTER ROLE grafana_%I WITH LOGIN PASSWORD %L', '$ENV', '$GRAFANA_PW');
              END IF;
              IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'app_$ENV') THEN
                EXECUTE format('CREATE ROLE app_%I WITH LOGIN PASSWORD %L', '$ENV', '$APP_PW');
              ELSE
                EXECUTE format('ALTER ROLE app_%I WITH LOGIN PASSWORD %L', '$ENV', '$APP_PW');
              END IF;
            END
            \$\$;
            SQL

            # Databases — CREATE DATABASE can't run inside a transaction, so
            # do these via shell-level idempotency checks.
            psql -tc "SELECT 1 FROM pg_database WHERE datname='grafana_$ENV'" | grep -q 1 || \
              psql -c "CREATE DATABASE grafana_$ENV OWNER grafana_$ENV;"

            psql -tc "SELECT 1 FROM pg_database WHERE datname='auto_repair_shop_$ENV'" | grep -q 1 || \
              psql -c "CREATE DATABASE auto_repair_shop_$ENV OWNER app_$ENV;"

            # Schema grants — safe to re-grant.
            psql -d grafana_$ENV -c "GRANT ALL ON SCHEMA public TO grafana_$ENV;"
            psql -d auto_repair_shop_$ENV -c "GRANT ALL ON SCHEMA public TO app_$ENV;"

            echo "DB init complete."
          EOT
          ]
        }
      }
    }
  }

  wait_for_completion = true
  timeouts {
    create = "10m"
    update = "10m"
  }

  depends_on = [kubernetes_secret.db_init_credentials]
}
