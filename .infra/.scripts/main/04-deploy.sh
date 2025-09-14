#!/bin/bash
set -Eeuo pipefail

# Get script directory and project root
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../../.." && pwd)"

# Load core modules and utilities
source "${SCRIPT_DIR}/../lib/bootstrap.sh"
source "${SCRIPT_DIR}/../core/environment.sh"

# Script configuration
readonly SCRIPT_NAME="$(basename "${BASH_SOURCE[0]}")"
readonly VALID_ENVIRONMENTS=("dev" "staging" "production")

# Global variables
DEPLOY_ENV=""
PROJECT_NAME=""

# Display usage information
show_usage() {
    cat << EOF
Usage: ${SCRIPT_NAME} [ENVIRONMENT]

Deploy the application to the specified environment.

ENVIRONMENTS:
  Development:  --dev, --development, --local, dev, development, local
  Staging:      --stage, --staging, stage, staging
  Production:   --prod, --production, --live, prod, production, live

EXAMPLES:
  ${SCRIPT_NAME} --dev
  ${SCRIPT_NAME} --staging
  ${SCRIPT_NAME} --production
  ${SCRIPT_NAME} dev
  ${SCRIPT_NAME} staging
  ${SCRIPT_NAME} production

OPTIONS:
  -h, --help    Show this help message

EOF
}

# Parse and normalize environment argument
parse_environment() {
    local input="${1:-}"
    
    # Remove leading dashes
    input="${input#--}"
    input="${input#-}"
    
    # Convert to lowercase (bash 4+ syntax)
    input="${input,,}"
    
    case "${input}" in
        # Development variants
        "dev"|"development"|"local"|"localhost")
            echo "dev"
            ;;
        # Staging variants  
        "stage"|"staging"|"test"|"testing"|"qa"|"uat")
            echo "staging"
            ;;
        # Production variants
        "prod"|"production"|"live"|"release"|"main"|"master")
            echo "production"
            ;;
        # Help
        "h"|"help")
            show_usage
            exit 0
            ;;
        *)
            log_error "Invalid environment: '${1:-}'"
            echo
            show_usage
            exit 1
            ;;
    esac
}

# Initialize the script
init_deploy_script() {
    # Initialize logging
    init_logging "INFO" "auto"
    
    # Initialize environment
    init_environment "${INFRA_ENV_FILE}"
    
    # Validate required environment variables
    validate_deploy_environment
    
    # Validate required directories
    ensure_directory_exists "${RENDERED_DIR}" "rendered directory"
    ensure_directory_exists "${RENDERED_DIR}/deploy" "deploy directory"
    
    # Generate project name
    PROJECT_NAME="$(kebab_case "${APP_HOST_NAME}")"
    
    log_success "Deploy script initialized successfully"
}

# Validate deployment environment requirements
validate_deploy_environment() {
    log_subsection "Deployment Environment Validation"
    
    # Check if docker-compose is available
    if ! command -v docker-compose >/dev/null 2>&1; then
        log_error "docker-compose is not installed or not in PATH"
        return 1
    fi
    
    # Check if docker daemon is running
    if ! docker info >/dev/null 2>&1; then
        log_error "Docker daemon is not running"
        return 1
    fi
    
    log_success "Deployment environment validation completed"
}

