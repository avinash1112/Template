<?php

namespace App\Http\Middleware;

use Closure;
use Illuminate\Http\Request;
use Symfony\Component\HttpFoundation\Response;

class EnsureJsonRequest
{

  // Methods that must carry JSON
  private const WRITE_METHODS = ['POST', 'PUT', 'PATCH'];

  // Allow-list URIs that can be non-JSON (e.g., file uploads, webhooks)
  private const EXCEPT_PATHS = [
    'api/v1/files/*',        // multipart/form-data uploads
    'api/v1/webhooks/*',
  ];

  public function handle(Request $request, Closure $next): Response {

    if (!in_array($request->getMethod(), self::WRITE_METHODS, true)) {
      return $next($request);
    }

    // Skip enforcement for excepted endpoints
    foreach (self::EXCEPT_PATHS as $pattern) {
      if ($request->is($pattern)) {
        return $next($request);
      }
    }

    // Require a JSON Content-Type (application/json or application/*+json)
    $contentType = $request->headers->get('Content-Type', '');
    $isJsonContentType = (bool) preg_match('#^application/(json|[\w.+-]+\\+json)(;|$)#i', $contentType);

    if (!$isJsonContentType) {
      return response()->json([
        'error'   => 'Unsupported Media Type',
        'message' => 'Requests must use Content-Type: application/json',
      ], 415);
    }

    // If there is a body, ensure it’s valid JSON
    $raw = $request->getContent();
    if (strlen($raw) > 0) {
      json_decode($raw);
      if (json_last_error() !== JSON_ERROR_NONE) {
        return response()->json([
          'error'   => 'Bad Request',
          'message' => 'Malformed JSON: ' . json_last_error_msg(),
        ], 400);
      }
    }

    return $next($request);
    
  }

}