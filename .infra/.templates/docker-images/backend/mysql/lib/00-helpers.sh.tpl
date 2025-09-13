# Get current timestamp
_log_time() {
  date "+%Y-%m-%d %H:%M:%S"
}


# Echo info
echo_info() {
  echo "$(_log_time) INFO:: $*"
}


# Echo warning
echo_warn() {
  echo "$(_log_time) WARNING:: $*" >&2
}


# Echo error
echo_error() {
  echo "$(_log_time) ERROR:: $*" >&2
}


# Echo success
echo_success() {
  echo "$(_log_time) SUCCESS:: $*"
}


# Get hostname
get_hostname() {

  if command -v hostname >/dev/null 2>&1; then
   hostname

  elif [[ -r /etc/hostname ]]; then
    cat /etc/hostname

  else
    echo "null"
  fi

}


# Get the role of the current instance
get_role() {

  local host_name="$(get_hostname)"
  local ordinal=$(echo "${host_name}" | sed -E 's/.*-([0-9]+)$/\1/')

  case "${ordinal}" in
    0)
      echo "master"
    ;;

    [1-9]*)
      echo "replica"
    ;;

    *)
      echo "null"
    ;;
  esac
}


# Get the server id of the current instance
get_server_id() {
  
  local host_name="$(get_hostname)"
  local ordinal=$(echo "${host_name}" | sed -E 's/.*-([0-9]+)$/\1/')

  case "${ordinal}" in
    ''|*[!0-9]*)
      # Not a number → return 0 to indicate failure
      echo "0"
      ;;
    *)
      # Add 100 to ordinal
      echo $((ordinal + 100))
      ;;
  esac
}


# Use extra file to avoid exposing the password on the process list
create_creds_file() {
  local user="${1}"
  local password="${2}"
  local host="${3:-$(get_hostname)}"

  local owner_name="${MYSQL_CONTAINER_RUNTIME_USER_NAME}"
  local owner_group="${MYSQL_CONTAINER_RUNTIME_USER_GROUP}"
  local port="${MYSQL_CONTAINER_PORT}"

  local file=$(mktemp)
  chown ${owner_name}:${owner_group} "${file}"
  chmod 600 "${file}"

  {
    echo "[client]"
    echo "user=${user}"
    echo "password=${password}"
    echo "host=${host}"
    echo "port=${port}"
    echo "protocol=TCP"    
    echo "ssl-mode=VERIFY_IDENTITY"
    echo "ssl-ca=/etc/ssl/certs/mysql/clients/${user}/ca.pem"
    echo "ssl-cert=/etc/ssl/certs/mysql/clients/${user}/leaf.pem"
    echo "ssl-key=/etc/ssl/certs/mysql/clients/${user}/key.pem"
  } > "${file}"

  echo "${file}"
}


# MySQL ping
mysql_ping() {
  local creds="$1"
  local host="${2:-$(get_hostname)}"
  local port="${3:-$MYSQL_CONTAINER_PORT}"
  mysqladmin --defaults-extra-file="${creds}" --host="${host}" --port="${port}" ping --silent >/dev/null 2>&1
}


# Run a mysql query
run_query() {
  local creds="${1}"
  local sql="${2}"
  local format_opts="${3:--Nse}"
  mysql --defaults-extra-file="${creds}" $format_opts "${sql}"
}


# Check if mysql is ready
is_ready() {
  local creds="${1}"
  local query="SELECT 1;"

  run_query "${creds}" "${query}" >/dev/null 2>&1 && return 0 || return 1
}


# Check if instance is master
is_master() {
  [[ "$(get_role)" == "master" ]]
}


# Check if instance is a replica
is_replica() {
  [[ "$(get_role)" == "replica" ]]
}


# Check if root account has been locked
initialized() {
  [[ -f "${INIT_MARKER}" ]] && return 0 || return 1
}


# Get parsed subject for a user
get_parsed_subject() {
  local user="${1}"
  openssl x509 -in "/etc/ssl/certs/mysql/clients/${user}/leaf.pem" -noout -subject | sed -E 's/^subject= ?//;s/, /\//g'
}


