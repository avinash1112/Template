;;;;;;;;;;;;;;;;;;;;;;;;;
; BASIC SETTINGS
;;;;;;;;;;;;;;;;;;;;;;;;;

; Language
default_charset="UTF-8"

; Set your timezone correctly
date.timezone="__APP_TIMEZONE__"

; Hide PHP version from headers (security)
expose_php=Off

; Prevent path traversal tricks
cgi.fix_pathinfo=0

; Disable dangerous functions that are not usually used
; disable_functions=exec,passthru,shell_exec,system,proc_open,popen,show_source

; disable assertions in prod (enable in dev)
zend.assertions=__PHP_CONFIG_ZEND_ASSERTIONS__ 

; make assertions throw exceptions instead of warnings in dev
assert.exception=__PHP_CONFIG_ASSERT_EXCEPTION__

; Keep sensitive args out of stack traces
zend.exception_ignore_args=On

;;;;;;;;;;;;;;;;;;;;;;;;;
; UPLOAD + POST SETTINGS
;;;;;;;;;;;;;;;;;;;;;;;;;

file_uploads=On
max_file_uploads=50
post_max_size=2G
upload_max_filesize=2G


;;;;;;;;;;;;;;;;;;;;;;;;;
; MEMORY + EXECUTION SETTINGS
;;;;;;;;;;;;;;;;;;;;;;;;;

memory_limit=2G
max_execution_time=300
max_input_time="-1"
max_input_vars=10000


;;;;;;;;;;;;;;;;;;;;;;;;;
; ERROR DISPLAY & LOGGING
;;;;;;;;;;;;;;;;;;;;;;;;;

; Show errors
display_errors=__PHP_CONFIG_DISPLAY_ERRORS__
display_startup_errors=__PHP_CONFIG_DISPLAY_STARTUP_ERRORS__

; Report everything
error_reporting=__PHP_CONFIG_ERROR_REPORTING__

; Log to stderr
error_log=/proc/self/fd/2
log_errors=On
log_errors_max_len=0


;;;;;;;;;;;;;;;;;;;;;;;;;
; OPcache
;;;;;;;;;;;;;;;;;;;;;;;;;

opcache.enable=1
opcache.enable_cli=0
opcache.memory_consumption=256
opcache.interned_strings_buffer=16
opcache.max_accelerated_files=50000
opcache.restrict_api=/var/www/html
opcache.save_comments=1

; Immutable builds in prod: no stat() checks; dev: enable and revalidate quickly
opcache.validate_timestamps=__PHP_CONFIG_OPCACHE_VALIDATE_TIMESTAMPS__
opcache.revalidate_freq=__PHP_CONFIG_OPCACHE_REVALIDATE_FREQ__

; JIT generally not helpful for Laravel request lifecycles
opcache.jit=0
opcache.jit_buffer_size=0


;;;;;;;;;;;;;;;;;;;;;;;;;
; SESSION SETTINGS
;;;;;;;;;;;;;;;;;;;;;;;;;

session.cookie_httponly=1
session.cookie_secure=1
session.use_cookies=1
session.use_only_cookies=1
session.cookie_samesite=Lax
session.use_strict_mode=1


;;;;;;;;;;;;;;;;;;;;;;;;;
; CUSTOM TWEAKS
;;;;;;;;;;;;;;;;;;;;;;;;;

realpath_cache_size=4096k
realpath_cache_ttl=600
default_socket_timeout=300
pcre.jit=1
