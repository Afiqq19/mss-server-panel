<?php

namespace App\Http\Controllers;

use App\Traits\ApiResponse;
use App\Traits\HostCommand;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Throwable;

class AppInstallerController extends Controller
{
    use ApiResponse, HostCommand;

    private $apps = [
        'nginx_proxy_manager' => [
            'name' => 'Nginx Proxy Manager',
            'description' => 'Docker-based proxy manager for reverse proxying and SSL management.',
            'compose' => "
version: '3.8'
services:
  app:
    image: 'jc21/nginx-proxy-manager:latest'
    restart: unless-stopped
    ports:
      - '80:80'
      - '81:81'
      - '443:443'
    volumes:
      - ./data:/data
      - ./letsencrypt:/etc/letsencrypt
"
        ],
        'wordpress' => [
            'name' => 'WordPress (with MySQL & phpMyAdmin)',
            'description' => 'Install a fresh WordPress instance bundled with phpMyAdmin (Port 8081).',
            'compose' => "
version: '3.8'
services:
  db:
    image: mysql:8.0
    restart: always
    environment:
      MYSQL_ROOT_PASSWORD: changeme
      MYSQL_DATABASE: wordpress
      MYSQL_USER: wordpress
      MYSQL_PASSWORD: changeme
    volumes:
      - ./db_data:/var/lib/mysql
  wordpress:
    depends_on:
      - db
    image: wordpress:latest
    ports:
      - '8080:80'
    restart: always
    environment:
      WORDPRESS_DB_HOST: db:3306
      WORDPRESS_DB_USER: wordpress
      WORDPRESS_DB_PASSWORD: changeme
      WORDPRESS_DB_NAME: wordpress
    volumes:
      - ./wp_data:/var/www/html
  phpmyadmin:
    image: phpmyadmin:latest
    restart: always
    ports:
      - '8081:80'
    environment:
      PMA_HOST: db
      PMA_PORT: 3306
      PMA_USER: root
      PMA_PASSWORD: changeme
    depends_on:
      - db
"
        ],
    ];

    public function listApps(): JsonResponse
    {
        $appList = [];
        foreach ($this->apps as $id => $app) {
            $appList[] = [
                'id' => $id,
                'name' => $app['name'],
                'description' => $app['description']
            ];
        }
        return $this->success(['apps' => $appList]);
    }

    public function installApp(Request $request): JsonResponse
    {
        $request->validate([
            'app_id' => 'required|string'
        ]);

        $appId = $request->input('app_id');
        if (!isset($this->apps[$appId])) {
            return $this->error('Aplikasi tidak ditemukan.', 404);
        }

        $app = $this->apps[$appId];
        $targetDir = "/opt/mss-apps/$appId";
        $composeContent = escapeshellarg(trim($app['compose']));

        $script = "
            mkdir -p $targetDir && 
            echo $composeContent > $targetDir/docker-compose.yml && 
            cd $targetDir && 
            nohup sh -c 'docker compose up -d || docker-compose up -d' > install.log 2>&1 &
        ";

        try {
            $this->runHostCommand($script);
            return $this->success(['output' => 'Proses instalasi sedang berjalan di latar belakang. Silakan tunggu 1-5 menit hingga proses download selesai.'], "{$app['name']} sedang diinstall di background.");
        } catch (Throwable $e) {
            return $this->error('Gagal menginstall aplikasi: ' . $e->getMessage(), 500);
        }
    }
}
