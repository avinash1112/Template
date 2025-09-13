# ============================================== #
# ==================== BASE ==================== #
# ============================================== #
FROM mysql:8.4.6 AS base


# Set to user root
USER root


# Install packages & user UID/GID modification
RUN <<EOF
set -eux

microdnf install -y --nodocs --setopt=install_weak_deps=0 shadow-utils bash gettext

ln -sf "/usr/share/zoneinfo/__APP_TIMEZONE__" /etc/localtime; \

# cur_gid="$(id -g __MYSQL_CONTAINER_RUNTIME_USER_GROUP__)"
# cur_uid="$(id -u __MYSQL_CONTAINER_RUNTIME_USER_NAME__)"
# tgt_gid="__MYSQL_CONTAINER_USER_GID__"
# tgt_uid="__MYSQL_CONTAINER_USER_UID__"

# if [ "${cur_gid}" != "${tgt_gid}" ]; then groupmod -g "${tgt_gid}" __MYSQL_CONTAINER_RUNTIME_USER_NAME__; fi
# if [ "${cur_uid}" != "${tgt_uid}" ]; then usermod -u "${tgt_uid}" -g "${tgt_gid}" __MYSQL_CONTAINER_RUNTIME_USER_NAME__; fi

microdnf remove -y shadow-utils || true
microdnf -y clean all
rm -rf /var/cache

EOF


# Set explicit shell to bash for inline scripts
SHELL ["/bin/bash", "-c"]


# Copy all base config files in one go to a temp location
COPY ./.infra/rendered/docker-images/backend/mysql/    /tmp/build/


# Apply ownerships, move files to their final destinations, set permissions
RUN <<EOF
set -Eeuxo pipefail

# Create necessary directories (perms & ownership will the overridden after files are moved)
install -d -m 550 -o root -g __MYSQL_CONTAINER_RUNTIME_USER_GROUP__ \
  /etc/ssl/certs/mysql/clients \
  /etc/ssl/certs/mysql/server

install -d -m 770 -o root -g __MYSQL_CONTAINER_RUNTIME_USER_GROUP__ \
  /opt/mysql/lib \
  /opt/mysql/scripts \
  /var/mysql/backup \
  /var/mysql/info \
  /var/mysql/restore \
  /opt/mysql/sql


# Move configuration and initialization files
cp -a /tmp/build/certs/.     /etc/ssl/certs/mysql/server/
cp -a /tmp/build/config/.    /etc/mysql/
cp -a /tmp/build/lib/.   /opt/mysql/lib/
cp -a /tmp/build/scripts/.   /opt/mysql/scripts/
cp -a /tmp/build/sql/.       /opt/mysql/sql/


# Cleanup temp directory
rm -rf /tmp/build


# Symlinks
ln -sf /opt/mysql/scripts/entrypoint.sh   /usr/local/bin/entrypoint.sh
ln -sf /opt/mysql/scripts/liveness.sh     /usr/local/bin/liveness.sh
ln -sf /opt/mysql/scripts/readiness.sh    /usr/local/bin/readiness.sh


# Update ownership
chown root:__MYSQL_CONTAINER_RUNTIME_USER_GROUP__ \
  /etc/ssl/certs/mysql/server/* \
  /etc/mysql/* \
  /opt/mysql/lib/* \
  /opt/mysql/scripts/* \
  /opt/mysql/sql/*


# Update permissions
chmod 0440 \
  /etc/ssl/certs/mysql/server/* \
  /etc/mysql/* \
  /opt/mysql/lib/* \
  /opt/mysql/sql/*

chmod 0550 \
  /opt/mysql/scripts/*

EOF


# Drop privileges explicitly
USER __MYSQL_CONTAINER_RUNTIME_USER_NAME__


# Ports
EXPOSE __MYSQL_HOST_PORT__


# Set the container's entrypoint script
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]


# Default command to start container's process
CMD ["mysqld", "--user=__MYSQL_CONTAINER_RUNTIME_USER_NAME__"]



# ============================================== #
# ==================== DEV ===================== #
# ============================================== #
FROM base AS dev



# ============================================== #
# =================== STAGING ================== #
# ============================================== #
FROM base AS staging



# ============================================== #
# ================= PRODUCTION ================= #
# ============================================== #
FROM staging AS production


