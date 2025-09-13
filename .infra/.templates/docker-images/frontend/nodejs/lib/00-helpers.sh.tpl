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
