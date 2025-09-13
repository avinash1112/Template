worker_processes auto;

events { 
  worker_connections 1024;
}

http {
  include       mime.types;
  default_type  application/octet-stream;
  sendfile      on;
  keepalive_timeout 65;

  proxy_buffering off;
  proxy_http_version 1.1;
  client_max_body_size  2g;
  proxy_read_timeout 900s;
  proxy_send_timeout 900s;
  proxy_redirect off;

  map $http_upgrade $connection_upgrade {
    default   "";
    websocket upgrade;
  }


  # ================== FRONTEND (vite dev server) ================== #
  upstream frontend_upstream {
    server __REPO_NAME__-__NODEJS_HOST_NAME__:__NODEJS_CONTAINER_PORT__;
    keepalive 32;
  }

  server {
    listen 80;
    server_name __FRONTEND_HOST_NAME__;
    return 301 https://$host$request_uri;
  }

  server {
    listen 443 ssl;
    http2 on;
    server_name __FRONTEND_HOST_NAME__;

    ssl_certificate     /etc/nginx/certs/frontend/fullchain.pem;
    ssl_certificate_key /etc/nginx/certs/frontend/key.pem;
    ssl_session_timeout 1d;
    ssl_prefer_server_ciphers on;

    add_header X-Content-Type-Options nosniff always;
    add_header X-Frame-Options SAMEORIGIN always;
    add_header Referrer-Policy strict-origin-when-cross-origin always;
    add_header X-XSS-Protection "1; mode=block" always;

    access_log /var/log/nginx/access.log;
    error_log  /var/log/nginx/error.log notice;

    location = /_proxy-ping { return 200 'OK'; }

    location / {
      proxy_pass http://frontend_upstream;

      proxy_set_header Host               $host;
      proxy_set_header X-Real-IP          $remote_addr;
      proxy_set_header X-Forwarded-For    $proxy_add_x_forwarded_for;
      proxy_set_header X-Forwarded-Proto  https;
      proxy_set_header X-Forwarded-Host   $host;
      proxy_set_header X-Forwarded-Port   443;

      proxy_set_header Upgrade            $http_upgrade;
      proxy_set_header Connection         $connection_upgrade;
    }
  }


  # ================== Frontend (dist via vite preview) ================== #
  upstream preview_upstream {
    server __REPO_NAME__-__NODEJS_HOST_NAME__:__NODEJS_VITE_PREVIEW_PORT__;
    keepalive 32;
  }

  server {
    listen __NODEJS_VITE_PREVIEW_PORT__;
    server_name _;

    access_log /var/log/nginx/access.log;
    error_log  /var/log/nginx/error.log notice;

    location = /_proxy-ping { return 200 'OK'; }

    location / {
      proxy_pass http://preview_upstream;

      proxy_http_version 1.1;
      proxy_set_header Host               $host;
      proxy_set_header X-Real-IP          $remote_addr;
      proxy_set_header X-Forwarded-For    $proxy_add_x_forwarded_for;
      proxy_set_header X-Forwarded-Proto  http;
      proxy_set_header X-Forwarded-Host   $host;
      proxy_set_header X-Forwarded-Port   __NODEJS_VITE_PREVIEW_PORT__;

    }

  }

  # ================== BACKEND ================== #
  upstream backend_upstream {
    server __REPO_NAME__-__NGINX_HOST_NAME__:80;
    keepalive 32;
  }

  server {
    listen 80;
    server_name __BACKEND_HOST_NAME__;
    return 301 https://$host$request_uri;
  }

  server {
    listen 443 ssl;
    http2 on;
    server_name __BACKEND_HOST_NAME__;

    ssl_certificate     /etc/nginx/certs/backend/fullchain.pem;
    ssl_certificate_key /etc/nginx/certs/backend/key.pem;
    ssl_session_timeout 1d;
    ssl_prefer_server_ciphers on;

    add_header X-Content-Type-Options nosniff always;
    add_header X-Frame-Options SAMEORIGIN always;
    add_header Referrer-Policy strict-origin-when-cross-origin always;
    add_header X-XSS-Protection "1; mode=block" always;

    access_log /var/log/nginx/access.log;
    error_log  /var/log/nginx/error.log notice;

    location = /_proxy-ping { return 200 'OK'; }

    location / {
      proxy_pass http://backend_upstream;

      proxy_set_header Host               $host;
      proxy_set_header X-Real-IP          $remote_addr;
      proxy_set_header X-Forwarded-For    $proxy_add_x_forwarded_for;
      proxy_set_header X-Forwarded-Proto  https;
      proxy_set_header X-Forwarded-Host   $host;
      proxy_set_header X-Forwarded-Port   443;

      proxy_set_header Upgrade            $http_upgrade;
      proxy_set_header Connection         $connection_upgrade;
    }

  }

}
