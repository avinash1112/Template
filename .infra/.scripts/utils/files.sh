#!/bin/bash
# =============================================================================
# File and Path Operations Utilities
# =============================================================================
# Provides safe and reliable file/directory operations with proper error handling

# Guard against multiple sourcing
if [[ -n "${FILE_UTILITIES_LOADED:-}" ]]; then
    return 0
fi

# Source platform and logging utilities if not already loaded
if [[ -z "${PLATFORM_DETECTION_LOADED:-}" ]]; then
  source "$(dirname "${BASH_SOURCE[0]}")/platform.sh"
fi

if [[ -z "${LOGGING_UTILITIES_LOADED:-}" ]]; then
  source "$(dirname "${BASH_SOURCE[0]}")/logging.sh"
fi

# Safe file copy with backup
safe_file_copy() {
  local source="${1}"
  local destination="${2}"
  local create_backup="${3:-true}"
  local backup_suffix="${4:-.backup.$(date +%Y%m%d_%H%M%S)}"
  
  if [[ ! -f "${source}" ]]; then
    log_error "Source file does not exist: ${source}"
    return 1
  fi
  
  # Create destination directory if it doesn't exist
  local dest_dir
  dest_dir="$(dirname "${destination}")"
  if [[ ! -d "${dest_dir}" ]]; then
    log_debug "Creating destination directory: ${dest_dir}"
    mkdir -p "${dest_dir}" || {
      log_error "Failed to create destination directory: ${dest_dir}"
      return 1
    }
  fi
  
  # Create backup if destination exists and backup is requested
  if [[ -f "${destination}" && "${create_backup}" == "true" ]]; then
    local backup_file="${destination}${backup_suffix}"
    log_debug "Creating backup: ${backup_file}"
    cp "${destination}" "${backup_file}" || {
      log_error "Failed to create backup: ${backup_file}"
      return 1
    }
  fi
  
  # Perform the copy
  log_file_operation "copy" "${source}" "$(basename "${source}") → $(basename "${destination}")"
  cp "${source}" "${destination}" || {
    log_error "Failed to copy file: ${source} → ${destination}"
    return 1
  }
  
  return 0
}

# Safe directory copy with backup
safe_directory_copy() {
  local source="${1}"
  local destination="${2}"
  local create_backup="${3:-true}"
  local backup_suffix="${4:-.backup.$(date +%Y%m%d_%H%M%S)}"
  
  if [[ ! -d "${source}" ]]; then
    log_error "Source directory does not exist: ${source}"
    return 1
  fi
  
  # Create destination parent directory if it doesn't exist
  local dest_parent
  dest_parent="$(dirname "${destination}")"
  if [[ ! -d "${dest_parent}" ]]; then
    log_debug "Creating destination parent directory: ${dest_parent}"
    mkdir -p "${dest_parent}" || {
      log_error "Failed to create destination parent directory: ${dest_parent}"
      return 1
    }
  fi
  
  # Create backup if destination exists and backup is requested
  if [[ -d "${destination}" && "${create_backup}" == "true" ]]; then
    local backup_dir="${destination}${backup_suffix}"
    log_debug "Creating backup directory: ${backup_dir}"
    mv "${destination}" "${backup_dir}" || {
      log_error "Failed to create backup directory: ${backup_dir}"
      return 1
    }
  fi
  
  # Perform the copy
  log_file_operation "copy" "${source}" "$(basename "${source}") → $(basename "${destination}")"
  cp -r "${source}" "${destination}" || {
    log_error "Failed to copy directory: ${source} → ${destination}"
    return 1
  }
  
  return 0
}

# Safe file move/rename
safe_file_move() {
  local source="${1}"
  local destination="${2}"
  local create_backup="${3:-true}"
  local backup_suffix="${4:-.backup.$(date +%Y%m%d_%H%M%S)}"
  local quiet="${5:-false}"
  
  if [[ ! -f "${source}" ]]; then
    log_error "Source file does not exist: ${source}"
    return 1
  fi
  
  # Create destination directory if it doesn't exist
  local dest_dir
  dest_dir="$(dirname "${destination}")"
  if [[ ! -d "${dest_dir}" ]]; then
    log_debug "Creating destination directory: ${dest_dir}"
    mkdir -p "${dest_dir}" || {
      log_error "Failed to create destination directory: ${dest_dir}"
      return 1
    }
  fi
  
  # Create backup if destination exists and backup is requested
  if [[ -f "${destination}" && "${create_backup}" == "true" ]]; then
    local backup_file="${destination}${backup_suffix}"
    log_debug "Creating backup: ${backup_file}"
    cp "${destination}" "${backup_file}" || {
      log_error "Failed to create backup: ${backup_file}"
      return 1
    }
  fi
  
  # Perform the move
  if [[ "${quiet}" != "true" ]]; then
    log_file_operation "move" "${source}" "$(basename "${source}") → $(basename "${destination}")"
  fi
  mv "${source}" "${destination}" || {
    log_error "Failed to move file: ${source} → ${destination}"
    return 1
  }
  
  return 0
}

