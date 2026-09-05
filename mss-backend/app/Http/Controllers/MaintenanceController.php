<?php

namespace App\Http\Controllers;

use App\Traits\ApiResponse;
use App\Traits\HostCommand;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Log;
use Throwable;

class MaintenanceController extends Controller
{
    use ApiResponse, HostCommand;

    /**
     * Daftar task maintenance yang tersedia
     */
    public function index(): JsonResponse
    {
        $tasks = [
            [
                'id' => 'apt_clean',
                'name' => 'Bersihkan Cache APT',
                'description' => 'Menghapus file cache paket apt yang tidak diperlukan (apt-get clean)',
                'icon' => 'cleaning_services',
                'danger' => false,
            ],
            [
                'id' => 'apt_autoremove',
                'name' => 'Hapus Paket Tidak Digunakan',
                'description' => 'Menghapus paket dependensi yang tidak lagi diperlukan (apt-get autoremove -y)',
                'icon' => 'delete_sweep',
                'danger' => false,
            ],
            [
                'id' => 'docker_prune',
                'name' => 'Bersihkan Docker (Prune)',
                'description' => 'Menghapus image, container, volume, dan network Docker yang tidak terpakai',
                'icon' => 'layers_clear',
                'danger' => true,
            ],
            [
                'id' => 'clear_journal',
                'name' => 'Bersihkan System Log',
                'description' => 'Menghapus journal systemd yang lebih dari 3 hari (journalctl --vacuum-time=3d)',
                'icon' => 'receipt_long',
                'danger' => false,
            ],
            [
                'id' => 'clear_tmp',
                'name' => 'Bersihkan /tmp',
                'description' => 'Menghapus file sementara di folder /tmp yang lebih dari 7 hari',
                'icon' => 'folder_delete',
                'danger' => false,
            ],
            [
                'id' => 'system_update',
                'name' => 'Update Sistem (apt upgrade)',
                'description' => 'Menjalankan apt-get update && apt-get upgrade -y untuk memperbarui seluruh paket OS',
                'icon' => 'system_update',
                'danger' => true,
            ],
        ];

        return $this->success($tasks, 'Daftar task maintenance berhasil diambil');
    }

    /**
     * Menjalankan task maintenance tertentu
     */
    public function execute(Request $request): JsonResponse
    {
        $request->validate([
            'task_id' => 'required|string',
        ]);

        $taskId = $request->input('task_id');

        $commands = [
            'apt_clean' => 'apt-get clean 2>&1',
            'apt_autoremove' => 'DEBIAN_FRONTEND=noninteractive apt-get autoremove -y 2>&1',
            'docker_prune' => 'docker system prune -af --volumes 2>&1',
            'clear_journal' => 'journalctl --vacuum-time=3d 2>&1',
            'clear_tmp' => 'find /tmp -type f -mtime +7 -delete 2>&1 && echo "File tmp lama berhasil dihapus"',
            'system_update' => 'DEBIAN_FRONTEND=noninteractive apt-get update 2>&1 && DEBIAN_FRONTEND=noninteractive apt-get upgrade -y 2>&1',
        ];

        if (!isset($commands[$taskId])) {
            return $this->error('Task ID tidak valid.', 422);
        }

        try {
            $command = $commands[$taskId];
            $output = $this->runHostCommand($command);

            if ($output === null) {
                return $this->error('Gagal terhubung ke host shell via Docker socket.', 500);
            }

            return $this->success([
                'output' => $output
            ], 'Task maintenance berhasil dijalankan');

        } catch (Throwable $e) {
            Log::error("Maintenance task error: " . $e->getMessage());
            return $this->error("Gagal menjalankan task: " . $e->getMessage(), 500);
        }
    }
}
