<?php

use Illuminate\Foundation\Inspiring;
use Illuminate\Support\Facades\Artisan;
use App\Models\User;
use Illuminate\Support\Facades\Hash;

Artisan::command('inspire', function () {
    $this->comment(Inspiring::quote());
})->purpose('Display an inspiring quote');

Artisan::command('admin:set-password {password} {--email=admin@mepal.local}', function ($password) {
    $email = $this->option('email');
    $user = User::where('email', $email)->first();
    if (!$user) {
        $user = new User();
        $user->email = $email;
        $user->name = 'MSS Panel Administrator';
    }
    $user->password = Hash::make($password);
    $user->save();
    $this->info("✓ Sukses! Password admin [{$email}] berhasil diatur ulang.");
})->purpose('Ganti kata sandi admin panel secara aman via CLI terminal');

Artisan::command('admin:create {email} {password} {--name=MSS Panel Administrator}', function ($email, $password) {
    $user = User::updateOrCreate(
        ['email' => $email],
        [
            'name' => $this->option('name'),
            'password' => Hash::make($password),
        ]
    );
    $this->info("✓ Akun admin [{$email}] berhasil disimpan.");
})->purpose('Buat atau perbarui akun admin panel');
