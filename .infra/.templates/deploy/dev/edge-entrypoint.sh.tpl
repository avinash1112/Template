#!/usr/bin/env sh
set -eu

# Ensure required environment variables are set
: "${WAIT_TIMEOUT}"
: "${WAIT_RETRY_INTERVAL}"
: "${UPSTREAM_URLS}"


# Logger with timestamp
_log() {
  printf '%s %s\n' "[$(date +'%H:%M:%S')]" "$*"
}


# Probe a URL (supports optional "host@url" format)
_probe_url() {
  item="${1}"

  case "${item}" in

    *@http://*|*@https://*)

      # Extract host before @
      host="${item%%@http*}"

      # Extract URL after @
      url="${item#*@}"

      # wget -q --spider --header="Host: ${host}" --timeout="${WAIT_RETRY_INTERVAL}" "${url}" 2>/dev/null
      wget -S -O- --header="Host: ${host}" --timeout="${WAIT_RETRY_INTERVAL}" "${url}" 2>&1 | head -20

    ;;

    # Default: just probe the raw URL
    *)
      # wget -q --spider --timeout="${WAIT_RETRY_INTERVAL}" "${item}" 2>/dev/null
      wget -S -O- --timeout="${WAIT_RETRY_INTERVAL}" "${url}" 2>&1 | head -20
    ;;

  esac
}



# Wait until a given URL responds or timeout reached
_wait_for() {
  url="${1}"
  elapsed=0

  _log "Waiting for: ${url} (timeout=${WAIT_TIMEOUT}s, interval=${WAIT_RETRY_INTERVAL}s)"

  while [ "${elapsed}" -lt "${WAIT_TIMEOUT}" ]; do
    
    if _probe_url "${url}"; then
      _log "Upstream READY: ${url}"
      return 0
    fi

    sleep "${WAIT_RETRY_INTERVAL}"
    elapsed=$(( elapsed + WAIT_RETRY_INTERVAL ))

  done

  _log "ERROR: Timed out waiting for ${url}"

  return 1

}


# Loop over all upstream URLs and wait for them
for url in ${UPSTREAM_URLS}; do
  _wait_for "${url}"
done


# Handle termination signals by stopping nginx gracefully
trap 'log "SIGTERM received, stopping nginx"; kill -TERM "$NGINX_PID" 2>/dev/null || true' TERM INT


# Start nginx after all upstreams are ready
_log "All upstreams ready. Starting nginx..."
nginx -g 'daemon off;' &
NGINX_PID=$!
wait "${NGINX_PID}"
