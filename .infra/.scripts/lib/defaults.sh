#!/bin/bash
# =============================================================================
# Defaults Library
# =============================================================================
# Provides default values and fallback configurations

# Load constants if not already loaded
if [[ -z "${CONSTANTS_LOADED:-}" ]]; then
  source "$(dirname "${BASH_SOURCE[0]}")/constants.sh"
fi

# Set default values for optional environment variables
set_default_values() {
  # TLS configuration defaults
  export TLS_COUNTRY="${TLS_COUNTRY:-${TLS_DEFAULT_COUNTRY}}"
  export TLS_VALIDITY_DAYS="${TLS_VALIDITY_DAYS:-${TLS_DEFAULT_VALIDITY_DAYS}}"

  # Container runtime defaults
  export NODEJS_CONTAINER_RUNTIME_USER_NAME="${NODEJS_CONTAINER_RUNTIME_USER_NAME:-node}"
  export NODEJS_CONTAINER_RUNTIME_USER_GROUP="${NODEJS_CONTAINER_RUNTIME_USER_GROUP:-node}"
  export NODEJS_CONTAINER_USER_UID="${NODEJS_CONTAINER_USER_UID:-1000}"
  export NODEJS_CONTAINER_USER_GID="${NODEJS_CONTAINER_USER_GID:-1000}"

  export MYSQL_CONTAINER_RUNTIME_USER_NAME="${MYSQL_CONTAINER_RUNTIME_USER_NAME:-mysql}"
  export MYSQL_CONTAINER_RUNTIME_USER_GROUP="${MYSQL_CONTAINER_RUNTIME_USER_GROUP:-mysql}"
  export MYSQL_CONTAINER_USER_UID="${MYSQL_CONTAINER_USER_UID:-999}"
  export MYSQL_CONTAINER_USER_GID="${MYSQL_CONTAINER_USER_GID:-999}"

  export REDIS_CONTAINER_RUNTIME_USER_NAME="${REDIS_CONTAINER_RUNTIME_USER_NAME:-redis}"
  export REDIS_CONTAINER_RUNTIME_USER_GROUP="${REDIS_CONTAINER_RUNTIME_USER_GROUP:-redis}"
  export REDIS_CONTAINER_USER_UID="${REDIS_CONTAINER_USER_UID:-999}"
  export REDIS_CONTAINER_USER_GID="${REDIS_CONTAINER_USER_GID:-1000}"

  export PHP_CONTAINER_RUNTIME_USER_NAME="${PHP_CONTAINER_RUNTIME_USER_NAME:-www-data}"
  export PHP_CONTAINER_RUNTIME_USER_GROUP="${PHP_CONTAINER_RUNTIME_USER_GROUP:-www-data}"
  export PHP_CONTAINER_USER_UID="${PHP_CONTAINER_USER_UID:-82}"
  export PHP_CONTAINER_USER_GID="${PHP_CONTAINER_USER_GID:-82}"

  export NGINX_CONTAINER_RUNTIME_USER_NAME="${NGINX_CONTAINER_RUNTIME_USER_NAME:-nginx}"
  export NGINX_CONTAINER_RUNTIME_USER_GROUP="${NGINX_CONTAINER_RUNTIME_USER_GROUP:-nginx}"
  export NGINX_CONTAINER_USER_UID="${NGINX_CONTAINER_USER_UID:-101}"
  export NGINX_CONTAINER_USER_GID="${NGINX_CONTAINER_USER_GID:-101}"

  # Port defaults
  export NODEJS_CONTAINER_PORT="${NODEJS_CONTAINER_PORT:-5173}"
  export NODEJS_VITE_PREVIEW_PORT="${NODEJS_VITE_PREVIEW_PORT:-3000}"
  export MYSQL_HOST_PORT="${MYSQL_HOST_PORT:-13306}"
  export MYSQL_CONTAINER_PORT="${MYSQL_CONTAINER_PORT:-3306}"
  export REDIS_HOST_PORT="${REDIS_HOST_PORT:-16379}"
  export REDIS_CONTAINER_PORT="${REDIS_CONTAINER_PORT:-6379}"
  export PHP_FPM_CONTAINER_PORT="${PHP_FPM_CONTAINER_PORT:-9000}"
  export PHP_LARAVEL_REVERB_CONTAINER_PORT="${PHP_LARAVEL_REVERB_CONTAINER_PORT:-6001}"

  # Replica count defaults
  export NODEJS_CONFIG_READ_REPLICA_COUNT="${NODEJS_CONFIG_READ_REPLICA_COUNT:-2}"
  export MYSQL_CONFIG_READ_REPLICA_COUNT="${MYSQL_CONFIG_READ_REPLICA_COUNT:-2}"
  export REDIS_CONFIG_READ_REPLICA_COUNT="${REDIS_CONFIG_READ_REPLICA_COUNT:-2}"
  export PHP_CONFIG_APP_REPLICA_COUNT="${PHP_CONFIG_APP_REPLICA_COUNT:-2}"
  export PHP_CONFIG_WORKERS_REPLICA_COUNT="${PHP_CONFIG_WORKERS_REPLICA_COUNT:-2}"
  export NGINX_CONFIG_REPLICA_COUNT="${NGINX_CONFIG_REPLICA_COUNT:-2}"

  # Health check paths
  export PHP_CONFIG_FPM_PING_PATH="${PHP_CONFIG_FPM_PING_PATH:-/_fpm-ping}"
  export PHP_CONFIG_FPM_STATUS_PATH="${PHP_CONFIG_FPM_STATUS_PATH:-/_fpm-status}"
  export NGINX_CONFIG_PING_PATH="${NGINX_CONFIG_PING_PATH:-/_nginx-ping}"
  export NGINX_CONFIG_STUB_STATUS_PATH="${NGINX_CONFIG_STUB_STATUS_PATH:-/_nginx-status}"

  # Kubernetes resource defaults
  export K8S_VOLUME_MYSQL_PV_CAPACITY="${K8S_VOLUME_MYSQL_PV_CAPACITY:-2Gi}"

  export K8S_MYSQL_CPU_REQUEST="${K8S_MYSQL_CPU_REQUEST:-500m}"
  export K8S_MYSQL_MEMORY_REQUEST="${K8S_MYSQL_MEMORY_REQUEST:-1Gi}"
  export K8S_MYSQL_CPU_LIMIT="${K8S_MYSQL_CPU_LIMIT:-1000m}"
  export K8S_MYSQL_MEMORY_LIMIT="${K8S_MYSQL_MEMORY_LIMIT:-2Gi}"

  export K8S_LARAVEL_APP_CPU_REQUEST="${K8S_LARAVEL_APP_CPU_REQUEST:-50m}"
  export K8S_LARAVEL_APP_MEMORY_REQUEST="${K8S_LARAVEL_APP_MEMORY_REQUEST:-64Mi}"
  export K8S_LARAVEL_APP_CPU_LIMIT="${K8S_LARAVEL_APP_CPU_LIMIT:-250m}"
  export K8S_LARAVEL_APP_MEMORY_LIMIT="${K8S_LARAVEL_APP_MEMORY_LIMIT:-256Mi}"

  export K8S_NGINX_CPU_REQUEST="${K8S_NGINX_CPU_REQUEST:-50m}"
  export K8S_NGINX_MEMORY_REQUEST="${K8S_NGINX_MEMORY_REQUEST:-64Mi}"
  export K8S_NGINX_CPU_LIMIT="${K8S_NGINX_CPU_LIMIT:-250m}"
  export K8S_NGINX_MEMORY_LIMIT="${K8S_NGINX_MEMORY_LIMIT:-256Mi}"

  # Let's Encrypt configuration
  export K8S_INGRESS_LETS_ENCRYPT_PROD="${K8S_INGRESS_LETS_ENCRYPT_PROD:-https://acme-v02.api.letsencrypt.org/directory}"
  export K8S_INGRESS_LETS_ENCRYPT_STAGING="${K8S_INGRESS_LETS_ENCRYPT_STAGING:-https://acme-staging-v02.api.letsencrypt.org/directory}"
}