# Safe file deletion with optional backup
safe_file_delete() {
  local file_path="${1}"
  local create_backup="${2:-false}"
  local backup_suffix="${3:-.backup.$(date +%Y%m%d_%H%M%S)}"
  
  if [[ ! -f "${file_path}" ]]; then
    log_debug "File does not exist (already deleted?): ${file_path}"
    return 0
  fi
  
  # Create backup if requested
  if [[ "${create_backup}" == "true" ]]; then
    local backup_file="${file_path}${backup_suffix}"
    log_debug "Creating backup before deletion: ${backup_file}"
    cp "${file_path}" "${backup_file}" || {
      log_error "Failed to create backup before deletion: ${backup_file}"
      return 1
    }
  fi
  
  # Perform the deletion
  log_file_operation "delete" "${file_path}" "$(basename "${file_path}")"
  rm "${file_path}" || {
    log_error "Failed to delete file: ${file_path}"
    return 1
  }
  
  return 0
}

# Safe directory deletion with confirmation
safe_directory_delete() {
  local dir_path="${1}"
  local force="${2:-false}"
  local create_backup="${3:-false}"
  local backup_suffix="${4:-.backup.$(date +%Y%m%d_%H%M%S)}"
  
  if [[ ! -d "${dir_path}" ]]; then
    log_debug "Directory does not exist (already deleted?): ${dir_path}"
    return 0
  fi
  
  # Safety check: don't delete important directories
  case "${dir_path}" in
    /|/bin|/boot|/dev|/etc|/home|/lib|/lib64|/opt|/proc|/root|/sbin|/srv|/sys|/tmp|/usr|/var)
      log_error "Refusing to delete system directory: ${dir_path}"
      return 1
    ;;

    /*/)
      # Remove trailing slash for consistency
      dir_path="${dir_path%/}"
    ;;
  esac
  
  # Require confirmation for non-force deletions of non-empty directories
  if [[ "${force}" != "true" && -n "$(ls -A "${dir_path}" 2>/dev/null)" ]]; then
    log_warn "Directory is not empty: ${dir_path}"
    echo "Contents:"
    ls -la "${dir_path}" | head -10
    if [[ $(ls -1A "${dir_path}" | wc -l) -gt 10 ]]; then
      echo "... and $(($(ls -1A "${dir_path}" | wc -l) - 10)) more items"
    fi
    echo
    
    local confirm
    read -rp "Are you sure you want to delete this directory? (y/N): " confirm
    case "${confirm}" in
      [Yy]|[Yy][Ee][Ss])
      ;;

      *)
        log_info "Directory deletion cancelled"
        return 1
      ;;
    esac
  fi
  
  # Create backup if requested
  if [[ "${create_backup}" == "true" ]]; then
    local backup_dir="${dir_path}${backup_suffix}"
    log_debug "Creating backup before deletion: ${backup_dir}"
    cp -r "${dir_path}" "${backup_dir}" || {
      log_error "Failed to create backup before deletion: ${backup_dir}"
      return 1
    }
  fi
  
  # Perform the deletion
  log_file_operation "delete" "${dir_path}" "$(basename "${dir_path}")"
  rm -rf "${dir_path}" || {
    log_error "Failed to delete directory: ${dir_path}"
    return 1
  }
  
  return 0
}

# Create directory with proper permissions and parent creation
ensure_directory_exists() {
  local dir_path="${1}"
  local permissions="${2:-755}"
  local owner="${3:-}"
  local group="${4:-}"
  
  if [[ -d "${dir_path}" ]]; then
    log_debug "Directory already exists: ${dir_path}"
    return 0
  fi
  
  log_file_operation "create" "${dir_path}" "directory $(basename "${dir_path}")"
  mkdir -p "${dir_path}" || {
    log_error "Failed to create directory: ${dir_path}"
    return 1
  }
  
  # Set permissions
  chmod "${permissions}" "${dir_path}" || {
    log_error "Failed to set permissions on directory: ${dir_path}"
    return 1
  }
  
  # Set ownership if specified and running as root
  if [[ -n "${owner}" && $(id -u) -eq 0 ]]; then
    local ownership="${owner}"
    if [[ -n "${group}" ]]; then
      ownership="${owner}:${group}"
    fi
    chown "${ownership}" "${dir_path}" || {
      log_error "Failed to set ownership on directory: ${dir_path}"
      return 1
    }
  fi
  
  return 0
}

# Get absolute path
get_absolute_path() {
  local path="${1}"
  
  if [[ -d "${path}" ]]; then
    (cd "${path}" && pwd)
  elif [[ -f "${path}" ]]; then
    local dir
    dir="$(dirname "${path}")"
    local file
    file="$(basename "${path}")"
    echo "$(cd "${dir}" && pwd)/${file}"
else
    # Path doesn't exist, resolve relative to current directory
    if [[ "${path}" == /* ]]; then
      echo "${path}"
    else
      echo "$(pwd)/${path}"
    fi
  fi
}

# Get relative path from one directory to another
get_relative_path() {
  local from="${1}"
  local to="${2}"
  
  # Convert to absolute paths
  from="$(get_absolute_path "${from}")"
  to="$(get_absolute_path "${to}")"
  
  # Use Python if available for reliable relative path calculation
  if command_exists python3; then
    python3 -c "import os.path; print(os.path.relpath('${to}', '${from}'))"
  elif command_exists python; then
    python -c "import os.path; print(os.path.relpath('${to}', '${from}'))"
  else
    # Fallback: simple implementation
    echo "${to}"
  fi
}

# Find files with pattern
find_files() {
  local search_dir="${1}"
  local pattern="${2}"
  local max_depth="${3:-}"
  
  if [[ ! -d "${search_dir}" ]]; then
    log_error "Search directory does not exist: ${search_dir}"
    return 1
  fi
  
  local find_args=("${search_dir}")
  
  if [[ -n "${max_depth}" ]]; then
    find_args+=(-maxdepth "${max_depth}")
  fi
  
  find_args+=(-name "${pattern}" -type f)
  
  find "${find_args[@]}" 2>/dev/null | sort
}

# Get file size in bytes
get_file_size() {
  local file_path="${1}"
  
  if [[ ! -f "${file_path}" ]]; then
    log_error "File does not exist: ${file_path}"
    return 1
  fi
  
  local platform
  platform="$(detect_platform)"
  
  case "${platform}" in
    macos)
      stat -f%z "${file_path}"
    ;;

    linux|wsl)
      stat -c%s "${file_path}"
    ;;

    *)
      # Fallback using wc
      wc -c < "${file_path}" | tr -d ' '
    ;;

  esac
}

# Get file modification time
get_file_mtime() {
  local file_path="${1}"
  local format="${2:-epoch}"
  
  if [[ ! -f "${file_path}" ]]; then
    log_error "File does not exist: ${file_path}"
    return 1
  fi
  
  local platform
  platform="$(detect_platform)"
  
  case "${format}" in
    epoch)
      case "${platform}" in
        macos)
          stat -f%m "${file_path}"
        ;;

        linux|wsl)
          stat -c%Y "${file_path}"
        ;;

        *)
          # Fallback
          date -r "${file_path}" +%s 2>/dev/null || echo "0"
        ;;

      esac
    ;;

    iso)
      case "${platform}" in
        macos)
          stat -f%Sm -t%Y-%m-%dT%H:%M:%S "${file_path}"
        ;;

        linux|wsl)
          stat -c%y "${file_path}" | cut -d. -f1
        ;;

        *)
          # Fallback
          date -r "${file_path}" +%Y-%m-%dT%H:%M:%S 2>/dev/null || echo "1970-01-01T00:00:00"
        ;;

      esac
    ;;

    *)
      log_error "Unknown date format: ${format}"
      return 1
    ;;

  esac
}

# Check if file is newer than another file
is_file_newer() {
  local file1="${1}"
  local file2="${2}"
  
  if [[ ! -f "${file1}" ]]; then
    return 1
  fi
  
  if [[ ! -f "${file2}" ]]; then
    return 0
  fi
  
  local mtime1
  local mtime2
  mtime1="$(get_file_mtime "${file1}" epoch)"
  mtime2="$(get_file_mtime "${file2}" epoch)"
  
  ((mtime1 > mtime2))
}

# Create temporary file
create_temp_file() {
  local prefix="${1:-tmp}"
  local suffix="${2:-}"
  
  local temp_dir
  temp_dir="$(get_temp_dir)"
  
  local temp_file
  if [[ -n "${suffix}" ]]; then
    temp_file="$(mktemp "${temp_dir}/${prefix}.XXXXXX${suffix}")"
  else
    temp_file="$(mktemp "${temp_dir}/${prefix}.XXXXXX")"
  fi
  
  echo "${temp_file}"
}

# Create temporary directory
create_temp_directory() {
  local prefix="${1:-tmp}"
  
  local temp_dir
  temp_dir="$(get_temp_dir)"
  
  mktemp -d "${temp_dir}/${prefix}.XXXXXX"
}

# Cleanup function for temporary files
cleanup_temp_files() {
  local temp_pattern="${1:-/tmp/tmp.*}"
  
  # Only clean up files/directories that match our pattern and are older than 1 hour
  find "${temp_pattern%/*}" -name "$(basename "${temp_pattern}")" -mmin +60 -delete 2>/dev/null || true
}

if [[ -z "${FILE_UTILITIES_LOADED:-}" ]]; then
  readonly FILE_UTILITIES_LOADED=1
fi
