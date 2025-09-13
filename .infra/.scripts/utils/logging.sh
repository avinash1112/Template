#!/bin/bash
# =============================================================================
# Logging Utilities
# =============================================================================
# Provides standardized logging functions with different levels and formatting

# Guard against multiple sourcing
if [[ -n "${LOGGING_UTILITIES_LOADED:-}" ]]; then
  return 0
fi

# Source platform utilities if not already loaded
if [[ -z "${PLATFORM_DETECTION_LOADED:-}" ]]; then
  source "$(dirname "${BASH_SOURCE[0]}")/platform.sh"
fi

# Log levels
readonly LOG_LEVEL_DEBUG=0
readonly LOG_LEVEL_INFO=1
readonly LOG_LEVEL_WARN=2
readonly LOG_LEVEL_ERROR=3
readonly LOG_LEVEL_FATAL=4

# Current log level (default to INFO)
LOG_LEVEL="${LOG_LEVEL:-${LOG_LEVEL_INFO}}"

# Color codes
readonly LOG_COLOR_DEBUG='\033[0;36m'   # Cyan
readonly LOG_COLOR_INFO='\033[0;34m'    # Blue
readonly LOG_COLOR_WARN='\033[1;33m'    # Yellow
readonly LOG_COLOR_ERROR='\033[0;31m'   # Red
readonly LOG_COLOR_FATAL='\033[1;31m'   # Bold Red
readonly LOG_COLOR_SUCCESS='\033[0;32m' # Green
readonly LOG_COLOR_RESET='\033[0m'      # Reset

# Log level names
readonly LOG_LEVEL_NAMES=(
  "DEBUG"
  "INFO"
  "WARN"
  "ERROR"
  "FATAL"
)

# Log level colors
readonly LOG_LEVEL_COLORS=(
  "${LOG_COLOR_DEBUG}"
  "${LOG_COLOR_INFO}"
  "${LOG_COLOR_WARN}"
  "${LOG_COLOR_ERROR}"
  "${LOG_COLOR_FATAL}"
)

# Enable/disable colors (auto-detect if terminal supports colors)
if [[ -t 1 ]] && command_exists tput && (($(tput colors) >= 8)); then
  LOG_COLORS_ENABLED=true
else
  LOG_COLORS_ENABLED=false
fi

# Override color detection
enable_log_colors() {
  LOG_COLORS_ENABLED=true
}

disable_log_colors() {
  LOG_COLORS_ENABLED=false
}

# Get current timestamp
get_log_timestamp() {
  format_date "%Y-%m-%d %H:%M:%S"
}

# Format log message
format_log_message() {
  local level="${1}"
  local message="${2}"
  local timestamp="${3:-$(get_log_timestamp)}"
  local level_name="${LOG_LEVEL_NAMES[${level}]}"
  local level_color="${LOG_LEVEL_COLORS[${level}]}"
  
  if [[ "${LOG_COLORS_ENABLED}" == "true" ]]; then
    echo -e "[${timestamp}] ${level_color}${level_name}${LOG_COLOR_RESET} ${message}"
  else
    echo "[${timestamp}] ${level_name} ${message}"
  fi
}

# Generic log function
log_message() {
  local level="${1}"
  local message="${2}"
  
  # Check if message should be logged based on current log level
  if ((level >= LOG_LEVEL)); then
    format_log_message "${level}" "${message}" >&2
  fi
}

# Debug logging
log_debug() {
  log_message "${LOG_LEVEL_DEBUG}" "${1}"
}

# Info logging
log_info() {
  log_message "${LOG_LEVEL_INFO}" "${1}"
}

# Warning logging
log_warn() {
  log_message "${LOG_LEVEL_WARN}" "${1}"
}

# Error logging
log_error() {
  log_message "${LOG_LEVEL_ERROR}" "${1}"
}

# Fatal logging (also exits)
log_fatal() {
  log_message "${LOG_LEVEL_FATAL}" "${1}"
  exit 1
}

# Success logging (always shown, special formatting)
log_success() {
  local message="${1}"
  local timestamp="$(get_log_timestamp)"
  
  if [[ "${LOG_COLORS_ENABLED}" == "true" ]]; then
    echo -e "[${timestamp}] ${LOG_COLOR_SUCCESS}✅ ${message}${LOG_COLOR_RESET}"
  else
    echo "[${timestamp}] ✅ ${message}"
  fi
}

# Step logging (for numbered steps)
log_step() {
  local step_number="${1}"
  local message="${2}"
  local timestamp="$(get_log_timestamp)"
  
  echo  # Add empty line before each step
  if [[ "${LOG_COLORS_ENABLED}" == "true" ]]; then
    echo -e "[${timestamp}] ${LOG_COLOR_INFO}STEP $(printf "%02d" "${step_number}"):${LOG_COLOR_RESET} ${message}"
  else
    echo "[${timestamp}] STEP $(printf "%02d" "${step_number}"): ${message}"
  fi
}

