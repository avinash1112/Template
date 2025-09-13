services:
  mysql-0:
    container_name: __REPO_NAME__-mysql-0
    hostname: mysql-0
    image: ghcr.io/__CONTAINER_REGISTRY_USERNAME__/__REPO_NAME__-mysql:latest
    restart: unless-stopped
    env_file:
      - ../../docker-images/backend/mysql/.env-runtime
    ports:
      - "__MYSQL_HOST_PORT__:__MYSQL_CONTAINER_PORT__"
    volumes:
      - type: bind
        source: ../../../certs/backend/mysql/clients
        target: /etc/ssl/certs/mysql/clients
    healthcheck:
      test: ["CMD", "/usr/local/bin/readiness.sh"]
      start_period: 0s
      timeout: 90s
      interval: 5s
      retries: 5
    networks:
      - __REPO_NAME__-backend-net

  redis-0:
    container_name: __REPO_NAME__-redis-0
    hostname: redis-0
    image: ghcr.io/__CONTAINER_REGISTRY_USERNAME__/__REPO_NAME__-redis:latest
    restart: unless-stopped
    env_file:
      - ../../docker-images/backend/redis/.env-runtime
    ports:
      - "__REDIS_HOST_PORT__:__REDIS_CONTAINER_PORT__"
    volumes:
      - type: bind
        source: ../../../certs/backend/redis/clients
        target: /etc/ssl/certs/redis/clients
    healthcheck:
      test: ["CMD", "/usr/local/bin/readiness.sh"]
      start_period: 0s
      timeout: 10s
      interval: 5s
      retries: 5
    networks:
      - __REPO_NAME__-backend-net

  php-app-0:
    container_name: __REPO_NAME__-php-app-0
    hostname: php-app-0
    image: ghcr.io/__CONTAINER_REGISTRY_USERNAME__/__REPO_NAME__-php:latest
    restart: unless-stopped
    env_file:
      - ../../docker-images/backend/php/.env-runtime
    expose:
      - "__PHP_FPM_CONTAINER_PORT__"
    volumes:
      - type: bind
        source: ../../../../backend
        target: /var/www/html
      - type: bind
        source: ../../../certs/backend/mysql/clients
        target: /etc/ssl/certs/mysql
      - type: bind
        source: ../../../certs/backend/redis/clients
        target: /etc/ssl/certs/redis
      - type: volume
        source: __REPO_NAME__-vendor
        target: /var/www/html/vendor
    healthcheck:
      test: ["CMD", "/usr/local/bin/readiness.sh"]
      start_period: 0s
      timeout: 10s
      interval: 5s
      retries: 5
    networks:
      - __REPO_NAME__-backend-net
    depends_on:
      mysql-__MYSQL_CONFIG_READ_REPLICA_COUNT__:
        condition: service_healthy
      redis-0:
        condition: service_healthy
    extra_hosts:
      - "host.docker.internal:host-gateway"

  nginx-0:
    container_name: __REPO_NAME__-nginx-0
    hostname: nginx-0
    image: ghcr.io/__CONTAINER_REGISTRY_USERNAME__/__REPO_NAME__-nginx:latest
    restart: unless-stopped
    env_file:
      - ../../docker-images/backend/nginx/.env-runtime
    expose:
      - "80"
    volumes:
      - type: bind
        source: ../../../../backend/public
        target: /var/www/html/public
    healthcheck:
      test: ["CMD", "/usr/local/bin/readiness.sh"]
      start_period: 0s
      timeout: 5s
      interval: 5s
      retries: 5
    networks:
      - __REPO_NAME__-backend-net
      - __REPO_NAME__-edge-net
    depends_on:
      php-app-0:
        condition: service_healthy

networks:
  __REPO_NAME__-backend-net:
    driver: bridge
  __REPO_NAME__-edge-net:
    external: true

volumes:
  __REPO_NAME__-vendor:
