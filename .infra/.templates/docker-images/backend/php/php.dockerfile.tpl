# ============================================== #
# ==================== BASE ==================== #
# ============================================== #
FROM php:8.4-fpm-alpine AS base


# Set to user root
USER root


# Install packages & user UID/GID modification
RUN <<EOF
set -eux

apk add --no-cache --virtual .build-deps \
  shadow autoconf make gcc g++ libc-dev pkgconf re2c file libpng-dev \
  libjpeg-turbo-dev freetype-dev icu-dev libzip-dev oniguruma-dev

apk add --no-cache \
  fcgi libpng libjpeg-turbo freetype icu-libs libzip oniguruma bash curl gettext zip \
  redis unzip mariadb-client

update-ca-certificates

docker-php-ext-configure gd --with-freetype --with-jpeg

docker-php-ext-install -j"$(nproc)" \
  pdo pdo_mysql mbstring exif pcntl bcmath gd zip intl opcache

pecl install redis
docker-php-ext-enable redis opcache

# cur_gid="$(id -g __PHP_CONTAINER_RUNTIME_USER_GROUP__)"
# cur_uid="$(id -u __PHP_CONTAINER_RUNTIME_USER_NAME__)"
# tgt_gid="__PHP_CONTAINER_USER_GID__"
# tgt_uid="__PHP_CONTAINER_USER_UID__"

# if [ "${cur_gid}" != "${tgt_gid}" ]; then groupmod -g "${tgt_gid}" __PHP_CONTAINER_RUNTIME_USER_NAME__; fi
# if [ "${cur_uid}" != "${tgt_uid}" ]; then usermod -u "${tgt_uid}" -g "${tgt_gid}" __PHP_CONTAINER_RUNTIME_USER_NAME__; fi

apk del .build-deps
rm -rf /tmp/pear

EOF


# Install Composer
COPY --from=composer:2 /usr/bin/composer /usr/bin/composer
RUN <<EOF
set -eu

chown root:__PHP_CONTAINER_RUNTIME_USER_GROUP__ \
  /usr/bin/composer

chmod 0550 \
  /usr/bin/composer

EOF


# Set explicit shell to bash for inline scripts
SHELL ["/bin/bash", "-c"]


# Copy all base config files in one go to a temp location
COPY ./.infra/rendered/docker-images/backend/php/   /tmp/build/


# Apply ownerships, move files to their final destinations, set permissions
RUN <<EOF
set -Eeuxo pipefail

install -d -m 770 -o root -g __PHP_CONTAINER_RUNTIME_USER_GROUP__ \
  /var/www/html \
  /opt/php/lib \
  /opt/php/scripts

mv /tmp/build/config/zz-pool-overrides.conf /usr/local/etc/php-fpm.d/zz-pool-overrides.conf

cp -a /tmp/build/config/.    /usr/local/etc/php/
cp -a /tmp/build/lib/.   /opt/php/lib/
cp -a /tmp/build/scripts/.   /opt/php/scripts/

rm -rf /tmp/build

ln -sf /opt/php/scripts/entrypoint.sh   /usr/local/bin/entrypoint.sh
ln -sf /opt/php/scripts/liveness.sh     /usr/local/bin/liveness.sh
ln -sf /opt/php/scripts/readiness.sh    /usr/local/bin/readiness.sh

