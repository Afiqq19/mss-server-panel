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
        $this->baseUrl = rtrim(config('services.portainer.url') ?: env('PORTAINER_URL', 'http://127.0.0.1:9000'), '/');
        $this->apiKey = config('services.portainer.api_key') ?: env('PORTAINER_API_KEY');
        $this->endpointId = (int) (config('services.portainer.endpoint_id') ?: (env('PORTAINER_ENVIRONMENT_ID') ?: env('PORTAINER_ENDPOINT_ID', 1)));
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
     * Memeriksa apakah port Portainer dapat diakses dalam hitungan milidetik
     */
    protected function isPortainerReachable(): bool
    {
        $parts = parse_url($this->baseUrl);
        $host = $parts['host'] ?? '127.0.0.1';
        $port = isset($parts['port']) ? (int) $parts['port'] : (($parts['scheme'] ?? '') === 'https' ? 9443 : 9000);

        $fp = @fsockopen($host, $port, $errno, $errstr, 1.0);
        if ($fp) {
            fclose($fp);
            return true;
        }

        return false;
    }
}
