<?php

use Illuminate\Http\Request;

require_once __DIR__ . '/init.php';
require_once __DIR__ . '/v1.php';

// Explicitly handle /api and /api/
Route::get('/', function () {
  return response()->json([
    'error'   => 'API version required',
    'message' => 'Please use /api/v1/...'
  ], 404);
});

// Catch-all for anything else under /api/*
Route::fallback(function () {
  return response()->json(['error' => 'Not Found'], 404);
});
