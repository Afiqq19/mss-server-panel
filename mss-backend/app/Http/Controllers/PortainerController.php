<?php

namespace App\Http\Controllers;

use App\Traits\ApiResponse;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Cache;
use Illuminate\Support\Facades\Http;
use Illuminate\Support\Facades\Log;
use Throwable;

class PortainerController extends Controller
{
    use ApiResponse;

    protected string $baseUrl;
    protected ?string $apiKey;
    protected int $endpointId;

    public function __construct()
    {
        $this->baseUrl = rtrim(config('services.portainer.url') ?: env('PORTAINER_URL', 'https://192.168.1.100:9443'), '/');
        $this->apiKey = config('services.portainer.api_key') ?: env('PORTAINER_API_KEY', 'ptr_/For91NXCWIC2XT4ptN7kJo4QXRLrYAz1SpIJ0V2D7A=');
        $this->endpointId = (int) (config('services.portainer.endpoint_id') ?: (env('PORTAINER_ENVIRONMENT_ID') ?: env('PORTAINER_ENDPOINT_ID', 3)));
    }

    /**
     * Mengambil data container dari Portainer API dengan timeout aman dan try-catch (Bab 4 & Catatan Pengguna)
     */
    public function index(): JsonResponse
    {
        // Pengecekan cepat port Portainer agar tidak menggantung jika service mati
        if (!$this->isPortainerReachable()) {
            return response()->json([
                'status' => 'error',
                'message' => 'Portainer unreachable: service offline di localhost:9000',
                'data' => []
            ], 200);
        }

        try {
            $response = Http::withoutVerifying()
                ->withHeaders([
                    'X-API-Key' => $this->apiKey,
                ])
                ->timeout(5)
                ->get("{$this->baseUrl}/api/endpoints/{$this->endpointId}/docker/containers/json?all=1");

            if (!$response->successful()) {
                throw new \Exception("Portainer API error: Status {$response->status()}");
            }

            $rawList = $response->json();

            $containers = collect($rawList)->map(function ($item) {
                $name = isset($item['Names'][0]) ? ltrim($item['Names'][0], '/') : ($item['Id'] ?? 'unknown');
                $ports = [];
                if (!empty($item['Ports'])) {
                    foreach ($item['Ports'] as $port) {
                        if (isset($port['PublicPort']) && isset($port['PrivatePort'])) {
                            $ports[] = "{$port['PublicPort']}:{$port['PrivatePort']}";
                        }
                    }
                }

                return [
                    'id' => substr($item['Id'] ?? '', 0, 12),
                    'name' => $name,
                    'state' => strtolower($item['State'] ?? 'unknown'),
                    'status' => $item['Status'] ?? '',
                    'image' => $item['Image'] ?? '',
                    'ports' => implode(', ', $ports),
                ];
            })->values()->all();

            return $this->success($containers, 'Data container berhasil diambil');

        } catch (Throwable $e) {
            return response()->json([
                'status' => 'error',
                'message' => 'Portainer unreachable: ' . $e->getMessage(),
                'data' => []
            ], 200);
        }
    }

    /**
     * Menjalankan aksi container (start, stop, restart) (Bab 4, 6)
     */
    public function action(string $id, string $action): JsonResponse
    {
        $allowedActions = ['start', 'stop', 'restart'];
        if (!in_array($action, $allowedActions, true)) {
            return $this->error('Aksi tidak valid. Aksi yang didukung: start, stop, restart.', 422);
        }

        try {
            $response = Http::withoutVerifying()
                ->withHeaders([
                    'X-API-Key' => $this->apiKey,
                ])
                ->timeout(15)
                ->post("{$this->baseUrl}/api/endpoints/{$this->endpointId}/docker/containers/{$id}/{$action}");

            if (!$response->successful()) {
                throw new \Exception("Gagal mengeksekusi aksi: {$response->body()}");
            }

            // Hapus cache agar status container langsung sinkron di request berikutnya
            Cache::forget('portainer_containers');

            return $this->success(
                ['id' => $id, 'action' => $action],
                "Aksi {$action} berhasil dikirim ke container {$id}"
            );

        } catch (Throwable $e) {
            Log::error("Gagal menjalankan aksi {$action} pada container {$id}: " . $e->getMessage());
            return $this->error("Gagal menjalankan aksi {$action} pada container {$id}: " . $e->getMessage(), 500);
        }
    }

    /**
     * Memeriksa apakah port Portainer dapat diakses dan mendeteksi host terbaik
     */
    protected function isPortainerReachable(): bool
    {
        $parts = parse_url($this->baseUrl);
        $port = isset($parts['port']) ? (int) $parts['port'] : (($parts['scheme'] ?? '') === 'https' ? 9443 : 9000);
        $scheme = $parts['scheme'] ?? 'https';

        $candidateHosts = [
            $parts['host'] ?? '192.168.1.100',
            'host.docker.internal',
            '172.17.0.1',
            '192.168.1.100',
            '127.0.0.1',
        ];

        $candidateHosts = array_unique(array_filter($candidateHosts));

        foreach ($candidateHosts as $host) {
            $fp = @fsockopen($host, $port, $errno, $errstr, 0.8);
            if ($fp) {
                fclose($fp);
                $this->baseUrl = "{$scheme}://{$host}:{$port}";
                return true;
            }
        }

        return false;
    }

    /**
     * Mengambil log dari container Docker via Portainer (Live Container Logs)
     */
    public function logs(string $id, Request $request): JsonResponse
    {
        if (!$this->isPortainerReachable()) {
            return response()->json([
                'status' => 'error',
                'message' => 'Portainer unreachable: service offline',
                'data' => ['logs' => '']
            ], 200);
        }

        try {
            $tail = $request->query('tail', 100);

            $response = Http::withoutVerifying()
                ->withHeaders([
                    'X-API-Key' => $this->apiKey,
                ])
                ->timeout(10)
                ->get("{$this->baseUrl}/api/endpoints/{$this->endpointId}/docker/containers/{$id}/logs", [
                    'stdout' => 1,
                    'stderr' => 1,
                    'tail' => $tail,
                    'timestamps' => 1,
                ]);

            if (!$response->successful()) {
                throw new \Exception("Gagal mengambil log container: Status {$response->status()}");
            }

            // Clean up Docker log stream header bytes (first 8 bytes per line)
            $rawLogs = $response->body();
            $lines = explode("\n", $rawLogs);
            $cleanedLines = [];
            foreach ($lines as $line) {
                // Docker stream protocol: first 8 bytes are header, strip them
                if (strlen($line) > 8) {
                    $cleanedLines[] = substr($line, 8);
                } elseif (!empty(trim($line))) {
                    $cleanedLines[] = $line;
                }
            }

            return $this->success([
                'container_id' => $id,
                'logs' => implode("\n", $cleanedLines),
            ], 'Log container berhasil diambil');

        } catch (Throwable $e) {
            return response()->json([
                'status' => 'error',
                'message' => 'Gagal mengambil log: ' . $e->getMessage(),
                'data' => ['logs' => '']
            ], 200);
        }
    }
}
