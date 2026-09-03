<?php

use App\Http\Controllers\AppLauncherController;
use App\Http\Controllers\AuthController;
use App\Http\Controllers\BackupController;
use App\Http\Controllers\DeployController;
use App\Http\Controllers\HostStatsController;
use App\Http\Controllers\PortainerController;
use Illuminate\Support\Facades\Route;

/*
|--------------------------------------------------------------------------
| API Routes - MSS-Server-Panel (Mepal)
|--------------------------------------------------------------------------
| Sesuai spesifikasi Prompt-mss-server-panel.txt:
| - Public: /login, /deploy-update
| - Protected (auth:sanctum): /containers, /host-stats, /backups, /app-launchers, /logout
*/

// Public Authentication & Auto-Deploy Routes (Protected by secret key)
Route::post('/login', [AuthController::class, 'login']);
Route::match(['get', 'post'], '/deploy-update', [DeployController::class, 'update']);

// Protected API Routes (Bab 5: "Semua endpoint API (kecuali login) wajib dilindungi middleware auth")
Route::middleware('auth:sanctum')->group(function () {
    // Auth & User Profile
    Route::post('/logout', [AuthController::class, 'logout']);
    Route::get('/user', [AuthController::class, 'user']);

    // Docker Containers via Portainer (Bab 2, 4, 6)
    Route::get('/containers', [PortainerController::class, 'index']);
    Route::post('/containers/{id}/{action}', [PortainerController::class, 'action'])
        ->where('action', 'start|stop|restart');

    // Host Server Hardware Monitoring (Bab 4, 8, 9.A)
    Route::get('/host-stats', [HostStatsController::class, 'index']);

    // Nextcloud NAS SQL Backup Module (Bab 9.B)
    Route::get('/backups', [BackupController::class, 'index']);
    Route::post('/backups/run', [BackupController::class, 'run']);

    // App Launcher Shortcuts (Bab 4, 7)
    Route::apiResource('app-launchers', AppLauncherController::class);
});
