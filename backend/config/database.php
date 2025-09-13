<?php

use Illuminate\Support\Str;

return [

    /*
    |--------------------------------------------------------------------------
    | Default Database Connection Name
    |--------------------------------------------------------------------------
    |
    | Here you may specify which of the database connections below you wish
    | to use as your default connection for database operations. This is
    | the connection which will be utilized unless another connection
    | is explicitly specified when you execute a query / statement.
    |
    */

    'default' => env('DB_CONNECTION', 'sqlite'),

    /*
    |--------------------------------------------------------------------------
    | Database Connections
    |--------------------------------------------------------------------------
    |
    | Below are all of the database connections defined for your application.
    | An example configuration is provided for each database system which
    | is supported by Laravel. You're free to add / remove connections.
    |
    */

    'connections' => [

        'sqlite' => [
            'driver' => 'sqlite',
            'url' => env('DB_URL'),
            'database' => env('DB_DATABASE', database_path('database.sqlite')),
            'prefix' => '',
            'foreign_key_constraints' => env('DB_FOREIGN_KEYS', true),
            'busy_timeout' => null,
            'journal_mode' => null,
            'synchronous' => null,
        ],

        'mysql' => [
            'database'        => env('DB_DATABASE'),
            'driver'          => 'mysql',
            'engine'          => null,
            'charset'         => env('DB_CHARSET', 'utf8mb4'),
            'collation'       => env('DB_COLLATION', 'utf8mb4_unicode_ci'),
            'prefix'          => '',
            'prefix_indexes'  => true,
            'sticky'          => true,
            'strict'          => true,
            'unix_socket'     => env('DB_SOCKET', ''),

            'read' => [
                'username' => env('DB_READ_USERNAME'),
                'password' => env('DB_READ_PASSWORD'),
                'host' => [
                      env('DB_READ_HOST'),
                ],
                'options' => extension_loaded('pdo_mysql') ? array_filter([
                    PDO::MYSQL_ATTR_SSL_CA                 => env('DB_READ_TLS_CA'),
                    PDO::MYSQL_ATTR_SSL_CERT               => env('DB_READ_TLS_CERT'),
                    PDO::MYSQL_ATTR_SSL_KEY                => env('DB_READ_TLS_KEY'),
                    PDO::MYSQL_ATTR_SSL_VERIFY_SERVER_CERT => env('DB_TLS_VERIFY_SERVER_CERT', false),
                ]) : [],
            ],

            'write' => [
                'username' => env('DB_WRITE_USERNAME'),
                'password' => env('DB_WRITE_PASSWORD'),
                'host' => [
                    env('DB_WRITE_HOST'),
                ],
                'options' => extension_loaded('pdo_mysql') ? array_filter([
                    PDO::MYSQL_ATTR_SSL_CA                 => env('DB_WRITE_TLS_CA'),
                    PDO::MYSQL_ATTR_SSL_CERT               => env('DB_WRITE_TLS_CERT'),
                    PDO::MYSQL_ATTR_SSL_KEY                => env('DB_WRITE_TLS_KEY'),
                    PDO::MYSQL_ATTR_SSL_VERIFY_SERVER_CERT => env('DB_TLS_VERIFY_SERVER_CERT', false),
                ]) : [],
            ],
        ],

        'mariadb' => [
            'driver'          => 'mariadb',
            'url'             => env('DB_URL'),
            'host'            => env('DB_HOST', '127.0.0.1'),
            'port'            => env('DB_PORT', '3306'),
            'database'        => env('DB_DATABASE', 'laravel'),
            'username'        => env('DB_USERNAME', 'root'),
            'password'        => env('DB_PASSWORD', ''),
            'unix_socket'     => env('DB_SOCKET', ''),
            'charset'         => env('DB_CHARSET', 'utf8mb4'),
            'collation'       => env('DB_COLLATION', 'utf8mb4_unicode_ci'),
            'prefix'          => '',
            'prefix_indexes'  => true,
            'strict'          => true,
            'engine'          => null,
            'options'         => extension_loaded('pdo_mysql') ? array_filter([
                PDO::MYSQL_ATTR_SSL_CA => env('DB_WRITE_TLS_CA'),
                PDO::MYSQL_ATTR_SSL_CERT => env('DB_WRITE_TLS_CERT'),
                PDO::MYSQL_ATTR_SSL_KEY  => env('DB_WRITE_TLS_KEY'),
                PDO::MYSQL_ATTR_SSL_VERIFY_SERVER_CERT => true,
            ]) : [],
        ],

        'pgsql' => [
            'driver' => 'pgsql',
            'url' => env('DB_URL'),
            'host' => env('DB_HOST', '127.0.0.1'),
            'port' => env('DB_PORT', '5432'),
            'database' => env('DB_DATABASE', 'laravel'),
            'username' => env('DB_USERNAME', 'root'),
            'password' => env('DB_PASSWORD', ''),
            'charset' => env('DB_CHARSET', 'utf8'),
            'prefix' => '',
            'prefix_indexes' => true,
            'search_path' => 'public',
            'sslmode' => 'prefer',
        ],

        'sqlsrv' => [
            'driver' => 'sqlsrv',
            'url' => env('DB_URL'),
            'host' => env('DB_HOST', 'localhost'),
            'port' => env('DB_PORT', '1433'),
            'database' => env('DB_DATABASE', 'laravel'),
            'username' => env('DB_USERNAME', 'root'),
            'password' => env('DB_PASSWORD', ''),
            'charset' => env('DB_CHARSET', 'utf8'),
            'prefix' => '',
            'prefix_indexes' => true,
            // 'encrypt' => env('DB_ENCRYPT', 'yes'),
            // 'trust_server_certificate' => env('DB_TRUST_SERVER_CERTIFICATE', 'false'),
        ],

    ],

    /*
    |--------------------------------------------------------------------------
    | Migration Repository Table
    |--------------------------------------------------------------------------
    |
    | This table keeps track of all the migrations that have already run for
    | your application. Using this information, we can determine which of
    | the migrations on disk haven't actually been run on the database.
    |
    */

    'migrations' => [
        'table' => 'migrations',
        'update_date_on_publish' => true,
    ],

    /*
    |--------------------------------------------------------------------------
    | Redis Databases
    |--------------------------------------------------------------------------
    |
    | Redis is an open source, fast, and advanced key-value store that also
    | provides a richer body of commands than a typical key-value system
    | such as Memcached. You may define your connection settings here.
    |
    */

    'redis' => [

        'client' => env('REDIS_CLIENT', 'phpredis'),
         
        'options'  => [
            'cluster' => env('REDIS_CLUSTER', 'redis'),
            'prefix'  => env('CACHE_PREFIX', Str::slug(env('APP_NAME', 'laravel'), '_').'_database_'),
          ],
          
          'cache' => [
            
            'scheme'        => env('REDIS_SCHEME', 'tls'),
            'host'          => env('REDIS_HOST'),
            'port'          => env('REDIS_PORT'),
            'username'      => env('REDIS_USERNAME'),
            'password'      => env('REDIS_PASSWORD'),
            'database'      => env('REDIS_DB', 0),
            'persistent'    => true,
            'persistent_id' => 'cache:laravel:'.strtolower(env('APP_ENV')).':'.strtolower(env('REDIS_HOST')).':'.env('REDIS_PORT'),
            'context'     => [
                'stream' => [
                    'local_cert'        => env('REDIS_TLS_CERT'), # no intermediates, using leaf instead of fullchain
                    'local_pk'          => env('REDIS_TLS_KEY'),
                    'cafile'            => env('REDIS_TLS_CA'),
                    'allow_self_signed' => env('REDIS_TLS_ALLOW_SELF_SIGNED', false),
                    'verify_peer'       => env('REDIS_TLS_VERIFY_PEER', true),
                    'verify_peer_name'  => env('REDIS_TLS_VERIFY_PEER', true),
                    'peer_name'         => env('REDIS_TLS_PEER_NAME', env('REDIS_HOST')),
                ],
            ],
        ],

    ],

];
