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
  
  generate_service_env_file "frontend" "nodejs"
  
  log_debug "Node.js environment file generation completed"
}

readonly NODEJS_SERVICE_LOADED=1
