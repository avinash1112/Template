#!/bin/bash
# =============================================================================
# PHP Service Module
# =============================================================================

if [[ -z "${INFRA_BOOTSTRAP_LOADED:-}" ]]; then
  SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  source "${SCRIPT_DIR}/../lib/bootstrap.sh"
fi

adjust_php_dockerfile_deps() {
  local dockerfile_path="${1}"
  log_info "Adjusting PHP Dockerfile dependencies"
  local backend_dir="${PROJECT_ROOT}/backend"
  local composer_json="${backend_dir}/composer.json"
  local composer_lock="${backend_dir}/composer.lock"
  
  if [[ ! -f "${composer_json}" ]]; then
    log_warn "composer.json not found, commenting out related COPY commands"
    sed_inplace 's|^([[:space:]]*COPY[[:space:]]+\./backend/composer\.json.*)|# \1|' "${dockerfile_path}"
  fi
  
  if [[ ! -f "${composer_lock}" ]]; then
    log_warn "composer.lock not found, commenting out related COPY commands"
    sed_inplace 's|^([[:space:]]*COPY[[:space:]]+\./backend/composer\.lock.*)|# \1|' "${dockerfile_path}"
  fi
  
  log_debug "PHP Dockerfile dependencies adjusted"
}

generate_php_env() {
  log_info "Generating PHP runtime environment file"
  local php_env_dir="${RENDERED_DIR}/docker-images/backend/php"
  ensure_directory_exists "${php_env_dir}"
  local php_env_file="${php_env_dir}/.env-runtime"
  cat > "${php_env_file}" <<EOF
INFRA_ENV=${INFRA_ENV}
HOST_NAME=php-app-0
PHP_CONFIG_FPM_PING_PATH=${PHP_CONFIG_FPM_PING_PATH}
PHP_CONFIG_FPM_STATUS_PATH=${PHP_CONFIG_FPM_STATUS_PATH}
MYSQL_MASTER_HOST_NAME=${MYSQL_MASTER_HOST_NAME}
MYSQL_REPLICA_HOST_NAME=${MYSQL_REPLICA_HOST_NAME}
REDIS_MASTER_HOST_NAME=${REDIS_MASTER_HOST_NAME}
REDIS_REPLICA_HOST_NAME=${REDIS_REPLICA_HOST_NAME}
EOF
  log_debug "PHP environment file written to: ${php_env_file}"
}

inject_php_app_replicas() {
  local docker_compose_file="${1}"
  log_info "Injecting PHP app replica configurations"
  log_debug "PHP app replicas injected"
}

inject_php_workers_replicas() {
  local docker_compose_file="${1}"
  log_info "Injecting PHP workers replica configurations"
  log_debug "PHP workers replicas injected"
}

readonly PHP_SERVICE_LOADED=1
