#!/bin/bash
# =============================================================================
# Node.js Service Module
# =============================================================================
# Handles Node.js-specific operations including dependencies and configuration

# Load required dependencies
if [[ -z "${INFRA_BOOTSTRAP_LOADED:-}" ]]; then
  SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  source "${SCRIPT_DIR}/../lib/bootstrap.sh"
fi

# Node.js-specific functions

# Adjust Node.js Dockerfile dependencies
adjust_nodejs_dockerfile_deps() {
  local dockerfile_path="${1}"
  
  log_info "Adjusting Node.js Dockerfile dependencies"
  
  local frontend_dir="${PROJECT_ROOT}/frontend"
  local package_json="${frontend_dir}/package.json"
  local package_lock="${frontend_dir}/package-lock.json"
  
  # Check for package.json
  if [[ ! -f "${package_json}" ]]; then
    log_warn "package.json not found, commenting out related COPY commands"
    sed_inplace 's|^([[:space:]]*COPY[[:space:]]+\./frontend/package\.json.*)|# \1|' "${dockerfile_path}"
  else
    log_debug "package.json found: ${package_json}"
  fi
  
  # Check for package-lock.json
  if [[ ! -f "${package_lock}" ]]; then
    log_warn "package-lock.json not found, commenting out related COPY commands"
    sed_inplace 's|^([[:space:]]*COPY[[:space:]]+\./frontend/package-lock\.json.*)|# \1|' "${dockerfile_path}"
  else
    log_debug "package-lock.json found: ${package_lock}"
  fi
  
  log_debug "Node.js Dockerfile dependencies adjusted"
}

# Generate Node.js runtime environment file
generate_nodejs_env() {
  log_info "Generating Node.js runtime environment file"
  
  local nodejs_env_dir="${RENDERED_DIR}/docker-images/frontend/nodejs"
  ensure_directory_exists "${nodejs_env_dir}"
  
  local nodejs_env_file="${nodejs_env_dir}/.env-runtime"
  
  cat > "${nodejs_env_file}" <<EOF
# Generated Node.js runtime environment
INFRA_ENV=${INFRA_ENV}
HOST_NAME=nodejs-0

# Application configuration
APP_NAME=${APP_NAME}
APP_ENV=${INFRA_ENV}
APP_URL=https://${FRONTEND_HOST_NAME}
API_URL=https://${BACKEND_HOST_NAME}
APP_TIMEZONE=${APP_TIMEZONE}

# Container runtime configuration
NODEJS_CONTAINER_RUNTIME_USER_NAME=${NODEJS_CONTAINER_RUNTIME_USER_NAME}
NODEJS_CONTAINER_RUNTIME_USER_GROUP=${NODEJS_CONTAINER_RUNTIME_USER_GROUP}
NODEJS_CONTAINER_USER_UID=${NODEJS_CONTAINER_USER_UID}
NODEJS_CONTAINER_USER_GID=${NODEJS_CONTAINER_USER_GID}

# Port configuration
NODEJS_CONTAINER_PORT=${NODEJS_CONTAINER_PORT}
NODEJS_VITE_PREVIEW_PORT=${NODEJS_VITE_PREVIEW_PORT}

# Development server configuration
VITE_DEV_SERVER_HOST=0.0.0.0
VITE_DEV_SERVER_PORT=${NODEJS_CONTAINER_PORT}
VITE_PREVIEW_PORT=${NODEJS_VITE_PREVIEW_PORT}

# Build configuration
VITE_BUILD_TARGET=${INFRA_ENV}

# Replica configuration
NODEJS_CONFIG_READ_REPLICA_COUNT=${NODEJS_CONFIG_READ_REPLICA_COUNT}
NODEJS_HOST_NAME=${NODEJS_HOST_NAME}
EOF
    
  log_debug "Node.js environment file written to: ${nodejs_env_file}"
}

# Inject Node.js replica configurations into Docker Compose
inject_nodejs_replicas() {
  local docker_compose_file="${1}"
  local match_service="nodejs-0"
  
  log_info "Injecting Node.js replica configurations"
  
  if [[ ! -f "${docker_compose_file}" ]]; then
    log_error "Docker Compose file not found: ${docker_compose_file}"
    return 1
  fi
  
  local all_replicas_block=""
  
  # Generate replica configurations
  for i in $(seq 1 "${NODEJS_CONFIG_READ_REPLICA_COUNT}"); do
    local container_port=$((NODEJS_CONTAINER_PORT + i))
    local preview_port=$((NODEJS_VITE_PREVIEW_PORT + i))
    
    local replica_block=$(cat <<EOF
nodejs-${i}:
  container_name: \${REPO_NAME}-nodejs-${i}
  hostname: nodejs-${i}
  image: ghcr.io/\${CONTAINER_REGISTRY_USERNAME}/\${REPO_NAME}-nodejs:latest
  restart: unless-stopped
  environment:
    INFRA_ENV: \${INFRA_ENV}
    HOST_NAME: nodejs-${i}
    VITE_DEV_SERVER_PORT: ${container_port}
    VITE_PREVIEW_PORT: ${preview_port}
  env_file:
    - ../../docker-images/frontend/nodejs/.env-runtime
  ports:
    - "${container_port}:${container_port}"
    - "${preview_port}:${preview_port}"
  volumes:
    - type: bind
      source: ../../../../frontend
      target: /var/www/html
    - type: volume
      source: \${REPO_NAME}-node-modules
      target: /var/www/html/node_modules
  healthcheck:
    test: ["CMD", "/usr/local/bin/readiness.sh"]
    start_period: 0s
    timeout: 10s
    interval: 5s
    retries: 5
  networks:
    - \${REPO_NAME}-frontend-net
  extra_hosts:
    - "host.docker.internal:host-gateway"
EOF
    )
        
    all_replicas_block+="${replica_block}"$'\n\n'
  done
    
  # Remove trailing newline
  all_replicas_block="${all_replicas_block%$'\n'}"
  
  # Inject the block into the Docker Compose file
  inject_service_block "${docker_compose_file}" "${match_service}" "${all_replicas_block}"
  
  log_debug "Injected ${NODEJS_CONFIG_READ_REPLICA_COUNT} Node.js replica configurations"
}

readonly NODEJS_SERVICE_LOADED=1
