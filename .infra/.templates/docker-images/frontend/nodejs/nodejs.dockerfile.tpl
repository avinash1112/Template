# ============================================== #
# ==================== BASE ==================== #
# ============================================== #
FROM node:24-alpine AS base


# Set to user root
USER root


# Install packages & user UID/GID modification
RUN <<EOF
set -eux

apk add --no-cache bash curl git openssh-client tzdata python3 make g++ libc6-compat tini

apk add --no-cache --virtual .build-deps shadow

# cur_uid="$(id -u __NODEJS_CONTAINER_RUNTIME_USER_NAME__)"
# cur_gid="$(id -g __NODEJS_CONTAINER_RUNTIME_USER_NAME__)"
# tgt_uid="__NODEJS_CONTAINER_USER_UID__"
# tgt_gid="__NODEJS_CONTAINER_USER_GID__"

# if [ "${cur_gid}" != "${tgt_gid}" ]; then groupmod -g "${tgt_gid}" __NODEJS_CONTAINER_RUNTIME_USER_NAME__; fi
# if [ "${cur_uid}" != "${tgt_uid}" ]; then usermod -u "${tgt_uid}" -g "${tgt_gid}" __NODEJS_CONTAINER_RUNTIME_USER_NAME__; fi

apk del .build-deps

EOF


# Set explicit shell to bash for inline scripts
SHELL ["/bin/bash", "-c"]


# Copy all base config files in one go to a temp location
COPY ./.infra/rendered/docker-images/frontend/nodejs/ /tmp/build/


# Apply ownerships, move files to their final destinations, set permissions
RUN <<EOF
set -Eeuxo pipefail

install -d -m 770 -o root -g __NODEJS_CONTAINER_RUNTIME_USER_GROUP__ \
  /app \
  /opt/nodejs/lib \
  /opt/nodejs/scripts

cp -a /tmp/build/lib/.   /opt/nodejs/lib/
cp -a /tmp/build/scripts/.   /opt/nodejs/scripts/

rm -rf /tmp/build

ln -sf /opt/nodejs/scripts/entrypoint.sh   /usr/local/bin/entrypoint.sh
ln -sf /opt/nodejs/scripts/liveness.sh     /usr/local/bin/liveness.sh
ln -sf /opt/nodejs/scripts/readiness.sh    /usr/local/bin/readiness.sh

chown root:__NODEJS_CONTAINER_RUNTIME_USER_GROUP__ \
  /opt/nodejs/lib/* \
  /opt/nodejs/scripts/*

chmod 0440 \
  /opt/nodejs/lib/*

chmod 0550 \
  /opt/nodejs/scripts/*

EOF



# Copy full source code
COPY ./frontend   /app


# Set Working directory
WORKDIR /app


# Set permissions
RUN <<EOF
set -Eeuxo pipefail

chown -R root:__NODEJS_CONTAINER_RUNTIME_USER_GROUP__ \
  /app
  
find /app -type d -exec chmod 2770 {} \;
find /app -type f -exec chmod 0660 {} \;

[ -f /app/package.json ] && chmod 0660 /app/package.json || true
[ -f /app/package-lock.json ] && chmod 0660 /app/package-lock.json || true

EOF


# Drop privileges explicitly
USER __NODEJS_CONTAINER_RUNTIME_USER_NAME__


# Set the container's entrypoint script
ENTRYPOINT ["/sbin/tini","--","/usr/local/bin/entrypoint.sh"]



# ============================================== #
# ===================== DEV ==================== #
# ============================================== #
FROM base AS dev


# Install dependencies
RUN <<EOF
set -Eeuxo pipefail

if [ -s package-lock.json ]; then
  npm ci --include=dev --no-progress --audit=false --fund=false

elif [ -s package-lock.json ]; then
  npm install --include=dev --no-progress --audit=false --fund=false
fi 

[ -d /app/node_modules ] && find /app/node_modules -type d -exec chmod 2770 {} \; || true
[ -d /app/node_modules ] && find /app/node_modules -type f -exec chmod 0660 {} \; || true

[ -d /app/node_modules/.bin ] && find /app/node_modules/.bin -type f -exec chmod 0770 {} \; || true
find /app/node_modules -type f -path "*/bin/*" -exec chmod 0770 {} \; || true

EOF


# Expose NodeJS container port
EXPOSE __NODEJS_CONTAINER_PORT__


# Default command to start container's process
CMD ["bash","-lc","npm run dev --if-present || npm start --if-present || npx vite --host 0.0.0.0 --port __NODEJS_CONTAINER_PORT__ || { echo '⚠️ No dev/start/vite found'; sleep infinity; }"]



# ============================================== #
# ================= BUILDER ==================== #
# ============================================== #
FROM base AS builder


# Install dependencies
RUN <<EOF
set -Eeuxo pipefail

if [ -f package-lock.json ]; then
  npm ci --omit=dev --no-progress --audit=false --fund=false

  elif [ -f package.json ]; then
  npm install --omit=dev --no-progress --audit=false --fund=false
fi

[ -d /app/node_modules ] && find /app/node_modules -type d -exec chmod 2550 {} \; || true
[ -d /app/node_modules ] && find /app/node_modules -type f -exec chmod 0440 {} \; || true

[ -d /app/node_modules/.bin ] && find /app/node_modules/.bin -type f -exec chmod 0550 {} \; || true
find /app/node_modules -type f -path "*/bin/*" -exec chmod 0550 {} \; || true

EOF


# Build the static site
RUN npm run build



# ============================================== #
# =================== STAGING ================== #
# ============================================== #
FROM nginx:alpine AS staging


# Copy custom nginx conf file
COPY ./.infra/rendered/docker-images/frontend/nodejs/config/nginx.conf   /etc/nginx/nginx.conf


# Serve the built static assets
COPY --from=builder /app/dist /var/www/html


# Expose ports
EXPOSE 80


# Default command to start container's process
CMD ["nginx","-g","daemon off;"]



# ============================================== #
# ================= PRODUCTION ================= #
# ============================================== #
FROM staging AS production


