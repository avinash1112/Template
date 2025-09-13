#!/bin/bash
# =============================================================================
# String Manipulation Utilities
# =============================================================================
# Provides various string manipulation functions used throughout the scripts

# Guard against multiple sourcing
if [[ -n "${STRING_UTILITIES_LOADED:-}" ]]; then
  return 0
fi

# Source platform utilities if not already loaded
if [[ -z "${PLATFORM_DETECTION_LOADED:-}" ]]; then
  source "$(dirname "${BASH_SOURCE[0]}")/platform.sh"
fi

# Slugify a string (make it URL/filename safe)
slugify() {
  local input="${1}"
  
  # Convert to lowercase and replace spaces with hyphens
  local result="${input,,}"
  result="${result// /-}"
  
  # Remove all non-alphanumeric characters except hyphens
  result="$(echo "${result}" | sed 's/[^a-z0-9-]//g')"
  
  # Remove multiple consecutive hyphens
  result="$(echo "${result}" | sed 's/-\+/-/g')"
  
  # Remove leading/trailing hyphens
  result="${result#-}"
  result="${result%-}"
      
  echo "${result}"
}

# Extract domain from hostname/URL
get_domain() {
  local input="${1}"
  
  # Remove protocol if present
  input="${input#*://}"
  
  # Remove path if present
  input="${input%%/*}"
  
  # Remove port if present
  input="${input%:*}"
  
  # Extract domain (last two parts for typical domains)
  if [[ "${input}" =~ \. ]]; then
    # Split by dots and get last two parts
    local IFS='.'
    local -a parts=(${input})
    local num_parts=${#parts[@]}
    
    if ((num_parts >= 2)); then
      echo "${parts[$((num_parts-2))]}.${parts[$((num_parts-1))]}"
    else
      echo "${input}"
    fi

  else
    echo "${input}"
  fi
}

# Check if string is an IP address
is_ip_address() {
  local input="${1}"
  
  # IPv4 check
  if [[ "${input}" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]]; then
    local IFS='.'
    local -a octets=(${input})
    for octet in "${octets[@]}"; do
      if ((octet < 0 || octet > 255)); then
        return 1
      fi
    done
    return 0
  fi
  
  # Basic IPv6 check
  if [[ "${input}" =~ ^[0-9a-fA-F:]+$ ]] && [[ "${input}" == *":"* ]]; then
    return 0
  fi
  
  return 1
}

# Generate random string
generate_random_string() {
  local length="${1:-32}"
  local charset="${2:-a-zA-Z0-9}"
  
  case "${charset}" in
    alphanumeric|a-zA-Z0-9)
      tr -dc 'a-zA-Z0-9' < /dev/urandom | head -c "${length}"
    ;;

    alpha|a-zA-Z)
      tr -dc 'a-zA-Z' < /dev/urandom | head -c "${length}"
    ;;

    numeric|0-9)
      tr -dc '0-9' < /dev/urandom | head -c "${length}"
    ;;

    hex|0-9a-f)
      tr -dc '0-9a-f' < /dev/urandom | head -c "${length}"
    ;;

    *)
      tr -dc "${charset}" < /dev/urandom | head -c "${length}"
    ;;

  esac
}

# Generate secure password
generate_password() {
  local length="${1:-32}"
  local include_symbols="${2:-true}"
  
  if [[ "${include_symbols}" == "true" ]]; then
    generate_random_string "${length}" 'a-zA-Z0-9!@#$%^&*'
  else
    generate_random_string "${length}" 'a-zA-Z0-9'
  fi
}

# URL encode string
url_encode() {
  local input="${1}"
  local encoded=""
  local char
  
  for (( i=0; i<${#input}; i++ )); do
    char="${input:$i:1}"
    case "${char}" in
      [a-zA-Z0-9.~_-])
        encoded+="${char}"
      ;;

      *)
        encoded+="$(printf '%%%02X' "'${char}")"
      ;;

    esac
  done
  
    echo "${encoded}"
}

# URL decode string
url_decode() {
  local input="${1}"
  printf '%b' "${input//%/\\x}"
}

# Base64 encode (wrapper for platform compatibility)
base64_encode_string() {
  local input="${1}"
  base64_encode "${input}"
}

# Base64 decode
base64_decode_string() {
  local input="${1}"
  local platform="${2:-$(detect_platform)}"
  
  case "${platform}" in
    macos)
      echo "${input}" | base64 -D
    ;;

    linux|wsl|windows)
      echo "${input}" | base64 -d
    ;;

    *)
      echo "${input}" | base64 -d
    ;;
  esac
}

