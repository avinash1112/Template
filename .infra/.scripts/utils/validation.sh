#!/bin/bash
# =============================================================================
# Validation Utilities
# =============================================================================
# Provides comprehensive validation functions for environment variables,
# file paths, network addresses, and other inputs

# Guard against multiple sourcing
if [[ -n "${VALIDATION_UTILITIES_LOADED:-}" ]]; then
  return 0
fi

# Source platform utilities if not already loaded
if [[ -z "${PLATFORM_DETECTION_LOADED:-}" ]]; then
  source "$(dirname "${BASH_SOURCE[0]}")/platform.sh"
fi

# Color codes for output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m' # No Color

# Validation result tracking
VALIDATION_ERRORS=0
VALIDATION_WARNINGS=0

# Reset validation counters
reset_validation_counters() {
  VALIDATION_ERRORS=0
  VALIDATION_WARNINGS=0
}

# Log validation error
log_validation_error() {
  local message="${1}"
  echo -e "${RED}❌ ERROR: ${message}${NC}" >&2
  ((VALIDATION_ERRORS++))
}

# Log validation warning
log_validation_warning() {
  local message="${1}"
  echo -e "${YELLOW}⚠️  WARNING: ${message}${NC}" >&2
  ((VALIDATION_WARNINGS++))
}

# Log validation success
log_validation_success() {
  local message="${1}"
  echo -e "${GREEN}✅ ${message}${NC}"
}

# Log validation info
log_validation_info() {
  local message="${1}"
  echo -e "${BLUE}ℹ️  ${message}${NC}"
}

# Validate required environment variable
validate_required_env_var() {
  local var_name="${1}"
  local description="${2:-${var_name}}"
  
  if [[ -z "${!var_name:-}" ]]; then
    log_validation_error "Required environment variable '${var_name}' (${description}) is not set"
    return 1
  fi
  
  log_validation_success "Environment variable '${var_name}' is set"
  return 0
}

# Validate environment variable with pattern
validate_env_var_pattern() {
  local var_name="${1}"
  local pattern="${2}"
  local description="${3:-${var_name}}"
  
  if [[ -z "${!var_name:-}" ]]; then
    log_validation_error "Environment variable '${var_name}' (${description}) is not set"
    return 1
  fi
  
  if [[ ! "${!var_name}" =~ ${pattern} ]]; then
    log_validation_error "Environment variable '${var_name}' (${description}) does not match pattern: ${pattern}"
    return 1
  fi
  
  log_validation_success "Environment variable '${var_name}' matches pattern"
  return 0
}

# Validate file exists and is readable
validate_file_readable() {
  local file_path="${1}"
  local description="${2:-${file_path}}"
  
  if [[ ! -f "${file_path}" ]]; then
    log_validation_error "File '${file_path}' (${description}) does not exist"
    return 1
  fi
  
  if [[ ! -r "${file_path}" ]]; then
    log_validation_error "File '${file_path}' (${description}) is not readable"
    return 1
  fi
  
  log_validation_success "File '${file_path}' exists and is readable"
  return 0
}

# Validate directory exists and is writable
validate_directory_writable() {
  local dir_path="${1}"
  local description="${2:-${dir_path}}"
  
  if [[ ! -d "${dir_path}" ]]; then
    log_validation_error "Directory '${dir_path}' (${description}) does not exist"
    return 1
  fi
  
  if [[ ! -w "${dir_path}" ]]; then
    log_validation_error "Directory '${dir_path}' (${description}) is not writable"
    return 1
  fi
  
  log_validation_success "Directory '${dir_path}' exists and is writable"
  return 0
}

# Validate command exists
validate_command_exists() {
  local command_name="${1}"
  local description="${2:-${command_name}}"
  
  if ! command_exists "${command_name}"; then
    log_validation_error "Required command '${command_name}' (${description}) is not available"
    return 1
  fi
  
  log_validation_success "Command '${command_name}' is available"
  return 0
}

# Validate IP address
validate_ip_address() {
  local ip="${1}"
  local description="${2:-IP address}"
  
  # IPv4 validation
  if [[ "${ip}" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]]; then
    local IFS='.'
    local -a octets=(${ip})
    for octet in "${octets[@]}"; do
      if ((octet < 0 || octet > 255)); then
        log_validation_error "${description} '${ip}' is not a valid IPv4 address"
        return 1
      fi
    done
    log_validation_success "${description} '${ip}' is a valid IPv4 address"
    return 0
  fi
  
  # Basic IPv6 validation (simplified)
  if [[ "${ip}" =~ ^[0-9a-fA-F:]+$ ]] && [[ "${ip}" == *":"* ]]; then
    log_validation_success "${description} '${ip}' appears to be a valid IPv6 address"
    return 0
  fi
  
  log_validation_error "${description} '${ip}' is not a valid IP address"
  return 1
}

