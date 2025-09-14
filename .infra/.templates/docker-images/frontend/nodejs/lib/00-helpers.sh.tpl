# Get current timestamp
_log_time() {
  date "+%Y-%m-%d %H:%M:%S"
}

# Echo info
echo_info() {
  echo "$(_log_time) INFO:: $*"
}

# Echo warning
echo_warn() {
  echo "$(_log_time) WARNING:: $*" >&2
}

# Echo error
echo_error() {
  echo "$(_log_time) ERROR:: $*" >&2
}

# Echo success
echo_success() {
  echo "$(_log_time) SUCCESS:: $*"
}

# Get hostname
get_hostname() {
  if command -v hostname >/dev/null 2>&1; then
   hostname
  elif [[ -r /etc/hostname ]]; then
    cat /etc/hostname
  else
    echo "null"
  fi
}

# Cluster coordination functions

# Discover other instances in the cluster
discover_cluster_members() {
  local service_name="${1:-nodejs}"
  local namespace="${KUBERNETES_NAMESPACE:-default}"
  local domain="${CLUSTER_DOMAIN:-cluster.local}"
  
  # For Kubernetes, try to discover other pods via DNS
  if [[ -n "${KUBERNETES_SERVICE_HOST:-}" ]]; then
    echo_info "Discovering cluster members via Kubernetes DNS"
    
    # Try to resolve the headless service
    local headless_service="${service_name}.${namespace}.svc.${domain}"
    if command -v nslookup >/dev/null 2>&1; then
      nslookup "${headless_service}" 2>/dev/null | grep -E "^Address:" | grep -v "#" | awk '{print $2}' || true
    elif command -v dig >/dev/null 2>&1; then
      dig +short "${headless_service}" 2>/dev/null || true
    fi
  else
    echo_info "Not running in Kubernetes, skipping cluster member discovery"
  fi
}

# Register this instance with the cluster
register_with_cluster() {
  local hostname="$(get_hostname)"
  local timestamp="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  
  echo_info "Registering instance ${hostname}"
  
  # Create a registration file that other instances can discover
  local reg_file="/tmp/nodejs/runtime/cluster_registration.json"
  cat > "${reg_file}" << EOF
{
  "hostname": "${hostname}",
  "role": "replica",
  "timestamp": "${timestamp}",
  "pid": $$,
  "port": "${NODEJS_CONTAINER_PORT:-5173}",
  "health_port": "${HEALTH_PORT:-9000}",
  "kubernetes_pod": "${POD_NAME:-}",
  "kubernetes_namespace": "${KUBERNETES_NAMESPACE:-}",
  "node_env": "${NODE_ENV:-development}"
}
EOF
  
  echo_success "Instance registered successfully"
}

# Get cluster status information
get_cluster_status() {
  local cluster_members=()
  mapfile -t cluster_members < <(discover_cluster_members)
  
  echo_info "Cluster status:"
  echo_info "  Total discovered members: ${#cluster_members[@]}"
  echo_info "  Instance role: replica (all instances identical)"
  echo_info "  Instance ID: ${NODEJS_INSTANCE_ID:-unknown}"
  
  if [[ ${#cluster_members[@]} -gt 0 ]]; then
    echo_info "  Discovered IPs:"
    printf '    %s\n' "${cluster_members[@]}"
  fi
}

# Check if we can reach other cluster members
ping_cluster_members() {
  local cluster_members=()
  mapfile -t cluster_members < <(discover_cluster_members)
  local reachable=0
  local total=${#cluster_members[@]}
  
  if [[ ${total} -eq 0 ]]; then
    echo_info "No cluster members to ping"
    return 0
  fi
  
  echo_info "Pinging ${total} cluster members..."
  
  for member_ip in "${cluster_members[@]}"; do
    local port="${NODEJS_CONTAINER_PORT:-5173}"
    if curl -sf --max-time 3 "http://${member_ip}:${port}/health" >/dev/null 2>&1; then
      echo_info "  ✓ ${member_ip}:${port} - reachable"
      ((reachable++))
    else
      echo_warn "  ✗ ${member_ip}:${port} - unreachable"
    fi
  done
  
  echo_info "Cluster connectivity: ${reachable}/${total} members reachable"
  return 0
}

# Wait for cluster to have minimum number of healthy instances
wait_for_cluster_ready() {
  local min_members="${1:-1}"
  local timeout="${2:-60}"
  local check_interval="${3:-5}"
  local count=0
  
  echo_info "Waiting for cluster to have at least ${min_members} ready members (timeout: ${timeout}s)"
  
  while [[ ${count} -lt ${timeout} ]]; do
    local cluster_members=()
    mapfile -t cluster_members < <(discover_cluster_members)
    local ready_members=0
    
    for member_ip in "${cluster_members[@]}"; do
      local port="${NODEJS_CONTAINER_PORT:-5173}"
      if curl -sf --max-time 3 "http://${member_ip}:${port}/ready" >/dev/null 2>&1; then
        ((ready_members++))
      fi
    done
    
    if [[ ${ready_members} -ge ${min_members} ]]; then
      echo_success "Cluster ready with ${ready_members} members"
      return 0
    fi
    
    echo_info "Cluster not ready yet (${ready_members}/${min_members} ready), waiting..."
    sleep "${check_interval}"
    count=$((count + check_interval))
  done
  
  echo_warn "Cluster readiness timeout reached, proceeding anyway"
  return 1
}

# Gracefully leave the cluster
leave_cluster() {
  local hostname="$(get_hostname)"
  echo_info "Instance ${hostname} leaving cluster"
  
  # Remove registration file
  rm -f /tmp/nodejs/runtime/cluster_registration.json
  
  echo_success "Left cluster successfully"
}
