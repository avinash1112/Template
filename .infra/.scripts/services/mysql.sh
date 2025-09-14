#!/bin/bash
# =============================================================================
# MySQL Service Module
# =============================================================================
# Handles MySQL-specific operations including replicas, configuration, and certificates

# Load required dependencies
if [[ -z "${INFRA_BOOTSTRAP_LOADED:-}" ]]; then
  SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  source "${SCRIPT_DIR}/../lib/bootstrap.sh"
fi

# MySQL-specific functions

# Generate MySQL runtime environment file
generate_mysql_env() {
  log_info "Generating MySQL runtime environment file"
  
  generate_service_env_file "backend" "mysql" "MYSQL_MASTER_HOST_NAME"
  
  log_debug "MySQL environment file generation completed"
}

# Inject MySQL replica configurations into Docker Compose
inject_mysql_replicas() {
  local docker_compose_file="${1}"
  local match_service="mysql-0"
  local inject_after=1
  local base_server_id=100
  
  log_info "Injecting MySQL replica configurations"
  
  if [[ ! -f "${docker_compose_file}" ]]; then
    log_error "Docker Compose file not found: ${docker_compose_file}"
    return 1
  fi
  
  local all_replicas_block=""
  
  # Generate replica configurations
  for i in $(seq 1 "${MYSQL_CONFIG_READ_REPLICA_COUNT}"); do
    local host_port=$((MYSQL_HOST_PORT + i))
    local server_id=$((base_server_id + i))
    
    local replica_block=$(cat <<EOF
mysql-${i}:
  container_name: ${REPO_NAME}-mysql-${i}
  hostname: mysql-${i}
  image: ghcr.io/${CONTAINER_REGISTRY_USERNAME}/${REPO_NAME}-mysql:latest
  restart: unless-stopped
  environment:
    INFRA_ENV: ${INFRA_ENV}
    HOST_NAME: mysql-${i}
    INSTANCE_SERVER_ID: ${server_id}
    MASTER_HOST_NAME: ${MYSQL_MASTER_HOST_NAME}
  env_file:
    - ../../docker-images/backend/mysql/.env-runtime
  ports:
    - "${host_port}:${MYSQL_CONTAINER_PORT}"
  volumes:
    - type: bind
      source: ../../../certs/backend/mysql/clients
      target: /etc/ssl/certs/mysql/clients
  healthcheck:
    test: ["CMD", "/usr/local/bin/readiness.sh"]
    start_period: 0s
    timeout: 90s
    interval: 5s
    retries: 5
  networks:
    - ${REPO_NAME}-backend-net
  depends_on:
    ${match_service}:
      condition: service_healthy
EOF
    )
        
    all_replicas_block+="${replica_block}"$'\n\n'
  done
    
  # Remove trailing newline
  all_replicas_block="${all_replicas_block%$'\n'}"
  
  # Inject the block into the Docker Compose file
  inject_service_block "${docker_compose_file}" "${match_service}" "${all_replicas_block}"
  
  log_debug "Injected ${MYSQL_CONFIG_READ_REPLICA_COUNT} MySQL replica configurations"
}

# Generate MySQL TLS certificates
generate_mysql_certificates() {
  log_info "Generating MySQL TLS certificates"
  
  local mysql_users=(
    "root"
    "${MYSQL_SUPER_USER_NAME}"
    "${MYSQL_RW_USER_NAME}"
    "${MYSQL_RO_USER_NAME}"
  )
  
  generate_service_tls_certs "backend" "mysql" "${mysql_users[@]}"
  
  log_debug "MySQL TLS certificates generated"
}

readonly MYSQL_SERVICE_LOADED=1
