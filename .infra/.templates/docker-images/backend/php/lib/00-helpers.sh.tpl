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


# Check if php fpm has been configured
is_php_fpm_configured() {
  php-fpm -t >/dev/null 2>&1
}


# Check if php fpm process is running
is_php_fpm_process_running() {
  pgrep -x php-fpm >/dev/null
}


# Run a FastCGI GET request to PHP-FPM over TCP using cgi-fcgi
fcgi_get() {
  local host="${1}"
  local port="${2}"
  local path="${3}"
  local t="${4:-3}"

  local script="/var/www/html/public/index.php"
  local docroot="var/www/html/public"

  # Minimal FastCGI env vars; REQUEST_URI triggers ping/status intercepts,
  # SCRIPT_FILENAME points to a real .php to satisfy security.limit_extensions.
  REQUEST_METHOD=GET \
  SERVER_PROTOCOL=HTTP/1.1 \
  REQUEST_URI="${path}" \
  SCRIPT_NAME="${path}" \
  SCRIPT_FILENAME="${script}" \
  DOCUMENT_ROOT="${docroot}" \
  QUERY_STRING= \
  timeout "${t}" cgi-fcgi -bind -connect "${host}:${port}"
}



# Expect body to contain a simple success token "pong"
fpm_ping_ok() {
  local host="${1}"
  local port="${2}"
  local path="${3}"

  local expect="pong"

  local out
  out="$(fcgi_get "${host}" "${port}" "${path}" 2>/dev/null || true)"

  # Normalize CRLF -> LF, then strip headers (everything until the first empty line)
  local body
  body="$(printf '%s' "${out}" | sed -E 's/\r$//' | sed '1,/^$/d')"
  
  [[ "${body}" == "${expect}" ]]
}


# Parse pm.status output into key:value lines (header/body splitter + CR stripping)
fpm_status_get() {
  local host="${1}"
  local port="${2}"
  local path="${3}"

  fcgi_get "${host}" "${port}" "${path}" 2>/dev/null \
    | sed -E 's/\r$//' \
    | awk 'BEGIN{hdr=1} hdr && $0==""{hdr=0;next} !hdr{print}'
}


# Get just the response status code from a FastCGI request
# Returns status code as text (e.g. "200", "404", "500")
fpm_status_code() {
  local host="${1}"
  local port="${2}"
  local path="${3}"

  local out
  out="$(fcgi_get "${host}" "${port}" "${path}" 2>/dev/null || true)"

  # Normalize CRLF -> LF, then extract the Status header
  local status
  status="$(printf '%s' "${out}" | awk 'BEGIN{IGNORECASE=1} /^Status:/ {print $2; exit}')"

  # php-fpm default is 200 if no Status header is present
  if [[ -z "${status}" ]]; then
    echo "200"
  else
    echo "${status}"
  fi
}


# Convenience: call an app health script through FPM and return 0 if body == "OK"
fpm_app_ok() {
  local host="${1}"
  local port="${2}"
  local path="${3}"

  local http_response_code="$(fpm_status_code "${host}", "${port}" "${path}")"
  [[ "${http_response_code}" == "200" ]]
}


# Check if a laravel project
is_laravel_project() {
  local artisan="${1}"
  [[ -f "${artisan}" ]]
}


# Clear Laravel cache & config
laravel_clear() {
  local artisan="${1}"

  php "${artisan}" cache:clear
  php "${artisan}" config:clear
  php "${artisan}" route:clear
  php "${artisan}" view:clear
  php "${artisan}" event:clear
  php "${artisan}" optimize:clear
}


# Optimize Laravel
laravel_optimize() {
  local artisan="${1}"

  php "${artisan}" config:cache
  php "${artisan}" route:cache
  php "${artisan}" view:cache
  php "${artisan}" event:cache
  php "${artisan}" optimize
}
