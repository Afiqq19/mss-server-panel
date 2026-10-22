<?php

namespace App\Http\Controllers;

use Illuminate\Http\Request;
use Illuminate\Http\JsonResponse;
use App\Traits\HostCommand;

class TerminalController extends Controller
{
    use HostCommand;

    /**
     * POST /api/terminal/execute
     * Menjalankan perintah bash di Host OS menggunakan akses Docker Socket
     */
    public function execute(Request $request): JsonResponse
    {
        $request->validate([
            'command' => 'required|string',
        ]);

        $cmd = $request->input('command');

        // Bantuan untuk command 'cd' (karena stateless, cd tidak akan mengubah directory antar request)
        if (preg_match('/^cd\s+/', $cmd) && strpos($cmd, '&&') === false && strpos($cmd, ';') === false) {
            return response()->json([
                'status' => 'success',
                'output' => "Terminal ini berstatus stateless.\nUntuk pindah direktori, gunakan 'cd /path && perintah', contoh:\ncd /var/www && ls -la"
            ]);
        }

        // Proteksi Keamanan Zero-Trust: Cegah perintah destruktif yang dapat merusak OS host
        $dangerousPatterns = [
            '/\brm\s+-[a-zA-Z]*r[a-zA-Z]*f\s+[\/\*]/', // rm -rf / atau rm -rf /*
            '/\bmkfs(\.[a-zA-Z0-9]+)?\b/i',             // format hardisk
            '/:\(\)\s*\{\s*:\|:&\s*\};:/',              // fork bomb
            '/\bdd\s+if=.*of=\/dev\/(sd[a-z]|nvme|loop)/i', // raw disk overwrite
            '/\bchmod\s+(-R\s+)?000\s+\//',             // lock out root permissions
        ];
        foreach ($dangerousPatterns as $pattern) {
            if (preg_match($pattern, $cmd)) {
                \Illuminate\Support\Facades\Log::critical("Percobaan eksekusi perintah berbahaya diblokir: {$cmd} dari User ID: " . ($request->user()?->id ?? 'unknown'));
                return response()->json([
                    'status' => 'error',
                    'output' => '🛡️ Proteksi Zero-Trust Aktif: Perintah ini diblokir secara otomatis demi mencegah kerusakan fatal pada sistem host.'
                ], 403);
            }
        }

        try {
            $output = $this->runHostCommand($cmd);
            
            return response()->json([
                'status' => 'success',
                'output' => $output ?? '',
            ]);
        } catch (\Exception $e) {
            return response()->json([
                'status' => 'error',
                'output' => 'Error eksekusi: ' . $e->getMessage(),
            ], 500);
        }
    }
}
