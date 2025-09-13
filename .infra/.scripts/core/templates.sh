#!/bin/bash
# =============================================================================
# Template Rendering Core Module
# =============================================================================
# Handles template processing and variable substitution

# Guard against multiple sourcing
if [[ -n "${TEMPLATE_CORE_LOADED:-}" ]]; then
  return 0
fi

# Load required utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../utils/platform.sh"
source "${SCRIPT_DIR}/../utils/logging.sh"
source "${SCRIPT_DIR}/../utils/validation.sh"
source "${SCRIPT_DIR}/../utils/strings.sh"
source "${SCRIPT_DIR}/../utils/files.sh"

# Template processing configuration
readonly TEMPLATE_EXTENSION=".tpl"
readonly PLACEHOLDER_PATTERN='__[A-Z0-9]+(?:_[A-Z0-9]+)*__'

# Global statistics tracking
declare -g TEMPLATE_STATS_TOTAL_PLACEHOLDERS=0
declare -g TEMPLATE_STATS_SUCCESSFUL_REPLACEMENTS=0
declare -g TEMPLATE_STATS_FAILED_REPLACEMENTS=0
declare -ga TEMPLATE_STATS_FAILED_PLACEHOLDERS=()

# Initialize template rendering system
init_template_system() {
  local templates_dir="${1}"
  local rendered_dir="${2}"
  local clean_existing="${3:-true}"

  log_info "Initializing template system"
  log_debug "Templates directory: ${templates_dir}"
  log_debug "Rendered directory: ${rendered_dir}"

  # Validate input directories
  if ! ensure_directory_exists "${templates_dir}" "templates directory"; then
    return 1
  fi

  # Clean existing rendered directory if requested
  if [[ "${clean_existing}" == "true" && -d "${rendered_dir}" ]]; then
    log_info "Cleaning existing rendered directory"
    safe_directory_delete "${rendered_dir}" true false
  fi

  # Create rendered directory
  ensure_directory_exists "${rendered_dir}"

  # Copy template structure to rendered directory
  log_info "Copying template structure to rendered directory"

  if [[ -d "${templates_dir}" ]]; then
    log_file_operation "copy" "${templates_dir}" ".templates/* → rendered/"

    cp -r "${templates_dir}"/* "${rendered_dir}/" || {
      log_error "Failed to copy template contents to rendered directory"
      return 1
    }
    else
    log_error "Templates directory does not exist: ${templates_dir}"
    return 1
  fi

  log_success "Template system initialized"
}

# Render all templates in a directory
render_templates() {
  local rendered_dir="${1}"
  local context="${2:-}"

  log_info "Starting template rendering process"

  if [[ ! -d "${rendered_dir}" ]]; then
    log_error "Rendered directory does not exist: ${rendered_dir}"
    return 1
  fi

  # Find all template files
  local template_files
  mapfile -t template_files < <(find_files "${rendered_dir}" "*${TEMPLATE_EXTENSION}")

  if [[ ${#template_files[@]} -eq 0 ]]; then
    log_info "No template files found to render"
    return 0
  fi

  log_info "Found ${#template_files[@]} template files to render"

  # Initialize statistics tracking
  TEMPLATE_STATS_TOTAL_PLACEHOLDERS=0
  TEMPLATE_STATS_SUCCESSFUL_REPLACEMENTS=0
  TEMPLATE_STATS_FAILED_REPLACEMENTS=0
  TEMPLATE_STATS_FAILED_PLACEHOLDERS=()

  # Pre-cache all environment variables for performance
  declare -A env_cache
  cache_environment_variables env_cache

  # Process each template file
  local processed=0
  local failed=0
  local total_files=${#template_files[@]}

  # Show initial message for template rendering
  printf "Rendering templates... 0%% (0/%d)" "${total_files}"

  for template_file in "${template_files[@]}"; do
    log_debug "Processing template: ${template_file}"

    if render_single_template "${template_file}" env_cache "${context}" "quiet"; then
      processed=$((processed + 1))
      else
      failed=$((failed + 1))
      log_error "Failed to render template: ${template_file}"
    fi

    # Update progress on same line
    local percentage=$((processed * 100 / total_files))
    printf "\rRendering templates... %d%% (%d/%d)" "${percentage}" "${processed}" "${total_files}"
  done

  # Clear the progress line
  printf "\r\033[2K"

  # Display comprehensive statistics and return appropriate exit code
  display_template_statistics "${processed}" "${failed}" "${total_files}"
  return $?
}


# Cache environment variables for performance
cache_environment_variables() {
  local -n cache_ref="${1}"

  log_debug "Caching environment variables"

  # Cache all exported environment variables
  while IFS='=' read -r key value; do
    cache_ref["${key}"]="${value}"
  done < <(env)

  log_debug "Cached ${#cache_ref[@]} environment variables"
}

# Render a single template file
render_single_template() {
  local template_file="${1}"
  local -n env_ref="${2}"
  local context="${3:-}"
  local quiet="${4:-false}"

  # Calculate output path by removing .tpl extension
  local output_file="${template_file%${TEMPLATE_EXTENSION}}"

  if [[ "${quiet}" != "quiet" ]]; then
    log_debug "Rendering: $(basename "${template_file}") → $(basename "${output_file}")"
  fi

  # Move template to output location with quiet parameter
  local quiet_param=""
  if [[ "${quiet}" == "quiet" ]]; then
    quiet_param="quiet"
  fi

  safe_file_move "${template_file}" "${output_file}" false "" true "${quiet_param}"

  # Extract all placeholders from the file
  local placeholders
  mapfile -t placeholders < <(
  grep -oE "${PLACEHOLDER_PATTERN}" "${output_file}" | sort -u || true
  )

  if [[ ${#placeholders[@]} -eq 0 ]]; then
    log_debug "No placeholders found in template"
    return 0
  fi

  log_debug "Found ${#placeholders[@]} unique placeholders"

  # Process each placeholder
  local replaced=0
  local skipped=0

  for placeholder in "${placeholders[@]}"; do
    if process_placeholder "${placeholder}" "${output_file}" "${2}" "${context}"; then
      ((replaced++))
      else
      ((skipped++))
    fi
  done

  log_debug "Replaced ${replaced} placeholders, skipped ${skipped}"
  return 0
}

# Process a single placeholder
process_placeholder() {
  local placeholder="${1}"
  local file_path="${2}"
  local env_cache_name="${3}"
  local context="${4:-}"

  # Extract variable name from placeholder (remove __ prefix and suffix)
  local var_name="${placeholder:2:$((${#placeholder}-4))}"

  log_debug "Processing placeholder: ${placeholder} (variable: ${var_name})"

  # Handle special placeholder types
  case "${placeholder}" in
    __FILE_B64_*__)
    replace_file_b64_placeholder "${placeholder}" "${var_name}" "${file_path}"
    ;;
    __FILE_TXT_*__)
    replace_file_txt_placeholder "${placeholder}" "${var_name}" "${file_path}"
    ;;
    __DOCKER_CONFIG_JSON_*__)
    replace_docker_config_placeholder "${placeholder}" "${var_name}" "${file_path}"
    ;;
    __B64_*__)
    replace_b64_variable_placeholder "${placeholder}" "${var_name}" "${file_path}" "${env_cache_name}"
    ;;
    __*__)
    replace_variable_placeholder "${placeholder}" "${var_name}" "${file_path}" "${env_cache_name}"
    ;;
    *)
    log_debug "Unrecognized placeholder pattern: ${placeholder}"
    return 1
    ;;
    esac
  }

  # Replace variable placeholder with environment variable value
  replace_variable_placeholder() {
    local placeholder="${1}"
    local var_name="${2}"
    local file_path="${3}"
    local env_cache_name="${4}"

    # Use eval to safely access the associative array
    local value=""

    # Use printf to safely construct the eval command with proper quoting
    local eval_cmd
    printf -v eval_cmd 'value="${%s[%q]:-}"' "${env_cache_name}" "${var_name}"
    eval "${eval_cmd}"

    # Update statistics
    TEMPLATE_STATS_TOTAL_PLACEHOLDERS=$((TEMPLATE_STATS_TOTAL_PLACEHOLDERS + 1))

    if [[ -n "${value}" ]]; then
      # Escape special characters for sed
      local escaped_value
      escaped_value="$(escape_for_sed "${value}")"
      local escaped_placeholder
      escaped_placeholder="$(escape_for_sed "${placeholder}")"

      sed_inplace "s|${escaped_placeholder}|${escaped_value}|g" "${file_path}"
      log_debug "Replaced ${placeholder} with value (length: ${#value})"

      TEMPLATE_STATS_SUCCESSFUL_REPLACEMENTS=$((TEMPLATE_STATS_SUCCESSFUL_REPLACEMENTS + 1))
      return 0
      else
      log_debug "Skipping ${placeholder} - variable '${var_name}' not set"

      TEMPLATE_STATS_FAILED_REPLACEMENTS=$((TEMPLATE_STATS_FAILED_REPLACEMENTS + 1))
      TEMPLATE_STATS_FAILED_PLACEHOLDERS+=("${placeholder}")
      return 1
    fi
  }

  # Replace base64 encoded variable placeholder
  replace_b64_variable_placeholder() {
    local placeholder="${1}"
    local var_name="${2}"
    local file_path="${3}"
    local env_cache_name="${4}"

    # Extract actual variable name (remove B64_ prefix)
    local actual_var_name="${var_name#B64_}"

    # Use eval to access the associative array safely
    local value=""
    eval "value=\"\${${env_cache_name}[${actual_var_name}]:-}\""

    if [[ -n "${value}" ]]; then
      local b64_value
      b64_value="$(base64_encode_string "${value}")"

      local escaped_b64_value
      escaped_b64_value="$(escape_for_sed "${b64_value}")"
      local escaped_placeholder
      escaped_placeholder="$(escape_for_sed "${placeholder}")"

      sed_inplace "s|${escaped_placeholder}|${escaped_b64_value}|g" "${file_path}"
      log_debug "Replaced ${placeholder} with base64 encoded value"
      return 0
      else
      log_debug "Skipping ${placeholder} - variable '${actual_var_name}' not set"
      return 1
    fi
  }

  # Replace file content placeholder (base64 encoded)
  replace_file_b64_placeholder() {
    local placeholder="${1}"
    local var_name="${2}"
    local file_path="${3}"

    # Extract file path from variable name (remove FILE_B64_ prefix)
    local file_var_name="${var_name#FILE_B64_}"
    local source_file="${PROJECT_ROOT}/${file_var_name}"

    if [[ -f "${source_file}" ]]; then
      local file_content
    file_content="$(cat "${source_file}")"
    local b64_content
    b64_content="$(base64_encode_string "${file_content}")"

    local escaped_b64_content
    escaped_b64_content="$(escape_for_sed "${b64_content}")"
    local escaped_placeholder
    escaped_placeholder="$(escape_for_sed "${placeholder}")"

    sed_inplace "s|${escaped_placeholder}|${escaped_b64_content}|g" "${file_path}"
    log_debug "Replaced ${placeholder} with base64 encoded file content"
    return 0
    else
    log_debug "Skipping ${placeholder} - file '${source_file}' not found"
    return 1
  fi
}

# Replace file content placeholder (plain text)
replace_file_txt_placeholder() {
  local placeholder="${1}"
  local var_name="${2}"
  local file_path="${3}"

  # Extract file path from variable name (remove FILE_TXT_ prefix)
  local file_var_name="${var_name#FILE_TXT_}"
  local source_file="${PROJECT_ROOT}/${file_var_name}"

  if [[ -f "${source_file}" ]]; then
    local file_content
  file_content="$(cat "${source_file}")"

  local escaped_content
  escaped_content="$(escape_for_sed "${file_content}")"
  local escaped_placeholder
  escaped_placeholder="$(escape_for_sed "${placeholder}")"

  sed_inplace "s|${escaped_placeholder}|${escaped_content}|g" "${file_path}"
  log_debug "Replaced ${placeholder} with plain text file content"
  return 0
  else
  log_debug "Skipping ${placeholder} - file '${source_file}' not found"
  return 1
fi
}

# Replace Docker config JSON placeholder
replace_docker_config_placeholder() {
  local placeholder="${1}"
  local var_name="${2}"
  local file_path="${3}"

  # Generate Docker config JSON
  local docker_config_json
  docker_config_json="$(generate_docker_config_json)"

  if [[ -n "${docker_config_json}" ]]; then
    local b64_config
    b64_config="$(base64_encode_string "${docker_config_json}")"

    local escaped_b64_config
    escaped_b64_config="$(escape_for_sed "${b64_config}")"
    local escaped_placeholder
    escaped_placeholder="$(escape_for_sed "${placeholder}")"

    sed_inplace "s|${escaped_placeholder}|${escaped_b64_config}|g" "${file_path}"
    log_debug "Replaced ${placeholder} with Docker config JSON"
    return 0
    else
    log_debug "Skipping ${placeholder} - could not generate Docker config JSON"
    return 1
  fi
}

# Generate Docker config JSON for registry authentication
generate_docker_config_json() {
  if [[ -n "${CONTAINER_REGISTRY_USERNAME:-}" && -n "${CONTAINER_REGISTRY_PAT_RW:-}" && -n "${CONTAINER_REGISTRY_EMAIL:-}" ]]; then
    local auth_string
    auth_string="$(base64_encode_string "${CONTAINER_REGISTRY_USERNAME}:${CONTAINER_REGISTRY_PAT_RW}")"

    cat <<EOF
{
  "auths": {
    "ghcr.io": {
      "username": "${CONTAINER_REGISTRY_USERNAME}",
      "password": "${CONTAINER_REGISTRY_PAT_RW}",
      "email": "${CONTAINER_REGISTRY_EMAIL}",
      "auth": "${auth_string}"
    }
  }
}
EOF
    else
    log_debug "Missing Docker registry credentials"
    return 1
  fi
}

# Validate template file
validate_template() {
  local template_file="${1}"

  if [[ ! -f "${template_file}" ]]; then
    log_error "Template file does not exist: ${template_file}"
    return 1
  fi

  # Check for malformed placeholders
  local malformed_placeholders
  mapfile -t malformed_placeholders < <(
  grep -oE '__[^_]*_[^_]*__' "${template_file}" | \
  grep -vE "${PLACEHOLDER_PATTERN}" || true
  )

  if [[ ${#malformed_placeholders[@]} -gt 0 ]]; then
    log_warn "Found potentially malformed placeholders in ${template_file}:"
    for placeholder in "${malformed_placeholders[@]}"; do
      log_warn "  ${placeholder}"
    done
  fi

  # Check for unmatched placeholder delimiters
  local unmatched_count
  unmatched_count="$(grep -o '__' "${template_file}" | wc -l)"

  if ((unmatched_count % 2 != 0)); then
    log_warn "Unmatched placeholder delimiters in ${template_file}"
  fi

  return 0
}

# Display comprehensive template rendering statistics
display_template_statistics() {
  local successful_files="${1}"
  local failed_files="${2}"
  local total_files="${3}"

  # Display file statistics
  if [[ "${failed_files}" -eq 0 ]]; then
    log_success "Template rendering completed: ${successful_files}/${total_files} files rendered successfully"
    else
    log_error "Template rendering completed with errors: ${successful_files} successful, ${failed_files} failed"
  fi

  # Display placeholder statistics
  echo
  log_info "Placeholder Statistics:"
  echo "  Total placeholders processed: ${TEMPLATE_STATS_TOTAL_PLACEHOLDERS}"
  echo "  Successful replacements: ${TEMPLATE_STATS_SUCCESSFUL_REPLACEMENTS}"
  echo "  Failed replacements: ${TEMPLATE_STATS_FAILED_REPLACEMENTS}"

  # Show failed placeholders if any
  if [[ "${TEMPLATE_STATS_FAILED_REPLACEMENTS}" -gt 0 ]]; then
    echo
    log_warning "Failed placeholders (variables not set):"
    for placeholder in "${TEMPLATE_STATS_FAILED_PLACEHOLDERS[@]}"; do
      echo "  ${placeholder}"
    done
  fi

  echo

  # Return appropriate exit code
  if [[ "${failed_files}" -gt 0 ]] || [[ "${TEMPLATE_STATS_FAILED_REPLACEMENTS}" -gt 0 ]]; then
    return 1
  fi

  return 0
}

if [[ -z "${TEMPLATE_CORE_LOADED:-}" ]]; then
  readonly TEMPLATE_CORE_LOADED=1
fi