# Get default configuration for a service
get_service_defaults() {
  local service="${1}"

  case "${service}" in
    nodejs)
      echo "container_port=${NODEJS_CONTAINER_PORT}"
      echo "user=${NODEJS_CONTAINER_RUNTIME_USER_NAME}"
      echo "group=${NODEJS_CONTAINER_RUNTIME_USER_GROUP}"
      echo "uid=${NODEJS_CONTAINER_USER_UID}"
      echo "gid=${NODEJS_CONTAINER_USER_GID}"
    ;;

    mysql)
      echo "container_port=${MYSQL_CONTAINER_PORT}"
      echo "host_port=${MYSQL_HOST_PORT}"
      echo "user=${MYSQL_CONTAINER_RUNTIME_USER_NAME}"
      echo "group=${MYSQL_CONTAINER_RUNTIME_USER_GROUP}"
      echo "uid=${MYSQL_CONTAINER_USER_UID}"
      echo "gid=${MYSQL_CONTAINER_USER_GID}"
    ;;

    redis)
      echo "container_port=${REDIS_CONTAINER_PORT}"
      echo "host_port=${REDIS_HOST_PORT}"
      echo "user=${REDIS_CONTAINER_RUNTIME_USER_NAME}"
      echo "group=${REDIS_CONTAINER_RUNTIME_USER_GROUP}"
      echo "uid=${REDIS_CONTAINER_USER_UID}"
      echo "gid=${REDIS_CONTAINER_USER_GID}"
    ;;

    php)
      echo "fpm_port=${PHP_FPM_CONTAINER_PORT}"
      echo "reverb_port=${PHP_LARAVEL_REVERB_CONTAINER_PORT}"
      echo "user=${PHP_CONTAINER_RUNTIME_USER_NAME}"
      echo "group=${PHP_CONTAINER_RUNTIME_USER_GROUP}"
      echo "uid=${PHP_CONTAINER_USER_UID}"
      echo "gid=${PHP_CONTAINER_USER_GID}"
      echo "ping_path=${PHP_CONFIG_FPM_PING_PATH}"
      echo "status_path=${PHP_CONFIG_FPM_STATUS_PATH}"
    ;;

    nginx)
      echo "user=${NGINX_CONTAINER_RUNTIME_USER_NAME}"
      echo "group=${NGINX_CONTAINER_RUNTIME_USER_GROUP}"
      echo "uid=${NGINX_CONTAINER_USER_UID}"
      echo "gid=${NGINX_CONTAINER_USER_GID}"
      echo "ping_path=${NGINX_CONFIG_PING_PATH}"
      echo "status_path=${NGINX_CONFIG_STUB_STATUS_PATH}"
    ;;

    *)
      echo "Unknown service: ${service}" >&2
      return 1
    ;;

  esac
}

