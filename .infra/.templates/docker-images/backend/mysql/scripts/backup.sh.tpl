#!/bin/bash
set -Eeuo pipefail

# Load helpers
source /opt/mysql/lib/00-helpers.sh

# Injected into container at buildtime/runtime
instance_role="$(get_role)"
super_user_name="${MYSQL_SUPER_USER_NAME}"
super_user_password="${MYSQL_SUPER_USER_PASSWORD}"

# Exported from entrypoint
backup_retention_days=7
backup_root_dir="/var/mysql/backup"

# Variables
timestamp=$(date +"%Y%m%d-%H%M%S")
backup_file="${backup_root_dir}/${timestamp}.sql.gz"
log_file="${backup_root_dir}/backup.log"


# Exit if replica (only master is allowed to perform backups)
if is_replica; then
  echo_info "[BACKUP] Skipping backup on replica node." | tee -a "${log_file}"
  exit 0
elif ! is_master; then
  echo_error "[BACKUP] Invalid or unknown role: ${instance_role}" |& tee -a "${log_file}"
  exit 1
fi
echo_info "[BACKUP] Detected master node. Proceeding with mysqldump" | tee -a "${log_file}"


# Create temp credentials file
su_creds=$(create_creds_file "${super_user_name}" "${super_user_password}")
trap "rm -f '${su_creds}'" EXIT


# List user (non-system) databases
mysql_out="$(
  mysql --defaults-extra-file="${su_creds}" -N -B -e \
    "SELECT SCHEMA_NAME
     FROM INFORMATION_SCHEMA.SCHEMATA
     WHERE SCHEMA_NAME NOT IN ('mysql','information_schema','performance_schema','sys')
     ORDER BY SCHEMA_NAME;" \
    2> >(while read -r line; do echo_error "[BACKUP] ${line}" |& tee -a "${log_file}"; done)
)"
mysql_rc=$?
if [ "${mysql_rc}" -ne 0 ]; then
  echo_error "[BACKUP] Failed to list databases (exit ${mysql_rc})" |& tee -a "${log_file}"
  exit 1
fi


# If no user DBs, bail
if [ -z "${mysql_out}" ]; then
  echo_warn "[BACKUP] No user databases found; nothing to back up." | tee -a "${log_file}"
  exit 0
fi


# Log the databases that will be dumped
echo_info "[BACKUP] User databases to dump:" | tee -a "${log_file}"
mapfile -t user_dbs <<< "${mysql_out}"
for db in "${user_dbs[@]}"; do
  echo_info "  - ${db}" | tee -a "${log_file}"
done


# Perform backup (only user DBs)
if mysqldump \
  --defaults-extra-file="${su_creds}" \
  --databases "${user_dbs[@]}" \
  --add-drop-database \
  --routines \
  --triggers \
  --events \
  --single-transaction \
  --set-gtid-purged=ON \
  | gzip > "${backup_file}"; then

  # Sanity check
  if [[ ! -s "${backup_file}" ]]; then
    echo_error "[BACKUP] Backup file is empty or failed!" |& tee -a "${log_file}"
    exit 1
  fi

  # Secure file
  chmod 600 "${backup_file}"

  # Success message
  echo_info "[BACKUP] Backup complete: ${backup_file}" | tee -a "${log_file}"

  # Prune old backups
  while IFS= read -r file; do
    echo_info "[BACKUP] Pruned: ${file}" | tee -a "${log_file}"
    rm -f "${file}" || true
  done < <(find "${backup_root_dir}" -type f -name '????????-??????.sql.gz' -mtime +"${backup_retention_days}" -print)

else
  echo_error "[BACKUP] Backup FAILED at ${timestamp}" |& tee -a "${log_file}"
  exit 1
fi
