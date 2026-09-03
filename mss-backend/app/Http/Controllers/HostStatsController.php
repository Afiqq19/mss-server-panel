<?php

namespace App\Http\Controllers;

use App\Traits\ApiResponse;
use Illuminate\Http\JsonResponse;
use Throwable;

class HostStatsController extends Controller
{
    use ApiResponse;

    /**
     * Membaca status Host Machine (CPU, RAM, Disk, Temperature, Battery) (Bab 4, 8, 9.A)
     */
    public function index(): JsonResponse
    {
        try {
            $cpuUsage = $this->getCpuUsage();
            $ram = $this->getRamUsage();
            $disk = $this->getDiskUsage();
            $temperature = $this->getCpuTemperature();
            $battery = $this->getBatteryStatus();

            $data = [
                'cpu_usage_percent' => $cpuUsage,
                'ram_total_gb' => $ram['total_gb'],
                'ram_used_gb' => $ram['used_gb'],
                'disk_total_gb' => $disk['total_gb'],
                'disk_used_gb' => $disk['used_gb'],
                'cpu_temperature' => $temperature,
                'battery_percent' => $battery['percent'],
                'is_charging' => $battery['is_charging'],
            ];

            return $this->success($data);

        } catch (Throwable $e) {
            return $this->error('Gagal membaca metrik sistem host: ' . $e->getMessage(), 500);
        }
    }

    protected function getProcPath(): string
    {
        $candidates = [
            config('services.server_monitor.proc_path'),
            '/host/proc',
            '/proc',
        ];

        foreach ($candidates as $path) {
            if ($path && is_dir($path) && file_exists($path . '/meminfo')) {
                return rtrim($path, '/');
            }
        }

        return '/proc';
    }

    protected function getSysPath(): string
    {
        $candidates = [
            config('services.server_monitor.sys_path'),
            '/host/sys',
            '/sys',
        ];

        foreach ($candidates as $path) {
            if ($path && is_dir($path)) {
                return rtrim($path, '/');
            }
        }

        return '/sys';
    }

    protected function getCpuUsage(): float
    {
        $procPath = $this->getProcPath();
        $statFile = $procPath . '/stat';

        if (file_exists($statFile) && is_readable($statFile)) {
            $content = file_get_contents($statFile);
            if (preg_match('/^cpu\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)/m', $content, $matches)) {
                $total = $matches[1] + $matches[2] + $matches[3] + $matches[4];
                $idle = $matches[4];
                return round((1 - ($idle / max($total, 1))) * 100, 1);
            }
        }

        if (function_exists('sys_getloadavg')) {
            $load = sys_getloadavg();
            if (isset($load[0])) {
                return round($load[0] * 10, 1);
            }
        }

        return 12.5; // Fallback mock value
    }

    protected function getRamUsage(): array
    {
        $procPath = $this->getProcPath();
        $meminfoFile = $procPath . '/meminfo';

        if (file_exists($meminfoFile) && is_readable($meminfoFile)) {
            $content = file_get_contents($meminfoFile);
            $totalKb = 0;
            $availKb = 0;

            if (preg_match('/MemTotal:\s+(\d+)\s+kB/', $content, $m)) {
                $totalKb = (int) $m[1];
            }
            if (preg_match('/MemAvailable:\s+(\d+)\s+kB/', $content, $m)) {
                $availKb = (int) $m[1];
            } elseif (preg_match('/MemFree:\s+(\d+)\s+kB/', $content, $m)) {
                $availKb = (int) $m[1];
            }

            if ($totalKb > 0) {
                $usedKb = $totalKb - $availKb;
                return [
                    'total_gb' => round($totalKb / (1024 * 1024), 1),
                    'used_gb' => round($usedKb / (1024 * 1024), 1),
                ];
            }
        }

        // Nilai fallback untuk Toshiba Satellite (RAM fisik 4GB -> terbaca ~3.8 GB di Linux kernel)
        return [
            'total_gb' => 3.8,
            'used_gb' => 1.8,
        ];
    }

