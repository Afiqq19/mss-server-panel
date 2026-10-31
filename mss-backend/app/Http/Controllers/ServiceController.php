<?php

namespace App\Http\Controllers;

use App\Traits\ApiResponse;
use App\Traits\HostCommand;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Cache;
use Throwable;

class ServiceController extends Controller
{
    use ApiResponse, HostCommand;

    /**
     * Mengambil status Daemon Services sistem Linux dengan validasi ketat dan multi-deteksi
     */
    public function index(): JsonResponse
    {
        // Cache hasil pengecekan service selama 10 detik agar hemat CPU
        $results = Cache::remember('host_services_cached', 10, function () {
            $definitions = [
                'docker' => [
                    'label'       => 'Docker Engine',
                    'description' => 'Daemon Virtualisasi Kontainer & Orkestrasi Microservice',
                    'proc_keys'   => ['dockerd', 'docker'],
                    'icon'        => 'layers',
                ],
                'ssh' => [
                    'label'       => 'OpenSSH Server',
                    'description' => 'Akses Remote Terminal Shell Host Linux (Port 22)',
                    'proc_keys'   => ['sshd', 'ssh'],
                    'icon'        => 'key',
                ],
                'cron' => [
                    'label'       => 'Cron Automation',
                    'description' => 'Penjadwal Latar Belakang Backup Database & Cron Jobs',
                    'proc_keys'   => ['cron', 'crond'],
                    'icon'        => 'schedule',
                ],
                'cloudflared' => [
                    'label'       => 'Cloudflare Tunnel',
                    'description' => 'Zero Trust Ingress Gateway Domain Publik (*.xie.my.id)',
                    'proc_keys'   => ['cloudflared'],
                    'icon'        => 'public',
                ],
                'mariadb' => [
                    'label'       => 'MariaDB SQL Engine',
                    'description' => 'Pusat Mesin Database Relasional SQL Host Server',
                    'proc_keys'   => ['mariadbd', 'mariadb', 'mysqld'],
                    'icon'        => 'storage',
                ],
                'nginx' => [
                    'label'       => 'Nginx Web Server',
                    'description' => 'Reverse Proxy Ingress & Web Server Frontend',
                    'proc_keys'   => ['nginx'],
                    'icon'        => 'dns',
                ],
            ];

            // 1. Ambil daftar proses yang sedang aktif di host Linux
            $procOutput = $this->runHostCommand("ps -eo comm 2>/dev/null || true");
            $runningProcs = [];
            if (!empty($procOutput)) {
                $lines = explode("\n", trim($procOutput));
                foreach ($lines as $line) {
                    $runningProcs[] = strtolower(trim($line));
                }
            }

            // 2. Ambil status systemctl jika tersedia
            $sysOutput = $this->runHostCommand("for s in docker ssh sshd cron cloudflared mariadb mysql nginx; do echo \"\$s:\$(systemctl is-active \$s 2>/dev/null || service \$s status 2>/dev/null || echo unknown)\"; done");
            $sysMap = [];
            if (!empty($sysOutput)) {
                $sysLines = explode("\n", trim($sysOutput));
                foreach ($sysLines as $line) {
                    if (str_contains($line, ':')) {
                        list($k, $v) = explode(':', trim($line), 2);
                        $k = strtolower(trim($k));
                        $v = strtolower(trim($v));
                        // Abaikan error shell seperti 'sh: 1: systemctl'
                        if (in_array($k, ['docker', 'ssh', 'sshd', 'cron', 'cloudflared', 'mariadb', 'mysql', 'nginx'])) {
                            $sysMap[$k] = $v;
                        }
                    }
                }
            }

            $parsed = [];
            foreach ($definitions as $key => $meta) {
                $isActive = false;

                // Cek 1: Apakah proses utamanya ada di daftar ps host?
                foreach ($meta['proc_keys'] as $pk) {
                    if (in_array($pk, $runningProcs)) {
                        $isActive = true;
                        break;
                    }
                }

                // Cek 2: Cek status systemctl / service
                if (!$isActive) {
                    $sysStatus = $sysMap[$key] ?? ($sysMap[$meta['proc_keys'][0]] ?? 'unknown');
                    if (str_contains($sysStatus, 'active') || str_contains($sysStatus, 'running')) {
                        $isActive = true;
                    }
                }

                $parsed[] = [
                    'name'        => $key,
                    'label'       => $meta['label'],
                    'description' => $meta['description'],
                    'status'      => $isActive ? 'active' : 'inactive',
                    'icon'        => $meta['icon'],
                    'raw'         => $isActive ? 'running' : 'stopped',
                ];
            }

            return $parsed;
        });

        return $this->success(['services' => $results]);
    }

