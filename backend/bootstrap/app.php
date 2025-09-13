<?php

use Illuminate\Foundation\Application;
use Illuminate\Foundation\Configuration\Exceptions;
use Illuminate\Foundation\Configuration\Middleware;

return Application::configure(basePath: dirname(__DIR__))

  ->withRouting(
    web: __DIR__.'/../routes/web.php',
    api: __DIR__.'/../routes/api.php',
    commands: __DIR__.'/../routes/console.php',
    health: '/up',
  )

  ->withMiddleware(function (Middleware $middleware): void {

    // Force JSON responses everywhere
    $middleware->append(\App\Http\Middleware\ForceJsonResponse::class);

    // Enforce JSON request bodies on API group (POST/PUT/PATCH)
    $middleware->appendToGroup('api', \App\Http\Middleware\EnsureJsonRequest::class);

  })

  ->withExceptions(function (Exceptions $exceptions): void {
    $exceptions->shouldRenderJsonWhen(fn () => true);
  })
  
  ->create();
