#!/bin/bash
set -Eeuo pipefail

# Load helpers
source /opt/mysql/lib/00-helpers.sh

# Injected into container at buildtime/runtime
super_user_name="${MYSQL_SUPER_USER_NAME}"
super_user_password="${MYSQL_SUPER_USER_PASSWORD}"

# Variables
instance_role="$(get_role)"
backup_root_dir="/var/mysql/backup"
restore_root_dir="/var/mysql/restore"
info_file="${restore_root_dir}/restore-info"
log_file="${restore_root_dir}/restore.log"
creds="$(create_creds_file "${super_user_name}" "${super_user_password}")"

trap "rm -f '${creds}'" EXIT

# Perform restore
case "${instance_role,,}" in

  # Restore master instance from latest backup file
  master)

    _import_dump() {
      local file="${1}"
      if gunzip -c "${file}" \
          | mysql --defaults-extra-file="${creds}" \
              2> >(while read -r line; do echo_error "[RESTORE] ${line}" |& tee -a "${log_file}"; done)
      then return 0; fi
      return 1
    }

    declare -a backup_files=()
    mapfile -t backup_files < <(
      (
        shopt -s nullglob
        files=( "${backup_root_dir}"/????????-??????.sql.gz )
        ((${#files[@]})) && ls -1t -- "${files[@]}"
      )
    )

    if ((${#backup_files[@]} == 0)); then
      echo_error "[RESTORE] No backup files found in '${backup_root_dir}'" |& tee -a "${log_file}"
      exit 1
    fi
    echo_info "[RESTORE] Found ${#backup_files[@]} backup(s) to consider." |& tee -a "${log_file}"

    for file in "${backup_files[@]}"; do
      echo_info "[RESTORE] Attempting restore from: ${file}" |& tee -a "${log_file}"

      echo_warn "[RESTORE] Resetting binary logs and GTIDs" |& tee -a "${log_file}"
      if ! run_query "${creds}" "RESET BINARY LOGS AND GTIDS;" "-e" 2> >(while IFS= read -r line; do echo_error "[RESTORE] ${line}" |& tee -a "${log_file}"; done); then
        if ! run_query "${creds}" 'RESET MASTER;' "-e" 2> >(while IFS= read -r line; do echo_error "[RESTORE] ${line}" |& tee -a "${log_file}"; done); then
          echo_error "[RESTORE] RESET MASTER failed; cannot safely proceed" |& tee -a "${log_file}"
          exit 1
        fi
      fi

      if _import_dump "${file}"; then
        gtid_after="$(run_query "$creds" "SELECT @@GLOBAL.GTID_EXECUTED;" 2> >(while read -r line; do echo_warn "[RESTORE] ${line}" |& tee -a "${log_file}"; done) || true)"

        if [[ -n "${gtid_after}" ]]; then
          mkdir -p "$(dirname "${info_file}")" 2>/dev/null || true
          {
            printf '[GTID]=%s\n' "${gtid_after}"
            printf '[FILENAME]=%s\n' "$(basename "${file}")"
          } > "${info_file}"
          echo_info "[RESTORE] GTID Executed after restore: ${gtid_after}" |& tee -a "${log_file}"

        else
          echo_warn "[RESTORE] Could not read GTID_EXECUTED after restore" |& tee -a "${log_file}"
        fi

        echo_success "[RESTORE] SUCCESS restoring from ${file}" |& tee -a "${log_file}"
        exit 0

      else
        echo_error "[RESTORE] FAILED restoring from ${file}" |& tee -a "${log_file}"
      fi
      
    done

    echo_error "[RESTORE] All restore attempts FAILED." |& tee -a "${log_file}"
    exit 1
  ;;

  # Reseed and reconfigure a replica to follow the master with GTID auto-position.
  replica)

    _cleanup_readonly() {
      echo_info "[RESTORE] Restoring read_only and super_read_only to 'ON" | tee -a "${log_file}"
      run_query "$creds" "SET GLOBAL read_only=ON; SET GLOBAL super_read_only=ON;" "-e" \
        2> >(while read -r l; do echo_error "[RESTORE] $l" |& tee -a "${log_file}"; done) || true
    }
    trap "_cleanup_readonly '${creds}'" EXIT

    if [[ ! -f "${info_file}" ]]; then
      echo_error "[RESTORE] Missing restore info file: ${info_file}" |& tee -a "${log_file}"
      exit 1
    fi

    restore_gtid=""
    restore_name=""
    while IFS='=' read -r k v; do
      k="${k//[[:space:]]/}"
      v="${v%%[$'\r\n']*}"
      case "${k}" in
        "[GTID]") restore_gtid="${v}";;
        "[FILENAME]") restore_name="${v}";;
      esac
    done < "${info_file}"

    if [[ -z "${restore_name}" ]]; then
      echo_error "[RESTORE] [FILENAME] block not found in ${info_file}" |& tee -a "${log_file}"
      exit 1
    fi

    backup_base="$(basename -- "${restore_name}")"
    backup_file="${backup_root_dir%/}/${backup_base}"
    if [[ ! -f "${backup_file}" ]]; then
      echo_error "[RESTORE] Referenced backup not found: ${backup_file}" |& tee -a "${log_file}"
      exit 1
    fi
    echo_info "[RESTORE] Using referenced backup: ${backup_file}" |& tee -a "${log_file}"
    [[ -n "${restore_gtid}" ]] && echo_info "[RESTORE] Referenced GTID: ${restore_gtid}" | tee -a "${log_file}"

    run_query "${creds}" "STOP REPLICA;" "-e" \
      2> >(while read -r l; do echo_error "[RESTORE] $l" |& tee -a "${log_file}"; done) || true
    
    run_query "${creds}" "RESET REPLICA ALL;" "-e" \
      2> >(while read -r l; do echo_error "[RESTORE] $l" |& tee -a "${log_file}"; done)

    if ! run_query "${creds}" "RESET BINARY LOGS AND GTIDS;" "-e" 2> >(while read -r l; do echo_error "[RESTORE] $l" |& tee -a "${log_file}"; done); then
      run_query "${creds}" "RESET MASTER;" "-e" 2> >(while read -r l; do echo_error "[RESTORE] $l" |& tee -a "${log_file}"; done)
    fi

    # Post-reset GTIDs
    gtid_exec="$(run_query "${creds}" "SELECT @@GLOBAL.GTID_EXECUTED;" 2>/dev/null || echo '')"
    gtid_purged="$(run_query "${creds}" "SELECT @@GLOBAL.GTID_PURGED;" 2>/dev/null || echo '')"
    
    if [[ -n "${gtid_exec}" ]]; then
      echo_error "[RESTORE] GTID_EXECUTED is not empty after reset; cannot apply GTID_PURGED safely. \
        Ensure MySQL >= 8.0.21 supports 'RESET BINARY LOGS AND GTIDS' or run with a user that has BINLOG_ADMIN privileges." |& tee -a "${log_file}"
      exit 1
    fi

    if gzip -cd "${backup_file}" | grep -qiE 'SET[[:space:]]+@@GLOBAL\.GTID_PURGED='; then
      echo_info "[RESTORE] Dump already contains SET @@GLOBAL.GTID_PURGED; skipping manual set." | tee -a "${log_file}"
    else
      echo_info "[RESTORE] Setting GTID_PURGED from restore info" | tee -a "${log_file}"
      esc_gtid="${restore_gtid//\'/\'\'}"
      run_query "${creds}" "SET GLOBAL GTID_PURGED='${esc_gtid}';" "-e" 2> >(while read -r l; do echo_error "[RESTORE] $l" |& tee -a "$log_file"; done) || exit 1
    fi

    # Temporarily writable for import
    run_query "${creds}" "SET GLOBAL super_read_only=OFF; SET GLOBAL read_only=OFF;" "-e" 2> >(while read -r l; do echo_error "[RESTORE] $l" |& tee -a "${log_file}"; done)
    if ! gzip -cd "${backup_file}" | mysql --defaults-extra-file="${creds}" 2> >(while read -r l; do echo_error "[RESTORE] ${l}" |& tee -a "${log_file}"; done); then
      echo_error "[RESTORE] Import failed for ${backup_file}" |& tee -a "${log_file}"
      exit 1
    fi

    if ! envsubst < /opt/mysql/sql/replica.sql | mysql --defaults-extra-file="${creds}" 2> >(while read -r l; do echo_error "[RESTORE] ${l}" |& tee -a "${log_file}"; done); then
      echo_error "[RESTORE] Applying /opt/mysql/sql/replica.sql failed" |& tee -a "${log_file}"
      exit 1
    fi

    echo_success "[RESTORE] Replica reseed + reconfiguration complete" |& tee -a "${log_file}"
    exit 0
  ;;
  
  # Unknown role
  *)
    echo_error "[RESTORE] Invalid or unknown role: ${role}" |& tee -a "${log_file}"
    exit 1
  ;;

esac
