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
}
