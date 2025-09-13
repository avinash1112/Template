#!/bin/bash
set -Eeuo pipefail

# Load helpers
source /opt/mysql/lib/00-helpers.sh

# Injected into container at buildtime/runtime
owner_name="${MYSQL_CONTAINER_RUNTIME_USER_NAME}"
owner_group="${MYSQL_CONTAINER_RUNTIME_USER_GROUP}"

# Export for latest use across container
export INIT_MARKER="/var/mysql/info/init-completed"
export CONF_FILE="/var/mysql/info/01-instance.cnf"


# Determine role
role="$(get_role)"
if [[ "${role}" == "null" ]]; then
  echo_error "[ENTRYPOINT] Failed to determine instance role"
  exit 1
fi


# Determine server id
server_id="$(get_server_id)"
if [[ "${server_id}" -eq 0 ]]; then
  echo_error "[ENTRYPOINT] Failed to get server id."
  exit 1
fi

echo_info "[ENTRYPOINT] Updating runtime conf file"
conf_file="${CONF_FILE}"
tmp_file="${conf_file}.tmp"

{
  echo "[mysqld]"
  echo "server-id=${server_id}"
  if is_replica; then
    echo "relay-log=/var/lib/mysql/mysql-relay-bin"
    echo "relay-log-index=/var/lib/mysql/mysql-relay-bin.index"
    echo "relay_log_purge=ON"
  fi
} > "${tmp_file}"

chown "${owner_name}:${owner_group}" "${tmp_file}"
chmod 0600 "${tmp_file}"
mv -f "${tmp_file}" "${conf_file}"


# Background logic depending on state and role
if ! initialized; then
  
  # Not initialized yet — wait for official init to finish and run config
  (
    for i in {1..60}; do
      if mysqladmin ping --silent; then
        echo_info "[ENTRYPOINT] Initializing new instance (${role})"
        configure_instance "${role}" "${server_id}"
        exit 0
      fi
      echo_info "[ENTRYPOINT] Waiting for official MySQL to finish startup... (${i}/60)"
      sleep 1
    done
    echo_error "[ENTRYPOINT] Timeout waiting for MySQL to be ready"
    exit 1
  ) &

# Already initialized & is a replica
elif is_replica; then
  (
    for i in {1..60}; do
      if mysqladmin ping --silent; then
        echo_info "[ENTRYPOINT] Already initialized ${role}. Reapplying ${role} configuration"
        configure_replica "${server_id}" 1
        exit 0
      fi
      echo_info "[ENTRYPOINT] Waiting for MySQL to be ready for ${role} re-sync... (${i}/60)"
      sleep 1
    done
    echo_error "[ENTRYPOINT] Timeout waiting for MySQL to come online"
    exit 1
  ) &

# Already initialized & is master
else
  echo_info "[ENTRYPOINT] Already initialized ${role}"
fi

# Final handoff
echo_info "[ENTRYPOINT] Handing off to the actual MySQL entrypoint"
exec docker-entrypoint.sh "$@"
