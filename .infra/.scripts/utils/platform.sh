#!/bin/bash
# =============================================================================
# Platform Compatibility Utilities
# =============================================================================
# Provides cross-platform compatible functions for macOS, Linux, and Windows/WSL
# Handles differences in core utilities like sed, grep, etc.

# Guard against multiple sourcing
if [[ -n "${PLATFORM_DETECTION_LOADED:-}" ]]; then
  return 0
fi

# Platform detection
detect_platform() {
  local platform=""
  case "${OSTYPE}" in
    darwin*)
      platform="macos"
    ;;

    linux*)
      if [[ -f /proc/version ]] && grep -qi microsoft /proc/version; then
        platform="wsl"
      else
        platform="linux"
      fi
    ;;

    msys*|cygwin*)
      platform="windows"
    ;;

    *)
      platform="unknown"
    ;;

  esac
  echo "${platform}"
}

# Get platform-appropriate sed in-place arguments
get_sed_inplace_args() {
  local platform="${1:-$(detect_platform)}"
  case "${platform}" in
    macos)
      echo "-i ''"
    ;;

    linux|wsl|windows)
      echo "-i"
    ;;

    *)
      # Default to GNU sed behavior
      echo "-i"
    ;;

  esac
}

# Cross-platform sed in-place replacement
sed_inplace() {
  local expression="${1}"
  local file="${2}"
  local platform="${3:-$(detect_platform)}"
  
  case "${platform}" in
    macos)
      sed -i '' "${expression}" "${file}"
    ;;

    linux|wsl|windows)
      sed -i "${expression}" "${file}"
    ;;

    *)
      # Fallback: create temp file and replace
      local temp_file
      temp_file="$(mktemp)"
      sed "${expression}" "${file}" > "${temp_file}"
      mv "${temp_file}" "${file}"
    ;;

  esac
}

# Cross-platform base64 encoding/decoding
base64_encode() {
  local input="${1}"
  local platform="${2:-$(detect_platform)}"
  
  case "${platform}" in
    macos)
      echo -n "${input}" | base64
    ;;

    linux|wsl|windows)
      echo -n "${input}" | base64 -w 0
    ;;

    *)
      echo -n "${input}" | base64
    ;;

  esac
}

# Cross-platform date formatting
format_date() {
  local format="${1}"
  local platform="${2:-$(detect_platform)}"
  
  case "${platform}" in
    macos)
      date "+${format}"
    ;;

    linux|wsl|windows)
      date "+${format}"
    ;;

    *)
      date "+${format}"
    ;;

  esac
}

# Check if running in Docker
is_running_in_docker() {
  [[ -f /.dockerenv ]] || grep -q docker /proc/1/cgroup 2>/dev/null
}

# Check if running in Kubernetes
is_running_in_kubernetes() {
  [[ -n "${KUBERNETES_SERVICE_HOST:-}" ]] || [[ -d /var/run/secrets/kubernetes.io ]]
}

# Get available memory in MB
get_available_memory_mb() {
  local platform="${1:-$(detect_platform)}"
  
  case "${platform}" in
    macos)
      # Get memory in bytes and convert to MB
      local memory_bytes
      memory_bytes="$(sysctl -n hw.memsize)"
      echo $((memory_bytes / 1024 / 1024))
    ;;

    linux|wsl)
      # Parse /proc/meminfo
      awk '/MemAvailable/ {print int($2/1024)}' /proc/meminfo 2>/dev/null || \
      awk '/MemFree/ {print int($2/1024)}' /proc/meminfo
    ;;

    *)
      # Default fallback
      echo "1024"
    ;;

  esac
}

# Get number of CPU cores
get_cpu_cores() {
  local platform="${1:-$(detect_platform)}"
  
  case "${platform}" in
    macos)
      sysctl -n hw.ncpu
    ;;

    linux|wsl)
      nproc
    ;;

    *)
      # Default fallback
      echo "1"
    ;;

  esac
}

# Check if command exists
command_exists() {
  command -v "${1}" >/dev/null 2>&1
}

# Get platform-specific temp directory
get_temp_dir() {
  local platform="${1:-$(detect_platform)}"
  
  if [[ -n "${TMPDIR:-}" ]]; then
    echo "${TMPDIR}"
  elif [[ -d /tmp ]]; then
    echo "/tmp"
  else
    echo "."
  fi
}

# Platform-specific file path handling
normalize_path() {
  local path="${1}"
  local platform="${2:-$(detect_platform)}"
  
  case "${platform}" in
    windows|wsl)
      # Convert Windows paths to Unix-style if needed
      echo "${path}" | sed 's|\\|/|g'
    ;;

    *)
      echo "${path}"
    ;;

  esac
}

# Export all functions for use in other scripts
if [[ -z "${PLATFORM_DETECTION_LOADED:-}" ]]; then
  readonly PLATFORM_DETECTION_LOADED=1
fi