; zz-pool-overrides.conf  (loads after www.conf)
; Purpose: raise FPM capacity, expose health endpoints, and keep TCP listen.

[global]
; --- Logs ---
log_level = __PHP_CONFIG_POOL_LOG_LEVEL__


[www]
; --- Capacity / responsiveness ---
pm = dynamic
pm.max_children = 20
pm.start_servers = 3
pm.min_spare_servers = 3
pm.max_spare_servers = 6
pm.max_requests = 500        ; recycle workers to mitigate leaks

; --- Listen socket ---
listen = 0.0.0.0:__PHP_FPM_CONTAINER_PORT__

; --- Health endpoints ---
pm.status_path = __PHP_CONFIG_FPM_STATUS_PATH__
ping.path      = __PHP_CONFIG_FPM_PING_PATH__
ping.response  = pong

; --- Safe defaults ---
clear_env = yes
catch_workers_output = yes
decorate_workers_output = no
security.limit_extensions = .php

; --- Tighten timeouts ---
slowlog = /proc/self/fd/2
request_slowlog_timeout  = 10s
request_terminate_timeout = 900s
