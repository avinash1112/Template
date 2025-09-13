#!/bin/bash
set -Eeuo pipefail

# Load helpers
source /opt/nginx/lib/00-helpers.sh

# Injected into container at buildtime/runtime
ping_path="${NGINX_CONFIG_PING_PATH}"
stub_path="${NGINX_CONFIG_STUB_STATUS_PATH}"

# Variables
host="127.0.0.1"
port="80"
scheme="http"
timeout_s="3"
max_active=2000
max_listen_q=50
max_reading=200
max_writing=500
max_waiting=1500
url_main="${scheme}://${host}:${port}${ping_path}"
url_stub="${scheme}://${host}:${port}${stub_path}"


# 1) Nginx must answer on the ready endpoint with 2xx/3xx
code="$(http_status "${scheme}" "${host}" "${port}" "${ping_path}" || echo)"
case "${code}" in
  2??|3??) ;;

  *)
    [[ -z "${code}" ]] && code="(no-response)"
    echo_error "[READINESS] Unexpected status ${code} at ${url_main}"
    exit 1
    ;;
esac


# 2) Stub_status sanity
stub="$(http_get "${url_stub}" 2>/dev/null || true)"

# Expected stub_status format:
# Active connections: 5
# server accepts handled requests
# 12345 12345 67890
# Reading: 0 Writing: 1 Waiting: 4
if ! grep -q '^Active connections:' <<<"${stub}"; then
  echo_error "[READINESS] stub_status not available at ${url_stub}"
  exit 1
fi

# Parse metrics
active="$(awk '/^Active connections:/ {print $3}' <<<"${stub}" | xargs)"
listen_q="$(awk '/^server accepts handled requests/{getline; print $1-$2}' <<<"${stub}" | xargs)"
reading="$(awk '/^Reading:/ {print $2}' <<<"${stub}" | xargs)"
writing="$(awk '/^Writing:/ {print $4}' <<<"${stub}" | xargs)"
waiting="$(awk '/^Waiting:/ {print $6}' <<<"${stub}" | xargs)"

# Enforce thresholds
if (( active > max_active  )); then 
  echo_error "[READINESS] active=${active} > max=${max_active}"
  exit 1
fi

if (( listen_q > max_listen_q )); then
  echo_error "[READINESS] listen_q=${listen_q} > max=${max_listen_q}"
  exit 1
fi

if (( reading > max_reading )); then
  echo_error "[READINESS] reading=${reading} > max=${max_reading}"
  exit 1
fi

if (( writing > max_writing )); then
  echo_error "[READINESS] writing=${writing} > max=${max_writing}"
  exit 1
fi

if (( waiting > max_waiting )); then
  echo_error "[READINESS] waiting=${waiting} > max=${max_waiting}"
  exit 1
fi

echo_success "[READINESS] All checks passed!"
exit 
