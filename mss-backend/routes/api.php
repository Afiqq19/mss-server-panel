<?php

use App\Http\Controllers\AppLauncherController;
use App\Http\Controllers\AuthController;
use App\Http\Controllers\BackupController;
use App\Http\Controllers\DeployController;
use App\Http\Controllers\HostStatsController;
use App\Http\Controllers\NetworkController;
use App\Http\Controllers\PortainerController;
use App\Http\Controllers\SettingsController;
use App\Http\Controllers\TerminalController;
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
Route::match(['get', 'post'], '/update-rahasia-panel', [DeployController::class, 'update']);
Route::match(['get', 'post'], '/deploy-update', [DeployController::class, 'update']);

// Protected Routes (Butuh Token)
Route::middleware('auth:sanctum')->group(function () {
    
    // User Profile
    Route::post('/logout', [AuthController::class, 'logout']);
    Route::get('/user', [AuthController::class, 'user']);
    
    // Settings & Terminal (Bab Tambahan)
    Route::post('/settings/update-account', [SettingsController::class, 'updateAccount']);
    Route::post('/settings/update-env', [SettingsController::class, 'updateEnv']);
    Route::post('/terminal/execute', [TerminalController::class, 'execute']);

    // Host Server Hardware Monitoring (Bab 4, 8, 9.A)
    Route::get('/host-stats', [HostStatsController::class, 'index']);

    // Docker Containers via Portainer (Bab 2, 4, 6)
    Route::get('/containers', [PortainerController::class, 'index']);
    Route::post('/containers/{id}/{action}', [PortainerController::class, 'action'])
        ->where('action', 'start|stop|restart');

    // Nextcloud NAS SQL Backup Module (Bab 9.B)
    Route::get('/backups', [BackupController::class, 'index']);
    Route::post('/backups/run', [BackupController::class, 'run']);

    // Network Monitoring
    Route::get('/network-info', [NetworkController::class, 'index']);

    // App Launcher Shortcuts (Bab 4, 7)
    Route::apiResource('app-launchers', AppLauncherController::class);
});
