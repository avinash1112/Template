#!/bin/bash
# =============================================================================
# Bootstrap Library
# =============================================================================
# Initializes the infrastructure environment and loads core dependencies

# Prevent multiple initialization
if [[ -n "${INFRA_BOOTSTRAP_LOADED:-}" ]]; then
  return 0
fi

# Set up basic error handling
set -Eeuo pipefail

# Get script directory and project root
if [[ -z "${SCRIPT_DIR:-}" ]]; then
  SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
fi

if [[ -z "${PROJECT_ROOT:-}" ]]; then
  PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
fi

# Infrastructure paths
export INFRA_DIR="${PROJECT_ROOT}/.infra"
export SCRIPTS_DIR="${INFRA_DIR}/.scripts"
export TEMPLATES_DIR="${INFRA_DIR}/.templates"
export INFRA_ENV_FILE="${INFRA_DIR}/.env-infra"
export RENDERED_DIR="${INFRA_DIR}/rendered"
export CERTS_DIR="${INFRA_DIR}/certs"

export BACKEND_APP_DIR="${PROJECT_ROOT}/backend"
export FRONTEND_APP_DIR="${PROJECT_ROOT}/frontend"
export DOCKER_BUILD_CONTEXT="${PROJECT_ROOT}"

# Make paths readonly
readonly PROJECT_ROOT INFRA_DIR SCRIPTS_DIR
readonly TEMPLATES_DIR RENDERED_DIR CERTS_DIR
readonly BACKEND_APP_DIR FRONTEND_APP_DIR
readonly INFRA_ENV_FILE DOCKER_BUILD_CONTEXT

# Load core utilities in order
source "${SCRIPTS_DIR}/utils/platform.sh"
source "${SCRIPTS_DIR}/utils/logging.sh"
source "${SCRIPTS_DIR}/utils/validation.sh"
source "${SCRIPTS_DIR}/utils/strings.sh"
source "${SCRIPTS_DIR}/utils/files.sh"

# Load constants and defaults
source "${SCRIPTS_DIR}/lib/constants.sh"
source "${SCRIPTS_DIR}/lib/defaults.sh"

# Validate bootstrap environment
validate_bootstrap_environment() {
  local validation_passed=true

  # Check required directories exist
  if [[ ! -d "${PROJECT_ROOT}" ]]; then
    echo "❌ Project root directory not found: ${PROJECT_ROOT}" >&2
    validation_passed=false
  fi

  if [[ ! -d "${INFRA_DIR}" ]]; then
    echo "❌ Infrastructure directory not found: ${INFRA_DIR}" >&2
    validation_passed=false
  fi

  if [[ ! -f "${INFRA_ENV_FILE}" ]]; then
    echo "❌ Infrastructure environment file not found: ${INFRA_ENV_FILE}" >&2
    validation_passed=false
  fi

  # Check for required commands
  local required_commands=("bash" "sed" "grep" "find" "mkdir" "cp" "mv" "rm")
  for cmd in "${required_commands[@]}"; do
    if ! command_exists "${cmd}"; then
      echo "❌ Required command not found: ${cmd}" >&2
      validation_passed=false
    fi
  done

  if [[ "${validation_passed}" != "true" ]]; then
    echo "❌ Bootstrap validation failed" >&2
    return 1
  fi

  return 0
}

# Initialize bootstrap environment
init_bootstrap() {
  local log_level="${1:-INFO}"

  # Validate environment first
  if ! validate_bootstrap_environment; then
    exit 1
  fi

  # Initialize logging if not already done
  if [[ -z "${LOGGING_UTILITIES_LOADED:-}" ]]; then
    init_logging "${log_level}" "auto"
  fi

  log_debug "Bootstrap environment initialized"
  log_debug "Project root: ${PROJECT_ROOT}"
  log_debug "Infrastructure directory: ${INFRA_DIR}"
  log_debug "Platform: $(detect_platform)"
}

# Export utility functions for global use
export -f command_exists
export -f detect_platform
export -f get_temp_dir
export -f normalize_path

# Mark bootstrap as loaded
readonly INFRA_BOOTSTRAP_LOADED=1