chown root:__PHP_CONTAINER_RUNTIME_USER_GROUP__ \
  /usr/local/etc/php/php.ini \
  /opt/php/lib/* \
  /opt/php/scripts/*

chmod 0440 \
  /usr/local/etc/php/php.ini \
  /opt/php/lib/*

chmod 0550 \
  /opt/php/scripts/*

EOF


# Copy full source code
COPY ./backend  /var/www/html


# Set Working directory
WORKDIR /var/www/html


# Set permissions
RUN <<EOF
set -Eeuxo pipefail

chown -R root:__PHP_CONTAINER_RUNTIME_USER_GROUP__ \
  /var/www/html

find /var/www/html -type d -exec chmod 2770 {} \;
find /var/www/html -type f -exec chmod 0660 {} \;

[ -f /var/www/html/composer.json ] && chmod 0660 /var/www/html/composer.json || true
[ -f /var/www/html/composer.lock ] && chmod 0660 /var/www/html/composer.lock || true

if [ -f /var/www/html/artisan ]; then
  chmod 0770 /var/www/html/artisan

  find /var/www/html -type d \
    ! -path "/var/www/html/storage*" \
    ! -path "/var/www/html/bootstrap/cache*" \
    -exec chmod 0770 {} \;

  find /var/www/html -type f \
    ! -path "/var/www/html/storage/*" \
    ! -path "/var/www/html/bootstrap/cache/*" \
    -exec chmod 0440 {} \;

  find /var/www/html/storage /var/www/html/bootstrap/cache -type d -exec chmod g+s {} \;

fi

EOF


# Drop privileges explicitly
USER __PHP_CONTAINER_RUNTIME_USER_NAME__


# Expose PHP-FPM port
EXPOSE __PHP_FPM_CONTAINER_PORT__


# Set the container's entrypoint script
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]


# Default command to start container's process
CMD ["php-fpm", "-F"]



# ============================================== #
# ==================== DEV ===================== #
# ============================================== #
FROM base AS dev


# Switch to root
USER root


# Install dev-only tools
RUN <<EOF
set -Eeuxo pipefail

# Build deps for pecl (phpize) + headers
apk add --no-cache --virtual .phpize-deps $PHPIZE_DEPS linux-headers ca-certificates tar gzip
update-ca-certificates

# Run pecl using php -n (so disable_functions doesn’t break it)
PHP_PEAR_PHP_BIN="php -n" pecl channel-update pecl.php.net
PHP_PEAR_PHP_BIN="php -n" pecl install -f xdebug

# Ensure the loader ini exists (safer than relying on docker-php-ext-enable)
echo "zend_extension=$(php-config --extension-dir)/xdebug.so" > /usr/local/etc/php/conf.d/00-xdebug-loader.ini

# Write xdebug config
cat > /usr/local/etc/php/conf.d/99-xdebug.ini <<'INI'
; ---- Xdebug (dev) ----
xdebug.mode=develop,debug
xdebug.start_with_request=yes
xdebug.client_port=9003
xdebug.client_host=host.docker.internal
xdebug.log_level=0
xdebug.log=/tmp/xdebug.log
INI

# Drop build deps
apk del .phpize-deps

# Install dev-only utilities
apk add --no-cache procps net-tools supervisor

EOF


# Switch to user __PHP_CONTAINER_RUNTIME_USER_NAME__ for composer packages installation
USER __PHP_CONTAINER_RUNTIME_USER_NAME__


# Install composer packages with dev dependencies
RUN <<EOF
set -Eeuxo pipefail

if [ -f composer.lock ]; then
  composer install --prefer-dist --no-interaction --no-progress --no-scripts --optimize-autoloader

  elif [ -f composer.json ]; then
  composer install --prefer-dist --no-interaction --no-progress --no-scripts --optimize-autoloader
fi

[ -d /app/node_modules ] && find /app/node_modules -type d -exec chmod 2770 {} \; || true
[ -d /app/node_modules ] && find /app/node_modules -type f -exec chmod 0660 {} \; || true

[ -d /var/www/html/vendor/bin ] && find /var/www/html/vendor/bin -type f -exec chmod 0770 {} \; || true
[ -d /var/www/html/vendor ] && find /var/www/html/vendor -type f -name "*.sh" -exec chmod 0770 {} \; || true

EOF



# ============================================== #
# =================== STAGING ================== #
# ============================================== #
FROM base AS staging


# Install composer packages without dev dependencies
RUN <<EOF
set -Eeuxo pipefail

if [ -f composer.lock ]; then
  composer install --no-dev --prefer-dist --no-interaction --no-progress --no-scripts --optimize-autoloader

elif [ -f composer.json ]; then
  composer install --no-dev --prefer-dist --no-interaction --no-progress --no-scripts --optimize-autoloader
fi

[ -d /var/www/html/vendor/bin ] && find /var/www/html/vendor/bin -type f -exec chmod 2550 {} \; || true
[ -d /var/www/html/vendor ] && find /var/www/html/vendor -type f -name "*.sh" -exec chmod 0550 {} \; || true

EOF



# ============================================== #
# ================= PRODUCTION ================= #
# ============================================== #
FROM staging AS production


