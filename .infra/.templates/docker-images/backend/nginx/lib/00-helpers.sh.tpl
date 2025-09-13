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


# Verify nginx config syntax quickly (non-fatal if binary lacks -t)
nginx_conf_ok() {
  nginx -t -q >/dev/null 2>&1
}


# Make an HTTP GET request
http_get() {
  local url="${1}"
  local ca="${2:-}"
  local cert="${3:-}"
  local key="${4:-}"

  local timeout_s="3"
  local args=(-sS -m "$timeout_s")

  [[ -n "$ca"   ]] && args+=( --cacert "$ca" )
  [[ -n "$cert" ]] && args+=( --cert   "$cert" )
  [[ -n "$key"  ]] && args+=( --key    "$key" )
  
  curl "${args[@]}" "$url"
}



# Make a request and print status code only
http_status() {
  local scheme="${1}"
  local host="${2}"
  local port="${3}" 
  local path="${4}"
  local ca="${5:-}"
  local cert="${6:-}"
  local key="${7:-}"

  local url="${scheme}://${host}:${port}${path}"

  local args=(
    --silent
    --show-error
    --max-time 3
    --output /dev/null
    --write-out "%{http_code}"
  )

  if [[ "${scheme}" == "https" ]]; then
    [[ -n "${ca}"   ]] && args+=( --cacert "${ca}" )
    [[ -n "${cert}" ]] && args+=( --cert   "${cert}" )
    [[ -n "${key}"  ]] && args+=( --key    "${key}" )
  fi

  curl "${args[@]}" "${url}"
  
}
