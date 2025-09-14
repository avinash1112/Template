#!/bin/bash
set -Eeuo pipefail

# Load helpers
source /opt/nodejs/lib/00-helpers.sh

# Environment detection and instance configuration
detect_instance_config() {
  # For frontend apps, all instances are identical replicas
  export NODEJS_ROLE="replica"
  export NODEJS_IS_MASTER="false"
  export NODEJS_IS_REPLICA="true"
  
  # Get instance information for logging/monitoring
  local hostname="$(get_hostname)"
  local instance_id="${hostname}"
  
  # Try to extract ordinal for monitoring purposes only
  if [[ "${hostname}" =~ -([0-9]+)$ ]]; then
    local pod_ordinal="${BASH_REMATCH[1]}"
    export POD_ORDINAL="${pod_ordinal}"
    instance_id="${hostname} (ordinal: ${pod_ordinal})"
  elif [[ -n "${POD_NAME:-}" ]]; then
    instance_id="${POD_NAME}"
  fi
  
  export NODEJS_INSTANCE_ID="${instance_id}"
  echo_info "Detected instance: ${instance_id} (role: replica)"
}

# Initialize application
initialize_application() {
  echo_info "Initializing frontend application instance"
  
  # Create runtime directories
  mkdir -p /tmp/nodejs/{logs,pids,runtime}
  
  # Register instance for monitoring/discovery
  register_instance
  
  # Common initialization for all instances
  echo_info "Performing application initialization"
  
  # For frontend apps, we might want to:
  # - Warm up any caches
  # - Verify static assets are available
  # - Test connectivity to backend APIs (if needed)
  
  # Discover other instances for monitoring
  get_cluster_status
  
  # Set up signal handlers for graceful shutdown
  trap 'handle_shutdown' SIGTERM SIGINT
  
  echo_success "Frontend application initialized successfully"
}

# Register this instance for discovery/monitoring
register_instance() {
  local hostname="$(get_hostname)"
  local timestamp="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  
  echo_info "Registering instance ${hostname}"
  
  # Create a registration file for monitoring/discovery
  local reg_file="/tmp/nodejs/runtime/instance_registration.json"
  cat > "${reg_file}" << EOF
{
  "hostname": "${hostname}",
  "instance_id": "${NODEJS_INSTANCE_ID}",
  "role": "${NODEJS_ROLE}",
  "timestamp": "${timestamp}",
  "pid": $$,
  "port": "${NODEJS_CONTAINER_PORT:-5173}",
  "health_port": "${HEALTH_PORT:-9000}",
  "pod_name": "${POD_NAME:-}",
  "pod_ordinal": "${POD_ORDINAL:-}",
  "kubernetes_namespace": "${KUBERNETES_NAMESPACE:-}",
  "node_env": "${NODE_ENV:-development}",
  "app_version": "${APP_VERSION:-unknown}"
}
EOF
  
  echo_success "Instance registered successfully"
}

# Handle graceful shutdown
handle_shutdown() {
  echo_info "Received shutdown signal, performing graceful shutdown"
  
  # Unregister instance
  leave_cluster
  
  # If we have a PID file, try to gracefully stop the process
  if [[ -f /tmp/nodejs/pids/app.pid ]]; then
    local pid="$(cat /tmp/nodejs/pids/app.pid)"
    if kill -0 "${pid}" 2>/dev/null; then
      echo_info "Sending SIGTERM to application (PID: ${pid})"
      kill -TERM "${pid}"
      
      # Wait for graceful shutdown
      local count=0
      while [[ ${count} -lt 30 ]] && kill -0 "${pid}" 2>/dev/null; do
        sleep 1
        count=$((count + 1))
      done
      
      # Force kill if still running
      if kill -0 "${pid}" 2>/dev/null; then
        echo_warn "Application didn't shut down gracefully, forcing termination"
        kill -KILL "${pid}"
      fi
    fi
  fi
  
  # Also try to stop PM2 if running in production
  if command -v pm2 >/dev/null 2>&1; then
    echo_info "Stopping PM2 processes"
    pm2 stop all >/dev/null 2>&1 || true
    pm2 delete all >/dev/null 2>&1 || true
  fi
  
  echo_info "Graceful shutdown completed"
  exit 0
}

# Detect instance configuration and initialize
detect_instance_config
initialize_application

# Final handoff
exec "$@"
