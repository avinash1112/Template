#!/bin/bash
set -Eeuo pipefail

# Apply openssl config to ignore unexpected EOFs
export openssl_CONF=/etc/redis/openssl.cnf


# Load helpers
source /opt/redis/lib/00-helpers.sh


# Substitute env vars from conf files
subs_env "/tpl/conf" "/etc/redis" "__REDIS_CONTAINER_RUNTIME_USER_NAME__:__REDIS_CONTAINER_RUNTIME_USER_GROUP__" "0440"
subs_env "/tpl/conf/conf.d" "/etc/redis/conf.d" "__REDIS_CONTAINER_RUNTIME_USER_NAME__:__REDIS_CONTAINER_RUNTIME_USER_GROUP__" "0440"


# Handoff to container's main process (passed via CMD)
exec "$@"