    protected function getDiskUsage(): array
    {
        // Prioritas 1: Baca dari /host/proc/mounts - disk fisik host Toshiba via mount Docker
        $procPath = $this->getProcPath();
        $mountsFile = $procPath . '/mounts';

        if (file_exists($mountsFile) && is_readable($mountsFile)) {
            // Coba baca dari root filesystem host menggunakan df via shell
            $dfOutput = shell_exec("df -B1 / 2>/dev/null | tail -1");
            if ($dfOutput) {
                $parts = preg_split('/\s+/', trim($dfOutput));
                if (count($parts) >= 4 && is_numeric($parts[1]) && is_numeric($parts[2])) {
                    $totalBytes = (float) $parts[1];
                    $usedBytes  = (float) $parts[2];
                    // Jika terbaca data yang masuk akal (total > 10GB)
                    if ($totalBytes > 10 * 1024 * 1024 * 1024) {
                        return [
                            'total_gb' => round($totalBytes / (1024 * 1024 * 1024), 1),
                            'used_gb'  => round($usedBytes  / (1024 * 1024 * 1024), 1),
                        ];
                    }
                }
            }
        }

        // Prioritas 2: Coba /host atau mount point container yang paling dekat dengan host
        $hostCandidates = ['/var/www', '/var/www/html', '/'];
        foreach ($hostCandidates as $candidate) {
            $totalBytes = @disk_total_space($candidate);
            $freeBytes  = @disk_free_space($candidate);
            if ($totalBytes && $freeBytes && $totalBytes > 10 * 1024 * 1024 * 1024) {
                $usedBytes = $totalBytes - $freeBytes;
                return [
                    'total_gb' => round($totalBytes / (1024 * 1024 * 1024), 1),
                    'used_gb'  => round($usedBytes  / (1024 * 1024 * 1024), 1),
                ];
            }
        }

        // Fallback jika Windows (lokal dev)
        if (PHP_OS_FAMILY === 'Windows') {
            $totalBytes = @disk_total_space('C:');
            $freeBytes  = @disk_free_space('C:');
            if ($totalBytes && $freeBytes) {
                return [
                    'total_gb' => round($totalBytes / (1024 * 1024 * 1024), 1),
                    'used_gb'  => round(($totalBytes - $freeBytes) / (1024 * 1024 * 1024), 1),
                ];
            }
        }

        return [
            'total_gb' => 256.0,
            'used_gb'  => 120.5,
        ];
    }

    protected function getCpuTemperature(): ?float
    {
        $sysPath = config('services.server_monitor.sys_path', '/sys');
        $thermalFiles = glob($sysPath . '/class/thermal/thermal_zone*/temp');

        if (!empty($thermalFiles)) {
            foreach ($thermalFiles as $file) {
                if (is_readable($file)) {
                    $raw = trim(file_get_contents($file));
                    if (is_numeric($raw)) {
                        $temp = (float) $raw;
                        return $temp > 1000 ? round($temp / 1000, 1) : round($temp, 1);
                    }
                }
            }
        }

        return 48.5; // Default/dev mock in Celsius
    }

    protected function getBatteryStatus(): array
    {
        $sysPath = config('services.server_monitor.sys_path', '/sys');
        $powerSupplies = glob($sysPath . '/class/power_supply/*');

        $batteryPercent = 100;
        $isCharging = true;

        if (!empty($powerSupplies)) {
            foreach ($powerSupplies as $dir) {
                $capacityFile = $dir . '/capacity';
                $statusFile = $dir . '/status';

                if (file_exists($capacityFile) && is_readable($capacityFile)) {
                    $batteryPercent = (int) trim(file_get_contents($capacityFile));
                }
                if (file_exists($statusFile) && is_readable($statusFile)) {
                    $status = strtolower(trim(file_get_contents($statusFile)));
                    $isCharging = ($status === 'charging' || $status === 'full');
                }
            }
        }

        return [
            'percent' => $batteryPercent,
            'is_charging' => $isCharging,
        ];
    }
}
