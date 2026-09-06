<?php

use App\Http\Controllers\AppLauncherController;
use App\Http\Controllers\AuthController;
use App\Http\Controllers\BackupController;
use App\Http\Controllers\DeployController;
use App\Http\Controllers\HostStatsController;
use App\Http\Controllers\MaintenanceController;
use App\Http\Controllers\NetworkController;
use App\Http\Controllers\PortainerController;
use App\Http\Controllers\SettingsController;
use App\Http\Controllers\TerminalController;
use App\Http\Controllers\SecurityController;
use App\Http\Controllers\ServiceController;
use App\Http\Controllers\LogController;
use App\Http\Controllers\CronController;
use App\Http\Controllers\AppInstallerController;
use App\Http\Controllers\DatabaseController;
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
Route::middleware('throttle:5,1')->post('/login', [AuthController::class, 'login']);
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
    Route::get('/containers/{id}/logs', [PortainerController::class, 'logs']);

    // Nextcloud NAS SQL Backup Module (Bab 9.B)
    Route::get('/backups', [BackupController::class, 'index']);
    Route::post('/backups/run', [BackupController::class, 'run']);

    // Network Monitoring
    Route::get('/network-info', [NetworkController::class, 'index']);

    // App Launcher Shortcuts (Bab 4, 7)
    Route::apiResource('app-launchers', AppLauncherController::class);

    // System Maintenance & Cleaner
    Route::get('/maintenance', [MaintenanceController::class, 'index']);
    Route::post('/maintenance/execute', [MaintenanceController::class, 'execute']);

    // Security & Firewall (Phase 2)
    Route::get('/security/ufw', [SecurityController::class, 'getUfwStatus']);
    Route::post('/security/ufw/toggle', [SecurityController::class, 'toggleUfw']);
    Route::post('/security/ufw/port', [SecurityController::class, 'managePort']);

    // Services & Top Processes (Phase 3)
    Route::get('/services', [ServiceController::class, 'index']);
    Route::post('/services/action', [ServiceController::class, 'action']);
    Route::get('/services/top', [ServiceController::class, 'topProcesses']);

    // Logs Viewer (Phase 3)
    Route::get('/logs', [LogController::class, 'getLogs']);

    // Cron Jobs (Phase 4)
    Route::get('/cron', [CronController::class, 'index']);
    Route::post('/cron', [CronController::class, 'addCron']);
    Route::post('/cron/delete', [CronController::class, 'deleteCron']);

    // App Installer (Phase 4)
    Route::get('/installer/apps', [AppInstallerController::class, 'listApps']);
    Route::post('/installer/install', [AppInstallerController::class, 'installApp']);

    // Database Manager (v1.1.0)
    Route::get('/database', [DatabaseController::class, 'getDatabases']);
    Route::post('/database/create', [DatabaseController::class, 'createDatabase']);
    Route::get('/database/tables', [DatabaseController::class, 'getTables']);
    Route::get('/database/rows', [DatabaseController::class, 'getTableRows']);
    Route::post('/database/query', [DatabaseController::class, 'executeRawQuery']);
    Route::get('/database/export', [DatabaseController::class, 'exportDatabase']);
});
