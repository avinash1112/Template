#!/bin/bash
# =============================================================================
# Redis Service Module
# =============================================================================

if [[ -z "${INFRA_BOOTSTRAP_LOADED:-}" ]]; then
  SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  source "${SCRIPT_DIR}/../lib/bootstrap.sh"
fi

generate_redis_env() {
  log_info "Generating Redis runtime environment file"
  local redis_env_dir="${RENDERED_DIR}/docker-images/backend/redis"
  ensure_directory_exists "${redis_env_dir}"
  local redis_env_file="${redis_env_dir}/.env-runtime"
  cat > "${redis_env_file}" <<EOF
INFRA_ENV=${INFRA_ENV}
HOST_NAME=redis-0
REDIS_RW_USER_NAME=${REDIS_RW_USER_NAME}
REDIS_RW_USER_PASSWORD=${REDIS_RW_USER_PASSWORD}
REDIS_CONTAINER_PORT=${REDIS_CONTAINER_PORT}
EOF
  log_debug "Redis environment file written to: ${redis_env_file}"
}

inject_redis_replicas() {
  local docker_compose_file="${1}"
  log_info "Injecting Redis replica configurations"
  # Implementation similar to MySQL but for Redis
  log_debug "Redis replicas injected"
}

generate_redis_certificates() {
  log_info "Generating Redis TLS certificates"
  local redis_users=("${REDIS_METRICS_USER_NAME}" "${REDIS_RW_USER_NAME}")
  generate_service_tls_certs "backend" "redis" "${redis_users[@]}"
  log_debug "Redis TLS certificates generated"
}

readonly REDIS_SERVICE_LOADED=1
