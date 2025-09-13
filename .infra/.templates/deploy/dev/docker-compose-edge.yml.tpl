networks:
  __REPO_NAME__-edge-net:
    name: __REPO_NAME__-edge-net
    driver: bridge
    external: false

services:
  reverse-proxy:
    container_name: __REPO_NAME__-reverse-proxy
    hostname: reverse-proxy-0
    image: nginx:alpine
    restart: unless-stopped
    ports:
      - "80:80"
      - "443:443"
      - "__NODEJS_VITE_PREVIEW_PORT__:__NODEJS_VITE_PREVIEW_PORT__"
    volumes:
      - type: bind
        source: ./edge-entrypoint.sh
        target: /usr/local/bin/entrypoint.sh
        read_only: true
      - type: bind
        source: ./proxy.conf
        target: /etc/nginx/nginx.conf
        read_only: true
      - type: bind
        source: ../../../certs/frontend/proxy/server/fullchain.pem
        target: /etc/nginx/certs/frontend/fullchain.pem
        read_only: true
      - type: bind
        source: ../../../certs/frontend/proxy/server/key.pem
        target: /etc/nginx/certs/frontend/key.pem
        read_only: true
      - type: bind
        source: ../../../certs/backend/proxy/server/fullchain.pem
        target: /etc/nginx/certs/backend/fullchain.pem
        read_only: true
      - type: bind
        source: ../../../certs/backend/proxy/server/key.pem
        target: /etc/nginx/certs/backend/key.pem
        read_only: true
    entrypoint: ["/usr/local/bin/entrypoint.sh"]
    environment:
      WAIT_TIMEOUT: "3"
      WAIT_RETRY_INTERVAL: "2"
      UPSTREAM_URLS: >-
        http://__REPO_NAME__-nginx-0:80__NGINX_CONFIG_PING_PATH__
        __FRONTEND_HOST_NAME__@http://__REPO_NAME__-nodejs-0:__NODEJS_CONTAINER_PORT__/
    networks:
      - __REPO_NAME__-edge-net
      