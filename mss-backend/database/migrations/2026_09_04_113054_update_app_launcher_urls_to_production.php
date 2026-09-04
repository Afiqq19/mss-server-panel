<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Support\Facades\DB;

return new class extends Migration
{
    /**
     * Run the migrations.
     */
    public function up(): void
    {
        DB::table('app_launchers')->where('name', 'Portainer CE')->update(['url' => 'https://portainer.xie.my.id']);
        DB::table('app_launchers')->where('name', 'Nextcloud NAS')->update(['url' => 'https://nas.xie.my.id']);
        DB::table('app_launchers')->where('name', 'E-Aspira DPM')->update(['url' => 'https://easpira-dpm.xie.my.id']);
        DB::table('app_launchers')->where('name', 'phpMyAdmin')->update(['url' => 'https://db.xie.my.id']);
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        DB::table('app_launchers')->where('name', 'Portainer CE')->update(['url' => 'https://192.168.1.100:9443']);
        DB::table('app_launchers')->where('name', 'Nextcloud NAS')->update(['url' => 'http://localhost:8080']);
        DB::table('app_launchers')->where('name', 'E-Aspira DPM')->update(['url' => 'http://localhost:8000']);
        DB::table('app_launchers')->where('name', 'phpMyAdmin')->update(['url' => 'http://localhost:8081']);
    }
};
