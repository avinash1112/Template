#!/bin/bash
# =============================================================================
# Certificate Management Core Module
# =============================================================================
# Handles TLS certificate generation and distribution

# Guard against multiple sourcing
if [[ -n "${CERTIFICATES_CORE_LOADED:-}" ]]; then
  return 0
fi

# Load required dependencies
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../utils/platform.sh"
source "${SCRIPT_DIR}/../utils/logging.sh"
source "${SCRIPT_DIR}/../utils/validation.sh"
source "${SCRIPT_DIR}/../utils/strings.sh"
source "${SCRIPT_DIR}/../utils/files.sh"

# Generate TLS certificates for a service
generate_service_tls_certs() {
  local stack="${1}"
  local service_raw="${2}"
  shift 2
  local users=("$@")

  log_info "Generating TLS certificates for ${stack}/${service_raw}"

  # Service names
  local service_lc="${service_raw,,}"
  local service_uc="${service_raw^^}"

  # Get hostnames
  local master_hosts=""
  local replica_hosts=""

  if [[ "${service_lc}" == "proxy" ]]; then
    if [[ "${stack}" == "frontend" ]]; then
      master_hosts="${FRONTEND_HOST_NAME}"
      elif [[ "${stack}" == "backend" ]]; then
        master_hosts="${BACKEND_HOST_NAME}"
      fi
      else
      local master_var="${service_uc}_MASTER_HOST_NAME"
      local replica_var="${service_uc}_REPLICA_HOST_NAME"
      master_hosts="${!master_var:-}"
      replica_hosts="${!replica_var:-}"
    fi

    # Certificate details
    local ca_cn="*.$(_get_domain)"
    local server_cn="${ca_cn}"
    local app_slug="$(slugify "${APP_NAME}")"
    local ca_subj="/C=${TLS_COUNTRY}/O=${app_slug}/CN=${ca_cn}"
    local server_subj="/C=${TLS_COUNTRY}/O=${app_slug}/CN=${server_cn}"

    # Build SAN list
    local san_entries=()
    if [[ -n "${master_hosts}" ]]; then
      IFS=',' read -ra hosts <<< "${master_hosts}"
      for host in "${hosts[@]}"; do
        host="$(trim_string "${host}")"
        if [[ -n "${host}" ]]; then
          if is_ip_address "${host}"; then
            san_entries+=("IP:${host}")
            else
            san_entries+=("DNS:${host}")
          fi
        fi
      done
    fi

    if [[ -n "${replica_hosts}" ]]; then
      IFS=',' read -ra hosts <<< "${replica_hosts}"
      for host in "${hosts[@]}"; do
        host="$(trim_string "${host}")"
        if [[ -n "${host}" ]]; then
          if is_ip_address "${host}"; then
            san_entries+=("IP:${host}")
            else
            san_entries+=("DNS:${host}")
          fi
        fi
      done
    fi

    local san_line
    san_line="$(join_array "," "${san_entries[@]}")"

    # Directory structure
    local base_dir="${CERTS_DIR}/${stack}/${service_lc}"
    local issuer_dir="${base_dir}/issuer"
    local server_dir="${base_dir}/server"
    local clients_dir="${base_dir}/clients"

    ensure_directory_exists "${issuer_dir}"
    ensure_directory_exists "${server_dir}"
    ensure_directory_exists "${clients_dir}"

    # Generate CA if needed
    generate_ca_certificate "${issuer_dir}" "${ca_subj}"

    # Generate server certificate
    generate_server_certificate "${issuer_dir}" "${server_dir}" "${server_subj}" "${san_line}"

    # Generate client certificates
    for user in "${users[@]}"; do
      if [[ -n "${user}" ]]; then
        generate_client_certificate "${issuer_dir}" "${clients_dir}/${user}" "${ca_subj}" "${user}"
      fi
    done

    log_success "TLS certificates generated for ${stack}/${service_raw}"
  }

  # Generate CA certificate
  generate_ca_certificate() {
    local issuer_dir="${1}"
    local ca_subj="${2}"

    local ca_key="${issuer_dir}/ca-key.pem"
    local ca_cert="${issuer_dir}/ca.pem"
    local ca_ext="${issuer_dir}/ca-ext.cnf"
    local serial_file="${issuer_dir}/serial"

    # Skip if CA already exists
    if [[ -f "${ca_key}" && -f "${ca_cert}" ]]; then
      log_debug "CA certificate already exists"
      return 0
    fi

    log_debug "Generating CA certificate"

    # Create CA extension file
    cat > "${ca_ext}" <<EOF
[ v3_ca ]
basicConstraints = critical, CA:TRUE, pathlen:1
keyUsage = critical, keyCertSign, cRLSign
subjectKeyIdentifier = hash
authorityKeyIdentifier = keyid:always,issuer
EOF

    # Initialize serial number
    echo '1000' > "${serial_file}"

    # Generate CA private key
    openssl genrsa -out "${ca_key}" 2048 2>/dev/null

    # Generate CA certificate
    openssl req -new -x509 -key "${ca_key}" -out "${ca_cert}" \
    -days "${TLS_VALIDITY_DAYS}" -sha256 \
    -subj "${ca_subj}" \
    -extensions v3_ca -config "${ca_ext}" 2>/dev/null
  }

  # Generate server certificate
  generate_server_certificate() {
    local issuer_dir="${1}"
    local server_dir="${2}"
    local server_subj="${3}"
    local san_line="${4}"

    local ca_key="${issuer_dir}/ca-key.pem"
    local ca_cert="${issuer_dir}/ca.pem"
    local serial_file="${issuer_dir}/serial"

    local server_key="${server_dir}/key.pem"
    local server_cert="${server_dir}/leaf.pem"
    local server_csr="${server_dir}/server.csr"
    local server_ext="${server_dir}/server-ext.cnf"

    # Skip if server cert already exists
    if [[ -f "${server_key}" && -f "${server_cert}" ]]; then
      log_debug "Server certificate already exists"
      return 0
    fi

    log_debug "Generating server certificate"

    # Create server extension file
    cat > "${server_ext}" <<EOF
[ v3_srv ]
subjectAltName = ${san_line}
extendedKeyUsage = serverAuth
keyUsage = digitalSignature, keyEncipherment, keyAgreement
authorityKeyIdentifier = keyid,issuer
subjectKeyIdentifier = hash
EOF

    # Generate server private key and CSR
    openssl req -new -newkey rsa:2048 -nodes \
    -keyout "${server_key}" -out "${server_csr}" \
    -subj "${server_subj}" 2>/dev/null

    # Generate server certificate
    openssl x509 -req -in "${server_csr}" \
    -CA "${ca_cert}" -CAkey "${ca_key}" -CAserial "${serial_file}" \
    -out "${server_cert}" -days "${TLS_VALIDITY_DAYS}" -sha256 \
    -extensions v3_srv -extfile "${server_ext}" 2>/dev/null

    # Copy CA certificate
    cp "${ca_cert}" "${server_dir}/ca.pem"

    # Create full chain
    cat "${server_cert}" "${ca_cert}" > "${server_dir}/fullchain.pem"
  }

  # Generate client certificate
  generate_client_certificate() {
    local issuer_dir="${1}"
    local client_dir="${2}"
    local ca_subj="${3}"
    local user="${4}"

    local ca_key="${issuer_dir}/ca-key.pem"
    local ca_cert="${issuer_dir}/ca.pem"
    local serial_file="${issuer_dir}/serial"

    ensure_directory_exists "${client_dir}"

    local client_key="${client_dir}/key.pem"
    local client_cert="${client_dir}/leaf.pem"
    local client_csr="${client_dir}/client.csr"
    local client_ext="${client_dir}/client-ext.cnf"

    log_debug "Generating client certificate for user: ${user}"

    # Create client extension file
    cat > "${client_ext}" <<EOF
[ v3_cli ]
extendedKeyUsage = clientAuth
keyUsage = digitalSignature, keyEncipherment
authorityKeyIdentifier = keyid,issuer
subjectKeyIdentifier = hash
EOF

    # Generate client private key and CSR
    openssl req -new -newkey rsa:2048 -nodes \
    -keyout "${client_key}" -out "${client_csr}" \
    -subj "${ca_subj}" 2>/dev/null

    # Generate client certificate
    openssl x509 -req -in "${client_csr}" \
    -CA "${ca_cert}" -CAkey "${ca_key}" -CAserial "${serial_file}" \
    -out "${client_cert}" -days "${TLS_VALIDITY_DAYS}" -sha256 \
    -extensions v3_cli -extfile "${client_ext}" 2>/dev/null

    # Copy CA certificate
    cp "${ca_cert}" "${client_dir}/ca.pem"
  }

  # Helper function to get domain
  _get_domain() {
    local hostname="${1:-${APP_HOST_NAME}}"
    get_domain "${hostname}"
  }

  # Generate frontend certificates
  generate_frontend_certificates() {
    log_info "Generating frontend TLS certificates"
    generate_service_tls_certs "frontend" "proxy" "health"
    generate_service_tls_certs "frontend" "nodejs" "health"
  }

  # Generate backend certificates
  generate_backend_certificates() {
    log_info "Generating backend TLS certificates"
    generate_service_tls_certs "backend" "proxy" "health"
    generate_service_tls_certs "backend" "mysql" "root" "${MYSQL_SUPER_USER_NAME}" "${MYSQL_RW_USER_NAME}" "${MYSQL_RO_USER_NAME}"
    generate_service_tls_certs "backend" "redis" "${REDIS_METRICS_USER_NAME}" "${REDIS_RW_USER_NAME}"
  }

  # Distribute service certificates
  distribute_service_certificates() {
    local service_path="${1}"

    log_debug "Distributing certificates from: ${service_path}"

    # Extract parent (backend/frontend) and service name
    local parent
    local service
    parent="$(basename "$(dirname "${service_path}")")"
    service="$(basename "${service_path}")"

    # Define server certificate directory and target directories
    local server_dir="${service_path}/server"
    local target_dir_backend="${RENDERED_DIR}/docker-images/backend/${service}/certs"
    local target_dir_frontend="${RENDERED_DIR}/docker-images/frontend/${service}/certs"

    # Check if server certificates exist
    if [[ -d "${server_dir}" ]]; then

      if [[ "${parent}" == "backend" ]]; then
        if ensure_directory_exists "${target_dir_backend}"; then
          if cp "${server_dir}"/*.pem "${target_dir_backend}/" 2>/dev/null; then
            # Count copied files for logging
            local file_count
          file_count=$(find "${target_dir_backend}" -name "*.pem" -type f | wc -l | tr -d ' ')
          log_success "✓ ${service} certificates copied (${file_count} .pem files) → backend"
          else
          log_error "✗ Failed to copy ${service} certificates to backend"
          return 1
        fi
        else
        log_error "Failed to create directory: ${target_dir_backend}"
        return 1
      fi

      elif [[ "${parent}" == "frontend" ]]; then
        if ensure_directory_exists "${target_dir_frontend}"; then
          if cp "${server_dir}"/*.pem "${target_dir_frontend}/" 2>/dev/null; then
            # Count copied files for logging
            local file_count
          file_count=$(find "${target_dir_frontend}" -name "*.pem" -type f | wc -l | tr -d ' ')
          log_success "✓ ${service} certificates copied (${file_count} .pem files) → frontend"
          else
          log_error "✗ Failed to copy ${service} certificates to frontend"
          return 1
        fi
        else
        log_error "Failed to create directory: ${target_dir_frontend}"
        return 1
      fi

      else
      log_warning "${service}: No mapping found for parent '${parent}', skipping..."
      return 0
    fi

    else
    log_warning "${service}: No server certs found at ${server_dir}. Skipping..."
    return 0
  fi

  return 0
}

# Inject service block into Docker Compose file
inject_service_block() {
  local compose_file="${1}"
  local match_service="${2}"
  local block_content="${3}"

  log_debug "Injecting service block after '${match_service}'"

  # Create a temporary file
  local temp_file
  temp_file="$(create_temp_file "compose")"

  local in_target_block=0
  local target_indent=""
  local injected=0

  while IFS= read -r line || [[ -n "${line}" ]]; do
    # Match the target service block
    if [[ "${in_target_block}" -eq 0 && "${line}" =~ ^([[:space:]]{2})${match_service}: ]]; then
      in_target_block=1
      target_indent="${BASH_REMATCH[1]}"
      echo "${line}" >> "${temp_file}"
      continue
    fi

    # Detect when we're exiting the block
    if [[ "${in_target_block}" -eq 1 ]]; then
      if [[ "${line}" =~ ^([[:space:]]*)[^[:space:]] ]]; then
        local current_indent="${BASH_REMATCH[1]}"
        if [[ ${#current_indent} -le ${#target_indent} ]]; then
          # Inject block before writing this line
          echo "${block_content}" | sed "s/^/${target_indent}/" >> "${temp_file}"
          injected=1
          in_target_block=0
        fi
      fi
    fi

    echo "${line}" >> "${temp_file}"
  done < "${compose_file}"

  # If we hit EOF while still in the block
  if [[ "${in_target_block}" -eq 1 && "${injected}" -eq 0 ]]; then
    echo "${block_content}" | sed "s/^/${target_indent}/" >> "${temp_file}"
    injected=1
  fi

  if [[ "${injected}" -eq 0 ]]; then
    log_error "Failed to inject block: could not find end of '${match_service}' block"
    rm -f "${temp_file}"
    return 1
  fi

  # Replace the original file
  mv "${temp_file}" "${compose_file}"
  log_debug "Service block injected successfully"
}

if [[ -z "${CERTIFICATES_CORE_LOADED:-}" ]]; then
  readonly CERTIFICATES_CORE_LOADED=1
fi
