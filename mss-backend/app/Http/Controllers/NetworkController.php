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
        return file_exists('/host/etc/hostname') 
            ? trim(file_get_contents('/host/etc/hostname')) 
            : gethostname();
    }

    private function getNetworkInterfaces(): array
    {
        $interfaces = [];
        $devFile = env('HOST_PROC_PATH', '/host/proc') . '/net/dev';
        
        if (file_exists($devFile) && is_readable($devFile)) {
            $lines = file($devFile, FILE_IGNORE_NEW_LINES | FILE_SKIP_EMPTY_LINES);
            foreach ($lines as $line) {
                if (strpos($line, ':') !== false) {
                    $parts = explode(':', $line, 2);
                    $name = trim($parts[0]);
                    
                    if (strpos($name, 'lo') === 0 || strpos($name, 'veth') === 0 || strpos($name, 'br-') === 0 || strpos($name, 'docker') === 0) continue;
                    
                    $interfaces[] = [
                        'name'  => $name,
                        'ip'    => 'Unknown', // Need more advanced parsing or ip command for IP/MAC
                        'mac'   => 'Unknown',
                        'state' => 'UP',
                    ];
                }
            }
        }
        
        return $interfaces;
    }

    private function getListeningPorts(): array
    {
        $ports = [];
        $tcpFile = env('HOST_PROC_PATH', '/host/proc') . '/net/tcp';
        
        if (file_exists($tcpFile) && is_readable($tcpFile)) {
            $lines = file($tcpFile, FILE_IGNORE_NEW_LINES | FILE_SKIP_EMPTY_LINES);
            array_shift($lines); // Skip header
            
            foreach ($lines as $line) {
                $line = trim($line);
                $parts = preg_split('/\s+/', $line);
                if (count($parts) >= 10) {
                    $localAddress = $parts[1];
                    $state = $parts[3];
                    
                    if ($state === '0A') { // 0A = TCP_LISTEN
                        list($ipHex, $portHex) = explode(':', $localAddress);
                        $port = hexdec($portHex);
                        
                        $ports[] = [
                            'port'    => $port,
                            'bind'    => 'Unknown',
                            'process' => 'Unknown',
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
        $resolv = file_exists('/host/etc/resolv.conf') 
            ? file_get_contents('/host/etc/resolv.conf') 
            : (file_exists('/etc/resolv.conf') ? file_get_contents('/etc/resolv.conf') : '');

        preg_match_all('/nameserver\s+([^\s]+)/', $resolv, $matches);
        return $matches[1] ?? ['8.8.8.8'];
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
