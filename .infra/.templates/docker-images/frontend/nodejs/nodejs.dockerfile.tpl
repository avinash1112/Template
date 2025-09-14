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
FROM nginx:alpine AS production

# Install additional tools for health checks and monitoring
RUN <<EOF
set -eux

apk add --no-cache \
  bash \
  curl \
  jq \
  tzdata \
  tini

# Create nginx user with specific UID/GID for consistency
addgroup -g __NODEJS_CONTAINER_USER_GID__ __NODEJS_CONTAINER_RUNTIME_USER_GROUP__ || true
adduser -u __NODEJS_CONTAINER_USER_UID__ -G __NODEJS_CONTAINER_RUNTIME_USER_GROUP__ -s /bin/bash -D __NODEJS_CONTAINER_RUNTIME_USER_NAME__ || true

# Create necessary directories
install -d -m 755 -o __NODEJS_CONTAINER_RUNTIME_USER_NAME__ -g __NODEJS_CONTAINER_RUNTIME_USER_GROUP__ \
  /var/www/html \
  /tmp/nginx \
  /tmp/nodejs/logs \
  /tmp/nodejs/pids \
  /tmp/nodejs/runtime \
  /opt/nodejs/lib \
  /opt/nodejs/scripts

# Create writable temp directories for nginx
install -d -m 777 /tmp/nginx/client_temp /tmp/nginx/proxy_temp /tmp/nginx/fastcgi_temp /tmp/nginx/uwsgi_temp /tmp/nginx/scgi_temp

EOF

# Copy enhanced nginx configuration
COPY ./.infra/rendered/docker-images/frontend/nodejs/config/nginx.conf /etc/nginx/nginx.conf
COPY ./.infra/rendered/docker-images/frontend/nodejs/config/health-endpoints.conf /etc/nginx/conf.d/health-endpoints.conf
COPY ./.infra/rendered/docker-images/frontend/nodejs/config/location-rules.conf /etc/nginx/conf.d/location-rules.conf

# Copy built static assets from builder stage
COPY --from=builder --chown=__NODEJS_CONTAINER_RUNTIME_USER_NAME__:__NODEJS_CONTAINER_RUNTIME_USER_GROUP__ /app/dist /var/www/html

# Copy helper scripts and libraries
COPY --chown=__NODEJS_CONTAINER_RUNTIME_USER_NAME__:__NODEJS_CONTAINER_RUNTIME_USER_GROUP__ ./.infra/rendered/docker-images/frontend/nodejs/lib/ /opt/nodejs/lib/
COPY --chown=__NODEJS_CONTAINER_RUNTIME_USER_NAME__:__NODEJS_CONTAINER_RUNTIME_USER_GROUP__ ./.infra/rendered/docker-images/frontend/nodejs/scripts/ /opt/nodejs/scripts/

# Copy TLS certificates (production only - will be mounted as secrets in K8s)
COPY ./.infra/rendered/docker-images/frontend/nodejs/certs/ /opt/nodejs/certs/

# Create enhanced health check endpoints and entrypoint
RUN <<EOF
set -eux

# Create a health check script for nginx + static assets
cat > /opt/nodejs/scripts/health-server.sh << 'EOFHEALTH'
#!/bin/bash
# Simple health check server that runs alongside nginx

source /opt/nodejs/lib/00-helpers.sh

HEALTH_PORT="${HEALTH_PORT:-9000}"
MAIN_PORT="${NGINX_PORT:-80}"

# Create health endpoints directory
mkdir -p /var/www/health

# Create health endpoint files
cat > /var/www/health/health.json << 'EOFJSON'
{
  "status": "healthy",
  "service": "frontend-nginx",
  "role": "replica",
  "timestamp": "TIMESTAMP_PLACEHOLDER"
}
EOFJSON

cat > /var/www/health/ready.json << 'EOFJSON'
{
  "status": "ready",
  "service": "frontend-nginx", 
  "role": "replica",
  "timestamp": "TIMESTAMP_PLACEHOLDER"
}
EOFJSON

# Update timestamps and start simple HTTP server for health checks
while true; do
  current_time="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  
  # Update health files with current timestamp
  sed "s/TIMESTAMP_PLACEHOLDER/${current_time}/g" /var/www/health/health.json > /tmp/health.json.tmp && \
    mv /tmp/health.json.tmp /var/www/health/health.json
  
  sed "s/TIMESTAMP_PLACEHOLDER/${current_time}/g" /var/www/health/ready.json > /tmp/ready.json.tmp && \
    mv /tmp/ready.json.tmp /var/www/health/ready.json
  
  sleep 30
done
EOFHEALTH

chmod +x /opt/nodejs/scripts/health-server.sh

EOF

# Create enhanced entrypoint script
RUN <<EOF
set -eux

