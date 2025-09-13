#!/usr/bin/env bash
set -Eeuo pipefail

# Load helpers
source /opt/mysql/lib/00-helpers.sh

# Injected into container at buildtime/runtime
port="${MYSQL_CONTAINER_PORT}"
super_user_name="${MYSQL_SUPER_USER_NAME}"
super_user_password="${MYSQL_SUPER_USER_PASSWORD}"

# Variables
host="$(get_hostname)"
timeout="2"


# Create creds file
creds=$(create_creds_file "${super_user_name}" "${super_user_password}" "${host}")
trap "rm -f '${creds}'" EXIT


# Perform liveness check
if ! timeout "${timeout}" mysql_ping "${creds}" "${host}" "${port}"; then
  echo_error "[LIVENESS] mysqld is not responding (TCP ${host}:${port})"
  exit 1
fi

echo_success "[LIVENESS] All checks passed!"
exit 0