# Silent IP address validation (no logging)
validate_ip_address_silent() {
  local ip="${1}"
  
  # Basic IPv4 validation
  if [[ "${ip}" =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
    IFS='.' read -ra ADDR <<< "${ip}"
    for i in "${ADDR[@]}"; do
      if ((i > 255)); then
        return 1
      fi
    done
    return 0
  fi
  
  # Basic IPv6 validation (simplified)
  if [[ "${ip}" =~ ^[0-9a-fA-F:]+$ ]] && [[ "${ip}" == *":"* ]]; then
    return 0
  fi
  
  return 1
}

# Validate hostname or FQDN
validate_hostname() {
  local hostname="${1}"
  local description="${2:-hostname}"
  
  # Check if it's an IP address first (silent check)
  if validate_ip_address_silent "${hostname}"; then
    log_validation_success "${description} '${hostname}' is a valid IP address"
    return 0
  fi
  
  # Hostname validation
  if [[ "${hostname}" =~ ^[a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?(\.[a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?)*$ ]]; then
    log_validation_success "${description} '${hostname}' is a valid hostname"
    return 0
  fi
  
  log_validation_error "${description} '${hostname}' is not a valid hostname"
  return 1
}

# Validate port number
validate_port() {
  local port="${1}"
  local description="${2:-port}"
  
  if [[ ! "${port}" =~ ^[0-9]+$ ]]; then
    log_validation_error "${description} '${port}' is not a valid port number"
    return 1
  fi
  
  if ((port < 1 || port > 65535)); then
    log_validation_error "${description} '${port}' is not in valid range (1-65535)"
    return 1
  fi
  
  log_validation_success "${description} '${port}' is valid"
  return 0
}

# Validate URL
validate_url() {
  local url="${1}"
  local description="${2:-URL}"
  
  if [[ "${url}" =~ ^https?://[a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?(\.[a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?)*([/?].*)?$ ]]; then
    log_validation_success "${description} '${url}' is valid"
    return 0
  fi
  
  log_validation_error "${description} '${url}' is not a valid URL"
  return 1
}

# Validate email address
validate_email() {
  local email="${1}"
  local description="${2:-email address}"
  
  if [[ "${email}" =~ ^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$ ]]; then
    log_validation_success "${description} '${email}' is valid"
    return 0
  fi
  
  log_validation_error "${description} '${email}' is not a valid email address"
  return 1
}

# Validate Docker image name
validate_docker_image_name() {
  local image_name="${1}"
  local description="${2:-Docker image name}"
  
  # Docker image name validation - more lenient for complete image names with registry
  # Format: [registry/]namespace/repository[:tag]
  if [[ "${image_name}" =~ ^[a-z0-9._-]+(/[a-z0-9._-]+)+(:[[a-z0-9._-]+)?$ ]]; then
    log_validation_success "${description} '${image_name}' is valid"
    return 0
  fi
  
  log_validation_error "${description} '${image_name}' is not a valid Docker image name"
  return 1
}

# Sanitize name for Docker image use
sanitize_for_docker() {
  local input="${1}"
  # Convert dots to hyphens, ensure lowercase, remove invalid characters
  echo "${input}" | tr '[:upper:]' '[:lower:]' | tr '.' '-' | sed 's/[^a-z0-9-]//g'
}

# Validate numeric range
validate_numeric_range() {
  local value="${1}"
  local min="${2}"
  local max="${3}"
  local description="${4:-value}"
  
  if [[ ! "${value}" =~ ^[0-9]+$ ]]; then
    log_validation_error "${description} '${value}' is not a number"
    return 1
  fi
  
  if ((value < min || value > max)); then
    log_validation_error "${description} '${value}' is not in valid range (${min}-${max})"
    return 1
  fi
  
  log_validation_success "${description} '${value}' is in valid range"
  return 0
}

# Validate and create directory if needed
ensure_directory() {
  local dir_path="${1}"
  local description="${2:-${dir_path}}"
  
  if [[ ! -d "${dir_path}" ]]; then
    log_validation_info "Creating directory '${dir_path}' (${description})"
    if ! mkdir -p "${dir_path}"; then
      log_validation_error "Failed to create directory '${dir_path}' (${description})"
      return 1
    fi
  fi
  
  validate_directory_writable "${dir_path}" "${description}"
}

# Print validation summary
print_validation_summary() {
  echo
  echo "=== Validation Summary ==="
  
  if ((VALIDATION_ERRORS > 0)); then
    echo -e "${RED}❌ ${VALIDATION_ERRORS} error(s) found${NC}"
  fi
  
  if ((VALIDATION_WARNINGS > 0)); then
    echo -e "${YELLOW}⚠️  ${VALIDATION_WARNINGS} warning(s) found${NC}"
  fi
  
  if ((VALIDATION_ERRORS == 0 && VALIDATION_WARNINGS == 0)); then
    echo -e "${GREEN}✅ All validations passed${NC}"
  fi
  
  echo "=========================="
  echo
  
  return $((VALIDATION_ERRORS > 0 ? 1 : 0))
}

if [[ -z "${VALIDATION_UTILITIES_LOADED:-}" ]]; then
  readonly VALIDATION_UTILITIES_LOADED=1
fi
