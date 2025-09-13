<?php

use Illuminate\Support\Facades\Route;
use Illuminate\Http\Request;

Route::prefix('v1')->as('v1.')->group(function () {
  
  // Health
  Route::get('health', fn () => ['ok' => true])->name('health');

  // Auth
  Route::get('/user', function (Request $request) {
      return $request->user();
  })->middleware('auth:sanctum');

  // v1-scoped fallback (typos under /api/v1/*)
  Route::fallback(function () {
    return response()->json([
      'error'   => 'Not Found',
      'message' => 'Unknown v1 endpoint.'
    ], 404);
  });

});
