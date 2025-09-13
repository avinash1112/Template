# ============================================== #
# ==================== BASE ==================== #
# ============================================== #
FROM redis:8.2.0-alpine3.22 AS base


# Set to user root
USER root


# Install packages & user UID/GID modification
RUN <<EOF
set -eux

apk add --no-cache bash ca-certificates gettext tini tzdata

update-ca-certificates

apk add --no-cache --virtual .build-deps shadow

# cur_gid="$(id -g __REDIS_CONTAINER_RUNTIME_USER_GROUP__)"
# cur_uid="$(id -u __REDIS_CONTAINER_RUNTIME_USER_NAME__)"
# tgt_gid="__REDIS_CONTAINER_USER_GID__"
# tgt_uid="__REDIS_CONTAINER_USER_UID__"

# if [ "${cur_gid}" != "${tgt_gid}" ]; then groupmod -g "${tgt_gid}" __REDIS_CONTAINER_RUNTIME_USER_NAME__; fi
# if [ "${cur_uid}" != "${tgt_uid}" ]; then usermod -u "${tgt_uid}" -g "${tgt_gid}" __REDIS_CONTAINER_RUNTIME_USER_NAME__; fi

apk del .build-deps

EOF


# Set explicit shell to bash for inline scripts
SHELL ["/bin/bash", "-c"]


# Copy all config files in one go to a temp location
COPY ./.infra/rendered/docker-images/backend/redis/   /tmp/build/


# Apply ownerships, move files to their final destinations, set permissions
RUN <<EOF
set -Eeuxo pipefail

# Set up runtime directories with proper ownership
install -d -m 550 -o root -g __REDIS_CONTAINER_RUNTIME_USER_GROUP__ \
  /etc/ssl/certs/redis/clients \
  /etc/ssl/certs/redis/server

# If using socket add /var/run/redis/
install -d -m 0700 -o __REDIS_CONTAINER_RUNTIME_USER_NAME__ -g __REDIS_CONTAINER_RUNTIME_USER_GROUP__ \
  /data/appendonlydir \
  /etc/redis \
  /etc/redis/conf.d \
  /opt/redis/lib \
  /opt/redis/scripts \
  /tpl/conf \
  /tpl/conf.d


# Move configuration and initialization files
cp -a /tmp/build/certs/.            /etc/ssl/certs/redis/server/
cp -a /tmp/build/config/.           /tpl/conf/
cp -a /tmp/build/config/conf.d/.    /tpl/conf.d/
cp -a /tmp/build/lib/.          /opt/redis/lib/
cp -a /tmp/build/scripts/.          /opt/redis/scripts/
mv /tmp/build/openssl/openssl.cnf   /etc/redis/openssl.cnf


# Cleanup temp directory
rm -rf /tmp/build


# Symlinks
ln -sf /opt/redis/scripts/entrypoint.sh   /usr/local/bin/entrypoint.sh
ln -sf /opt/redis/scripts/liveness.sh     /usr/local/bin/liveness.sh
ln -sf /opt/redis/scripts/readiness.sh    /usr/local/bin/readiness.sh


# Update ownership
chown root:__REDIS_CONTAINER_RUNTIME_USER_GROUP__ \
  /etc/ssl/certs/redis/server/* \
  /opt/redis/lib/* \
  /opt/redis/scripts/*


# Update permissions
chmod 440 \
  /etc/ssl/certs/redis/server/* \
  /opt/redis/lib/*

chmod 0550 \
  /opt/redis/scripts/*

EOF


# Drop privileges explicitly
USER __REDIS_CONTAINER_RUNTIME_USER_NAME__


# Ports
EXPOSE __REDIS_CONTAINER_PORT__


# Set the container's entrypoint script
ENTRYPOINT ["/sbin/tini","--","/usr/local/bin/entrypoint.sh"]



# ============================================== #
# ==================== DEV ===================== #
# ============================================== #
FROM base AS dev


# Default command to start container's process
CMD ["redis-server", "/etc/redis/redis.conf", "--include", "/etc/redis/conf.d/dev.conf"]



# ============================================== #
# =================== STAGING ================== #
# ============================================== #
FROM base AS staging


# Default command to start container's process
CMD ["redis-server", "/etc/redis/redis.conf", "--include", "/etc/redis/conf.d/staging.conf"]



# ============================================== #
# ================= PRODUCTION ================= #
# ============================================== #
FROM base AS production


# Default command to start container's process
CMD ["redis-server", "/etc/redis/redis.conf", "--include", "/etc/redis/conf.d/production.conf"]