# Get parsed client subject for a user
get_parsed_issuer() {
  local user="${1}"
  openssl x509 -in "/etc/ssl/certs/mysql/clients/${user}/leaf.pem" -noout -issuer | sed -E 's/^issuer= ?//;s/, /\//g'
}


# Configure instance
configure_instance() {
  case "${role}" in
  master)  configure_master;;
  replica) configure_replica;;
  *)       echo_error "[ENTRYPOINT] Unknown role: ${role}"; return 1 ;;
esac

}


# Configure master
configure_master() {
  local owner_name="${MYSQL_CONTAINER_RUNTIME_USER_NAME}"
  local owner_group="${MYSQL_CONTAINER_RUNTIME_USER_GROUP}"
  local root_password="${MYSQL_ROOT_PASSWORD}"
  local super_user_name="${MYSQL_SUPER_USER_NAME}"
  local super_user_password="${MYSQL_SUPER_USER_PASSWORD}"
  local rw_user_name="${MYSQL_RW_USER_NAME}"
  local ro_user_name="${MYSQL_RO_USER_NAME}"
  local init_marker="${INIT_MARKER}"

  for i in {1..60}; do
    if mysqladmin ping --silent; then break; fi
    echo_info "[ENTRYPOINT] Master => Waiting for MySQL process to respond... (${i}/60)"
    sleep 1
  done

  if ! mysqladmin ping --silent; then
    echo_error "[ENTRYPOINT] Master => Timeout waiting for MySQL to come online"
    return 1
  fi
  
  if initialized; then
    echo_info "[ENTRYPOINT] Master => Already configured."
    return 0
  fi

  local root_creds
  root_creds=$(create_creds_file "root" "${root_password}")

  local su_creds
  su_creds=$(create_creds_file "${super_user_name}" "${super_user_password}")

  trap "rm -f '${root_creds}' '${su_creds}'" RETURN

  for i in {1..60}; do
    if is_ready "${root_creds}"; then break; fi
    echo_info "[ENTRYPOINT] Master => Waiting to be ready for authenticated queries... (${i}/60)"
    sleep 1
  done
  if ! is_ready "${root_creds}"; then
    echo_error "[ENTRYPOINT] Master => Timeout waiting for MySQL to accept authenticated queries"
    return 1
  fi

  echo_info "[ENTRYPOINT] Master => Running configuration script"

  local -r super_user_parsed_subject=$(get_parsed_subject "${super_user_name}")
  local -r super_user_parsed_issuer=$(get_parsed_issuer "${super_user_name}")
  local -r rw_user_parsed_subject=$(get_parsed_subject "${rw_user_name}")
  local -r rw_user_parsed_issuer=$(get_parsed_issuer "${rw_user_name}")
  local -r ro_user_parsed_subject=$(get_parsed_subject "${ro_user_name}")
  local -r ro_user_parsed_issuer=$(get_parsed_issuer "${ro_user_name}")

  envsubst < "/opt/mysql/sql/master.sql" | mysql --defaults-extra-file="${root_creds}"

  echo_info "[ENTRYPOINT] Master => Locking root user and finalizing post-init"
  local query="ALTER USER 'root'@'localhost' ACCOUNT LOCK;ALTER USER 'root'@'%' ACCOUNT LOCK;"
  
  if run_query "${su_creds}" "${query}"; then
    touch "${init_marker}"
    chown ${owner_name}:${owner_group} "${init_marker}"
    chmod 0400 "${init_marker}"
    echo_info "[ENTRYPOINT] Master => Custom initialization complete"
    return 0
  fi

  echo_error "[ENTRYPOINT] Master => Failed to complete initialization steps"
  return 1
}


