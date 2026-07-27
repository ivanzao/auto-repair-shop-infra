#!/usr/bin/env bash
# admin-bootstrap.sh: cria um usuário admin no DB (idempotente)
# para uso futuro no login da API.
#
# Uso:
#   ./scripts/admin-bootstrap.sh [prod|hml] [cpf] [senha]
#
# Defaults: env=prod, cpf=11144477735, senha=admin123
#
# Pré-requisitos: aws cli, kubectl, python3 com módulo `bcrypt`, jq

set -euo pipefail

ENV="${1:-prod}"
CPF="${2:-11144477735}"
PASS="${3:-admin123}"

if [[ "$ENV" != "prod" && "$ENV" != "hml" ]]; then
  echo "uso: $0 [prod|hml] [cpf] [senha]" >&2
  exit 1
fi
if ! python3 -c "import bcrypt" 2>/dev/null; then
  echo "✗ python3 -m bcrypt não disponível. Instale: pip install bcrypt" >&2
  exit 1
fi

NAMESPACE="auto-repair-shop-$ENV"

DB_SECRET_ARN=$(aws ssm get-parameter \
  --name "/auto-repair-shop/$ENV/db/secret-arn" \
  --query Parameter.Value --output text)
DB_JSON=$(aws secretsmanager get-secret-value \
  --secret-id "$DB_SECRET_ARN" --query SecretString --output text)
DB_HOST=$(echo "$DB_JSON" | jq -r .host)
DB_USER=$(echo "$DB_JSON" | jq -r .username)
DB_PASS=$(echo "$DB_JSON" | jq -r .password)
DB_NAME=$(echo "$DB_JSON" | jq -r .dbname)

HASH=$(python3 -c "import bcrypt; print(bcrypt.hashpw(b'$PASS', bcrypt.gensalt(rounds=10)).decode())")
UUID=$(python3 -c 'import uuid; print(uuid.uuid4())')

echo "→ env=$ENV cpf=$CPF (senha hash gerada)"
echo "→ pod psql temp ..."

kubectl run "psql-admin-bootstrap-$$" -n "$NAMESPACE" \
  --rm -i --restart=Never --image=postgres:16-alpine \
  --env="PGHOST=$DB_HOST" --env="PGUSER=$DB_USER" \
  --env="PGPASSWORD=$DB_PASS" --env="PGDATABASE=$DB_NAME" \
  --command -- psql -v ON_ERROR_STOP=1 -c "
    CREATE TABLE IF NOT EXISTS users (
      id              UUID         PRIMARY KEY,
      document        VARCHAR(20)  NOT NULL UNIQUE,
      role            VARCHAR(20)  NOT NULL,
      hashed_password VARCHAR(255) NOT NULL,
      status          VARCHAR(20)  NOT NULL DEFAULT 'ACTIVE',
      attendant_id    UUID         UNIQUE,
      created_at      TIMESTAMP    NOT NULL DEFAULT NOW(),
      modified_at     TIMESTAMP    NOT NULL DEFAULT NOW(),
      version         INTEGER      NOT NULL DEFAULT 0,
      CONSTRAINT users_role_check CHECK (role IN ('ADMIN', 'ATTENDANT')),
      CONSTRAINT users_status_check CHECK (status IN ('ACTIVE', 'INACTIVE'))
    );

    INSERT INTO users (id, document, role, hashed_password, status)
    VALUES ('$UUID', '$CPF', 'ADMIN', '$HASH', 'ACTIVE')
    ON CONFLICT (document) DO UPDATE
      SET hashed_password = EXCLUDED.hashed_password,
          role            = 'ADMIN',
          status          = 'ACTIVE',
          modified_at     = NOW();

    INSERT INTO attendants (id, name, document, email, contact)
    SELECT u.id, 'Admin Bootstrap', u.document, 'admin@dev.com', '11999990000'
      FROM users u WHERE u.document = '$CPF'
    ON CONFLICT (id) DO NOTHING;

    SELECT u.id, u.document, u.role, u.status
      FROM users u WHERE u.document = '$CPF';
  " 2>&1 | tail -8

echo ""
echo "✓ Admin pronto:"
echo "  cpf:    $CPF"
echo "  senha:  $PASS"
echo ""
echo "Login:"
echo "  curl -X POST <api>/auth/login -H 'Content-Type: application/json' \\"
echo "    -d '{\"cpf\":\"$CPF\",\"password\":\"$PASS\"}'"
