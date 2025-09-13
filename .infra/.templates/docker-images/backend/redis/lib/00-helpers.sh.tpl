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


# Get the role of the current instance
get_role() {

  local host_name="$(get_hostname)"
  local ordinal=$(echo "${host_name}" | sed -E 's/.*-([0-9]+)$/\1/')

  case "${ordinal}" in
    0)
      echo "master"
    ;;

    [1-9]*)
      echo "replica"
    ;;

    *)
      echo "null"
    ;;
  esac
}


# Redis cli
redis_cmd() {
  local host="${1}"
  local port="${2}"
  local user="${3}"
  local pass="${4}"
  shift 4

  local ca="/etc/ssl/certs/redis/clients/${user}/ca.pem"
  local crt="/etc/ssl/certs/redis/clients/${user}/leaf.pem"
  local key="/etc/ssl/certs/redis/clients/${user}/key.pem"

  [[ -r "${ca}"  && -s "${ca}"  ]] || { echo_error "[REDIS] Missing ${ca}" >&2; return 1; }
  [[ -r "${crt}" && -s "${crt}" ]] || { echo_error "[REDIS] Missing ${crt}" >&2; return 1; }
  [[ -r "${key}" && -s "${key}" ]] || { echo_error "[REDIS] Missing ${key}" >&2; return 1; }

  # Set password in env var (avoids showing in process list)
  REDISCLI_AUTH="${pass}" redis-cli \
    -h "${host}" \
    -p "${port}" \
    --user "${user}" \
    --tls \
    --cacert "${ca}" \
    --cert "${crt}" \
    --key "${key}" \
    --no-auth-warning \
    --raw \
    "$@"
}


# Test if connected
is_connected() {
  local host="${1}"
  local port="${2}"
  local user="${3}"
  local pass="${4}"

  local out
  out="$(redis_cmd "${host}" "${port}" "${user}" "${pass}" PING 2>/dev/null || true)"

  [[ "${out}" == "PONG" ]]
}


# Returns "loading:<0|1> async_loading:<0|1>"
redis_loading_flags() {
  local host="${1}"
  local port="${2}"
  local user="${3}"
  local pass="${4}"
  
  redis_cmd "${host}" "${port}" "${user}" "${pass}" INFO 2>/dev/null \
  | sed -E 's/\\r\\n/\n/g' | tr -d '\r' \
  | awk -F: '
      $1=="loading"        { l=$2 }
      $1=="async_loading"  { a=$2 }
      END {
        if (l=="") l=0; if (a=="") a=0;
        gsub(/^[[:space:]]+|[[:space:]]+$/, "", l);
        gsub(/^[[:space:]]+|[[:space:]]+$/, "", a);
        print "loading:" l " async_loading:" a
      }'
}


# Render template atomically if target missing
subs_env () {

  local src="${1}"
  local dst="${2}"
  local owner="${3}"
  local mode="${4}"
  local user="${owner%%:*}"
  local group="${owner#*:}"

  # Build list of files to process
  local files=()

  # src is a directory
  if [[ -d "${src}" ]]; then
    
    while IFS= read -r -d '' f; do files+=("${f}"); done \
      < <(find "${src}" -mindepth 1 -maxdepth 1 -type f -print0)
  
  # treat as a single file
  else
    shopt -s nullglob
    files=(${src})
    shopt -u nullglob
  fi

  [[ "${#files[@]}" -gt 0 ]] || { echo_warn "subs_env: no files matched: '${src}'"; return 0; }
  
  local f
  local base
  local tmp
  local out

  for f in "${files[@]}"; do
    base="$(basename -- "${f}")"
    out="${dst%/}/${base}"
    tmp="$(mktemp)"

    envsubst < "${f}" > "${tmp}"
    mv -f -- "${tmp}" "${out}"
    chown "${user}:${group}" "${out}" 2>/dev/null || true
    chmod "${mode}" "${out}"
  done

}
