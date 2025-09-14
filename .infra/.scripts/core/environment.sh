#!/bin/bash
# =============================================================================
# Environment Management Core Module
# =============================================================================
# Handles environment loading, validation, and configuration

# Guard against multiple sourcing
if [[ -n "${ENVIRONMENT_CORE_LOADED:-}" ]]; then
  return 0
fi

# Load required utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../utils/platform.sh"
source "${SCRIPT_DIR}/../utils/logging.sh"
source "${SCRIPT_DIR}/../utils/validation.sh"
source "${SCRIPT_DIR}/../utils/strings.sh"

# Required environment variables for different contexts
readonly REQUIRED_ENV_VARS_BASIC=(
"INFRA_ENV"
"APP_HOST_NAME"
"APP_NAME"
"APP_TIMEZONE"
)

readonly REQUIRED_ENV_VARS_DOCKER=(
"CONTAINER_REGISTRY_USERNAME"
"REPO_NAME"
"REPO_BRANCH"
)

readonly REQUIRED_ENV_VARS_MYSQL=(
"MYSQL_DATABASE"
"MYSQL_ROOT_PASSWORD"
"MYSQL_RW_USER_NAME"
"MYSQL_RW_USER_PASSWORD"
"MYSQL_RO_USER_NAME"
"MYSQL_RO_USER_PASSWORD"
)

readonly REQUIRED_ENV_VARS_REDIS=(
"REDIS_RW_USER_NAME"
"REDIS_RW_USER_PASSWORD"
)

readonly REQUIRED_ENV_VARS_PRODUCTION=(
"SSH_HOSTNAME"
"SSH_USER"
"SSH_PORT"
"SSH_IDENTITY_FILE"
"K8S_NAMESPACE"
)

