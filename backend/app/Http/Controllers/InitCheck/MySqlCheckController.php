<?php

namespace App\Http\Controllers\InitCheck;

use App\Http\Controllers\Controller;
use Illuminate\Http\Request;

class MySqlCheckController extends Controller {
   
    // GET /_init/mysql/hosts
    public function hosts() {
      $writeHost = DB::connection('mysql_writeonly')->selectOne('select @@hostname as h')->h ?? null;
      $readHost  = DB::connection('mysql_readonly')->selectOne('select @@hostname as h')->h ?? null;

      return response()->json([
        'write_hostname' => $writeHost,
        'read_hostname'  => $readHost,
      ]);
    }

    // POST /_init/mysql/write
    public function write(Request $request) {
      $id = (string) \Str::uuid();
      $payload = [
        'id'         => $id,
        'note'       => $request->input('note', 'init-check'),
      ];

      DB::connection('mysql_writeonly')->insert(
        'insert into init_check_items (id, note, created_at) values (?, ?, now())',
        [$payload['id'], $payload['note']]
      );

      $from = DB::connection('mysql_writeonly')->selectOne('select @@hostname as h')->h ?? null;

      return response()->json([
        'id' => $id,
        'wrote_from_hostname' => $from,
        'payload' => $payload,
      ], 201);
    }

    // GET /_init/mysql/read/{id}
    public function read(string $id) {
      $row = DB::connection('mysql_readonly')->selectOne(
        'select id, note, created_at from init_check_items where id = ?',
        [$id]
      );

      $from = DB::connection('mysql_readonly')->selectOne('select @@hostname as h')->h ?? null;

      return response()->json([
        'id' => $id,
        'found' => (bool) $row,
        'read_from_hostname' => $from,
        'data' => $row,
      ]);
    }

    // GET /_init/mysql/lag  (best-effort; requires suitable grants)
    public function lag() {
      try {
        // MySQL 8+: attempt common sources of lag info
        $row = DB::connection('mysql_readonly')->selectOne("
          SELECT
            COALESCE(
              (SELECT CAST(variable_value AS SIGNED) FROM performance_schema.global_status WHERE variable_name = 'SLAVE_SQL_RUNCNT'), 
              NULL
            ) AS legacy_hint
        ");

        // If your RO user can: SHOW REPLICA STATUS
        $status = DB::connection('mysql_readonly')->select('SHOW REPLICA STATUS');
        $lag = null;
        if (!empty($status)) {
          $s = (array) $status[0];
          $lag = $s['Seconds_Behind_Source'] ?? $s['Seconds_Behind_Master'] ?? null;
        }

        return response()->json([
          'replica_seconds_behind' => $lag,
        ]);
      }
      
      catch (\Throwable $e) {
        return response()->json([
          'replica_seconds_behind' => null,
          'note' => 'Could not read replica lag with current grants.',
        ]);
      }
    }
