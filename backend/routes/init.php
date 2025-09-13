<?php

use Illuminate\Support\Facades\Route;
use App\Http\Controllers\InitCheck\MySqlCheckController;
use App\Http\Controllers\InitCheck\S3CheckController;

Route::prefix('_init')->as('init.')->group(function () {
  
  // MySQL
  Route::prefix('mysql')->as('mysql.')->group(function () {
    Route::get('/hosts', [MySqlCheckController::class, 'hosts']);
    Route::post('/write', [MySqlCheckController::class, 'write']);
    Route::get('/read/{id}', [MySqlCheckController::class, 'read']);
    Route::get('/lag', [MySqlCheckController::class, 'lag']); 
  });

  // Redis
  Route::prefix('redis')->as('redis.')->group(function () {
    
  });

  // S3 (cloudflare R2)
  Route::prefix('s3')->as('s3.')->group(function () {
    Route::get('/test-s3', [S3CheckController::class, 'index'])->name('test-s3.form');
    Route::post('/test-s3', [S3CheckController::class, 'upload'])->name('test-s3.upload');
  });


  // init-scoped fallback (typos under /api/_init/*)
  Route::fallback(function () {
    return response()->json([
      'error'   => 'Not Found',
      'message' => 'Unknown _init endpoint.'
    ], 404);
  });

});
