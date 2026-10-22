<?php

namespace App\Traits;

trait HostCommand
{
    /**
     * Eksekusi perintah secara langsung di Host OS (laptop Toshiba) 
     * melalui Docker Socket & chroot host filesystem.
     */
    protected function runHostCommand(string $cmd): ?string
    {
        $socket = '/var/run/docker.sock';
        if (!file_exists($socket)) {
            // Fallback jika dijalankan di lokal Windows saat development
            return shell_exec($cmd . ' 2>&1');
        }

        // 1. Cepat: Coba eksekusi langsung via container mss-ttyd yang sedang berjalan (20ms vs 3000ms)
        $fastOutput = $this->execViaRunningTtyd($socket, $cmd);
        if ($fastOutput !== null) {
            return $fastOutput;
        }

        // 2. Fallback: Buat temporary task container jika mss-ttyd offline
        $images = ['nginx:alpine', 'tsl0922/ttyd:latest', 'alpine:latest'];
        $containerId = null;

        foreach ($images as $image) {
            $containerId = $this->createHostTaskContainer($socket, $image, $cmd);
            if ($containerId) break;
        }

        if (!$containerId) {
            return shell_exec($cmd . ' 2>&1');
        }

        // 1. Jalankan kontainer
        $this->dockerSocketRequest($socket, "/containers/$containerId/start", 'POST');

        // 2. Tunggu eksekusi selesai (maksimal timeout 180 detik untuk proses berat seperti docker pull)
        $this->dockerSocketRequest($socket, "/containers/$containerId/wait", 'POST', null, 180);

        // 3. Ambil log hasil output
        $rawLogs = $this->dockerSocketRequest($socket, "/containers/$containerId/logs?stdout=true&stderr=true", 'GET');

        // 4. Hapus kontainer sementara agar disk tidak penuh
        $this->dockerSocketRequest($socket, "/containers/$containerId?v=true&force=true", 'DELETE');

        return $this->stripDockerStreamHeader($rawLogs ?? '');
    }

    /**
     * Eksekusi ultra-cepat (20ms) memanfaatkan container mss-ttyd yang sudah berjalan dengan privileged & pid host
     */
    private function execViaRunningTtyd(string $socket, string $cmd): ?string
    {
        try {
            $ch = curl_init("http://localhost/containers/mss-ttyd/json");
            curl_setopt($ch, CURLOPT_UNIX_SOCKET_PATH, $socket);
            curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
            curl_setopt($ch, CURLOPT_TIMEOUT, 2);
            $res = curl_exec($ch);
            $code = curl_getinfo($ch, CURLINFO_HTTP_CODE);
            curl_close($ch);

            if ($code !== 200 || empty($res)) {
                return null;
            }

            $info = json_decode($res, true);
            if (!isset($info['State']['Running']) || $info['State']['Running'] !== true) {
                return null;
            }

            $payload = json_encode([
                'AttachStdout' => true,
                'AttachStderr' => true,
                'Tty' => false,
                'Cmd' => ['nsenter', '-t', '1', '-m', '-u', '-i', '-n', '-p', 'sh', '-c', "PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin " . $cmd]
            ]);

            $ch = curl_init("http://localhost/containers/mss-ttyd/exec");
            curl_setopt($ch, CURLOPT_UNIX_SOCKET_PATH, $socket);
            curl_setopt($ch, CURLOPT_POST, true);
            curl_setopt($ch, CURLOPT_POSTFIELDS, $payload);
            curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
            curl_setopt($ch, CURLOPT_TIMEOUT, 5);
            curl_setopt($ch, CURLOPT_HTTPHEADER, ['Content-Type: application/json']);
            $execRes = curl_exec($ch);
            $execCode = curl_getinfo($ch, CURLINFO_HTTP_CODE);
            curl_close($ch);

            if ($execCode !== 201 || empty($execRes)) {
                return null;
            }

            $execData = json_decode($execRes, true);
            $execId = $execData['Id'] ?? null;
            if (!$execId) {
                return null;
            }

            $startPayload = json_encode(['Detach' => false, 'Tty' => false]);
            $ch = curl_init("http://localhost/exec/{$execId}/start");
            curl_setopt($ch, CURLOPT_UNIX_SOCKET_PATH, $socket);
            curl_setopt($ch, CURLOPT_POST, true);
            curl_setopt($ch, CURLOPT_POSTFIELDS, $startPayload);
            curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
            curl_setopt($ch, CURLOPT_TIMEOUT, 60);
            curl_setopt($ch, CURLOPT_HTTPHEADER, ['Content-Type: application/json']);
            $output = curl_exec($ch);
            curl_close($ch);

            if ($output === false || $output === null) {
                return null;
            }

            return $this->stripDockerStreamHeader($output);
        } catch (\Throwable $e) {
            return null;
        }
    }

    /**
     * Membuat container worker sementara dengan akses penuh ke host
     */
    private function createHostTaskContainer(string $socket, string $image, string $cmd): ?string
    {
        $payload = json_encode([
            'Image' => $image,
            'Cmd' => [
                'sh', '-c',
                "chroot /host_fs /usr/bin/env PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin sh -c " . escapeshellarg($cmd)
            ],
            'HostConfig' => [
                'NetworkMode' => 'host',
                'Privileged'  => true,
                'AutoRemove'   => false,
                'Binds'       => [
                    '/:/host_fs'
                ]
            ]
        ]);

        $ch = curl_init("http://localhost/containers/create");
        curl_setopt($ch, CURLOPT_UNIX_SOCKET_PATH, $socket);
        curl_setopt($ch, CURLOPT_POST, true);
        curl_setopt($ch, CURLOPT_POSTFIELDS, $payload);
        curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
        curl_setopt($ch, CURLOPT_HTTPHEADER, ['Content-Type: application/json']);
        
        $response = curl_exec($ch);
        $code = curl_getinfo($ch, CURLINFO_HTTP_CODE);
        curl_close($ch);

        if ($code === 201) {
            $data = json_decode($response, true);
            return $data['Id'] ?? null;
        }

        return null;
    }

    /**
     * Helper universal curl ke Docker Socket
     */
    private function dockerSocketRequest(string $socket, string $endpoint, string $method = 'GET', ?array $payload = null, int $timeout = 10): ?string
    {
        $ch = curl_init("http://localhost" . $endpoint);
        curl_setopt($ch, CURLOPT_UNIX_SOCKET_PATH, $socket);
        curl_setopt($ch, CURLOPT_CUSTOMREQUEST, $method);
        curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
        curl_setopt($ch, CURLOPT_TIMEOUT, $timeout);

        if ($payload) {
            curl_setopt($ch, CURLOPT_POSTFIELDS, json_encode($payload));
            curl_setopt($ch, CURLOPT_HTTPHEADER, ['Content-Type: application/json']);
        }

        $res = curl_exec($ch);
        curl_close($ch);
        return $res ?: null;
    }

    /**
     * Menghapus 8-byte Docker stream multiplexing header dari output logs
     */
    private function stripDockerStreamHeader(string $raw): string
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