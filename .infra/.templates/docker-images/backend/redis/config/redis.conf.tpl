# Never daemonize in containers
daemonize no

# Bind & protected mode
bind 0.0.0.0
protected-mode yes

# Data dir
dir /data

# Socket
# unixsocket /var/run/redis/redis.sock
# unixsocketperm 770

# Logs (send to stdout)
logfile ""

# Security: require ACL file, disable CONFIG command for non-admin users via ACLs
aclfile /etc/redis/users.acl

# Rename or disable dangerous commands (belt-and-suspenders; ACLs already restrict).
rename-command FLUSHALL ""
rename-command FLUSHDB ""
rename-command CONFIG ""
rename-command SHUTDOWN ""
rename-command DEBUG ""
rename-command SAVE ""
rename-command KEYS ""

# Persistence: AOF + RDB (overridden in different build stages)
appendonly yes

# CoW memory control
aof-use-rdb-preamble yes
rdbcompression yes
rdbchecksum yes
save 900 1
save 300 10
save 60  10000

# Memory management (maxmemory - overridden in different build stages)
maxmemory-policy allkeys-lru

# Slowlog / Latency monitoring
slowlog-log-slower-than 10000
slowlog-max-len 128

# Networking & timeouts
tcp-keepalive 60
timeout 0

# TLS
port 0
tls-port __REDIS_CONTAINER_PORT__
tls-auth-clients yes
tls-ca-cert-file /etc/ssl/certs/redis/server/ca.pem
tls-cert-file /etc/ssl/certs/redis/server/leaf.pem
tls-key-file /etc/ssl/certs/redis/server/key.pem
tls-protocols "TLSv1.2 TLSv1.3"
