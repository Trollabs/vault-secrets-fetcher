#!/bin/bash

set -Eeuo pipefail

export TMPDIR=${TMPDIR:-/tmp}

tmp_file() {
  local name="$1"
  mktemp "$TMPDIR/$1.XXXXXX"
}

log() {
  local message="$(date -u '+%F %T'): $1"
  echo -e "$message" >&2
}

call_vault_api() {
  # $1 host
  # $2 path
  # $3 token
  # $4 data
  # $5 HTTP Method (default: POST if data is present, GET it not)
  # $6 Skip SSL verification
  local host="$1"
  local path="$2"
  local token="${3:-}"
  local data="${4:-}"
  local method="${5:-}"
  local skip_ssl_verification=${6:-"false"}
  local api_version="v1"

  local request_url="$host/$api_version/$path"
  request_data="$(tmp_file data)"
  response="$(tmp_file response)"

  cleanup() {
    rm -f "$request_data"
    rm -f "$response"
  }

  report() {
    log "Vault request $request_url failed"
    exit 1
  }

  trap report ERR
  trap cleanup EXIT

  local extra_options=""

  if [ -n "$data" ]; then
    method=${method:-POST}
    echo "$data" | jq -c '.' > "$request_data"
    extra_options+="-H \"Content-Type: application/json\" -d @$request_data"
  fi

  if [ -n "$method" ]; then
    extra_options+=" -X $method"
  fi

  if [ "$skip_ssl_verification" = "true" ]; then
    extra_options+=" -k"
  fi

  if [ -n "$token" ]; then
    extra_options+=" -H \"X-Vault-Token: $token\""
  fi

  code="$(eval "curl -s -w "%{response_code}" $extra_options -o $response $request_url")"

  if [ "$code" -ge "400" ]; then
      log "Error($code):\n $(jq .errors $response)"
    exit 1
  else
    log "Success($code)"
    jq -c '.' $response
  fi

  cleanup
}

fetch_secrets() {
  local host=$1
  local path=$2
  local role_id=$3
  local secret_id=$4
  log "Login..."
  token="$(call_vault_api "$host" "auth/approle/login" "" "{\"role_id\":\"$role_id\",\"secret_id\":\"$secret_id\"}" | jq -r '.auth.client_token')"
  log "Get secrets list..."
  secrets="$(call_vault_api "$host" "$path" "${token}" "" "LIST" | jq -r '.data.keys[]')"
  log "Inject secrets..."
  for secret in $secrets; do
    log "Injecting \"$secret\"..."
    export $secret="$(call_vault_api "$host" "$path/$secret" "$token" | jq -r '.data.value')"
  done
}


# if there is no envvars file it'll attempt to get environment variables
. ./envvars || true

fetch_secrets "$VAULT_URL" "$KV_PATH_PREFIX/$ENVIRONMENT" "$APP_ROLE_ID" "$APP_ROLE_SECRET_ID"

exec "$@"
