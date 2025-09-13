#!/bin/bash
set -Eeuo pipefail

# Get script directory and project root
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../../.." && pwd)"

# Load core modules and utilities
source "${SCRIPT_DIR}/../lib/bootstrap.sh"
source "${SCRIPT_DIR}/../core/environment.sh"
source "${SCRIPT_DIR}/../utils/validation.sh"

# Script configuration
readonly SCRIPT_NAME="$(basename "${BASH_SOURCE[0]}")"
readonly IMAGE_TAG="latest"
readonly STACKS=("frontend" "backend")
readonly REGISTRY_HOST="ghcr.io"

# Initialize the script
init_push_script() {
  # Initialize logging
  init_logging "INFO" "auto"

  # Initialize environment
  init_environment "${INFRA_ENV_FILE}"

  # Check if pushing is needed for this environment
  # if [[ "${INFRA_ENV}" == "dev" ]]; then
  #   log_info "Environment is 'dev' - skipping image push"
  #   exit 0
  # fi

  # Validate required environment variables
  validate_push_environment

  # Validate required directories
  ensure_directory_exists "${RENDERED_DIR}" "rendered directory"
  ensure_directory_exists "${RENDERED_DIR}/docker-images" "docker images directory"

  log_success "Push script initialized successfully"
}

# Validate push environment requirements
validate_push_environment() {
  log_subsection "Container Registry Environment Validation"

  # Check if docker is available
  if ! command -v docker >/dev/null 2>&1; then
    log_error "Docker is not installed or not in PATH"
    return 1
  fi

  # Check if docker daemon is running
  if ! docker info >/dev/null 2>&1; then
    log_error "Docker daemon is not running"
    return 1
  fi

  # Validate required environment variables
  local required_vars=(
    "CONTAINER_REGISTRY_USERNAME"
    "CONTAINER_REGISTRY_PAT_RW"
    "REPO_NAME"
    "INFRA_ENV"
  )

  for var in "${required_vars[@]}"; do
    if [[ -z "${!var:-}" ]]; then
      log_error "Required environment variable '${var}' is not set"
      return 1
    fi
  done

  log_success "Container registry environment validation completed"
}

# Login to container registry
registry_login() {
  log_step 1 "Logging into container registry"

  log_info "Logging into ${REGISTRY_HOST} as ${CONTAINER_REGISTRY_USERNAME}"

  if echo "${CONTAINER_REGISTRY_PAT_RW}" | \
    docker login "${REGISTRY_HOST}" \
    -u "${CONTAINER_REGISTRY_USERNAME}" \
    --password-stdin 2>&1 | sed 's/^/    /'; then
    log_success "Successfully logged into container registry"
    return 0
  else
    log_error "Failed to login to container registry"
    return 1
  fi
}

# Push a single Docker image
push_docker_image() {
  local service_name="${1}"
  local image_tag="${2}"

  log_info "Pushing ${service_name} image..."
  log_debug "Image tag: ${image_tag}"

  # Check if image exists locally
  if ! docker image inspect "${image_tag}" >/dev/null 2>&1; then
    log_error "Image not found locally: ${image_tag}"
    return 1
  fi

  # Push the image
  local push_start_time=$(date +%s)

  if docker push "${image_tag}"; then
    local push_end_time=$(date +%s)
    local push_duration=$((push_end_time - push_start_time))

    log_success "Successfully pushed ${service_name} image in ${push_duration}s"
    return 0
  else
    log_error "Failed to push ${service_name} image"
    return 1
  fi
}

# Push images for a specific stack
push_stack_images() {
  local stack="${1}"
  local step_number="${2}"
  local stack_dir="${RENDERED_DIR}/docker-images/${stack}"

  log_step "${step_number}" "Pushing ${stack} images"

  if [[ ! -d "${stack_dir}" ]]; then
    log_warning "Stack directory not found: ${stack_dir}"
    return 0
  fi

  local services=()
  local successful_pushes=()
  local failed_pushes=()

  # Find all services in the stack
  for service_dir in "${stack_dir}"/*/; do
    if [[ -d "${service_dir}" ]]; then
      local service=$(basename "${service_dir}")
      # Skip proxy service if it exists
      [[ "${service}" == "proxy" ]] && continue
      services+=("${service}")
    fi
  done

  if [[ ${#services[@]} -eq 0 ]]; then
    log_info "No services found in ${stack} stack"
    return 0
  fi

  log_info "Found ${#services[@]} services to push: ${services[*]}"

  # Push each service
  for service in "${services[@]}"; do
    local sanitized_repo_name
    sanitized_repo_name="$(sanitize_for_docker "${REPO_NAME}")"
    local image_name="${sanitized_repo_name}-${service}"
    local image_tag="${REGISTRY_HOST}/${CONTAINER_REGISTRY_USERNAME}/${image_name}:${IMAGE_TAG}"

    if push_docker_image "${service}" "${image_tag}"; then
      successful_pushes+=("${service}:${image_tag}")
    else
      failed_pushes+=("${service}")
    fi
  done

  # Report results
  if [[ ${#successful_pushes[@]} -gt 0 ]]; then
    echo
    log_success "Successfully pushed ${#successful_pushes[@]} ${stack} images:"
    for push in "${successful_pushes[@]}"; do
      echo "  ✅ ${push}"
    done
  fi

  if [[ ${#failed_pushes[@]} -gt 0 ]]; then
    echo
    log_error "Failed to push ${#failed_pushes[@]} ${stack} images:"
    for service in "${failed_pushes[@]}"; do
      echo "  ❌ ${service}"
    done
    return 1
  fi

  return 0
}

# Push all Docker images
push_all_images() {
  log_section "Pushing Docker Images to Registry"

  local total_successful=0
  local total_failed=0
  local failed_stacks=()
  local step_number=2

  for stack in "${STACKS[@]}"; do
    if push_stack_images "${stack}" "${step_number}"; then
      total_successful=$((total_successful + 1))
    else
      total_failed=$((total_failed + 1))
      failed_stacks+=("${stack}")
    fi
    step_number=$((step_number + 1))
    echo
  done

  # Final summary
  if [[ ${total_failed} -eq 0 ]]; then
    log_success "All ${total_successful} stacks pushed successfully"
    return 0
  else
    log_error "Push completed with errors: ${total_successful} successful, ${total_failed} failed"
    if [[ ${#failed_stacks[@]} -gt 0 ]]; then
      log_error "Failed stacks: ${failed_stacks[*]}"
    fi
    return 1
  fi
}

# Main execution function
main() {
  log_section "Docker Image Push Process"

  init_push_script
  registry_login
  push_all_images

  log_success "Docker image push process completed"
}

# Execute main function if script is run directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  # Execute in subshell to prevent environment pollution
  (
    main "$@"
  )
  exit $?
fi
