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

# Initialize the script
init_build_script() {
  # Initialize logging
  init_logging "INFO" "auto"

  # Initialize environment
  init_environment "${INFRA_ENV_FILE}"

  # Validate required environment variables
  validate_docker_environment

  # Validate required directories
  ensure_directory_exists "${RENDERED_DIR}" "rendered directory"
  ensure_directory_exists "${RENDERED_DIR}/docker-images" "docker images directory"

  log_success "Build script initialized successfully"
}

# Validate Docker environment requirements
validate_docker_environment() {
  log_subsection "Docker Environment Validation"

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

  # Validate required Docker environment variables
  local required_vars=(
    "CONTAINER_REGISTRY_USERNAME"
    "REPO_NAME"
    "REPO_BRANCH"
    "INFRA_ENV"
  )

  for var in "${required_vars[@]}"; do
    if [[ -z "${!var:-}" ]]; then
      log_error "Required environment variable '${var}' is not set"
      return 1
    fi
  done

  log_success "Docker environment validation completed"
}

# Build a single Docker image
build_docker_image() {
  local service_name="${1}"
  local dockerfile_path="${2}"
  local image_tag="${3}"
  local build_target="${4}"
  local build_context="${5}"

  log_info "Building ${service_name} image..."
  log_debug "Dockerfile: ${dockerfile_path}"
  log_debug "Image tag: ${image_tag}"
  log_debug "Build target: ${build_target}"
  log_debug "Build context: ${build_context}"

  # Validate dockerfile exists
  if [[ ! -f "${dockerfile_path}" ]]; then
    log_error "Dockerfile not found: ${dockerfile_path}"
    return 1
  fi

  # Validate image tag format
  if ! validate_docker_image_name "${image_tag}" "image tag"; then
    return 1
  fi

  # Build the Docker image
  local build_start_time=$(date +%s)

  if docker build \
    -t "${image_tag}" \
    -f "${dockerfile_path}" \
    --target="${build_target}" \
    "${build_context}"; then

    local build_end_time=$(date +%s)
    local build_duration=$((build_end_time - build_start_time))

    log_success "Successfully built ${service_name} image in ${build_duration}s"
    return 0
  else
    log_error "Failed to build ${service_name} image"
    return 1
  fi
}

  # Build images for a specific stack
  build_stack_images() {
    local stack="${1}"
    local step_number="${2}"
    local stack_dir="${RENDERED_DIR}/docker-images/${stack}"

    log_step "${step_number}" "Building ${stack} images"

    if [[ ! -d "${stack_dir}" ]]; then
      log_warning "Stack directory not found: ${stack_dir}"
      return 0
    fi

    local services=()
    local successful_builds=()
    local failed_builds=()

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

    log_info "Found ${#services[@]} services to build: ${services[*]}"

    # Build each service
    for service in "${services[@]}"; do
      local sanitized_repo_name
      sanitized_repo_name="$(sanitize_for_docker "${REPO_NAME}")"
      local image_name="${sanitized_repo_name}-${service}"
      local image_tag="ghcr.io/${CONTAINER_REGISTRY_USERNAME}/${image_name}:${IMAGE_TAG}"
      local dockerfile="${stack_dir}/${service}/${service}.dockerfile"

      if build_docker_image "${service}" "${dockerfile}" "${image_tag}" "${INFRA_ENV}" "${DOCKER_BUILD_CONTEXT}"; then
        successful_builds+=("${service}:${image_tag}")
        else
        failed_builds+=("${service}")
      fi
    done

    # Report results
    if [[ ${#successful_builds[@]} -gt 0 ]]; then
      echo
      log_success "Successfully built ${#successful_builds[@]} ${stack} images:"
      for build in "${successful_builds[@]}"; do
        echo "  ✅ ${build}"
      done
    fi

    if [[ ${#failed_builds[@]} -gt 0 ]]; then
      echo
      log_error "Failed to build ${#failed_builds[@]} ${stack} images:"
      for service in "${failed_builds[@]}"; do
        echo "  ❌ ${service}"
      done
      return 1
    fi

    return 0
  }

  # Build all Docker images
  build_all_images() {
    log_section "Building Docker Images"

    local total_successful=0
    local total_failed=0
    local failed_stacks=()
    local step_number=1

    for stack in "${STACKS[@]}"; do
      if build_stack_images "${stack}" "${step_number}"; then
        ((total_successful++))
        else
        ((total_failed++))
        failed_stacks+=("${stack}")
      fi
      ((step_number++))
      echo
    done

    # Final summary
    if [[ ${total_failed} -eq 0 ]]; then
      log_success "All ${total_successful} stacks built successfully"
      return 0
    else
      log_error "Build completed with errors: ${total_successful} successful, ${total_failed} failed"
      if [[ ${#failed_stacks[@]} -gt 0 ]]; then
        log_error "Failed stacks: ${failed_stacks[*]}"
      fi
      return 1
    fi
  }

  # Main execution function
  main() {
    log_section "Docker Image Build Process"

    init_build_script
    build_all_images

    log_success "Docker image build process completed"
  }

# Execute main function if script is run directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  # Execute in subshell to prevent environment pollution
  (
    main "$@"
  )
  exit $?
fi
