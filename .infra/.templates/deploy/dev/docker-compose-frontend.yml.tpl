services:
  nodejs-0:
    container_name: __REPO_NAME__-nodejs-0
    hostname: nodejs-0
    image: ghcr.io/__CONTAINER_REGISTRY_USERNAME__/__REPO_NAME__-nodejs:latest
    restart: unless-stopped
    env_file:
      - ../../docker-images/frontend/nodejs/.env-runtime
    expose:
      - "__NODEJS_CONTAINER_PORT__"
    volumes:
      - type: bind
        source: ../../../../frontend
        target: /app
      - type: volume
        source: __REPO_NAME__-node_modules
        target: /app/node_modules
    healthcheck:
      test: ["CMD", "/usr/local/bin/readiness.sh"]
      start_period: 0s
      timeout: 10s
      interval: 5s
      retries: 5
    networks:
      - __REPO_NAME__-frontend-net
      - __REPO_NAME__-edge-net

networks:
  __REPO_NAME__-frontend-net:
    driver: bridge
  __REPO_NAME__-edge-net:
    external: true

volumes:
  __REPO_NAME__-node_modules:
  