    /**
     * Menjalankan aksi service (start, stop, restart) dengan proteksi nama service
     */
    public function action(Request $request): JsonResponse
    {
        $request->validate([
            'service' => 'required|string|in:docker,ssh,cron,cloudflared,mariadb,nginx,mysql',
            'action'  => 'required|in:start,stop,restart'
        ]);

        $svc = escapeshellarg($request->input('service'));
        $action = escapeshellarg($request->input('action'));

        // Coba systemctl dulu, lalu service sebagai fallback
        $cmd = "systemctl $action $svc 2>&1 || service $svc $action 2>&1";

        try {
            Cache::forget('host_services_cached');
            $output = $this->runHostCommand($cmd);
            return $this->success(['output' => $output], "Service berhasil di-$action");
        } catch (Throwable $e) {
            return $this->error('Gagal memanajemen service: ' . $e->getMessage(), 500);
        }
    }

    /**
     * Mengambil daftar proses CPU & RAM tertinggi di server
     */
    public function topProcesses(): JsonResponse
    {
        return Cache::remember('host_top_processes_cached', 6, function () {
            try {
                // Ambil 25 proses teratas dan parse detailnya
                $cmd = "ps -eo pid,user,%cpu,%mem,comm --sort=-%cpu | head -n 25 2>&1";
                $output = $this->runHostCommand($cmd);

                $processes = [];
                if (!empty($output)) {
                    $lines = explode("\n", trim($output));
                    array_shift($lines); // header baris pertama

                    foreach ($lines as $line) {
                        $parts = preg_split('/\s+/', trim($line));
                        if (count($parts) >= 5) {
                            $comm = $parts[4];

                            // Abaikan proses ephemeral pencari metrik itu sendiri (ps, head, awk)
                            if (in_array($comm, ['ps', 'head', 'awk', 'grep'])) {
                                continue;
                            }

                            $cpuVal = floatval($parts[2]);
                            $memVal = floatval($parts[3]);

                            // Tentukan label ramah pengguna untuk command populer
                            $friendlyLabel = $this->getFriendlyCommandLabel($comm);

                            $processes[] = [
                                'pid'      => $parts[0],
                                'user'     => $parts[1],
                                'cpu_val'  => $cpuVal,
                                'mem_val'  => $memVal,
                                'cpu'      => number_format($cpuVal, 1) . '%',
                                'mem'      => number_format($memVal, 1) . '%',
                                'command'  => $comm,
                                'friendly' => $friendlyLabel,
                            ];
                        }
                    }
                }

                // Ambil maksimal 12 proses teratas yang relevan
                $processes = array_slice($processes, 0, 12);

                return $this->success(['processes' => $processes]);
            } catch (Throwable $e) {
                return $this->error('Gagal mengambil top processes: ' . $e->getMessage(), 500);
            }
        });
    }

    /**
     * Label ramah manusia untuk nama perintah Linux
     */
    private function getFriendlyCommandLabel(string $comm): string
    {
        $c = strtolower($comm);
        if ($c === 'node') return 'Node.js App Service (Game / Backend)';
        if ($c === 'mariadbd' || $c === 'mysqld') return 'MariaDB Database Engine';
        if ($c === 'cloudflared') return 'Cloudflare Tunnel Ingress';
        if ($c === 'dockerd') return 'Docker Host Virtualization Engine';
        if ($c === 'containerd') return 'Container Runtime Core';
        if ($c === 'sshd') return 'Secure Shell Server (SSH)';
        if ($c === 'nginx') return 'Nginx Web Server / Reverse Proxy';
        if ($c === 'php-fpm' || str_contains($c, 'php')) return 'PHP-FPM Application Engine';
        if ($c === 'cron' || $c === 'crond') return 'Cron Automation Scheduler';
        if ($c === 'systemd' || $c === 'systemd-journald') return 'Systemd Core Daemon';
        if ($c === 'ttyd') return 'MSS Web Terminal Daemon';
        return 'System Process';
    }
}
