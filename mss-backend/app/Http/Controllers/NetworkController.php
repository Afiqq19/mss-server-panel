<?php

namespace App\Http\Controllers;

use Illuminate\Http\JsonResponse;

class NetworkController extends Controller
{
    /**
     * GET /api/network-info
     * Menampilkan informasi jaringan server (IP, interfaces, port listening)
     */
    public function index(): JsonResponse
    {
        try {
            $data = [
                'public_ip'   => $this->getPublicIp(),
                'interfaces'  => $this->getNetworkInterfaces(),
                'listening'   => $this->getListeningPorts(),
                'dns'         => $this->getDnsServers(),
                'hostname'    => gethostname(),
            ];

            return response()->json([
                'status' => 'success',
                'data'   => $data,
            ]);
        } catch (\Exception $e) {
            return response()->json([
                'status'  => 'error',
                'message' => 'Gagal mengambil data jaringan: ' . $e->getMessage(),
            ], 500);
        }
    }

    private function getPublicIp(): string
    {
        try {
            $ip = @file_get_contents('https://api.ipify.org?format=text');
            return $ip ?: 'N/A';
        } catch (\Exception $e) {
            return 'N/A';
        }
    }

    private function getNetworkInterfaces(): array
    {
        $interfaces = [];

        // Parse output dari `ip -j addr show`
        $output = shell_exec('ip -j addr show 2>/dev/null');
        if ($output) {
            $parsed = json_decode($output, true);
            if (is_array($parsed)) {
                foreach ($parsed as $iface) {
                    $name = $iface['ifname'] ?? 'unknown';
                    if ($name === 'lo') continue; // Skip loopback

                    $ipv4 = '';
                    $mac  = $iface['address'] ?? '';
                    $state = $iface['operstate'] ?? 'UNKNOWN';

                    if (isset($iface['addr_info'])) {
                        foreach ($iface['addr_info'] as $addr) {
                            if (($addr['family'] ?? '') === 'inet') {
                                $ipv4 = $addr['local'] ?? '';
                                break;
                            }
                        }
                    }

                    $interfaces[] = [
                        'name'  => $name,
                        'ip'    => $ipv4,
                        'mac'   => $mac,
                        'state' => $state,
                    ];
                }
            }
        }

        // Fallback jika `ip -j` tidak tersedia
        if (empty($interfaces)) {
            $output = shell_exec("ip -4 addr show 2>/dev/null | grep -E 'inet |state' | awk '{print $2}'");
            if ($output) {
                $lines = array_filter(explode("\n", trim($output)));
                foreach ($lines as $line) {
                    if (strpos($line, '/') !== false) {
                        $interfaces[] = [
                            'name'  => 'eth0',
                            'ip'    => explode('/', $line)[0],
                            'mac'   => '',
                            'state' => 'UP',
                        ];
                    }
                }
            }
        }

        return $interfaces;
    }

    private function getListeningPorts(): array
    {
        $ports = [];

        $output = shell_exec("ss -tlnp 2>/dev/null | tail -n +2");
        if ($output) {
            $lines = array_filter(explode("\n", trim($output)));
            foreach ($lines as $line) {
                $parts = preg_split('/\s+/', trim($line));
                if (count($parts) >= 5) {
                    $localAddr = $parts[3] ?? '';
                    $process   = $parts[5] ?? $parts[4] ?? '';

                    // Extract port number
                    $port = '';
                    if (preg_match('/:(\d+)$/', $localAddr, $m)) {
                        $port = $m[1];
                    }

                    // Extract process name
                    $procName = '';
                    if (preg_match('/users:\(\("([^"]+)"/', $process, $m)) {
                        $procName = $m[1];
                    }

                    // Extract bind address
                    $bindAddr = preg_replace('/:(\d+)$/', '', $localAddr);
                    if ($bindAddr === '*' || $bindAddr === '0.0.0.0' || $bindAddr === '[::]') {
                        $bindAddr = '0.0.0.0';
                    }

                    $ports[] = [
                        'port'    => $port,
                        'bind'    => $bindAddr,
                        'process' => $procName,
                        'proto'   => 'TCP',
                    ];
                }
            }
        }

        // Sort by port number
        usort($ports, fn($a, $b) => intval($a['port']) - intval($b['port']));

        return $ports;
    }

    private function getDnsServers(): array
    {
        $dns = [];
        $output = shell_exec("cat /etc/resolv.conf 2>/dev/null | grep nameserver | awk '{print $2}'");
        if ($output) {
            $dns = array_filter(explode("\n", trim($output)));
        }
        return array_values($dns);
    }
}
