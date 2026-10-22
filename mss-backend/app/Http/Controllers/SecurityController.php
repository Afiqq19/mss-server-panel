<?php

namespace App\Http\Controllers;

use App\Traits\ApiResponse;
use App\Traits\HostCommand;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Throwable;

class SecurityController extends Controller
{
    use ApiResponse, HostCommand;

    public function getUfwStatus(): JsonResponse
    {
        try {
            $data = \Illuminate\Support\Facades\Cache::remember('host_ufw_status', 15, function () {
                $output = $this->runHostCommand('ufw status numbered 2>&1');
                
                if ($output === null) {
                    return [
                        'is_active' => true,
                        'rules' => [],
                        'raw_output' => 'UFW Active'
                    ];
                }

                $isActive = strpos(strtolower($output), 'status: active') !== false;
                $rules = [];
                if ($isActive) {
                    $lines = explode("\n", $output);
                    foreach ($lines as $line) {
                        if (preg_match('/\[\s*(\d+)\]\s+(\S+)\s+(ALLOW IN|DENY IN|ALLOW|DENY)\s+(.*)/', $line, $matches)) {
                            $rules[] = [
                                'id' => $matches[1],
                                'port' => $matches[2],
                                'action' => $matches[3],
                                'from' => $matches[4],
                            ];
                        }
                    }
                }

                return [
                    'is_active' => $isActive,
                    'rules' => $rules,
                    'raw_output' => $output
                ];
            });

            return $this->success($data);
        } catch (Throwable $e) {
            return $this->error('Gagal membaca status UFW: ' . $e->getMessage(), 500);
        }
    }

    public function toggleUfw(Request $request): JsonResponse
    {
        $request->validate([
            'action' => 'required|in:enable,disable'
        ]);

        $action = $request->input('action');
        $cmd = $action === 'enable' ? 'echo y | ufw enable 2>&1' : 'ufw disable 2>&1';

        try {
            $output = $this->runHostCommand($cmd);
            if (strpos(strtolower((string)$output), 'not found') !== false) {
                return $this->error('UFW tidak terinstall di sistem host.', 400);
            }
            return $this->success(['output' => $output], "UFW berhasil di-$action");
        } catch (Throwable $e) {
            return $this->error('Gagal mengubah status UFW: ' . $e->getMessage(), 500);
        }
    }

    public function managePort(Request $request): JsonResponse
    {
        $request->validate([
            'port' => [
                'required',
                'string',
                'regex:/^[0-9]{1,5}(:[0-9]{1,5})?$/', // hanya izinkan angka port 1-65535 atau rentang port (contoh: 8000:8010)
            ],
            'protocol' => 'nullable|in:tcp,udp',
            'action' => 'required|in:allow,deny,delete'
        ]);

        $cleanPort = preg_replace('/[^0-9:]/', '', (string)$request->input('port'));
        $proto = $request->input('protocol') ? '/' . $request->input('protocol') : '';
        $action = $request->input('action');
        
        $cmd = "";
        if ($action === 'delete') {
            // Delete by ID (port input is actually the rule ID here)
            $cmd = "echo y | ufw delete " . escapeshellarg($cleanPort) . " 2>&1";
        } else {
            // Allow or Deny
            $cmd = "ufw $action " . escapeshellarg($cleanPort . $proto) . " 2>&1";
        }

        try {
            \Illuminate\Support\Facades\Cache::forget('host_ufw_status');
            $output = $this->runHostCommand($cmd);
            if (strpos(strtolower((string)$output), 'not found') !== false) {
                return $this->error('UFW tidak terinstall di sistem host.', 400);
            }
            return $this->success(['output' => $output], "Aturan port berhasil diupdate");
        } catch (Throwable $e) {
            return $this->error('Gagal memodifikasi port: ' . $e->getMessage(), 500);
        }
    }
}
