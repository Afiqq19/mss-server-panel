<?php

namespace App\Http\Controllers;

use App\Traits\ApiResponse;
use App\Traits\HostCommand;
use Illuminate\Http\Request;
use Illuminate\Http\JsonResponse;

class DatabaseController extends Controller
{
    use ApiResponse, HostCommand;

    private function getAllDbContainers(): array
    {
        if (!file_exists('/var/run/docker.sock')) {
            throw new \Exception("Docker socket not found on host.");
        }
        
        $ch = curl_init("http://localhost/containers/json");
        curl_setopt_array($ch, [
            CURLOPT_UNIX_SOCKET_PATH => '/var/run/docker.sock',
            CURLOPT_RETURNTRANSFER => true,
            CURLOPT_TIMEOUT => 5,
        ]);
        $response = curl_exec($ch);
        curl_close($ch);

        $dbContainers = [];
        if ($response) {
            $containers = json_decode($response, true) ?? [];
            foreach ($containers as $c) {
                $names = $c['Names'] ?? [];
                $image = strtolower($c['Image'] ?? '');
                
                $matchedName = ltrim($names[0] ?? '', '/');
                $isDb = false;

                if (str_contains($image, 'mysql') || str_contains($image, 'mariadb')) {
                    $isDb = true;
                } else {
                    foreach ($names as $name) {
                        $n = strtolower(ltrim($name, '/'));
                        if (str_contains($n, 'db') || str_contains($n, 'mysql') || str_contains($n, 'mariadb')) {
                            $isDb = true;
                            break;
                        }
                    }
                }

                if ($isDb) {
                    $dbContainers[] = $matchedName;
                }
            }
        }
        
        if (empty($dbContainers)) {
            throw new \Exception("Tidak ditemukan container database (MySQL/MariaDB) yang sedang berjalan.");
        }

        return $dbContainers;
    }

    private function getDbPassword(string $container): string
    {
        $ch = curl_init("http://localhost/containers/{$container}/json");
        curl_setopt_array($ch, [
            CURLOPT_UNIX_SOCKET_PATH => '/var/run/docker.sock',
            CURLOPT_RETURNTRANSFER => true,
            CURLOPT_TIMEOUT => 5,
        ]);
        $inspectJson = curl_exec($ch);
        curl_close($ch);
        
        if ($inspectJson) {
            $inspectData = json_decode($inspectJson, true);
            $envs = $inspectData['Config']['Env'] ?? [];
            foreach ($envs as $envStr) {
                if (str_starts_with($envStr, 'MYSQL_ROOT_PASSWORD=') || str_starts_with($envStr, 'MARIADB_ROOT_PASSWORD=')) {
                    $parts = explode('=', $envStr, 2);
                    return $parts[1] ?? 'rahasia123';
                }
            }
        }
        return 'rahasia123';
    }

    private function dockerExecDb(string $container, array $cmd): ?string
    {
        $execPayload = json_encode([
            'AttachStdout' => true,
            'AttachStderr' => true,
            'Tty' => false,
            'Cmd' => $cmd,
        ]);

        $ch = curl_init("http://localhost/containers/{$container}/exec");
        curl_setopt_array($ch, [
            CURLOPT_UNIX_SOCKET_PATH => '/var/run/docker.sock',
            CURLOPT_POST => true,
            CURLOPT_POSTFIELDS => $execPayload,
            CURLOPT_HTTPHEADER => ['Content-Type: application/json'],
            CURLOPT_RETURNTRANSFER => true,
        ]);
        $response = curl_exec($ch);
        $code = curl_getinfo($ch, CURLINFO_HTTP_CODE);
        curl_close($ch);

        if ($code !== 201 || !$response) return null;
        
        $data = json_decode($response, true);
        $execId = $data['Id'] ?? null;
        if (!$execId) return null;

        $chStart = curl_init("http://localhost/exec/{$execId}/start");
        curl_setopt_array($chStart, [
            CURLOPT_UNIX_SOCKET_PATH => '/var/run/docker.sock',
            CURLOPT_POST => true,
            CURLOPT_POSTFIELDS => json_encode(['Detach' => false, 'Tty' => false]),
            CURLOPT_HTTPHEADER => ['Content-Type: application/json'],
            CURLOPT_RETURNTRANSFER => true,
        ]);
        $output = curl_exec($chStart);
        curl_close($chStart);

        $cleanOutput = '';
        $length = strlen($output);
        $offset = 0;
        while ($offset < $length) {
            if ($offset + 8 > $length) break;
            $header = substr($output, $offset, 8);
            $type = ord($header[0]);
            if ($type > 2) {
                $cleanOutput = $output;
                break;
            }
            $sizeArray = unpack('N', substr($header, 4, 4));
            $size = $sizeArray[1];
            $offset += 8;
            $cleanOutput .= substr($output, $offset, $size);
            $offset += $size;
        }

        return trim($cleanOutput);
    }

