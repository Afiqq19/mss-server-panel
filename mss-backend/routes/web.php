<?php

use App\Http\Controllers\DeployController;
use Illuminate\Support\Facades\Route;

Route::get('/', function () {
    if (file_exists(public_path('index.html'))) {
        return response()->file(public_path('index.html'));
    }
    return view('welcome');
});

// JSON Webhook Auto-Deploy Controller (Support GET & POST with key)
Route::match(['get', 'post'], '/deploy-update', [DeployController::class, 'update']);
Route::match(['get', 'post'], '/update-rahasia-panel', [DeployController::class, 'update']);
