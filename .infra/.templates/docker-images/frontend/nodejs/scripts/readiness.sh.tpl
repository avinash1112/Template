#!/bin/bash
set -Eeuo pipefail

# Load helpers
source /opt/nodejs/lib/00-helpers.sh

# Configuration
READINESS_PORT="${NGINX_PORT:-80}"
READINESS_TIMEOUT="${NODEJS_READINESS_TIMEOUT:-10}"
READINESS_ENDPOINT="${NODEJS_READINESS_ENDPOINT:-/ready}"

# Check if port is accessible
check_port() {
  local port="${1}"
  local timeout="${2:-5}"
  
  if command -v nc >/dev/null 2>&1; then
    if nc -z localhost "${port}" 2>/dev/null; then
      return 0
    fi
  elif command -v curl >/dev/null 2>&1; then
    if curl -sf --max-time "${timeout}" "http://localhost:${port}" >/dev/null 2>&1; then
      return 0
    fi
  else
    # Fallback: try to connect using /dev/tcp
    if timeout "${timeout}" bash -c "exec 3<>/dev/tcp/localhost/${port}" 2>/dev/null; then
      exec 3<&-
      exec 3>&-
      return 0
    fi
  fi
  
  return 1
}

# Check application health endpoint
check_health_endpoint() {
  local port="${1}"
  local endpoint="${2}"
  local timeout="${3:-5}"
  
  if command -v curl >/dev/null 2>&1; then
    local url="http://localhost:${port}${endpoint}"
    local response
    
    # Try to get response from health endpoint
    if response="$(curl -sf --max-time "${timeout}" "${url}" 2>/dev/null)"; then
      # For frontend apps, any 200 response is usually good
      # You could add more sophisticated health checks here
      return 0
    fi
  fi
  
  return 1
}

# Check if application process is running (nginx)
check_application_process() {
  # Check if nginx master process is running
  if pgrep -f "nginx: master process" >/dev/null 2>&1; then
    return 0
  fi
  
  echo_warn "[READINESS] Nginx master process not found"
  return 1
}

# Check filesystem readiness
check_filesystem() {
  # Check if we can write to temp directory
  if ! touch /tmp/nginx/readiness_test 2>/dev/null; then
    echo_warn "[READINESS] Cannot write to nginx temp directory"
    return 1
  fi
  rm -f /tmp/nginx/readiness_test
  
  # Check if static assets directory is accessible
  if [[ ! -d /var/www/html ]]; then
    echo_warn "[READINESS] Static assets directory /var/www/html not found"
    return 1
  fi
  
  # Check if index.html exists (main entry point)
  if [[ ! -f /var/www/html/index.html ]]; then
    echo_warn "[READINESS] Main entry point /var/www/html/index.html not found"
    return 1
  fi
  
  # Check if health endpoints directory exists
  if [[ ! -d /var/www/health ]]; then
    echo_warn "[READINESS] Health endpoints directory not found"
    mkdir -p /var/www/health || return 1
  fi
  
  return 0
}

# Main readiness check
main() {
  echo_info "[READINESS] Starting readiness probe"
  
  # Check filesystem first
  if ! check_filesystem; then
    echo_error "[READINESS] Filesystem check failed"
    exit 1
  fi
  
  # Check if application process is running
  if ! check_application_process; then
    echo_error "[READINESS] Application process check failed"
    exit 1
  fi
  
  # Check if port is accessible
  if ! check_port "${READINESS_PORT}" 3; then
    echo_error "[READINESS] Port ${READINESS_PORT} is not accessible"
    exit 1
  fi
  
  # Check health endpoint if available
  if ! check_health_endpoint "${READINESS_PORT}" "${READINESS_ENDPOINT}" "${READINESS_TIMEOUT}"; then
    echo_warn "[READINESS] Health endpoint check failed, but port is accessible"
    # For frontend apps, port accessibility might be sufficient
    # Don't fail the readiness check if health endpoint is not available
  fi
  
  # Role-specific checks - removed as all instances are identical replicas
  # For frontend apps, all instances serve the same content
  
  echo_success "[READINESS] All checks passed!"
  exit 0
}

# Run main function
main "$@"