# Join array elements with delimiter
join_array() {
  local delimiter="${1}"
  shift
  local elements=("$@")
  
  local result=""
  local first=true
  
  for element in "${elements[@]}"; do
    if [[ "${first}" == "true" ]]; then
      result="${element}"
      first=false
    else
      result="${result}${delimiter}${element}"
    fi
  done
    
  echo "${result}"
}

# Split string into array
split_string() {
  local delimiter="${1}"
  local input="${2}"
  local -n result_array="${3}"
  
  IFS="${delimiter}" read -ra result_array <<< "${input}"
}

# Trim whitespace from string
trim_string() {
  local input="${1}"
  
  # Remove leading whitespace
  input="${input#"${input%%[![:space:]]*}"}"
  
  # Remove trailing whitespace
  input="${input%"${input##*[![:space:]]}"}"
  
  echo "${input}"
}

# Pad string to specified length
pad_string() {
  local input="${1}"
  local length="${2}"
  local pad_char="${3:- }"
  local align="${4:-left}"
  
  local current_length=${#input}
  
  if ((current_length >= length)); then
    echo "${input}"
    return
  fi
  
  local pad_length=$((length - current_length))
  local padding=""
  
  for (( i=0; i<pad_length; i++ )); do
    padding+="${pad_char}"
  done
  
  case "${align}" in
    left)
      echo "${input}${padding}"
    ;;

    right)
      echo "${padding}${input}"
    ;;

    center)
      local left_pad=$((pad_length / 2))
      local right_pad=$((pad_length - left_pad))
      local left_padding="${padding:0:${left_pad}}"
      local right_padding="${padding:0:${right_pad}}"
      echo "${left_padding}${input}${right_padding}"
    ;;

    *)
      echo "${input}${padding}"
    ;;

  esac
}

# Convert string to title case
title_case() {
  local input="${1}"
  echo "${input}" | sed 's/\b\w/\U&/g'
}

# Convert string to camelCase
camel_case() {
  local input="${1}"
  local result=""
  local first=true
  
  IFS=' -_' read -ra words <<< "${input}"
  
  for word in "${words[@]}"; do
    if [[ "${first}" == "true" ]]; then
      result="${word,,}"
      first=false
    else
      result="${result}${word^}"
    fi
  done
  
  echo "${result}"
}

# Convert string to snake_case
snake_case() {
  local input="${1}"
  
  # Convert camelCase to snake_case
  local result="${input}"
  result="$(echo "${result}" | sed 's/\([a-z]\)\([A-Z]\)/\1_\2/g')"
  
  # Convert spaces and hyphens to underscores
  result="${result// /_}"
  result="${result//-/_}"
  
  # Convert to lowercase
  result="${result,,}"
  
  # Remove multiple consecutive underscores
  result="$(echo "${result}" | sed 's/_\+/_/g')"
  
  # Remove leading/trailing underscores
  result="${result#_}"
  result="${result%_}"
  
  echo "${result}"
}

# Escape string for use in sed
escape_for_sed() {
  local input="${1}"
  echo "${input}" | sed 's/[[\.*^$()+?{|]/\\&/g'
}

# Escape string for use in regex
escape_for_regex() {
  local input="${1}"
  echo "${input}" | sed 's/[[\.*^$()+?{|]/\\&/g'
}

# Generate unique identifier
generate_uuid() {
  if command_exists uuidgen; then
    uuidgen | tr '[:upper:]' '[:lower:]'
  else
    # Fallback: generate pseudo-UUID
    printf '%08x-%04x-%04x-%04x-%012x' \
      $((RANDOM * RANDOM)) \
      $((RANDOM % 65536)) \
      $((RANDOM % 65536)) \
      $((RANDOM % 65536)) \
      $((RANDOM * RANDOM * RANDOM))
  fi
}

# Check if string contains substring
string_contains() {
  local haystack="${1}"
  local needle="${2}"
  [[ "${haystack}" == *"${needle}"* ]]
}

# Check if string starts with prefix
string_starts_with() {
  local string="${1}"
  local prefix="${2}"
  [[ "${string}" == "${prefix}"* ]]
}

# Check if string ends with suffix
string_ends_with() {
  local string="${1}"
  local suffix="${2}"
  [[ "${string}" == *"${suffix}" ]]
}

if [[ -z "${STRING_UTILITIES_LOADED:-}" ]]; then
  readonly STRING_UTILITIES_LOADED=1
fi