# Deploy a specific stack
deploy_stack() {
    local stack_name="${1}"
    local step_number="${2}"
    
    log_step "${step_number}" "Deploying ${stack_name} stack"
    
    local compose_file="${RENDERED_DIR}/deploy/${DEPLOY_ENV}/docker-compose-${stack_name}.yml"
    local override_file="${RENDERED_DIR}/deploy/${DEPLOY_ENV}/docker-compose-${stack_name}-${INFRA_ENV}.override.yml"
    local compose_args=(-f "${compose_file}")
    
    # Check if main compose file exists
    if [[ ! -f "${compose_file}" ]]; then
        log_warn "Compose file not found: ${compose_file}"
        return 0
    fi
    
    # Add override file if it exists
    if [[ -f "${override_file}" ]]; then
        compose_args+=(-f "${override_file}")
        log_info "Using override file: $(basename "${override_file}")"
    else
        log_debug "No override file found for ${INFRA_ENV} environment"
    fi
    
    local project_name="${stack_name}-${PROJECT_NAME}"
    
    # Stop existing containers
    log_info "Stopping existing ${stack_name} containers..."
    if docker-compose -p "${project_name}" "${compose_args[@]}" down 2>/dev/null; then
        log_debug "Successfully stopped existing containers"
    else
        log_warn "No existing containers to stop or stop failed"
    fi
    
    # Start new containers
    log_info "Starting ${stack_name} containers..."
    if docker-compose -p "${project_name}" "${compose_args[@]}" up -d; then
        log_success "✓ ${stack_name} stack deployed successfully"
        return 0
    else
        log_error "✗ Failed to deploy ${stack_name} stack"
        return 1
    fi
}

# Deploy development environment
deploy_dev() {
    log_section "Development Environment Deployment"
    
    local stacks=("edge" "frontend" "backend")
    local successful_deployments=()
    local failed_deployments=()
    local step_number=1
    
    log_info "Deploying to development environment"
    log_info "Project name: ${PROJECT_NAME}"
    echo
    
    # Deploy each stack
    for stack in "${stacks[@]}"; do
        if deploy_stack "${stack}" "${step_number}"; then
            successful_deployments+=("${stack}")
        else
            failed_deployments+=("${stack}")
        fi
        step_number=$((step_number + 1))
        echo
    done
    
    # Report results
    if [[ ${#successful_deployments[@]} -gt 0 ]]; then
        log_success "Successfully deployed ${#successful_deployments[@]} stacks:"
        for stack in "${successful_deployments[@]}"; do
            echo "  ✅ ${stack}"
        done
    fi
    
    if [[ ${#failed_deployments[@]} -gt 0 ]]; then
        echo
        log_error "Failed to deploy ${#failed_deployments[@]} stacks:"
        for stack in "${failed_deployments[@]}"; do
            echo "  ❌ ${stack}"
        done
        return 1
    fi
    
    log_success "Development environment deployment completed successfully"
    return 0
}

# Deploy staging environment
deploy_staging() {
    log_section "Staging Environment Deployment"
    
    log_info "TODO: Implement staging deployment"
    log_warn "Staging deployment is not yet implemented"
    
    # TODO: Implement staging-specific deployment logic
    # - Pull images from registry
    # - Deploy with staging configurations
    # - Run health checks
    # - Update load balancer configurations
    
    return 0
}

# Deploy production environment
deploy_production() {
    log_section "Production Environment Deployment"
    
    log_info "TODO: Implement production deployment"
    log_warn "Production deployment is not yet implemented"
    
    # TODO: Implement production-specific deployment logic
    # - Blue-green deployment strategy
    # - Pull images from registry
    # - Deploy with production configurations
    # - Run comprehensive health checks
    # - Update load balancer configurations
    # - Send deployment notifications
    
    return 0
}

# Main deployment orchestrator
deploy_environment() {
    case "${DEPLOY_ENV}" in
        "dev")
            deploy_dev
            ;;
        "staging")
            deploy_staging
            ;;
        "production")
            deploy_production
            ;;
        *)
            log_error "Unknown deployment environment: ${DEPLOY_ENV}"
            return 1
            ;;
    esac
}

# Main execution function
main() {
    local env_arg="${1:-}"
    
    # Check for help or missing arguments
    if [[ -z "${env_arg}" ]]; then
        log_error "Environment argument is required"
        echo
        show_usage
        exit 1
    fi
    
    # Parse environment
    DEPLOY_ENV="$(parse_environment "${env_arg}")"
    
    log_section "Application Deployment Process"
    log_info "Target environment: ${DEPLOY_ENV}"
    
    # Initialize script
    init_deploy_script
    
    # Deploy to target environment
    deploy_environment
    
    log_success "Deployment process completed for ${DEPLOY_ENV} environment"
}

# Execute main function if script is run directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    # Execute in subshell to prevent environment pollution
    (
        main "$@"
    )
    exit $?
fi