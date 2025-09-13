<?php

namespace App\Http\Controllers\InitCheck;

use Illuminate\Http\Request;
use Illuminate\Support\Facades\Storage;


class S3CheckController extends Controller {


  /**
   * Show a basic upload form.
   */
  public function index() {
      return view('test-s3');
  }



  /**
   * Handle file upload to R2.
   */
  public function upload(Request $request) {
    $request->validate([
      'file' => ['required', 'file', 'max:10240'], // 10MB max
    ]);

    $file = $request->file('file');
    $path = Storage::disk('s3')->putFile(
      'test-uploads',
      $file,
      [
        'visibility' => 'private',
        'CacheControl' => 'no-store',
      ]
    );

    $url = Storage::disk('s3')->temporaryUrl(
      $path,
      now()->addMinutes(15)
    );

    return back()->with([
      'message' => "Uploaded successfully to: {$path}",
      'url' => $url,
    ]);

  }

}
