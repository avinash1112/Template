#!/bin/bash
set -Eeuo pipefail

# Load helpers
source /opt/nginx/lib/00-helpers.sh

# Injected into container at buildtime/runtime
ping_path="${NGINX_CONFIG_PING_PATH}"

# Variables
scheme="http"
host="$(get_hostname)"
port="80"


# 1) Config sanity
if ! nginx_conf_ok; then
  echo_error "[LIVENESS] nginx -t failed"
  exit 1
fi

# 2) HTTP(S) status must be 200–399
code="$(http_status "${scheme}" "${host}" "${port}" "${ping_path}" || echo)"
case "${code}" in
  2??|3??)
    echo_success "[LIVENESS] All checks passed!"
    exit 0
  ;;

  *)
    [[ -z "${code}" ]] && code="(no-response)"
    echo_error "[LIVENESS] Unexpected status ${code} at ${url}"
    exit 1
  ;;
esac
