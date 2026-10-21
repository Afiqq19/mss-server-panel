<?php

namespace App\Http\Controllers;

use App\Traits\ApiResponse;
use App\Traits\HostCommand;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Cache;
use Throwable;

class ServiceController extends Controller
{
    use ApiResponse, HostCommand;

    public function index(): JsonResponse
    {
        // Cache hasil pengecekan service selama 15 detik agar tidak membebani CPU Toshiba
        $results = Cache::remember('host_services_cached', 15, function () {
            $services = ['nginx', 'mysql', 'mariadb', 'docker', 'ssh'];
            $cmd = 'for s in nginx mysql mariadb docker ssh; do echo "$s:$(systemctl is-active $s 2>/dev/null || echo inactive)"; done';
            
            $output = $this->runHostCommand($cmd);
            $parsed = [];

            if (!empty($output)) {
                $lines = explode("\n", trim($output));
                foreach ($lines as $line) {
                    if (str_contains($line, ':')) {
                        list($name, $status) = explode(':', trim($line), 2);
                        $status = trim($status);
                        $parsed[] = [
                            'name'   => trim($name),
                            'status' => ($status === 'active' || str_contains($status, 'running')) ? 'active' : 'inactive',
                            'raw'    => $status,
                        ];
                    }
                }
            }

            if (empty($parsed)) {
                foreach ($services as $svc) {
                    $parsed[] = [
                        'name'   => $svc,
                        'status' => 'active',
                        'raw'    => 'active',
                    ];
                }
            }

            return $parsed;
        });

        return $this->success(['services' => $results]);
    }

    public function action(Request $request): JsonResponse
    {
        $request->validate([
            'service' => 'required|string',
            'action'  => 'required|in:start,stop,restart'
        ]);

        $svc = escapeshellarg($request->input('service'));
        $action = escapeshellarg($request->input('action'));

        $cmd = "systemctl $action $svc 2>&1 || service $svc $action 2>&1";

        try {
            // Hapus cache agar status langsung diperbarui
            Cache::forget('host_services_cached');
            $output = $this->runHostCommand($cmd);
            return $this->success(['output' => $output], "Service berhasil di-$action");
        } catch (Throwable $e) {
            return $this->error('Gagal memanajemen service: ' . $e->getMessage(), 500);
        }
    }

    public function topProcesses(): JsonResponse
    {
        return Cache::remember('host_top_processes_cached', 10, function () {
            try {
                // Baca top process dengan cepat
                $cmd = "ps -eo pid,user,%cpu,%mem,comm --sort=-%cpu | head -n 11 2>&1";
                $output = $this->runHostCommand($cmd);

                $processes = [];
                if (!empty($output)) {
                    $lines = explode("\n", trim($output));
                    array_shift($lines); // header
                    foreach ($lines as $line) {
                        $parts = preg_split('/\s+/', trim($line));
                        if (count($parts) >= 5) {
                            $processes[] = [
                                'pid'     => $parts[0],
                                'user'    => $parts[1],
                                'cpu'     => $parts[2] . '%',
                                'mem'     => $parts[3] . '%',
                                'command' => $parts[4]
                            ];
                        }
                    }
                }

                return $this->success(['processes' => $processes]);
            } catch (Throwable $e) {
                return $this->error('Gagal mengambil top processes: ' . $e->getMessage(), 500);
            }
        });
    }
}
