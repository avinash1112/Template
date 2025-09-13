#!/bin/bash
set -Eeuo pipefail

# Load helpers
source /opt/php/lib/00-helpers.sh

# Injected into container at buildtime/runtime
port="${PHP_FPM_CONTAINER_PORT}"
ping_path="${PHP_CONFIG_FPM_PING_PATH}"
status_path="${PHP_CONFIG_FPM_STATUS_PATH}"

# Variables
host="$(get_hostname)"
laravel_health_endpoint="/up"


# Wait for custom initialization to complete
for i in {1..20}; do
  if is_php_fpm_process_running; then break; fi
  sleep 1
done


# 1) FPM ping must work
if ! fpm_ping_ok "${host}" "${port}" "${ping_path}"; then
  echo_error "[LIVENESS] php-fpm ping failed (${host}:${port}${ping_path})"
  exit 1
fi


# 2) FPM status must look sane (at least 1 idle or total processes > 0)
status="$(fpm_status_get "${host}" "${port}" "${status_path}")"

# Common fields: pool, process manager, start time, accepted conn, listen queue, max children reached,
# active processes, idle processes, total processes, slow requests, etc.
active="$(printf '%s\n' "${status}" | awk -F': ' '$1=="active processes"{print $2}' | xargs)"
idle="$(printf  '%s\n' "${status}" | awk -F': ' '$1=="idle processes"{print $2}' | xargs)"
total="$(printf '%s\n' "${status}" | awk -F': ' '$1=="total processes"{print $2}' | xargs)"

# Basic sanity: numeric and >0
[[ "${total}" =~ ^[0-9]+$ ]] || { echo_error "[READINESS] invalid total processes in /status"; exit 1; }
if (( total == 0 )); then
  echo_error "[READINESS] no php-fpm workers running (total=0)"
  exit 1
fi

[[ "${idle}" =~ ^[0-9]+$ ]] || { echo_error "[READINESS] invalid idle processes in /status"; exit 1; }
if (( idle < 1 )); then
  echo_error "[READINESS] insufficient idle processes (idle=${idle} < 1)"
  exit 1
fi

# 3) App-level health script via FPM (returns plain "OK")
if ! fpm_app_ok "${host}" "${port}" "${laravel_health_endpoint}"; then
  echo_error "[READINESS] App ready script failed (${laravel_health_endpoint})"
  exit 1
fi


echo_success "[READINESS] All checks passed!"
exit 0
