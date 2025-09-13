[mysqld]

; ==================== Connection & Networking ====================
;Disable host name caching (safer for dynamic environments)
host_cache_size=0

;Disable DNS lookups for client hostnames (faster & more secure)
skip-name-resolve

;Limit max concurrent client connections
max_connections=200

;Location of Unix socket file
socket=/var/run/mysqld/mysqld.sock

;Location of PID file (moved to secure directory)
pid-file=/var/mysql/info/mysqld.pid


; ========================= Authentication ========================
;Default secure authentication plugin
authentication_policy=caching_sha2_password

;Enforce SSL/TLS for client connections
require_secure_transport=ON


; ============================ SSL/TLS ============================
;Path to CA cert
ssl-ca=/etc/ssl/certs/mysql/server/ca.pem

; Path to Server certificate
ssl-cert=/etc/ssl/certs/mysql/server/leaf.pem

; Path to Server private key
ssl-key=/etc/ssl/certs/mysql/server/key.pem


; ===================== GTID-Based Replication ====================
;Enable Global Transaction ID (required for GTID replication)
gtid_mode=ON

;Ensure GTID-safe transactions only
enforce_gtid_consistency=ON


; ========================= Binary Logging ========================
;Enable binary logging (required for replication)
log_bin=mysql-bin

; Expire bin logs
binlog_expire_logs_auto_purge=ON
binlog_expire_logs_seconds=2592000

;Set error log to stderr
log_error=stderr


; ======================= External Includes =======================
;Include server-id file (used for replication uniqueness)
!include /var/mysql/info/01-instance.cnf
