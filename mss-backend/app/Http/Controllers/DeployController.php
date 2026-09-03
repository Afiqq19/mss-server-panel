<?php

namespace App\Http\Controllers;

use Illuminate\Http\Request;

class DeployController extends Controller
{
    /**
     * Endpoint Webhook Auto-Deploy untuk menarik kodingan terbaru dari GitHub
     * URL: /update-rahasia-panel?key=kunci-rahasia-mepal-2026 atau /api/update-rahasia-panel?key=...
     */
    public function update(Request $request)
    {
        // 1. Validasi Kunci rahasia untuk keamanan
        $secretKey = env('DEPLOY_SECRET', 'kunci-rahasia-mepal-2026');
        $providedKey = $request->query('key', $request->input('key'));

        $wantsJson = ($request->wantsJson() || $request->isJson()) && !$request->acceptsHtml();

        if ($providedKey !== $secretKey) {
            if ($wantsJson) {
                return response()->json([
                    'status' => 'error',
                    'message' => 'Unauthorized / Kunci Rahasia Salah'
                ], 403);
            }

            return response("
                <div style='background:#0f172a; color:#f87171; font-family:system-ui,sans-serif; min-height:100vh; display:flex; align-items:center; justify-content:center; padding:20px;'>
                    <div style='max-width:500px; width:100%; background:#1e293b; border:1px solid #ef4444; border-radius:16px; padding:32px; text-align:center;'>
                        <div style='font-size:48px; margin-bottom:16px;'>🚫</div>
                        <h2 style='color:#f87171; margin:0 0 10px 0;'>Akses Ditolak / Kunci Salah</h2>
                        <p style='color:#94a3b8; font-size:14px; margin-bottom:20px;'>Kunci rahasia (?key=...) yang Anda masukkan tidak valid.</p>
                    </div>
                </div>
            ", 403)->header('Content-Type', 'text/html');
        }

        // 2. Deteksi direktori repositori Git (Docker container vs Host server)
        putenv('GIT_DISCOVERY_ACROSS_FILESYSTEM=1');
        shell_exec("git config --global --add safe.directory '*' 2>&1");

        $repoDir = '/var/www/project';
        if (!file_exists($repoDir . '/.git')) {
            if (file_exists('/var/www/html/.git')) {
                $repoDir = '/var/www/html';
            } elseif (file_exists(base_path('../.git'))) {
                $repoDir = base_path('..');
            } else {
                $repoDir = base_path();
            }
        }

        $appDir = file_exists('/var/www/html/artisan') ? '/var/www/html' : base_path();

        // 4. Tarik update terbaru dari GitHub
        $fetch = shell_exec("cd \"$repoDir\" && git fetch --all 2>&1");
        $gitOutput = shell_exec("cd \"$repoDir\" && git reset --hard origin/main 2>&1");

        // 5. Jalankan migrasi dan pembersihan cache Laravel
        $migrate = shell_exec("cd \"$appDir\" && php artisan migrate --force 2>&1");
        $optimize = shell_exec("cd \"$appDir\" && php artisan optimize:clear 2>&1");

        $timestamp = date('d M Y - H:i:s T');

        // Jika dipanggil via API atau curl, kembalikan JSON
        if ($wantsJson) {
            return response()->json([
                'status' => 'success',
                'message' => 'UPDATE SUKSES! Server Toshiba berhasil di-update dengan kodingan terbaru!',
                'timestamp' => $timestamp,
                'repo_directory' => $repoDir,
                'git_fetch' => trim((string)$fetch),
                'git' => trim((string)$gitOutput),
                'migrate' => trim((string)$migrate),
                'cache' => trim((string)$optimize)
            ]);
        }

        // Jika dibuka langsung di browser, tampilkan UI visual yang elegan & jelas
        $cleanGit = htmlspecialchars(trim((string)$gitOutput));
        $cleanMigrate = htmlspecialchars(trim((string)$migrate));
        $cleanCache = htmlspecialchars(trim((string)$optimize));

        return response("
        <!DOCTYPE html>
        <html lang='id'>
        <head>
            <meta charset='UTF-8'>
            <meta name='viewport' content='width=device-width, initial-scale=1.0'>
            <title>Update Mepal Berhasil</title>
            <style>
                * { box-sizing: border-box; margin:0; padding:0; }
                body { background:#030712; color:#f8fafc; font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',Roboto,Helvetica,Arial,sans-serif; padding:40px 20px; }
                .container { max-width: 750px; margin: 0 auto; }
                .card { background: #0f172a; border: 1px solid #10b981; border-radius: 16px; padding: 28px; box-shadow: 0 20px 40px rgba(0,0,0,0.5); }
                .header { display: flex; align-items: center; gap: 16px; margin-bottom: 24px; }
                .badge-icon { width: 52px; height: 52px; background: rgba(16, 185, 129, 0.15); border: 2px solid #10b981; border-radius: 50%; display: flex; align-items: center; justify-content: center; font-size: 26px; }
                .title { font-size: 22px; font-weight: 700; color: #10b981; }
                .subtitle { font-size: 13px; color: #94a3b8; margin-top: 4px; }
                .terminal { background: #020617; border: 1px solid #1e293b; border-radius: 12px; padding: 18px; font-family: 'Consolas', 'Courier New', monospace; font-size: 13px; color: #38bdf8; overflow-x: auto; margin-bottom: 20px; line-height: 1.6; }
                .section-title { font-weight: bold; color: #06b6d4; margin-top: 10px; margin-bottom: 4px; }
                .btn { display: inline-block; background: #10b981; color: #020617; font-weight: bold; text-decoration: none; padding: 12px 24px; border-radius: 10px; transition: 0.2s; }
                .btn:hover { background: #34d399; }
                .footer { margin-top: 20px; text-align: center; color: #64748b; font-size: 12px; }
            </style>
        </head>
        <body>
            <div class='container'>
                <div class='card'>
                    <div class='header'>
                        <div class='badge-icon'>✅</div>
                        <div>
                            <div class='title'>UPDATE MEPAL SELESAI & SUKSES!</div>
                            <div class='subtitle'>Waktu: {$timestamp} • Server Laptop Toshiba</div>
                        </div>
                    </div>

                    <div class='terminal'>
                        <div class='section-title'>[1/3] GIT PULL TERBARU:</div>
                        {$cleanGit}

                        <div class='section-title'>[2/3] MIGRASI DATABASE:</div>
                        {$cleanMigrate}

                        <div class='section-title'>[3/3] BERSIHKAN CACHE & OPTIMASI:</div>
                        {$cleanCache}
                    </div>

                    <div style='display:flex; justify-content:space-between; align-items:center;'>
                        <a href='/' class='btn'>🚀 Buka Dashboard Panel</a>
                        <span style='color:#10b981; font-weight:bold; font-size:13px;'>Status: Siap Melayani 🟢</span>
                    </div>
                </div>
                <div class='footer'>MSS Server Panel (Mepal) • Auto-Deploy Webhook</div>
            </div>
        </body>
        </html>
        ")->header('Content-Type', 'text/html');
    }
}
