#!/bin/bash
set -Eeuo pipefail

# Load helpers
source /opt/nodejs/lib/00-helpers.sh

# Configuration
LIVENESS_PORT="${NGINX_PORT:-80}"
LIVENESS_TIMEOUT="${NODEJS_LIVENESS_TIMEOUT:-5}"

# Check if the main application process is alive (nginx)
check_process_alive() {
  # Check if nginx master process is running
  if pgrep -f "nginx: master process" >/dev/null 2>&1; then
    return 0
  fi
  
  echo_error "[LIVENESS] Nginx master process is not running"
  return 1
}

# Check if port is responsive
check_port_responsive() {
  local port="${1}"
  local timeout="${2:-3}"
  
  if command -v curl >/dev/null 2>&1; then
    # Try a simple HTTP request
    if curl -sf --max-time "${timeout}" "http://localhost:${port}" >/dev/null 2>&1; then
      return 0
    fi
  elif command -v nc >/dev/null 2>&1; then
    # Fallback to netcat
    if echo -e "GET / HTTP/1.0\r\n\r\n" | nc -w "${timeout}" localhost "${port}" >/dev/null 2>&1; then
      return 0
    fi
  else
    # Last resort: try TCP connection
    if timeout "${timeout}" bash -c "exec 3<>/dev/tcp/localhost/${port}" 2>/dev/null; then
      exec 3<&-
      exec 3>&-
      return 0
    fi
  fi
  
  return 1
}

# Check system resources (memory, disk)
check_system_resources() {
  # Check available memory (basic check)
  if command -v free >/dev/null 2>&1; then
    local available_mem_kb
    available_mem_kb="$(free | awk '/^Mem:/ {print $7}')"
    if [[ -n "${available_mem_kb}" ]] && [[ "${available_mem_kb}" -lt 50000 ]]; then
      echo_warn "[LIVENESS] Low available memory: ${available_mem_kb}KB"
      # Don't fail liveness for low memory, just warn
    fi
  fi
  
  # Check disk space in temp directory
  local temp_usage
  temp_usage="$(df /tmp | awk 'NR==2 {print $5}' | sed 's/%//')"
  if [[ -n "${temp_usage}" ]] && [[ "${temp_usage}" -gt 95 ]]; then
    echo_warn "[LIVENESS] High disk usage in /tmp: ${temp_usage}%"
    # Don't fail liveness for high disk usage, just warn
  fi
  
  return 0
}

# Check if container is in a deadlock state
check_deadlock() {
  # Check if there are too many nginx processes (should be master + workers)
  local nginx_processes
  nginx_processes="$(pgrep -f nginx | wc -l)"
  
  # Normally should have 1 master + worker processes (typically 1-4 workers)
  if [[ "${nginx_processes}" -gt 10 ]]; then
    echo_warn "[LIVENESS] High number of nginx processes: ${nginx_processes}"
  fi
  
  # Check for zombie processes
  local zombie_count
  zombie_count="$(ps aux | awk '$8 ~ /^Z/ { count++ } END { print count+0 }')"
  
  if [[ "${zombie_count}" -gt 5 ]]; then
    echo_warn "[LIVENESS] High number of zombie processes: ${zombie_count}"
  fi
  
  return 0
}

# Main liveness check
main() {
  echo_info "[LIVENESS] Starting liveness probe"
  
  # Core check: Is the main process alive?
  if ! check_process_alive; then
    echo_error "[LIVENESS] Main process is not alive"
    exit 1
  fi
  
  # Core check: Is the application port responsive?
  if ! check_port_responsive "${LIVENESS_PORT}" "${LIVENESS_TIMEOUT}"; then
    echo_error "[LIVENESS] Application port ${LIVENESS_PORT} is not responsive"
    exit 1
  fi
  
  # Additional system checks (non-fatal)
  check_system_resources
  check_deadlock
  
  echo_success "[LIVENESS] All checks passed!"
  exit 0
}

# Run main function
main "$@"