# Get default replica count for a service
get_default_replica_count() {
  local service="${1}"

  case "${service}" in
    nodejs)
    echo "${NODEJS_CONFIG_READ_REPLICA_COUNT}"
    ;;

    mysql)
      echo "${MYSQL_CONFIG_READ_REPLICA_COUNT}"
    ;;

    redis)
      echo "${REDIS_CONFIG_READ_REPLICA_COUNT}"
    ;;

    php-app)
      echo "${PHP_CONFIG_APP_REPLICA_COUNT}"
    ;;

    php-workers)
      echo "${PHP_CONFIG_WORKERS_REPLICA_COUNT}"
    ;;

    nginx)
      echo "${NGINX_CONFIG_REPLICA_COUNT}"
    ;;

    *)
      echo "1"
    ;;

  esac
}

# Get default health check configuration
get_default_health_check() {
local service="${1}"

case "${service}" in
  nodejs)
    echo "path=/health"
    echo "port=${NODEJS_CONTAINER_PORT}"
    echo "interval=30s"
    echo "timeout=10s"
    echo "retries=3"
  ;;

  mysql)
    echo "command=mysqladmin ping"
    echo "interval=30s"
    echo "timeout=10s"
    echo "retries=3"
  ;;

  redis)
    echo "command=redis-cli ping"
    echo "interval=30s"
    echo "timeout=10s"
    echo "retries=3"
  ;;

  php)
    echo "path=${PHP_CONFIG_FPM_PING_PATH}"
    echo "port=${PHP_FPM_CONTAINER_PORT}"
    echo "interval=30s"
    echo "timeout=10s"
    echo "retries=3"
  ;;
  
  nginx)
    echo "path=${NGINX_CONFIG_PING_PATH}"
    echo "port=80"
    echo "interval=30s"
    echo "timeout=10s"
    echo "retries=3"
  ;;

  *)
    echo "interval=30s"
    echo "timeout=10s"
    echo "retries=3"
  ;;
  
  esac
}

readonly DEFAULTS_LOADED=1
