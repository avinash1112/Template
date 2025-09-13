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
max_lag=10


# 1) Base connectivity + not loading
if ! is_connected "${host}" "${port}" "${user}" "${pass}"; then
  echo_error "[READINESS] Cannot connect/auth to redis via TLS (${host}:${port})"
  exit 1
fi

flags="$(redis_loading_flags "${host}" "${port}" "${user}" "${pass}")"
loading="${flags##*loading:}"
loading="${loading%% *}"
async_loading="${flags##*async_loading:}"

if [[ "${loading}" != "0" || "${async_loading}" != "0" ]]; then
  echo_error "[HEALTH] Redis still loading (loading=${loading}, async_loading=${async_loading})"
  exit 1
fi

# # 2) Determine role
# role_line="$(redis_cmd "${host}" "${port}" "${user}" "${pass}" ROLE 2>/dev/null | head -n1 || true)"

# case "${role_line}" in
#   master)
#     # Optional: verify primary is writable using a tiny ephemeral key.
#     if [[ "${require_primary_writable}" == "1" ]]; then
#       key="__health__:rw:$(date +%s%N)"
#       setok="$(redis_cmd "${host}" "${port}" "${user}" "${pass}" SET "${key}" "1" EX 5 NX 2>/dev/null || true)"
#       if [[ "${setok}" != "OK" ]]; then
#         echo_error "[READINESS] Primary appears not writable (SET returned '${setok}')"
#         exit 1
#       fi
#       # best-effort cleanup
#       redis_cmd "${host}" "${port}" "${user}" "${pass}" DEL "${key}" >/dev/null 2>&1 || true
#     fi

#     # Surface background persistence state (non-fatal)
#     pers_info="$(redis_cmd "${host}" "${port}" "${user}" "${pass}" INFO persistence 2>/dev/null || true)"
#     rdb_busy="$(awk -F: '/^rdb_bgsave_in_progress:/ {print $2}' <<<"${pers_info}" | tr -d '\r')"
#     aof_busy="$(awk -F: '/^aof_rewrite_in_progress:/ {print $2}' <<<"${pers_info}" | tr -d '\r')"

#     if [[ "${rdb_busy}" == "1" || "${aof_busy}" == "1" ]]; then
#       echo_success "[READINESS] Primary ready (bg rdb=${rdb_busy}, aof=${aof_busy})"
#     else
#       echo_success "[READINESS] Primary ready"
#     fi
#     exit 0
#     ;;

#   slave|replica)
#     # Replica: link up, not syncing, IO age within threshold
#     repl_info="$(redis_cmd "${host}" "${port}" "${user}" "${pass}" INFO replication 2>/dev/null || true)"

#     link_status="$(awk -F: '/^master_link_status:/ {print $2}' <<<"${repl_info}" | tr -d '\r')"
#     sync_in_prog="$(awk -F: '/^master_sync_in_progress:/ {print $2}' <<<"${repl_info}" | tr -d '\r')"
#     last_io="$(awk -F: '/^master_last_io_seconds_ago:/ {print $2}' <<<"${repl_info}" | tr -d '\r')"

#     if [[ "${link_status}" != "up" ]]; then
#       echo_error "[READINESS] Replica link down (master_link_status=${link_status})"
#       exit 1
#     fi
#     if [[ "${sync_in_prog}" != "0" ]]; then
#       echo_error "[READINESS] Replica still syncing (master_sync_in_progress=${sync_in_prog})"
#       exit 1
#     fi
#     [[ -n "${last_io}" && "${last_io}" =~ ^[0-9]+$ ]] || { echo_error "[READINESS] Invalid last_io='${last_io}'"; exit 1; }
#     if (( last_io > max_lag )); then
#       echo_error "[READINESS] Replica lag ${last_io}s exceeds threshold ${max_lag}s"
#       exit 1
#     fi

#     echo_success "[READINESS] Replica ready (last_io=${last_io}s ≤ ${max_lag}s)"
#     exit 0
#     ;;

#   *)
#     # Fallback: parse INFO replication role if ROLE output is unexpected
#     info_role="$(redis_cmd "${host}" "${port}" "${user}" "${pass}" INFO replication 2>/dev/null \
#                  | awk -F: '/^role:/ {print $2}' | tr -d '\r')"
#     if [[ "${info_role}" == "master" || "${info_role}" == "slave" || "${info_role}" == "replica" ]]; then
#       echo_success "[READINESS] Role via INFO: ${info_role} — minimal checks passed"
#       exit 0
#     fi
#     echo_error "[READINESS] Unknown role from ROLE: '${role_line}'"
#     exit 1
#     ;;
# esac

echo_success "[READINESS] All checks passed!"
exit 0