# Configure replica
configure_replica() {
  local owner_name="${MYSQL_CONTAINER_RUNTIME_USER_NAME}"
  local owner_group="${MYSQL_CONTAINER_RUNTIME_USER_GROUP}"
  local master_host_name="${MYSQL_MASTER_HOST_NAME}"
  local root_password="${MYSQL_ROOT_PASSWORD}"
  local super_user_name="${MYSQL_SUPER_USER_NAME}"
  local super_user_password="${MYSQL_SUPER_USER_PASSWORD}"
  local init_marker="${INIT_MARKER}"

  for i in {1..60}; do
    if mysqladmin ping --silent; then break; fi
    echo_info "[ENTRYPOINT] Replica => Waiting for MySQL process to respond... (${i}/60)"
    sleep 1
  done

  if ! mysqladmin ping --silent; then
    echo_error "[ENTRYPOINT] Timeout waiting for MySQL to come online"
    return 1
  fi

  local master_creds
  master_creds=$(create_creds_file "${super_user_name}" "${super_user_password}" "${master_host_name}")

  for i in {1..60}; do
    if mysql_ping "${master_creds}"; then break; fi
    echo_info "[ENTRYPOINT] Replica => Waiting for master MySQL to be ready at host: ${master_host_name}... ($i/60)"
    sleep 1
  done

  if ! mysql_ping "${master_creds}"; then
    echo_error "[ENTRYPOINT] Timeout waiting for master to come online"
    return 1
  fi

  echo_info "[ENTRYPOINT] Replica => Master is now accepting connections. Initializing replication config."

  local instance_creds
  if initialized; then
    instance_creds=$(create_creds_file "${super_user_name}" "${super_user_password}")
  else
    instance_creds=$(create_creds_file "root" "${root_password}")
  fi
  trap "rm -f '${master_creds}' '${instance_creds}'" RETURN
  
  for i in {1..60}; do
    if is_ready "${instance_creds}"; then break; fi
    echo_info "[ENTRYPOINT] Replica => Waiting to be ready for authenticated queries... (${i}/60)"
    sleep 1
  done

  if ! is_ready "${instance_creds}"; then
    echo_error "[ENTRYPOINT] Master => Timeout waiting for MySQL to accept authenticated queries"
    return 1
  fi
  
  echo_info "[ENTRYPOINT] Replica => Replica is now accepting connections. Proceeding replication config."

  # Turn read only mode off (if its on)
  run_query "${instance_creds}" "SET GLOBAL super_read_only=OFF; SET GLOBAL read_only=OFF;" "-e" 2> >(while read -r l; do echo_error "[ENTRYPOINT] $l" |& tee -a "${log_file}"; done)

  # Apply configuration
  envsubst < "/opt/mysql/sql/replica.sql" | mysql --defaults-extra-file="${instance_creds}"

  # Turn read only mode on
  run_query "${instance_creds}" "SET GLOBAL read_only=ON; SET GLOBAL super_read_only=ON;" "-e" 2> >(while read -r l; do echo_error "[ENTRYPOINT] $l" |& tee -a "${log_file}"; done)

  for i in {1..90}; do

    # At least one replication connection present
    conn_rows=$(run_query "${instance_creds}" "SELECT COUNT(*) FROM performance_schema.replication_connection_status;")

    # I/O thread ON?
    io_on=$(run_query "${instance_creds}" "SELECT COUNT(*) FROM performance_schema.replication_connection_status WHERE SERVICE_STATE='ON';")

    # SQL (applier) ON?
    sql_on=$(run_query "${instance_creds}" "SELECT COUNT(*) FROM performance_schema.replication_applier_status WHERE SERVICE_STATE='ON';")

    if (( conn_rows > 0 && io_on > 0 && sql_on > 0 )); then
      touch "${init_marker}"
      chown ${owner_name}:${owner_group} "${init_marker}"
      chmod 0400 "${init_marker}"
      echo_info "[ENTRYPOINT] Replica => Replica is healthy and replicating"
      return 0
    fi
    echo_info "[ENTRYPOINT] Replica => Waiting for replica to report healthy replication status... ($i/90)"
    sleep 1
  done

  echo_error "[ENTRYPOINT] Replica => Replica did not reach healthy state within 90 seconds"
  return 1
}