    private function resolveDbCommand(string $container, string $cmdType = 'client'): string
    {
        $testCmd = ['mysql', '--version'];
        $res = $this->dockerExecDb($container, $testCmd);
        
        $hasMysql = true;
        if (str_contains(strtolower($res ?? ''), 'executable file not found')) {
            $hasMysql = false;
        }

        if ($cmdType === 'client') {
            return $hasMysql ? 'mysql' : 'mariadb';
        } else {
            return $hasMysql ? 'mysqldump' : 'mariadb-dump';
        }
    }

    private function runQuery(string $query, string $db = '')
    {
        $container = null;
        // Deteksi format [container_name] database_name
        if ($db !== '' && preg_match('/^\[(.*?)\]\s+(.*)$/', $db, $matches)) {
            $container = $matches[1];
            $db = trim($matches[2]);
        }

        if (!$container) {
            $containers = $this->getAllDbContainers();
            $container = $containers[0];
        }

        $password = $this->getDbPassword($container);
        $client = $this->resolveDbCommand($container, 'client');
        
        $cmd = [$client, '-u', 'root', "-p{$password}", '-s', '-e', $query];
        if ($db !== '') {
            $cmd = [$client, '-u', 'root', "-p{$password}", $db, '-s', '-e', $query];
        }
        
        $result = $this->dockerExecDb($container, $cmd);
        
        if (str_contains(strtolower($result ?? ''), 'error ') && str_contains(strtolower($result ?? ''), 'at line')) {
            throw new \Exception($result);
        }
        
        return $result;
    }

    public function getDatabases(): JsonResponse
    {
        try {
            $containers = $this->getAllDbContainers();
            $allDbs = [];

            foreach ($containers as $c) {
                $password = $this->getDbPassword($c);
                $client = $this->resolveDbCommand($c, 'client');
                $cmd = [$client, '-u', 'root', "-p{$password}", '-s', '-e', 'SHOW DATABASES;'];
                $output = $this->dockerExecDb($c, $cmd);
                
                if ($output && !str_contains(strtolower($output), 'oci runtime') && !str_contains(strtolower($output), 'executable file not found') && !str_contains(strtolower($output), 'error ')) {
                    $dbs = array_filter(explode("\n", $output));
                    foreach ($dbs as $db) {
                        $db = trim($db);
                        if (!in_array($db, ['information_schema', 'performance_schema', 'sys', 'mysql'])) {
                            $allDbs[] = "[$c] $db";
                        }
                    }
                }
            }
            
            return $this->success(['databases' => array_values(array_unique($allDbs))]);
        } catch (\Throwable $e) {
            return $this->error($e->getMessage(), 500);
        }
    }

    public function createDatabase(Request $request): JsonResponse
    {
        $request->validate([
            'name' => 'required|string|alpha_dash',
            'container' => 'nullable|string'
        ]);
        try {
            $container = $request->input('container');
            if (!$container) {
                $containers = $this->getAllDbContainers();
                $container = $containers[0];
            }

            $password = $this->getDbPassword($container);
            $client = $this->resolveDbCommand($container, 'client');
            $cmd = [$client, '-u', 'root', "-p{$password}", '-s', '-e', "CREATE DATABASE `{$request->name}`;"];
            $this->dockerExecDb($container, $cmd);

            return $this->success([], "Database {$request->name} berhasil dibuat di container {$container}.");
        } catch (\Throwable $e) {
            return $this->error($e->getMessage(), 500);
        }
    }