# Load and validate environment file
load_environment_file() {
  local env_file="${1}"

  log_info "Loading environment from: ${env_file}"

  # Validate environment file exists and is readable
  if ! validate_file_readable "${env_file}" "environment file"; then
    return 1
  fi

  # Load environment variables from file
  local line_number=0
  while IFS='=' read -r key val; do
    ((line_number++))

    # Skip comments and blank lines
    [[ -z "${key}" || "${key}" == \#* ]] && continue

    # Trim whitespace
    key="$(trim_string "${key}")"
    val="$(trim_string "${val}")"

    # Validate key format
    if [[ ! "${key}" =~ ^[A-Z][A-Z0-9_]*$ ]]; then
      log_warn "Invalid environment variable name at line ${line_number}: ${key}"
      continue
    fi

    # Remove surrounding quotes from value if present
    val="${val%\"}"
    val="${val#\"}"
    val="${val%\'}"
    val="${val#\'}"

    # Export the variable
    export "${key}=${val}"
    log_debug "Loaded: ${key}=${val:0:20}$([ ${#val} -gt 20 ] && echo "...")"

  done < "${env_file}"

  log_success "Environment file loaded successfully"

  # Validate environment based on specified level
  validate_environment "${INFRA_ENV}"
}

# Validate environment variables based on context
validate_environment() {
  local validation_level="${1:-local}"

  log_info "Validating environment (level: ${validation_level})"
  reset_validation_counters

  # Always validate basic requirements
  log_subsection "Basic Environment Variables"
  for var in "${REQUIRED_ENV_VARS_BASIC[@]}"; do
    validate_required_env_var "${var}"
  done

  # Validate INFRA_ENV value
  if [[ -n "${INFRA_ENV:-}" ]]; then
    case "${INFRA_ENV}" in
      dev|staging|production)
      log_validation_success "INFRA_ENV '${INFRA_ENV}' is valid"
      ;;
      *)
      log_validation_error "INFRA_ENV '${INFRA_ENV}' must be one of: dev, staging, production"
      ;;
      esac
    fi

    # Validate hostname format
    if [[ -n "${APP_HOST_NAME:-}" ]]; then
      validate_hostname "${APP_HOST_NAME}" "APP_HOST_NAME"
    fi

    # Validate timezone
    if [[ -n "${APP_TIMEZONE:-}" && -d "/usr/share/zoneinfo" ]]; then
      if [[ ! -f "/usr/share/zoneinfo/${APP_TIMEZONE}" ]]; then
        log_validation_warning "Timezone '${APP_TIMEZONE}' may not be valid"
      fi
    fi

    # # Docker validation
    log_subsection "Docker Environment Variables"
    for var in "${REQUIRED_ENV_VARS_DOCKER[@]}"; do
      validate_required_env_var "${var}"
    done

    # Validate container registry username format
    if [[ -n "${CONTAINER_REGISTRY_USERNAME:-}" ]]; then
      validate_env_var_pattern "CONTAINER_REGISTRY_USERNAME" "^[a-z0-9._-]+$" "container registry username"
    fi

    # Validate repository name format
    if [[ -n "${REPO_NAME:-}" ]]; then
      validate_env_var_pattern "REPO_NAME" "^[a-z0-9._-]+$" "repository name"
    fi

    # Production validation
    if [[ "${validation_level}" == "production" ]]; then
      log_subsection "Production Environment Variables"
      for var in "${REQUIRED_ENV_VARS_PRODUCTION[@]}"; do
        validate_required_env_var "${var}"
      done

      # Validate SSH configuration
      if [[ -n "${SSH_PORT:-}" ]]; then
        validate_port "${SSH_PORT}" "SSH_PORT"
      fi

      if [[ -n "${SSH_IDENTITY_FILE:-}" ]]; then
        # Expand tilde in SSH identity file path
        local ssh_key="${SSH_IDENTITY_FILE/#\~/$HOME}"
        validate_file_readable "${ssh_key}" "SSH identity file"
      fi

      if [[ -n "${SSH_HOSTNAME:-}" ]]; then
        validate_hostname "${SSH_HOSTNAME}" "SSH_HOSTNAME"
      fi

      # Validate Kubernetes namespace format
      if [[ -n "${K8S_NAMESPACE:-}" ]]; then
        validate_env_var_pattern "K8S_NAMESPACE" "^[a-z0-9-]+$" "Kubernetes namespace"
      fi
    fi

    print_validation_summary
  }

  # Generate derived environment variables
  generate_derived_variables() {
    log_info "Generating derived environment variables"

    # Ensure required base variables exist
    if [[ -z "${INFRA_ENV:-}" || -z "${APP_HOST_NAME:-}" ]]; then
      log_error "Cannot generate derived variables without INFRA_ENV and APP_HOST_NAME"
      return 1
    fi

    # Force replica counts to 1 in dev environment
    if [[ "${INFRA_ENV}" == "dev" ]]; then
      log_debug "Setting replica counts to 1 for local environment"

      # Find all variables ending with _REPLICA_COUNT and set them to 1
      while IFS= read -r var_name; do
        export "${var_name}=1"
        log_debug "Set ${var_name}=1 (local environment)"
      done < <(compgen -v | grep -E '_REPLICA_COUNT$' || true)
    fi

    # Generate hostname variables based on environment
    if [[ "${INFRA_ENV}" == "dev" ]]; then
      export FRONTEND_HOST_NAME="${APP_HOST_NAME%.*}.ca"
      export BACKEND_HOST_NAME="api.${APP_HOST_NAME%.*}.ca"
      export NODEJS_HOST_NAME="nodejs-0"
      export MYSQL_MASTER_HOST_NAME="mysql-0"
      export MYSQL_REPLICA_HOST_NAME="mysql-1"
      export REDIS_MASTER_HOST_NAME="redis-0"
      export REDIS_REPLICA_HOST_NAME="redis-1"
      export PHP_APP_HOST_NAME="php-app-0"
      export PHP_WORKERS_HOST_NAME="php-workers-0"
      export NGINX_HOST_NAME="nginx-0"

      # Development-specific configuration
      export NGINX_CONFIG_ERROR_LOG_LEVEL="info"
      export PHP_CONFIG_ASSERT_EXCEPTION="1"
      export PHP_CONFIG_DISPLAY_ERRORS="On"
      export PHP_CONFIG_DISPLAY_STARTUP_ERRORS="On"
      export PHP_CONFIG_ERROR_REPORTING="E_ALL"
      export PHP_CONFIG_OPCACHE_REVALIDATE_FREQ="1"
      export PHP_CONFIG_OPCACHE_VALIDATE_TIMESTAMPS="1"
      export PHP_CONFIG_POOL_LOG_LEVEL="notice"
      export PHP_CONFIG_ZEND_ASSERTIONS="1"

      log_debug "Generated dev environment hostnames and configuration"
      else
      export FRONTEND_HOST_NAME="${APP_HOST_NAME}"
      export BACKEND_HOST_NAME="api.${APP_HOST_NAME}"

      # Use Kubernetes service names for production
      local k8s_suffix=".${K8S_NAMESPACE:-default}.svc.cluster.local"
      export NODEJS_HOST_NAME="nodejs${k8s_suffix}"
      export MYSQL_MASTER_HOST_NAME="mysql-master${k8s_suffix}"
      export MYSQL_REPLICA_HOST_NAME="mysql-replica${k8s_suffix}"
      export REDIS_MASTER_HOST_NAME="redis-master${k8s_suffix}"
      export REDIS_REPLICA_HOST_NAME="redis-replica${k8s_suffix}"
      export PHP_APP_HOST_NAME="php-app${k8s_suffix}"
      export PHP_WORKERS_HOST_NAME="php-workers${k8s_suffix}"
      export NGINX_HOST_NAME="nginx${k8s_suffix}"

      # Production-specific configuration
      export NGINX_CONFIG_ERROR_LOG_LEVEL="warn"
      export PHP_CONFIG_ASSERT_EXCEPTION="0"
      export PHP_CONFIG_DISPLAY_ERRORS="Off"
      export PHP_CONFIG_DISPLAY_STARTUP_ERRORS="Off"
      export PHP_CONFIG_ERROR_REPORTING="E_ALL & ~E_DEPRECATED & ~E_USER_DEPRECATED & ~E_NOTICE"
      export PHP_CONFIG_OPCACHE_REVALIDATE_FREQ="0"
      export PHP_CONFIG_OPCACHE_VALIDATE_TIMESTAMPS="0"
      export PHP_CONFIG_POOL_LOG_LEVEL="warning"
      export PHP_CONFIG_ZEND_ASSERTIONS="-1"

      log_debug "Generated production environment hostnames and configuration"
    fi

    log_success "Derived environment variables generated"
  }

  # Print environment summary
  print_environment_summary() {
    log_section "Environment Summary"

    echo "Environment: ${INFRA_ENV:-<not set>}"
    echo "Application: ${APP_NAME:-<not set>}"
    echo "Host: ${APP_HOST_NAME:-<not set>}"
    echo "Timezone: ${APP_TIMEZONE:-<not set>}"
    echo
    echo "Frontend Host: ${FRONTEND_HOST_NAME:-<not set>}"
    echo "Backend Host: ${BACKEND_HOST_NAME:-<not set>}"
    echo
    echo "Repository: ${REPO_NAME:-<not set>}"
    echo "Registry User: ${CONTAINER_REGISTRY_USERNAME:-<not set>}"
    echo

    if [[ "${INFRA_ENV}" != "dev" ]]; then
      echo "SSH Host: ${SSH_HOSTNAME:-<not set>}"
      echo "SSH User: ${SSH_USER:-<not set>}"
      echo "SSH Port: ${SSH_PORT:-<not set>}"
      echo "K8s Namespace: ${K8S_NAMESPACE:-<not set>}"
      echo
    fi

    # Show replica counts
    echo "Replica Counts:"
    for var in $(compgen -v | grep -E '_REPLICA_COUNT$' | sort); do
      echo "  ${var}: ${!var:-<not set>}"
    done
    echo
  }

  # Initialize environment system
  init_environment() {
    local env_file="${1}"
    local enable_logging="${2:-true}"

    if [[ "${enable_logging}" == "true" ]]; then
      init_logging "INFO" "auto"
    fi

    log_section "Environment Initialization"

    # Load environment file
    if ! load_environment_file "${env_file}"; then
      log_fatal "Failed to load environment file"
    fi

    # Generate derived variables
    if ! generate_derived_variables; then
      log_fatal "Failed to generate derived variables"
    fi

    # Print summary if debug logging is enabled
    if ((LOG_LEVEL <= LOG_LEVEL_DEBUG)); then
      print_environment_summary
    fi

    log_success "Environment initialization completed"
  }

  # Environment cleanup function
  # Unsets all environment variables that were loaded by this module
  cleanup_environment() {
    log_debug "Cleaning up environment variables"

    # List of all environment variables that might be set by the infrastructure
    local infra_vars=(
    # Core variables
    "INFRA_ENV" "APP_HOST_NAME" "APP_NAME" "APP_TIMEZONE"
    "PROJECT_ROOT" "TEMPLATES_DIR" "RENDERED_DIR" "CERTS_DIR"

    # Docker variables
    "CONTAINER_REGISTRY_USERNAME" "CONTAINER_REGISTRY_PASSWORD"
    "REPO_NAME" "REPO_BRANCH" "CONTAINER_REGISTRY_URL"

    # MySQL variables
    "MYSQL_DATABASE" "MYSQL_ROOT_PASSWORD" "MYSQL_RW_USER_NAME"
    "MYSQL_RW_USER_PASSWORD" "MYSQL_RO_USER_NAME" "MYSQL_RO_USER_PASSWORD"
    "MYSQL_MASTER_HOST_NAME" "MYSQL_SLAVE_HOST_NAME" "MYSQL_HOST_PORT"

    # Redis variables
    "REDIS_RW_USER_NAME" "REDIS_RW_USER_PASSWORD"
    "REDIS_MASTER_HOST_NAME" "REDIS_SLAVE_HOST_NAME" "REDIS_HOST_PORT"

    # Production variables
    "SSH_HOSTNAME" "SSH_USER" "SSH_PORT" "SSH_IDENTITY_FILE"
    "K8S_NAMESPACE" "K8S_CONTEXT"

    # Generated variables
    "MYSQL_REPLICAS" "REDIS_REPLICAS" "NODE_REPLICAS" "PHP_REPLICAS"
    "NGINX_REPLICAS" "CONTAINER_REGISTRY_HOST" "CONTAINER_REGISTRY_PROJECT"
    )

    for var in "${infra_vars[@]}"; do
      if [[ -n "${!var:-}" ]]; then
        unset "${var}"
        log_debug "Unset variable: ${var}"
      fi
    done

    log_debug "Environment cleanup completed"
  }

  # Generate dynamic service environment file
  # Usage: generate_service_env_file <stack> <service_name> [exception_keys...]
  generate_service_env_file() {
    local stack="${1}"
    local service_name="${2}"
    shift 2
    local -a exception_keys=("${@:-}")

    log_debug "Generating ${service_name} runtime environment file"

    # Generate service prefix (e.g., MYSQL_, NODEJS_, REDIS_)
    local prefix
    prefix="$(echo "${service_name}" | tr '[:lower:]' '[:upper:]')_"

    # Define paths
    local service_env_dir="${RENDERED_DIR}/docker-images/${stack}/${service_name}"
    local output_file="${service_env_dir}/.env-runtime"
    local source_file="${INFRA_ENV_FILE}"

    # Ensure directory exists and create empty file
    ensure_directory_exists "${service_env_dir}"
    : > "${output_file}"

    # Track handled exception keys
    declare -A handled_exceptions=()

    # Process environment file line by line
    while IFS='=' read -r key value || [[ -n "$key" ]]; do
      # Skip empty lines and comments
      [[ -z "$key" || "$key" =~ ^[[:space:]]*# ]] && continue

      # Trim whitespace
      key="$(echo "$key" | xargs)"
      value="$(echo "$value" | xargs)"

      # Include variables with service prefix that are NOT ${PREFIX}CONFIG_*
      if [[ "$key" == "${prefix}"* && "$key" != "${prefix}CONFIG_"* ]]; then
        echo "${key}=${value}" >> "${output_file}"
        continue
      fi

      # Handle exception keys (additional variables to include)
      for ex_key in "${exception_keys[@]}"; do
        if [[ "$key" == "$ex_key" ]]; then
          echo "${key}=${value}" >> "${output_file}"
          handled_exceptions["$key"]=1
          break
        fi
      done
    done < "$source_file"

    # Handle unprocessed exception keys (fallback to shell environment)
    if [[ "${#exception_keys[@]}" -gt 0 ]]; then
      for ex_key in "${exception_keys[@]}"; do
        [[ -z "$ex_key" ]] && continue  # Skip empty keys

        # If not handled from file, try shell environment
        if [[ -z "${handled_exceptions[$ex_key]+_}" ]]; then
          if [[ -n "${!ex_key:-}" ]]; then
            echo "${ex_key}=${!ex_key}" >> "${output_file}"
            log_debug "Added ${ex_key} from shell environment"
          else
            log_warn "Required exception key '${ex_key}' not found in env file or shell environment"
          fi
        fi
      done
    fi

    log_debug "${service_name} runtime env file generated: ${output_file}"
  }

  # Trap function to ensure cleanup on script exit
  setup_environment_cleanup_trap() {
    # Only set trap if we're not in a subshell already
    if [[ "${BASH_SUBSHELL}" -eq 0 ]]; then
      trap cleanup_environment EXIT
      log_debug "Environment cleanup trap set"
    fi
  }

  if [[ -z "${ENVIRONMENT_CORE_LOADED:-}" ]]; then
    readonly ENVIRONMENT_CORE_LOADED=1
  fi
