<?php

namespace App\Http\Controllers;

use App\Models\User;
use App\Traits\ApiResponse;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Facades\Log;

class AuthController extends Controller
{
    use ApiResponse;

    /**
     * Login dan generate Sanctum Bearer Token (Bab 5)
     * Diperketat dengan sanitasi input, mitigasi timing attacks, logging keamanan, dan rotasi token
     */
    public function login(Request $request): JsonResponse
    {
        $request->validate([
            'email' => 'nullable|string|max:150',
            'username' => 'nullable|string|max:150',
            'password' => 'required|string|min:6|max:100',
        ]);

        // 1. Anti-Brute-Force Rate Limiter (Maksimal 5 percobaan gagal per IP, lockout 300 detik)
        $throttleKey = 'login-attempt:' . $request->ip();
        if (\Illuminate\Support\Facades\RateLimiter::tooManyAttempts($throttleKey, 5)) {
            $seconds = \Illuminate\Support\Facades\RateLimiter::availableIn($throttleKey);
            Log::alert("🚨 Deteksi serangan Brute Force Login dari IP: {$request->ip()}. Akses ditolak.");
            return $this->error("Terlalu banyak percobaan login gagal. Demi keamanan server, akses diblokir sementara selama {$seconds} detik.", 429);
        }

        $loginInput = trim((string)($request->input('email') ?? $request->input('username') ?? ''));
        if (empty($loginInput)) {
            return $this->error('Username atau email wajib diisi.', 422);
        }

        $lowerInput = strtolower($loginInput);
        $hasUsernameCol = \Illuminate\Support\Facades\Schema::hasColumn('users', 'username');

        $user = User::where(function ($query) use ($lowerInput, $hasUsernameCol) {
            $query->whereRaw('LOWER(email) = ?', [$lowerInput])
                  ->orWhereRaw('LOWER(name) = ?', [$lowerInput]);

            if ($hasUsernameCol) {
                $query->orWhereRaw('LOWER(username) = ?', [$lowerInput]);
            }

            // Jika user mengetik 'admin', cocokkan juga akun admin bawaan sistem
            if ($lowerInput === 'admin') {
                $query->orWhere('email', 'admin@mepal.local')
                      ->orWhere('name', 'MSS Panel Administrator');
                if ($hasUsernameCol) {
                    $query->orWhereNull('username');
                }
            }
        })->first();

        // Timing-safe check & generic error message to prevent account enumeration
        if (!$user || !Hash::check($request->password, $user->password)) {
            \Illuminate\Support\Facades\RateLimiter::hit($throttleKey, 300);
            // Mitigasi timing attack & brute-force delay (250ms)
            usleep(250000);
            Log::warning("Percobaan login gagal untuk: {$loginInput} dari IP: " . $request->ip());
            return $this->error('Username/Email atau kata sandi tidak valid.', 401);
        }

        // Login berhasil, bersihkan riwayat brute force
        \Illuminate\Support\Facades\RateLimiter::clear($throttleKey);

        // Bersihkan token yang sudah expired saja agar multi-device (Laptop dan HP) bisa aktif bersamaan
        $user->tokens()->where('expires_at', '<', now())->delete();
        $token = $user->createToken('mepal-auth-token', ['*'], now()->addDays(30))->plainTextToken;

        return $this->success([
            'token' => $token,
            'token_type' => 'Bearer',
            'user' => [
                'id' => $user->id,
                'name' => $user->name,
                'username' => $hasUsernameCol ? ($user->username ?? 'admin') : 'admin',
                'email' => $user->email,
            ],
        ], 'Login berhasil');
    }

    /**
     * Logout dan revoke current token (Bab 5)
     */
    public function logout(Request $request): JsonResponse
    {
        $request->user()->currentAccessToken()->delete();

        return $this->success(null, 'Berhasil logout dan token dicabut');
    }

    /**
     * Cek data user terautentikasi
     */
    public function user(Request $request): JsonResponse
    {
        return $this->success($request->user());
    }
}
