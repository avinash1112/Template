#!/bin/bash
set -Eeuo pipefail

# Load helpers
source /opt/php/lib/00-helpers.sh

# Injected into container at buildtime/runtime
port="${PHP_FPM_CONTAINER_PORT}"
ping_path="${PHP_CONFIG_FPM_PING_PATH}"

# Variables
host="$(get_hostname)"


# Wait for custom initialization to complete
for i in {1..20}; do
  if is_php_fpm_process_running; then break; fi
  sleep 1
done

# FPM must respond to ping over TCP
if ! fpm_ping_ok "${host}" "${port}" "${ping_path}"; then
  echo_error "[LIVENESS] php-fpm ping failed (${host}:${port}${ping_path})"
  exit 1
fi

echo_success "[LIVENESS] All checks passed!"
exit 0
