<?php

namespace App\Http\Controllers;

use App\Traits\ApiResponse;
use App\Traits\HostCommand;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Throwable;

class CronController extends Controller
{
    use ApiResponse, HostCommand;

    public function index(): JsonResponse
    {
        try {
            $output = $this->runHostCommand('crontab -l 2>&1');
            
            $crons = [];
            if (strpos(strtolower((string)$output), 'no crontab') === false) {
                $lines = explode("\n", trim((string)$output));
                foreach ($lines as $i => $line) {
                    $line = trim($line);
                    if (empty($line) || str_starts_with($line, '#')) continue;
                    
                    // Basic parse for 5 time fields + command
                    $parts = preg_split('/\s+/', $line, 6);
                    if (count($parts) === 6) {
                        $crons[] = [
                            'id' => $i, // pseudo ID
                            'schedule' => implode(' ', array_slice($parts, 0, 5)),
                            'command' => $parts[5],
                            'raw' => $line
                        ];
                    }
                }
            }

            return $this->success(['crons' => $crons]);
        } catch (Throwable $e) {
            return $this->error('Gagal membaca cron jobs: ' . $e->getMessage(), 500);
        }
    }

    public function addCron(Request $request): JsonResponse
    {
        $request->validate([
            'schedule' => 'required|string',
            'command' => 'required|string',
        ]);

        $schedule = $request->input('schedule');
        $cmd = escapeshellarg($request->input('command'));
        $newLine = "$schedule $cmd";

        try {
            // Append to crontab
            $script = "(crontab -l 2>/dev/null; echo " . escapeshellarg($newLine) . ") | crontab -";
            $this->runHostCommand($script);

            return $this->success([], 'Cron job berhasil ditambahkan');
        } catch (Throwable $e) {
            return $this->error('Gagal menambahkan cron job: ' . $e->getMessage(), 500);
        }
    }

    public function deleteCron(Request $request): JsonResponse
    {
        $request->validate([
            'index' => 'required|integer',
        ]);

        $index = (int)$request->input('index');

        try {
            $output = $this->runHostCommand('crontab -l 2>&1');
            $lines = explode("\n", trim((string)$output));
            
            if (isset($lines[$index])) {
                unset($lines[$index]);
                $newCrontab = implode("\n", $lines) . "\n";
                // Write new crontab back
                $script = "echo " . escapeshellarg($newCrontab) . " | crontab -";
                $this->runHostCommand($script);
            }

            return $this->success([], 'Cron job berhasil dihapus');
        } catch (Throwable $e) {
            return $this->error('Gagal menghapus cron job: ' . $e->getMessage(), 500);
        }
    }
}
