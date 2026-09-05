<?php

namespace App\Http\Controllers;

use App\Traits\ApiResponse;
use App\Traits\HostCommand;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Throwable;

class LogController extends Controller
{
    use ApiResponse, HostCommand;

    public function getLogs(Request $request): JsonResponse
    {
        $request->validate([
            'type' => 'required|in:syslog,auth,nginx_access,nginx_error,docker'
        ]);

        $type = $request->input('type');
        $lines = (int)$request->input('lines', 100);

        $cmd = "";
        switch ($type) {
            case 'syslog':
                $cmd = "tail -n $lines /var/log/syslog 2>&1";
                break;
            case 'auth':
                $cmd = "tail -n $lines /var/log/auth.log 2>&1";
                break;
            case 'nginx_access':
                $cmd = "tail -n $lines /var/log/nginx/access.log 2>&1";
                break;
            case 'nginx_error':
                $cmd = "tail -n $lines /var/log/nginx/error.log 2>&1";
                break;
            case 'docker':
                $cmd = "journalctl -u docker --no-pager -n $lines 2>&1";
                break;
        }

        try {
            $output = $this->runHostCommand($cmd);
            if (strpos(strtolower((string)$output), 'no such file') !== false) {
                $output = "Log file not found on host.";
            }
            return $this->success(['logs' => $output]);
        } catch (Throwable $e) {
            return $this->error('Gagal membaca logs: ' . $e->getMessage(), 500);
        }
    }
}
