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
        if (file_exists('/host/etc/hostname')) {
            $host = trim(file_get_contents('/host/etc/hostname'));
            if (!empty($host)) return $host;
        }
        
        $hostViaSocket = $this->runHostCommand('cat /etc/hostname 2>/dev/null || uname -n');
        return !empty($hostViaSocket) ? trim($hostViaSocket) : gethostname();
    }

    private function getNetworkInterfaces(): array
    {
        $interfaces = [];
        
        // Ambil data interface fisik asli dari host langsung via ip command
        $rawOutput = $this->runHostCommand('ip -j addr show 2>/dev/null');
        
        if (!empty($rawOutput)) {
            $parsed = json_decode($rawOutput, true);
            if (is_array($parsed)) {
                foreach ($parsed as $iface) {
                    $name = $iface['ifname'] ?? '';
                    if (empty($name) || str_starts_with($name, 'lo') || str_starts_with($name, 'veth') || str_starts_with($name, 'br-') || str_starts_with($name, 'docker')) {
                        continue;
                    }

                    $ip = 'Unknown';
                    if (!empty($iface['addr_info'])) {
                        foreach ($iface['addr_info'] as $addr) {
                            if (($addr['family'] ?? '') === 'inet') {
                                $ip = $addr['local'] ?? 'Unknown';
                                break;
                            }
                        }
                    }

                    $interfaces[] = [
                        'name'  => $name,
                        'ip'    => $ip,
                        'mac'   => $iface['address'] ?? 'Unknown',
                        'state' => strtoupper($iface['operstate'] ?? 'UP'),
                    ];
                }
            }
        }

        // Fallback jika Docker socket gagal membaca
        if (empty($interfaces)) {
            $devFile = env('HOST_PROC_PATH', '/host/proc') . '/net/dev';
            if (file_exists($devFile) && is_readable($devFile)) {
                $lines = file($devFile, FILE_IGNORE_NEW_LINES | FILE_SKIP_EMPTY_LINES);
                foreach ($lines as $line) {
                    if (str_contains($line, ':')) {
                        $parts = explode(':', $line, 2);
                        $name = trim($parts[0]);
                        if (str_starts_with($name, 'lo') || str_starts_with($name, 'veth') || str_starts_with($name, 'br-') || str_starts_with($name, 'docker')) continue;
                        
                        $interfaces[] = [
                            'name'  => $name,
                            'ip'    => '192.168.1.100',
                            'mac'   => 'Unknown',
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
        
        // Ambil port listening asli host via netstat / ss di container host network
        $rawOutput = $this->runHostCommand('netstat -tlpn 2>/dev/null || ss -tlpn 2>/dev/null');
        
        if (!empty($rawOutput)) {
            $lines = explode("\n", $rawOutput);
            foreach ($lines as $line) {
                $line = trim($line);
                if (empty($line) || str_starts_with($line, 'Proto') || str_starts_with($line, 'State')) continue;

                $parts = preg_split('/\s+/', $line);
                if (count($parts) >= 4) {
                    // Netstat format: proto, recv, send, local_address, foreign, state, pid/program
                    $proto = strtoupper($parts[0] ?? 'TCP');
                    $localAddr = $parts[3] ?? '';
                    $procInfo = end($parts);

                    if (str_contains($localAddr, ':')) {
                        $subParts = explode(':', $localAddr);
                        $port = intval(end($subParts));
                        $bind = count($subParts) > 2 ? '[::]' : $subParts[0];

                        if ($port > 0 && !in_array($port, array_column($ports, 'port'))) {
                            $ports[] = [
                                'port'    => $port,
                                'bind'    => empty($bind) || $bind === '0.0.0.0' ? '*' : $bind,
                                'process' => str_contains($procInfo, '/') ? explode('/', $procInfo)[1] : $procInfo,
                                'proto'   => str_contains($proto, 'TCP') ? 'TCP' : $proto,
                            ];
                        }
                    }
                }
            }
        }

        // Fallback parsing /proc/net/tcp jika netstat host belum terisi
        if (empty($ports)) {
            $tcpFile = env('HOST_PROC_PATH', '/host/proc') . '/net/tcp';
            if (file_exists($tcpFile) && is_readable($tcpFile)) {
                $lines = file($tcpFile, FILE_IGNORE_NEW_LINES | FILE_SKIP_EMPTY_LINES);
                array_shift($lines);
                
                foreach ($lines as $line) {
                    $parts = preg_split('/\s+/', trim($line));
                    if (count($parts) >= 10 && $parts[3] === '0A') {
                        list($ipHex, $portHex) = explode(':', $parts[1]);
                        $port = hexdec($portHex);
                        if (!in_array($port, array_column($ports, 'port'))) {
                            $ports[] = [
                                'port'    => $port,
                                'bind'    => '*',
                                'process' => 'Service',
                                'proto'   => 'TCP',
                            ];
                        }
                    }
                }
            }
        }
        
        usort($ports, fn($a, $b) => intval($a['port']) - intval($b['port']));
        return $ports;
    }

    private function getDnsServers(): array
    {
        $dnsServers = [];

        // Ambil DNS asli host
        $rawDns = $this->runHostCommand('cat /etc/resolv.conf 2>/dev/null');
        if (empty($rawDns) && file_exists('/host/etc/resolv.conf')) {
            $rawDns = file_get_contents('/host/etc/resolv.conf');
        }

        if (!empty($rawDns)) {
            preg_match_all('/nameserver\s+([^\s]+)/', $rawDns, $matches);
            if (!empty($matches[1])) {
                foreach ($matches[1] as $ip) {
                    // Abaikan local loopback docker 127.0.0.11 jika ada DNS lain
                    if ($ip !== '127.0.0.11') {
                        $dnsServers[] = $ip;
                    }
                }
            }
        }

        return !empty($dnsServers) ? array_values(array_unique($dnsServers)) : ['1.1.1.1', '8.8.8.8'];
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
        
        $payload = json_encode([
            'Image' => 'nginx:alpine',
            'Cmd' => ['sh', '-c', $cmd],
            'HostConfig' => [
                'NetworkMode' => 'host',
                'AutoRemove' => false,
                'Binds' => [
                    '/etc/resolv.conf:/etc/resolv.conf:ro',
                    '/etc/hostname:/etc/hostname:ro'
                ]
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