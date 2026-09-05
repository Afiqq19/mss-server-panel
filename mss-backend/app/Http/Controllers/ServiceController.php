<?php

namespace App\Http\Controllers;

use App\Traits\ApiResponse;
use App\Traits\HostCommand;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Throwable;

class ServiceController extends Controller
{
    use ApiResponse, HostCommand;

    public function index(): JsonResponse
    {
        $services = ['nginx', 'mysql', 'docker', 'ssh', 'php8.2-fpm'];
        $results = [];

        foreach ($services as $svc) {
            $cmd = "systemctl is-active $svc 2>&1";
            $status = trim((string)$this->runHostCommand($cmd));
            
            // if systemctl doesn't exist, try service command
            if (strpos(strtolower($status), 'not found') !== false) {
                $cmd = "service $svc status 2>&1";
                $statusFull = trim((string)$this->runHostCommand($cmd));
                $isActive = strpos(strtolower($statusFull), 'is running') !== false || strpos(strtolower($statusFull), 'active (running)') !== false;
                $status = $isActive ? 'active' : 'inactive';
            }

            $results[] = [
                'name' => $svc,
                'status' => $status === 'active' ? 'active' : 'inactive',
                'raw' => $status
            ];
        }

        return $this->success(['services' => $results]);
    }

    public function action(Request $request): JsonResponse
    {
        $request->validate([
            'service' => 'required|string',
            'action' => 'required|in:start,stop,restart'
        ]);

        $svc = escapeshellarg($request->input('service'));
        $action = escapeshellarg($request->input('action'));

        $cmd = "systemctl $action $svc 2>&1 || service $svc $action 2>&1";

        try {
            $output = $this->runHostCommand($cmd);
            return $this->success(['output' => $output], "Service berhasil di-$action");
        } catch (Throwable $e) {
            return $this->error('Gagal memanajemen service: ' . $e->getMessage(), 500);
        }
    }

    public function topProcesses(): JsonResponse
    {
        try {
            // Get top 15 processes by CPU usage
            $cmd = "ps -eo pid,user,%cpu,%mem,comm --sort=-%cpu | head -n 16 2>&1";
            $output = $this->runHostCommand($cmd);

            $processes = [];
            $lines = explode("\n", trim((string)$output));
            array_shift($lines); // remove header

            foreach ($lines as $line) {
                $parts = preg_split('/\s+/', trim($line));
                if (count($parts) >= 5) {
                    $processes[] = [
                        'pid' => $parts[0],
                        'user' => $parts[1],
                        'cpu' => $parts[2],
                        'mem' => $parts[3],
                        'command' => $parts[4]
                    ];
                }
            }

            return $this->success(['processes' => $processes]);
        } catch (Throwable $e) {
            return $this->error('Gagal membaca process: ' . $e->getMessage(), 500);
        }
    }
}
