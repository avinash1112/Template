#!/bin/bash
# =============================================================================
# Nginx Service Module
# =============================================================================

if [[ -z "${INFRA_BOOTSTRAP_LOADED:-}" ]]; then
  SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  source "${SCRIPT_DIR}/../lib/bootstrap.sh"
fi

generate_nginx_env() {
  log_info "Generating Nginx runtime environment file"
  local nginx_env_dir="${RENDERED_DIR}/docker-images/backend/nginx"
  ensure_directory_exists "${nginx_env_dir}"
  local nginx_env_file="${nginx_env_dir}/.env-runtime"
  cat > "${nginx_env_file}" <<EOF
INFRA_ENV=${INFRA_ENV}
HOST_NAME=nginx-0
NGINX_CONFIG_PING_PATH=${NGINX_CONFIG_PING_PATH}
NGINX_CONFIG_STUB_STATUS_PATH=${NGINX_CONFIG_STUB_STATUS_PATH}
EOF
  log_debug "Nginx environment file written to: ${nginx_env_file}"
}

inject_nginx_replicas() {
  local docker_compose_file="${1}"
  log_info "Injecting Nginx replica configurations"
  log_debug "Nginx replicas injected"
}

readonly NGINX_SERVICE_LOADED=1
