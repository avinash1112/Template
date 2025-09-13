#!/bin/bash
set -Eeuo pipefail

# Load helpers
source /opt/redis/lib/00-helpers.sh

# Injected into container at buildtime/runtime
port="${REDIS_CONTAINER_PORT}"
user="${REDIS_METRICS_USER_NAME}"
pass="${REDIS_METRICS_USER_PASSWORD}"

# Variables
host="$(get_hostname)"


# 1) TCP/TLS + AUTH + PING
if ! is_connected "${host}" "${port}" "${user}" "${pass}"; then
  echo_error "[LIVENESS] Unable to connect/auth to redis via TLS at ${host}:${port}"
  exit 1
fi


# 2) Not still loading dataset
loading="$(redis_cmd "${host}" "${port}" "${user}" "${pass}" INFO server | awk -F: '/^loading:/ {print $2}' | tr -d '\r')"
if [[ "${loading}" != "0" ]]; then
  echo_error "[LIVENESS] Redis still loading dataset (loading=${loading})"
  exit 1
fi

echo_success "[LIVENESS] All checks passed!"
exit 0
