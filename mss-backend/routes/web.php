<?php

use Illuminate\Support\Facades\Route;

Route::get('/', function () {
    if (file_exists(public_path('index.html'))) {
        return response()->file(public_path('index.html'));
    }
    return view('welcome');
});

// ============================================================
// AUTO DEPLOY WEBHOOK (VERSI MEPAL SERVER)
// ============================================================
Route::get('/update-rahasia-panel', function () {
    $repoDir = base_path('..');
    if (!file_exists($repoDir . '/.git')) {
        $repoDir = base_path(); // Fallback jika clone langsung mss-backend
    }

    // 1. AUTO-PATCH .env untuk konfigurasi server
    $envFile = base_path('.env');
    if (file_exists($envFile)) {
        $env = file_get_contents($envFile);
        $env = preg_replace('/^APP_URL=.*/m', 'APP_URL=https://panel.xie.my.id', $env);
        $env = preg_replace('/^APP_TIMEZONE=.*/m', 'APP_TIMEZONE=Asia/Jakarta', $env);
        if (!str_contains($env, 'APP_TIMEZONE=')) {
            $env .= "\nAPP_TIMEZONE=Asia/Jakarta\n";
        }
        file_put_contents($envFile, $env);
    }

    // 2. Mengatasi isu kepemilikan git di Linux/Docker
    shell_exec("git config --global --add safe.directory \"$repoDir\"");

    // 3. Tarik update kode terbaru
    $output1 = shell_exec("cd \"$repoDir\" && git fetch --all 2>&1");
    $output2 = shell_exec("cd \"$repoDir\" && git reset --hard origin/main 2>&1");

    // 4. Update dependencies dan database Laravel
    $output3 = shell_exec("cd \"" . base_path() . "\" && composer install --no-interaction --prefer-dist --optimize-autoloader 2>&1");
    $output4 = shell_exec("cd \"" . base_path() . "\" && php artisan migrate --force 2>&1");
    $output_clear = shell_exec("cd \"" . base_path() . "\" && php artisan optimize:clear 2>&1");

    return "<h1 style='color:green;'>Berhasil Menarik Kodingan Baru & Update Mepal!</h1>
            <h3>Laporan Log:</h3>
            <pre style='background:#1e1e1e;color:#00ff66;padding:20px;border-radius:10px;font-family:monospace;'>
[GIT FETCH & RESET]
" . htmlspecialchars((string) $output1) . "
" . htmlspecialchars((string) $output2) . "

[COMPOSER INSTALL]
" . htmlspecialchars((string) $output3) . "

[DATABASE MIGRATE]
" . htmlspecialchars((string) $output4) . "

[OPTIMIZE CLEAR]
" . htmlspecialchars((string) $output_clear) . "
            </pre>";
});
