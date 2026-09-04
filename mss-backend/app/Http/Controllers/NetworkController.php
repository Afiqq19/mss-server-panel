<?php

namespace App\Http\Controllers;

use Illuminate\Http\JsonResponse;

class NetworkController extends Controller
{
    /**
     * GET /api/network-info
     */
    public function index(): JsonResponse
    {
        try {
            $data = [
                'public_ip'   => $this->getPublicIp(),
                'interfaces'  => $this->getNetworkInterfaces(),
                'listening'   => $this->getListeningPorts(),
                'dns'         => $this->getDnsServers(),
                'hostname'    => $this->getHostName(),
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

    private function getHostName(): string
    {
        // Prioritas 1: Baca langsung dari mount /host/proc
        $hostProc = config('services.server_monitor.proc_path', '/host/proc');
        $hostnameFile = rtrim($hostProc, '/') . '/sys/kernel/hostname';
        
        if (file_exists($hostnameFile) && is_readable($hostnameFile)) {
            $name = trim(file_get_contents($hostnameFile));
            if (!empty($name)) return $name;
        }

        // Prioritas 2: Jalankan command di host via Docker
        $hostName = $this->runHostCommand('hostname');
        if (!empty($hostName)) return $hostName;

        return gethostname();
    }

    private function getNetworkInterfaces(): array
    {
        $interfaces = [];
        $output = $this->runHostCommand('ip -j addr show');
        
        if (!$output) {
            $output = shell_exec('ip -j addr show 2>/dev/null');
        }

        if ($output) {
            $parsed = json_decode($output, true);
            if (is_array($parsed)) {
                foreach ($parsed as $iface) {
                    $name = $iface['ifname'] ?? 'unknown';
                    if (strpos($name, 'veth') === 0 || strpos($name, 'br-') === 0 || strpos($name, 'docker') === 0) continue; // Skip docker virtual interfaces
                    if ($name === 'lo') continue;

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
        
        return $interfaces;
    }

    private function getListeningPorts(): array
    {
        $ports = [];
        $output = $this->runHostCommand('ss -tlnp');
        
        if (!$output) {
            $output = shell_exec("ss -tlnp 2>/dev/null | tail -n +2");
        } else {
            $output = implode("\n", array_slice(explode("\n", $output), 1));
        }

        if ($output) {
            $lines = array_filter(explode("\n", trim($output)));
            foreach ($lines as $line) {
                $parts = preg_split('/\s+/', trim($line));
                if (count($parts) >= 5) {
                    $localAddr = $parts[3] ?? '';
                    $process   = $parts[5] ?? $parts[4] ?? '';

                    $port = '';
                    if (preg_match('/:(\d+)$/', $localAddr, $m)) {
                        $port = $m[1];
                    }

                    $procName = '';
                    if (preg_match('/users:\(\("([^"]+)"/', $process, $m)) {
                        $procName = $m[1];
                    }

                    $bindAddr = preg_replace('/:(\d+)$/', '', $localAddr);
                    if ($bindAddr === '*' || $bindAddr === '0.0.0.0' || $bindAddr === '[::]') {
                        $bindAddr = '0.0.0.0';
                    }

                    if ($port) {
                        $ports[] = [
                            'port'    => $port,
                            'bind'    => $bindAddr,
                            'process' => $procName,
                            'proto'   => 'TCP',
                        ];
                    }
                }
            }
        }

        usort($ports, fn($a, $b) => intval($a['port']) - intval($b['port']));
        return $ports;
    }

    private function getDnsServers(): array
    {
        $output = $this->runHostCommand('cat /etc/resolv.conf | grep nameserver | awk \'{print $2}\'');
        if (!$output) {
            $output = shell_exec("cat /etc/resolv.conf 2>/dev/null | grep nameserver | awk '{print $2}'");
        }
        
        $dns = [];
        if ($output) {
            $dns = array_filter(explode("\n", trim($output)));
        }
        return array_values($dns);
    }

    /**
     * Mengeksekusi command secara native di Host OS dengan meminjam akses Docker Socket
     * untuk spawn container sementara yang menggunakan Network Host.
     */
    private function runHostCommand(string $cmd): ?string
    {
        $socket = '/var/run/docker.sock';
        if (!file_exists($socket)) return null;

        $ch = curl_init("http://localhost/containers/create");
        curl_setopt($ch, CURLOPT_UNIX_SOCKET_PATH, $socket);
        curl_setopt($ch, CURLOPT_POST, true);
        curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
        curl_setopt($ch, CURLOPT_HTTPHEADER, ['Content-Type: application/json']);
        
        // Kita menggunakan image 'nginx:alpine' karena image ini dijamin ada
        // (dipakai oleh service mss-frontend)
        $payload = json_encode([
            'Image' => 'nginx:alpine',
            'Cmd' => ['sh', '-c', $cmd],
            'HostConfig' => [
                'NetworkMode' => 'host',
                'AutoRemove' => false,
                'Binds' => ['/etc/resolv.conf:/etc/resolv.conf:ro']
            ]
        ]);
        curl_setopt($ch, CURLOPT_POSTFIELDS, $payload);
        $response = curl_exec($ch);
        $code = curl_getinfo($ch, CURLINFO_HTTP_CODE);
        curl_close($ch);

        if ($code !== 201) return null;

        $container = json_decode($response, true);
        $id = $container['Id'] ?? null;
        if (!$id) return null;

        // Start
        $ch = curl_init("http://localhost/containers/$id/start");
        curl_setopt($ch, CURLOPT_UNIX_SOCKET_PATH, $socket);
        curl_setopt($ch, CURLOPT_POST, true);
        curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
        curl_exec($ch);
        curl_close($ch);

        // Wait
        $ch = curl_init("http://localhost/containers/$id/wait");
        curl_setopt($ch, CURLOPT_UNIX_SOCKET_PATH, $socket);
        curl_setopt($ch, CURLOPT_POST, true);
        curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
        curl_exec($ch);
        curl_close($ch);

        // Logs
        $ch = curl_init("http://localhost/containers/$id/logs?stdout=true&stderr=false");
        curl_setopt($ch, CURLOPT_UNIX_SOCKET_PATH, $socket);
        curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
        $logsRaw = curl_exec($ch);
        curl_close($ch);

        // Delete
        $ch = curl_init("http://localhost/containers/$id?v=true");
        curl_setopt($ch, CURLOPT_UNIX_SOCKET_PATH, $socket);
        curl_setopt($ch, CURLOPT_CUSTOMREQUEST, "DELETE");
        curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
        curl_exec($ch);
        curl_close($ch);

        return $this->stripDockerStreamHeader($logsRaw);
    }

    private function stripDockerStreamHeader($raw): string
    {
        if (empty($raw)) return '';
        $output = '';
        $offset = 0;
        $len = strlen($raw);
        while ($offset < $len) {
            if ($offset + 8 > $len) break;
            $header = substr($raw, $offset, 8);
            $size = unpack('N', substr($header, 4, 4))[1];
            $offset += 8;
            $output .= substr($raw, $offset, $size);
            $offset += $size;
        }
        return trim($output);
    }
}
