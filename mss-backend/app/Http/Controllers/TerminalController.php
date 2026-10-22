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

        // Proteksi Keamanan Zero-Trust: Cegah perintah destruktif, reverse shell, dan exploit berbahaya
        $dangerousPatterns = [
            '/\brm\s+-[a-zA-Z]*r[a-zA-Z]*f\s+[\/\*]/',               // rm -rf / atau rm -rf /*
            '/\bmkfs(\.[a-zA-Z0-9]+)?\b/i',                           // format hardisk/partisi
            '/:\(\)\s*\{\s*:\|:&\s*\};:/',                            // fork bomb
            '/\bdd\s+if=.*of=\/dev\/(sd[a-z]|nvme|loop|mapper)/i',   // raw disk overwrite
            '/\bchmod\s+(-R\s+)?(000|777)\s+\//',                    // lock out root / dangerous permissive
            '/\/dev\/tcp\/[0-9a-zA-Z\.\-_]+\/[0-9]+/i',              // bash reverse shell (/dev/tcp/...)
            '/\b(nc|netcat|ncat|socat)\b.*(-e|--exec|-c|\/bin\/(ba)?sh)/i', // netcat/socat reverse shell
            '/python[0-9]*\s+-c\s+[\'"].*socket.*pty\.spawn/i',        // python pty reverse shell
            '/perl\s+-e\s+[\'"].*Socket.*open\(STDIN/i',              // perl reverse shell
            '/base64\s+(-d|--decode)\s*\|\s*(sh|bash)/i',            // obfuscated base64 payload execution
            '/echo\s+[a-zA-Z0-9\+\/]{30,}={0,2}\s*\|\s*base64/i',    // base64 dropper
            '/\bcat\s+(\/etc\/shadow|\/etc\/gshadow)\b/',             // password hash exfiltration
            '/\/proc\/sysrq-trigger\b/',                              // intentional kernel crash trigger
        ];
        foreach ($dangerousPatterns as $pattern) {
            if (preg_match($pattern, $cmd)) {
                \Illuminate\Support\Facades\Log::critical("🚨 Serangan Cyber Terdeteksi: Perintah berbahaya diblokir: {$cmd} dari User ID: " . ($request->user()?->id ?? 'unknown'));
                return response()->json([
                    'status' => 'error',
                    'output' => '🛡️ Zero-Trust Defense Shield: Perintah ini diblokir secara otomatis oleh sistem keamanan MSS Panel demi mencegah eksploitasi cyber atau kerusakan sistem host.'
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