    public function getTables(Request $request): JsonResponse
    {
        $db = $request->query('db', '');
        try {
            $output = $this->runQuery('SHOW TABLES;', $db);
            $tables = array_filter(explode("\n", $output));
            return $this->success(['tables' => array_values($tables)]);
        } catch (\Throwable $e) {
            return $this->error($e->getMessage(), 500);
        }
    }

    public function getTableRows(Request $request): JsonResponse
    {
        $db = $request->query('db', '');
        $table = $request->query('table', '');
        try {
            $descOutput = $this->runQuery("DESCRIBE `{$table}`;", $db);
            $descLines = array_filter(explode("\n", $descOutput));
            $columns = [];
            foreach ($descLines as $line) {
                $parts = explode("\t", $line);
                if (count($parts) > 0) $columns[] = $parts[0];
            }

            $output = $this->runQuery("SELECT * FROM `{$table}` LIMIT 100;", $db);
            $lines = array_filter(explode("\n", $output));
            
            $rows = [];
            foreach ($lines as $line) {
                $rows[] = explode("\t", $line);
            }
            
            return $this->success(['columns' => $columns, 'rows' => $rows]);
        } catch (\Throwable $e) {
            return $this->error($e->getMessage(), 500);
        }
    }

    public function executeRawQuery(Request $request): JsonResponse
    {
        $request->validate(['query' => 'required|string']);
        try {
            $db = $request->input('db', '');
            $container = null;
            $realDb = '';
            if ($db !== '' && preg_match('/^\[(.*?)\]\s+(.*)$/', $db, $matches)) {
                $container = $matches[1];
                $realDb = trim($matches[2]);
            }

            if (!$container) {
                $containers = $this->getAllDbContainers();
                $container = $containers[0];
            }
            $password = $this->getDbPassword($container);
            $client = $this->resolveDbCommand($container, 'client');
            
            $cmd = [$client, '-u', 'root', "-p{$password}"];
            if ($realDb !== '') {
                $cmd[] = $realDb;
            }
            $cmd[] = '-t';
            $cmd[] = '-e';
            $cmd[] = $request->input('query');
            
            $output = $this->dockerExecDb($container, $cmd);
            
            if (str_contains(strtolower($output ?? ''), 'error ') && str_contains(strtolower($output ?? ''), 'at line')) {
                throw new \Exception($output);
            }
            return $this->success(['output' => $output], "Query berhasil dieksekusi di {$container}" . ($realDb ? " ($realDb)" : "") . ".");
        } catch (\Throwable $e) {
            return $this->error($e->getMessage(), 500);
        }
    }

    public function exportDatabase(Request $request): JsonResponse
    {
        $db = $request->query('db', '');
        try {
            $container = null;
            $realDb = $db;
            if (preg_match('/^\[(.*?)\]\s+(.*)$/', $db, $matches)) {
                $container = $matches[1];
                $realDb = trim($matches[2]);
            }

            if (!$container) {
                $containers = $this->getAllDbContainers();
                $container = $containers[0];
            }

            $password = $this->getDbPassword($container);
            $dump = $this->resolveDbCommand($container, 'dump');
            
            $cmd = [$dump, '-u', 'root', "-p{$password}", $realDb];
            $sql = $this->dockerExecDb($container, $cmd);
            
            $filename = "{$realDb}_backup_" . date('Ymd_His') . ".sql";
            $path = public_path("downloads");
            if (!is_dir($path)) mkdir($path, 0777, true);
            
            file_put_contents("$path/$filename", $sql);
            
            return $this->success(['download_url' => url("downloads/{$filename}")]);
        } catch (\Throwable $e) {
            return $this->error($e->getMessage(), 500);
        }
    }
}
