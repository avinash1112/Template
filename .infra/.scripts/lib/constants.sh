#!/bin/bash
# =============================================================================
# Constants Library
# =============================================================================
# Defines application-wide constants used throughout the infrastructure scripts

# Template processing constants
readonly TEMPLATE_FILE_EXTENSION=".tpl"
readonly PLACEHOLDER_REGEX='__[A-Z0-9]+(?:_[A-Z0-9]+)*__'

# Service names and types
readonly -a FRONTEND_SERVICES=("nodejs")
readonly -a BACKEND_SERVICES=("mysql" "redis" "php" "nginx")
readonly -a ALL_SERVICES=("${FRONTEND_SERVICES[@]}" "${BACKEND_SERVICES[@]}")

# Container registry
readonly CONTAINER_REGISTRY_DOMAIN="ghcr.io"

# TLS certificate configuration
readonly TLS_DEFAULT_COUNTRY="CA"
readonly TLS_DEFAULT_VALIDITY_DAYS=3650
readonly TLS_KEY_SIZE=2048

# Docker configuration
readonly DOCKER_COMPOSE_VERSION="3.8"
readonly DOCKER_NETWORK_DRIVER="bridge"

# File permissions
readonly SCRIPT_PERMISSIONS="755"
readonly CONFIG_PERMISSIONS="644"
readonly SECRET_PERMISSIONS="600"
readonly DIRECTORY_PERMISSIONS="755"

# Log retention and cleanup
readonly LOG_RETENTION_DAYS=30
readonly TEMP_FILE_CLEANUP_HOURS=24

# Validation patterns
readonly EMAIL_PATTERN='^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$'
readonly HOSTNAME_PATTERN='^[a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?(\.[a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?)*$'
readonly IPV4_PATTERN='^([0-9]{1,3}\.){3}[0-9]{1,3}$'
readonly PORT_PATTERN='^[0-9]+$'

# Environment validation groups
readonly -a ENV_VARS_BASIC=(
"INFRA_ENV"
"APP_HOST_NAME"
"APP_NAME"
"APP_TIMEZONE"
)

readonly -a ENV_VARS_CONTAINER_REGISTRY=(
"CONTAINER_REGISTRY_USERNAME"
"CONTAINER_REGISTRY_EMAIL"
"REPO_NAME"
"REPO_BRANCH"
)

readonly -a ENV_VARS_MYSQL=(
"MYSQL_DATABASE"
"MYSQL_ROOT_PASSWORD"
"MYSQL_RW_USER_NAME"
"MYSQL_RW_USER_PASSWORD"
"MYSQL_RO_USER_NAME"
"MYSQL_RO_USER_PASSWORD"
"MYSQL_HOST_PORT"
"MYSQL_CONTAINER_PORT"
)

readonly -a ENV_VARS_REDIS=(
"REDIS_RW_USER_NAME"
"REDIS_RW_USER_PASSWORD"
"REDIS_HOST_PORT"
"REDIS_CONTAINER_PORT"
)

readonly -a ENV_VARS_PRODUCTION=(
"SSH_HOSTNAME"
"SSH_USER"
"SSH_PORT"
"SSH_IDENTITY_FILE"
"K8S_NAMESPACE"
)

# Exit codes
readonly EXIT_SUCCESS=0
readonly EXIT_GENERAL_ERROR=1
readonly EXIT_MISUSE_SHELL_BUILTINS=2
readonly EXIT_CANNOT_EXECUTE=126
readonly EXIT_COMMAND_NOT_FOUND=127
readonly EXIT_INVALID_EXIT_ARGUMENT=128
readonly EXIT_VALIDATION_FAILED=10
readonly EXIT_ENVIRONMENT_ERROR=11
readonly EXIT_TEMPLATE_ERROR=12
readonly EXIT_DOCKER_ERROR=13
readonly EXIT_NETWORK_ERROR=14
readonly EXIT_KUBERNETES_ERROR=15

readonly CONSTANTS_LOADED=1
