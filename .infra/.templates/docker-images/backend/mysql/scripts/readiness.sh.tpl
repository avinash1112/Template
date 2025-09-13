#!/usr/bin/env bash
set -Eeuo pipefail

# Load helpers
source /opt/mysql/lib/00-helpers.sh

# Injected into container at buildtime/runtime
port="${MYSQL_CONTAINER_PORT}"
root_password="${MYSQL_ROOT_PASSWORD}"
su_name="${MYSQL_SUPER_USER_NAME}"
su_password="${MYSQL_SUPER_USER_PASSWORD}"

# Variables
host="$(get_hostname)"
role="$(get_role)"
timeout="3"
max_lag="10"


# Check role
if [[ "${role}" == "null" ]]; then
  echo_error "[READINESS] Failed to determine instance role"
  exit 1
fi


# Creds file
root_creds="$(create_creds_file "root" "${root_password}" "${host}")"
su_creds="$(create_creds_file "${su_name}" "${su_password}" "${host}")"
trap 'rm -f "${root_creds}" "${su_creds}"' EXIT

# Wait for custom initialization to complete
for i in {1..90}; do
  if is_ready "${su_creds}"; then break; fi
  sleep 1
done

# Check server process
if ! mysql_ping "${su_creds}" "${host}" "${port}"; then
  echo_error "[READINESS] Cannot connect to mysqld via TCP (${host}:${port}) with super user"
  exit 1
fi

# Root must be locked
if is_ready "${root_creds}"; then
  echo_error "Root account is still accessible — expected to be locked"
  exit 1
fi


case "${role,,}" in
  master)

    # Must be writable
    writable="$(run_query "${su_creds}" "SELECT (@@GLOBAL.read_only=0 AND @@GLOBAL.super_read_only=0)+0;" )"
    if [[ "${writable//[[:space:]]/}" != "1" ]]; then
      ro="$(run_query "${su_creds}" "SELECT @@GLOBAL.read_only, @@GLOBAL.super_read_only;")"
      echo_error "[READINESS] Master not writable (read_only/super_read_only != 0) -> ${ro}"
      exit 1
    fi

    # Should not have replication configured
    conn_rows="$(run_query "${su_creds}" "SELECT COUNT(*) FROM performance_schema.replication_connection_status;" )"
    if (( conn_rows > 0 )); then
      echo_error "[READINESS] Master has replication connection(s) configured — unexpected"
      exit 1
    fi

    echo_success "[READINESS] All checks passed!"
    exit 0
  ;;

  replica)

    # Enforce read_only
    is_ro="$(run_query "${su_creds}" "SELECT @@GLOBAL.read_only;")"
    if [[ "${is_ro//[[:space:]]/}" != "1" ]]; then
      echo_error "[READINESS] Replica is not in read-only mode"
      exit 1
    fi

    # Enforce super_read_only
    is_sro="$(run_query "${su_creds}" "SELECT @@GLOBAL.super_read_only;")"
    if [[ "${is_sro//[[:space:]]/}" != "1" ]]; then
      echo_error "[READINESS] Replica is not in super-read-only mode"
      exit 1
    fi

    # Must have a replication connection row
    conn_rows="$(run_query "${su_creds}" "SELECT COUNT(*) FROM performance_schema.replication_connection_status;" )"
    if (( conn_rows == 0 )); then
      echo_error "[READINESS] Replica has no replication status (no connection rows)"
      exit 1
    fi

    # I/O thread must be ON
    io_on="$(run_query "${su_creds}" "SELECT COUNT(*) FROM performance_schema.replication_connection_status WHERE SERVICE_STATE='ON';" )"
    if (( io_on == 0 )); then
      echo_error "[READINESS] Replica I/O thread not running"
      exit 1
    fi

    # SQL (applier) thread must be running
    sql_on="$(run_query "${su_creds}" "SELECT COUNT(*) FROM performance_schema.replication_applier_status WHERE SERVICE_STATE='ON';" )"
    if (( sql_on == 0 )); then
      echo_error "[READINESS] Replica SQL (applier) thread not running"
      exit 1
    fi

    # Lag threshold (max across workers). NULL -> -1 (treat unknown as failure)
    lag=""

    # 1) by-worker table (preferred when available)
    lag="$(run_query "${su_creds}" "SELECT MAX(SECONDS_BEHIND_SOURCE) FROM performance_schema.replication_applier_status_by_worker;" 2>/dev/null || true)"

    # 2) single-row applier_status (some versions expose it here)
    if [[ -z "${lag}" ]]; then
      lag="$(run_query "${su_creds}" "SELECT SECONDS_BEHIND_SOURCE FROM performance_schema.replication_applier_status;" 2>/dev/null || true)"
    fi

    # 3) Fallback: parse SHOW REPLICA STATUS (Seconds_Behind_Source/Master)
    if [[ -z "${lag}" ]]; then
      lag="$(run_query "${su_creds}" "SHOW REPLICA STATUS\G" "-e" 2>/dev/null \
        | awk -F':[[:space:]]*' \
          '
            /^[[:space:]]*Seconds_Behind_Source:/ { print $2; exit }
          ' \
        | xargs
      )"
    fi

    # Normalize: treat NULL/empty as unknown
    if [[ -z "${lag}" || "${lag}" == "NULL" ]]; then
      echo_error "[READINESS] Replica lag unknown (no SECONDS_BEHIND_* available)"
      exit 1
    fi

    if (( lag > max_lag )); then
      echo_error "[READINESS] Replica lag ${lag}s exceeds threshold ${max_lag}s"
      exit 1
    fi

    echo_success "[READINESS] All checks passed!"
    exit 0
  ;;

  *)
    echo_error "[READINESS] Unknown role='${role}' (expected master|replica)"
    exit 1
  ;;
esac
