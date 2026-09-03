<?php

namespace App\Http\Controllers;

use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class DeployController extends Controller
{
    /**
     * Endpoint Webhook Auto-Deploy untuk menarik kodingan terbaru dari GitHub
     * URL: /api/deploy-update?key=kunci-rahasia-mepal-2026 atau /deploy-update?key=...
     */
    public function update(Request $request): JsonResponse
    {
        // 1. Validasi Kunci rahasia untuk keamanan
        $secretKey = env('DEPLOY_SECRET', 'kunci-rahasia-mepal-2026');
        $providedKey = $request->query('key', $request->input('key'));

        if ($providedKey !== $secretKey) {
            return response()->json([
                'status' => 'error',
                'message' => 'Unauthorized / Kunci Rahasia Salah'
            ], 403);
        }

        // 2. Deteksi direktori repositori Git (Docker container vs Host server)
        $repoDir = '/var/www/html';
        if (!file_exists($repoDir . '/.git')) {
            $parent = base_path('..');
            if (file_exists($parent . '/.git')) {
                $repoDir = $parent;
            } else {
                $repoDir = base_path();
            }
        }

        $appDir = file_exists('/var/www/html/artisan') ? '/var/www/html' : base_path();

        // 3. Mengatasi isu safe.directory di Linux/Docker
        shell_exec("git config --global --add safe.directory \"$repoDir\"");
        if ($appDir !== $repoDir) {
            shell_exec("git config --global --add safe.directory \"$appDir\"");
        }

        // 4. Tarik update terbaru dari GitHub
        $fetch = shell_exec("cd \"$repoDir\" && git fetch --all 2>&1");
        $gitOutput = shell_exec("cd \"$repoDir\" && git reset --hard origin/main 2>&1");

        // 5. Jalankan migrasi dan pembersihan cache Laravel
        $migrate = shell_exec("cd \"$appDir\" && php artisan migrate --force 2>&1");
        $optimize = shell_exec("cd \"$appDir\" && php artisan optimize:clear 2>&1");

        return response()->json([
            'status' => 'success',
            'message' => 'Server Toshiba berhasil di-update dengan kodingan terbaru!',
            'repo_directory' => $repoDir,
            'git_fetch' => trim((string)$fetch),
            'git' => trim((string)$gitOutput),
            'migrate' => trim((string)$migrate),
            'cache' => trim((string)$optimize)
        ]);
    }
}
