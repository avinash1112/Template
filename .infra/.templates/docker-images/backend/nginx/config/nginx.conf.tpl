worker_processes auto;
worker_rlimit_nofile 65536;
pid /tmp/nginx.pid;

events {
  worker_connections 4096;
}

http {
  
  # MIME / defaults
  include mime.types;
  default_type application/octet-stream;
  types_hash_max_size 4096;

  # I/O optimizations
  sendfile    on;
  tcp_nodelay on;
  tcp_nopush  on;

  # Caching niceties
  etag on;
  if_modified_since exact;

  # Gzip – safe set
  gzip              on;
  gzip_vary         on;
  gzip_comp_level   5;
  gzip_min_length   1024;
  gzip_proxied      any;
  gzip_types
    text/plain text/css application/json application/javascript
    text/xml application/xml application/xml+rss image/svg+xml
    application/font-woff application/font-woff2 font/ttf font/opentype;

  # Large headers (many cookies, etc.)
  large_client_header_buffers 8 16k;

  # Timeouts (support big uploads, long responses)
  client_header_timeout 15s;
  client_body_timeout   900s;
  send_timeout          900s;
  keepalive_timeout     65s;

  # Limits
  client_body_buffer_size 512k;
  client_max_body_size    2g;

  # Temp paths to writable locations
  client_body_temp_path /tmp/client_temp;
  fastcgi_temp_path     /tmp/fastcgi_temp;
  proxy_temp_path       /tmp/proxy_temp;
  scgi_temp_path        /tmp/scgi_temp;
  uwsgi_temp_path       /tmp/uwsgi_temp;

  # Logs to stdout/stderr
  access_log /dev/stdout;
  error_log  /dev/stderr __NGINX_CONFIG_ERROR_LOG_LEVEL__;
  log_format main '$remote_addr - $remote_user [$time_local] "$request" '
                '$status $body_bytes_sent "$http_referer" '
                '"$http_user_agent" "$http_x_forwarded_for"';

  # Hide Nginx version information to reduce fingerprinting
  server_tokens off;

  # HTTPS config for proxy
  map $http_x_forwarded_proto $fcgi_https {
    default "";
    https   on;
  }

  upstream php_upstream {
    server __PHP_APP_HOST_NAME__:__PHP_FPM_CONTAINER_PORT__;
  }

  server {
    listen 80;
    listen [::]:80;
    server_name _;

    root /var/www/html/public;
    index index.php index.html;

    # Don’t list directories
    autoindex off;

    # Health probes
    location __NGINX_CONFIG_PING_PATH__ {
      access_log off;
      add_header Content-Type text/plain;
      return 200 'OK';
    }
    location __NGINX_CONFIG_STUB_STATUS_PATH__ {
      stub_status;
      allow 127.0.0.1;   # required for curl inside the container
      allow ::1;
      deny all;
    }

    # Static assets: long-lived caching (immutable filenames)
    location ~* \.(?:css|js|mjs|ico|gif|bmp|svg|png|jpe?g|webp|avif|woff2?|ttf|eot)$ {
      access_log off;
      expires 30d;
      add_header Cache-Control "public, max-age=2592000, immutable";
      try_files $uri =404;
    }

    # Main app routing – only serve from /public
    location / {
      disable_symlinks if_not_owner from=/var/www/html;
      try_files $uri $uri/ /index.php?$query_string;
    }

    # Deny access to hidden files and sensitive config
    location ~ /\.(?!well-known) { deny all; }
    location ~* /(composer\.(json|lock)|package\.json|webpack\.mix\.js|vite\.(config|manifest)\.json|artisan|env|phpunit\.xml|\.env|\.git) {
      deny all;
    }

    # Never execute PHP under these paths (uploads, storage, etc.)
    location ~* ^/(storage|uploads|files)/.*\.php$ { deny all; }

    # Block all .php except the single front controller
    location ~ \.php$ { return 404; }

    # The only allowed PHP entry-point
    location = /index.php {
      
      # Ensure file exists
      try_files $uri =404;

      include fastcgi_params;

      # Pass scheme
      fastcgi_param REQUEST_SCHEME $scheme;
      fastcgi_param HTTP_X_FORWARDED_PROTO $http_x_forwarded_proto;
      fastcgi_param HTTPS  $fcgi_https;

      # Resolve real path (thwarts some symlink tricks)
      fastcgi_param SCRIPT_FILENAME $realpath_root$fastcgi_script_name;
      fastcgi_param DOCUMENT_ROOT $realpath_root;

      fastcgi_pass php_upstream;
      fastcgi_keep_conn on;

      # Timeouts/buffers
      fastcgi_buffering on;
      fastcgi_buffer_size 64k;
      fastcgi_buffers 32 64k;
      fastcgi_busy_buffers_size 1m;
      fastcgi_temp_file_write_size 1m;
      fastcgi_read_timeout 900s;
      fastcgi_send_timeout 900s;

      # Don’t forward this proxy header to PHP
      fastcgi_param HTTP_PROXY "";
    }

    # Restrict methods for the whole vhost
    if ($request_method !~ ^(GET|HEAD|POST|PUT|DELETE|OPTIONS)$) { return 405; }
  }
  
}