# Progress logging (for long-running operations)
log_progress() {
  local current="${1}"
  local total="${2}"
  local message="${3}"
  local percentage=$((current * 100 / total))
  
  if [[ "${LOG_COLORS_ENABLED}" == "true" ]]; then
    printf "\r%s[%3d%%] %s%s" \
      "${LOG_COLOR_INFO}" \
      "${percentage}" \
      "${message}" \
      "${LOG_COLOR_RESET}"
  else
    printf "\r[%3d%%] %s" "${percentage}" "${message}"
  fi
  
  # Add newline if complete
  if ((current >= total)); then
    echo
  fi
}

# Section headers
log_section() {
  local title="${1}"
  local timestamp="$(get_log_timestamp)"
  local separator="=================================================================="
  
  echo
  if [[ "${LOG_COLORS_ENABLED}" == "true" ]]; then
    echo -e "${LOG_COLOR_INFO}${separator}${LOG_COLOR_RESET}"
    echo -e "${LOG_COLOR_INFO}[${timestamp}] ${title}${LOG_COLOR_RESET}"
    echo -e "${LOG_COLOR_INFO}${separator}${LOG_COLOR_RESET}"
  else
    echo "${separator}"
    echo "[${timestamp}] ${title}"
    echo "${separator}"
  fi
  echo
}

# Subsection headers
log_subsection() {
  local title="${1}"
  local separator="------------------------------------------------------------------"
  
  echo
  if [[ "${LOG_COLORS_ENABLED}" == "true" ]]; then
    echo -e "${LOG_COLOR_DEBUG}${title}${LOG_COLOR_RESET}"
    echo -e "${LOG_COLOR_DEBUG}${separator}${LOG_COLOR_RESET}"
  else
    echo "${title}"
    echo "${separator}"
  fi
}

# Set log level from string
set_log_level() {
  local level_name
  level_name="$(echo "${1}" | tr '[:lower:]' '[:upper:]')" # Convert to uppercase
  
  case "${level_name}" in
    DEBUG)
      LOG_LEVEL="${LOG_LEVEL_DEBUG}"
    ;;

    INFO)
      LOG_LEVEL="${LOG_LEVEL_INFO}"
    ;;

    WARN|WARNING)
      LOG_LEVEL="${LOG_LEVEL_WARN}"
    ;;

    ERROR)
      LOG_LEVEL="${LOG_LEVEL_ERROR}"
    ;;

    FATAL)
      LOG_LEVEL="${LOG_LEVEL_FATAL}"
    ;;

    *)
      log_warn "Unknown log level '${level_name}', using INFO"
      LOG_LEVEL="${LOG_LEVEL_INFO}"
    ;;

  esac
    
  log_debug "Log level set to ${LOG_LEVEL_NAMES[${LOG_LEVEL}]}"
}

# Get current log level name
get_log_level_name() {
  echo "${LOG_LEVEL_NAMES[${LOG_LEVEL}]}"
}

# Log command execution
log_command() {
  local command_description="${1}"
  shift
  local command=("$@")
  
  log_debug "Executing: ${command[*]}"
  log_info "🔨 ${command_description}"
  
  if ! "${command[@]}"; then
    log_error "Command failed: ${command[*]}"
    return 1
  fi
  
  log_success "${command_description} completed"
  return 0
}

# Log file operations
log_file_operation() {
  local operation="${1}"
  local file_path="${2}"
  local description="${3:-${file_path}}"
  
  case "${operation}" in
    read)
      log_debug "Reading file: ${file_path}"
    ;;

    write)
      log_debug "Writing file: ${file_path}"
    ;;

    create)
      log_info "📝 Creating ${description}"
    ;;

    delete)
      log_info "🗑️  Deleting ${description}"
    ;;

    copy)
      log_info "📋 Copying ${description}"
    ;;

    move)
      log_info "📦 Moving ${description}"
    ;;

    *)
      log_debug "File operation '${operation}' on: ${file_path}"
    ;;

  esac
}

# Initialize logging system
init_logging() {
  local log_level="${1:-INFO}"
  local enable_colors="${2:-auto}"
  
  set_log_level "${log_level}"
  
  case "${enable_colors}" in
    true|yes|1)
      enable_log_colors
    ;;

    false|no|0)
      disable_log_colors
    ;;

    auto)
      # Keep auto-detection
    ;;

  esac
  
  log_debug "Logging system initialized (level: $(get_log_level_name), colors: ${LOG_COLORS_ENABLED})"
}

if [[ -z "${LOGGING_UTILITIES_LOADED:-}" ]]; then
  readonly LOGGING_UTILITIES_LOADED=1
fi
