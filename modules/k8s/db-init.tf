locals {
  db_init = {
    for name, cfg in var.app_databases : name => {
      endpoint = cfg.endpoint
      role     = cfg.role
      db       = cfg.db
      pw       = var.app_db_passwords[name]
    }
  }
}

resource "kubernetes_secret" "db_init" {
  for_each = local.db_init

  metadata {
    name      = "db-init-${each.key}-credentials"
    namespace = local.app_namespace
  }
  data = {
    POSTGRES_PASSWORD = var.db_master_password
    ROLE_PASSWORD     = each.value.pw
  }
  type       = "Opaque"
  depends_on = [kubernetes_namespace.app]
}

resource "kubernetes_job_v1" "db_init" {
  for_each = local.db_init

  metadata {
    name      = "db-init-${each.key}-${substr(sha1("${var.db_master_password}${each.value.pw}${each.value.endpoint}"), 0, 8)}"
    namespace = local.app_namespace
  }

  spec {
    backoff_limit = 5

    template {
      metadata {}
      spec {
        restart_policy = "OnFailure"

        container {
          name  = "psql"
          image = "postgres:16-alpine"

          env {
            name  = "PGHOST"
            value = each.value.endpoint
          }
          env {
            name  = "PGUSER"
            value = "postgres"
          }
          env {
            name = "PGPASSWORD"
            value_from {
              secret_key_ref {
                name = kubernetes_secret.db_init[each.key].metadata[0].name
                key  = "POSTGRES_PASSWORD"
              }
            }
          }
          env {
            name = "ROLE_PW"
            value_from {
              secret_key_ref {
                name = kubernetes_secret.db_init[each.key].metadata[0].name
                key  = "ROLE_PASSWORD"
              }
            }
          }
          env {
            name  = "DB_ROLE"
            value = each.value.role
          }
          env {
            name  = "DB_NAME"
            value = each.value.db
          }

          command = ["sh", "-c"]
          args = [<<-EOT
            set -e
            echo "Initializing database $DB_NAME (role $DB_ROLE) on $PGHOST..."

            psql <<SQL
            DO \$\$
            BEGIN
              IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = '$DB_ROLE') THEN
                EXECUTE format('CREATE ROLE %I WITH LOGIN PASSWORD %L', '$DB_ROLE', '$ROLE_PW');
              ELSE
                EXECUTE format('ALTER ROLE %I WITH LOGIN PASSWORD %L', '$DB_ROLE', '$ROLE_PW');
              END IF;
            END
            \$\$;
            SQL

            psql -tc "SELECT 1 FROM pg_database WHERE datname='$DB_NAME'" | grep -q 1 || \
              psql -c "CREATE DATABASE $DB_NAME OWNER $DB_ROLE;"

            psql -d "$DB_NAME" -c "GRANT ALL ON SCHEMA public TO $DB_ROLE;"

            echo "DB init complete for $DB_NAME."
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

  depends_on = [kubernetes_secret.db_init]
}
