# ============================================== #
# ==================== BASE ==================== #
# ============================================== #
FROM nginx:alpine AS base


# Set to user root
USER root


# Install packages & user UID/GID modification
RUN <<EOF
set -eux
  
apk add --no-cache \
  bash libcap ca-certificates tzdata gettext

update-ca-certificates

setcap 'cap_net_bind_service=+ep' /usr/sbin/nginx

apk add --no-cache --virtual .build-deps shadow

# cur_gid="$(id -g __NGINX_CONTAINER_RUNTIME_USER_GROUP__)"
# cur_uid="$(id -u __NGINX_CONTAINER_RUNTIME_USER_NAME__)"
# tgt_gid="__NGINX_CONTAINER_USER_GID__"
# tgt_uid="__NGINX_CONTAINER_USER_UID__"

# if [ "${cur_gid}" != "${tgt_gid}" ]; then groupmod -g "${tgt_gid}" __NGINX_CONTAINER_RUNTIME_USER_NAME__; fi
# if [ "${cur_uid}" != "${tgt_uid}" ]; then usermod -u "${tgt_uid}" -g "${tgt_gid}" __NGINX_CONTAINER_RUNTIME_USER_NAME__; fi

apk del .build-deps

EOF


# Set explicit shell to bash for inline scripts
SHELL ["/bin/bash", "-c"]


# Copy all base config files in one go to a temp location
COPY ./.infra/rendered/docker-images/backend/nginx/   /tmp/build/


# Apply ownerships, move files to their final destinations, set permissions
RUN <<EOF
set -Eeuxo pipefail

# Set up runtime directories with proper ownership
install -d -m 770 -o root -g __NGINX_CONTAINER_RUNTIME_USER_GROUP__ \
  /var/www/html/public

install -d -m 770 -o root -g __NGINX_CONTAINER_RUNTIME_USER_GROUP__ \
  /opt/nginx/lib \
  /opt/nginx/scripts


# Move configuration and initialization files
cp -a /tmp/build/config/.    /etc/nginx/
cp -a /tmp/build/lib/.   /opt/nginx/lib/
cp -a /tmp/build/scripts/.   /opt/nginx/scripts/


# Cleanup temp directory
rm -rf /tmp/build


# Symlinks
ln -sf /opt/nginx/scripts/entrypoint.sh   /usr/local/bin/entrypoint.sh
ln -sf /opt/nginx/scripts/liveness.sh     /usr/local/bin/liveness.sh
ln -sf /opt/nginx/scripts/readiness.sh    /usr/local/bin/readiness.sh


# Update ownership
chown root:__NGINX_CONTAINER_RUNTIME_USER_GROUP__ \
  /etc/nginx/* \
  /opt/nginx/lib/* \
  /opt/nginx/scripts/*


# Update permissions
chmod 0440 \
  /etc/nginx/* \
  /opt/nginx/lib/*

chmod 0550 \
  /opt/nginx/scripts/*

EOF


# Copy static public assets
COPY ./backend/public   /var/www/html/public


# Drop privileges explicitly
USER __NGINX_CONTAINER_RUNTIME_USER_NAME__


# Ports
EXPOSE 80


# Set the container's entrypoint script
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]


# Default command to start container's process
CMD ["nginx", "-g", "daemon off;"]



# ============================================== #
# ==================== DEV ===================== #
# ============================================== #
FROM base AS dev


# Switch to root
USER root


# Install dev-only tooling
RUN <<EOF
set -Eeuxo pipefail
  
apk add --no-cache curl

EOF


# Drop privileges explicitly
USER __NGINX_CONTAINER_RUNTIME_USER_NAME__



# ============================================== #
# =================== STAGING ================== #
# ============================================== #
FROM base AS staging



# ============================================== #
# ================= PRODUCTION ================= #
# ============================================== #
FROM staging AS production


