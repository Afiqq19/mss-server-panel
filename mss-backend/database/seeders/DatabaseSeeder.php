<?php

namespace Database\Seeders;

use App\Models\AppLauncher;
use App\Models\User;
use Illuminate\Database\Seeder;
use Illuminate\Support\Facades\Hash;

class DatabaseSeeder extends Seeder
{
    /**
     * Seed the application's database.
     */
    public function run(): void
    {
        // 1. Akun Admin Default untuk Login Panel (Bab 5)
        User::updateOrCreate(
            ['email' => 'admin@mepal.local'],
            [
                'name' => 'MSS Panel Administrator',
                'password' => Hash::make('password123'),
            ]
        );

        // 2. Daftar Shortcut URL Dinamis App Launcher (Bab 4 & 7)
        $launchers = [
            [
                'name' => 'Portainer CE',
                'url' => 'https://portainer.xie.my.id',
                'icon' => 'docker',
                'category' => 'Infrastructure',
                'description' => 'Docker Container Management UI',
                'order' => 1,
                'is_active' => true,
            ],
            [
                'name' => 'Nextcloud NAS',
                'url' => 'https://nas.xie.my.id',
                'icon' => 'cloud',
                'category' => 'Storage',
                'description' => 'Private Cloud & NAS Server',
                'order' => 2,
                'is_active' => true,
            ],
            [
                'name' => 'E-Aspira DPM',
                'url' => 'https://easpira-dpm.xie.my.id',
                'icon' => 'school',
                'category' => 'Application',
                'description' => 'Sistem Aspirasi Mahasiswa DPM Polmed',
                'order' => 3,
                'is_active' => true,
            ],
            [
                'name' => 'phpMyAdmin',
                'url' => 'https://db.xie.my.id',
                'icon' => 'storage',
                'category' => 'Database',
                'description' => 'MySQL Web Administration Interface',
                'order' => 4,
                'is_active' => true,
            ],
        ];

        foreach ($launchers as $launcher) {
            AppLauncher::updateOrCreate(
                ['name' => $launcher['name']],
                $launcher
            );
        }
    }
}
