<?php

namespace App\Traits;

trait HostCommand
{
    /**
     * Spawn temporary container dengan mode Host Network dan akses volume host
     */
    protected function runHostCommand(string $cmd): ?string
    {
        $socket = '/var/run/docker.sock';
        if (!file_exists($socket)) {
            // Fallback jika tidak ada akses Docker (misal di local dev Windows)
            return shell_exec($cmd . ' 2>&1');
        }

        $ch = curl_init("http://localhost/containers/create");
        curl_setopt($ch, CURLOPT_UNIX_SOCKET_PATH, $socket);
        curl_setopt($ch, CURLOPT_POST, true);
        curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
        curl_setopt($ch, CURLOPT_HTTPHEADER, ['Content-Type: application/json']);
        
        // Kita bind mount seluruh filesystem host ke /host_fs agar bisa manipulasi file host
        $payload = json_encode([
            'Image' => 'alpine:latest',
            'Cmd' => ['sh', '-c', "chroot /host_fs sh -c " . escapeshellarg($cmd)],
            'HostConfig' => [
                'NetworkMode' => 'host',
                'AutoRemove' => false,
                'Binds' => [
                    '/:/host_fs'
                ]
            ]
        ]);
        
        curl_setopt($ch, CURLOPT_POSTFIELDS, $payload);
        $response = curl_exec($ch);
        $code = curl_getinfo($ch, CURLINFO_HTTP_CODE);
        curl_close($ch);

        if ($code !== 201) {
            // Jika alpine:latest tidak ada, fallback ke nginx:alpine tanpa chroot (karena nginx container nggak punya sh shell yang lengkap kadang)
            return $this->runHostCommandFallback($cmd, $socket);
        }

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

        // Wait (timeout 30 detik untuk menghindari hanging)
        $ch = curl_init("http://localhost/containers/$id/wait");
        curl_setopt($ch, CURLOPT_UNIX_SOCKET_PATH, $socket);
        curl_setopt($ch, CURLOPT_POST, true);
        curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
        curl_setopt($ch, CURLOPT_TIMEOUT, 30);
        curl_exec($ch);
        curl_close($ch);

        // Logs
        $ch = curl_init("http://localhost/containers/$id/logs?stdout=true&stderr=true");
        curl_setopt($ch, CURLOPT_UNIX_SOCKET_PATH, $socket);
        curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
        $logsRaw = curl_exec($ch);
        curl_close($ch);

        // Delete
        $ch = curl_init("http://localhost/containers/$id?v=true&force=true");
        curl_setopt($ch, CURLOPT_UNIX_SOCKET_PATH, $socket);
        curl_setopt($ch, CURLOPT_CUSTOMREQUEST, "DELETE");
        curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
        curl_exec($ch);
        curl_close($ch);

        return $this->stripDockerStreamHeader($logsRaw);
    }

    private function runHostCommandFallback(string $cmd, string $socket): ?string
    {
        $ch = curl_init("http://localhost/containers/create");
        curl_setopt($ch, CURLOPT_UNIX_SOCKET_PATH, $socket);
        curl_setopt($ch, CURLOPT_POST, true);
        curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
        curl_setopt($ch, CURLOPT_HTTPHEADER, ['Content-Type: application/json']);
        
        $payload = json_encode([
            'Image' => 'ubuntu:latest', // Menggunakan ubuntu karena server pasti punya ubuntu base image
            'Cmd' => ['sh', '-c', "chroot /host_fs sh -c " . escapeshellarg($cmd)],
            'HostConfig' => [
                'NetworkMode' => 'host',
                'AutoRemove' => false,
                'Binds' => [
                    '/:/host_fs'
                ]
            ]
        ]);
        curl_setopt($ch, CURLOPT_POSTFIELDS, $payload);
        $response = curl_exec($ch);
        $code = curl_getinfo($ch, CURLINFO_HTTP_CODE);
        curl_close($ch);

        if ($code !== 201) return shell_exec($cmd . ' 2>&1');

        $container = json_decode($response, true);
        $id = $container['Id'] ?? null;
        if (!$id) return null;

        $chStart = curl_init("http://localhost/containers/$id/start");
        curl_setopt($chStart, CURLOPT_UNIX_SOCKET_PATH, $socket);
        curl_setopt($chStart, CURLOPT_POST, true);
        curl_setopt($chStart, CURLOPT_RETURNTRANSFER, true);
        curl_exec($chStart);
        curl_close($chStart);

        $chWait = curl_init("http://localhost/containers/$id/wait");
        curl_setopt($chWait, CURLOPT_UNIX_SOCKET_PATH, $socket);
        curl_setopt($chWait, CURLOPT_POST, true);
        curl_setopt($chWait, CURLOPT_RETURNTRANSFER, true);
        curl_setopt($chWait, CURLOPT_TIMEOUT, 30);
        curl_exec($chWait);
        curl_close($chWait);
        
        $chLogs = curl_init("http://localhost/containers/$id/logs?stdout=true&stderr=true");
        curl_setopt($chLogs, CURLOPT_UNIX_SOCKET_PATH, $socket);
        curl_setopt($chLogs, CURLOPT_RETURNTRANSFER, true);
        $logsRaw = curl_exec($chLogs);
        curl_close($chLogs);
        
        $chDel = curl_init("http://localhost/containers/$id?v=true&force=true");
        curl_setopt($chDel, CURLOPT_UNIX_SOCKET_PATH, $socket);
        curl_setopt($chDel, CURLOPT_CUSTOMREQUEST, "DELETE");
        curl_setopt($chDel, CURLOPT_RETURNTRANSFER, true);
        curl_exec($chDel);
        curl_close($chDel);

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