cat > /opt/nodejs/scripts/entrypoint-nginx.sh << 'EOFENTRY'
#!/bin/bash
set -Eeuo pipefail

source /opt/nodejs/lib/00-helpers.sh

# Environment detection and instance configuration (simplified for nginx)
detect_instance_config() {
  export NODEJS_ROLE="replica"
  export NODEJS_IS_MASTER="false" 
  export NODEJS_IS_REPLICA="true"
  
  local hostname="$(get_hostname)"
  local instance_id="${hostname}"
  
  if [[ "${hostname}" =~ -([0-9]+)$ ]]; then
    local pod_ordinal="${BASH_REMATCH[1]}"
    export POD_ORDINAL="${pod_ordinal}"
    instance_id="${hostname} (ordinal: ${pod_ordinal})"
  elif [[ -n "${POD_NAME:-}" ]]; then
    instance_id="${POD_NAME}"
  fi
  
  export NODEJS_INSTANCE_ID="${instance_id}"
  echo_info "Frontend Nginx instance: ${instance_id}"
}

# Initialize application
initialize_application() {
  echo_info "Initializing frontend nginx application"
  
  # Register instance
  register_instance
  
  # Test static assets
  if [[ ! -d /var/www/html ]] || [[ ! "$(ls -A /var/www/html 2>/dev/null)" ]]; then
    echo_error "Static assets not found in /var/www/html"
    exit 1
  fi
  
  echo_info "Static assets verified: $(du -sh /var/www/html | cut -f1)"
  
  # Set up signal handlers
  trap 'handle_shutdown' SIGTERM SIGINT
  
  echo_success "Frontend nginx initialized successfully"
}

# Register instance
register_instance() {
  local hostname="$(get_hostname)"
  local timestamp="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  
  cat > /tmp/nodejs/runtime/instance_registration.json << EOFREG
{
  "hostname": "${hostname}",
  "instance_id": "${NODEJS_INSTANCE_ID}",
  "role": "replica",
  "service_type": "nginx",
  "timestamp": "${timestamp}",
  "pid": $$,
  "port": "${NGINX_PORT:-80}",
  "health_port": "${HEALTH_PORT:-9000}",
  "pod_name": "${POD_NAME:-}",
  "pod_ordinal": "${POD_ORDINAL:-}",
  "kubernetes_namespace": "${KUBERNETES_NAMESPACE:-}",
  "node_env": "${NODE_ENV:-production}",
  "app_version": "${APP_VERSION:-unknown}"
}
EOFREG
}

# Handle shutdown
handle_shutdown() {
  echo_info "Shutting down frontend nginx application"
  
  # Stop health server background process
  jobs -p | xargs -r kill 2>/dev/null || true
  
  # Stop nginx gracefully
  nginx -s quit 2>/dev/null || true
  
  # Clean up
  rm -f /tmp/nodejs/runtime/instance_registration.json
  
  echo_info "Shutdown complete"
  exit 0
}

# Main execution
detect_instance_config
initialize_application

# Start health server in background
/opt/nodejs/scripts/health-server.sh &

# Start nginx in foreground
echo_info "Starting nginx server on port ${NGINX_PORT:-80}"
exec nginx -g "daemon off;"
EOFENTRY

chmod +x /opt/nodejs/scripts/entrypoint-nginx.sh

# Create symlinks for health check scripts
ln -sf /opt/nodejs/scripts/liveness.sh /usr/local/bin/liveness.sh
ln -sf /opt/nodejs/scripts/readiness.sh /usr/local/bin/readiness.sh

EOF

# Set proper permissions
RUN <<EOF
set -eux

chown -R __NODEJS_CONTAINER_RUNTIME_USER_NAME__:__NODEJS_CONTAINER_RUNTIME_USER_GROUP__ \
  /var/www/html \
  /tmp/nodejs \
  /opt/nodejs

chmod -R 755 /opt/nodejs/scripts/
chmod -R 644 /opt/nodejs/lib/

# Set secure permissions for certificates (if they exist)
if [[ -d /opt/nodejs/certs ]]; then
  chown -R root:__NODEJS_CONTAINER_RUNTIME_USER_GROUP__ /opt/nodejs/certs
  chmod 750 /opt/nodejs/certs
  find /opt/nodejs/certs -name "*.key" -exec chmod 640 {} \; || true
  find /opt/nodejs/certs -name "*.crt" -exec chmod 644 {} \; || true
fi

# Ensure nginx can write to its temp directories
chown -R nginx:nginx /tmp/nginx/
chmod -R 777 /tmp/nginx/

EOF

# Expose the nginx ports (HTTP and HTTPS)
EXPOSE __NODEJS_CONTAINER_PORT__
EXPOSE 443

# Use tini as init system and custom entrypoint
ENTRYPOINT ["/sbin/tini", "--", "/opt/nodejs/scripts/entrypoint-nginx.sh"]


