#!/bin/sh
# Decodifica las credenciales Base64 de .env_encoded y ejecuta el comando recibido.
# Uso: sh scripts/with_snowflake_env.sh dbt build
set -eu

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
ENV_FILE="${ENV_FILE:-$SCRIPT_DIR/../../.env_encoded}"

# En Docker las variables ya vienen de env_file; localmente se leen del archivo.
if [ -z "${SECRET_SNOWFLAKE_ACCOUNT:-}" ]; then
  if [ ! -f "$ENV_FILE" ]; then
    echo "No se encontró $ENV_FILE" >&2
    exit 1
  fi
  set -a
  . "$ENV_FILE"
  set +a
fi

decode() { printf %s "$1" | base64 -d; }

SNOWFLAKE_ACCOUNT=$(decode "$SECRET_SNOWFLAKE_ACCOUNT")
SNOWFLAKE_USERNAME=$(decode "$SECRET_SNOWFLAKE_USERNAME")
SNOWFLAKE_ROLE=$(decode "$SECRET_SNOWFLAKE_ROLE")
SNOWFLAKE_WAREHOUSE=$(decode "$SECRET_SNOWFLAKE_WAREHOUSE")
SNOWFLAKE_DATABASE=$(decode "$SECRET_SNOWFLAKE_DATABASE")
SNOWFLAKE_PRIVATE_KEY_PASSWORD=$(decode "${SECRET_SNOWFLAKE_PRIVATE_KEY_PASSWORD:-}")
export SNOWFLAKE_ACCOUNT SNOWFLAKE_USERNAME SNOWFLAKE_ROLE SNOWFLAKE_WAREHOUSE \
  SNOWFLAKE_DATABASE SNOWFLAKE_PRIVATE_KEY_PASSWORD

# La clave privada se escribe en un archivo temporal que se borra al terminar.
umask 077
SNOWFLAKE_PRIVATE_KEY_PATH=$(mktemp)
export SNOWFLAKE_PRIVATE_KEY_PATH
trap 'rm -f "$SNOWFLAKE_PRIVATE_KEY_PATH"' EXIT
decode "$SECRET_SNOWFLAKE_PRIVATE_KEY" > "$SNOWFLAKE_PRIVATE_KEY_PATH"

"$@"
