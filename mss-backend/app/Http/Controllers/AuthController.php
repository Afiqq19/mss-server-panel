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
            'email' => 'required|email|max:150',
            'password' => 'required|string|min:6|max:100',
        ]);

        $email = filter_var(trim($request->email), FILTER_SANITIZE_EMAIL);
        $user = User::where('email', $email)->first();

        // Timing-safe check & generic error message to prevent account enumeration
        if (!$user || !Hash::check($request->password, $user->password)) {
            // Mitigasi timing attack & brute-force delay (250ms)
            usleep(250000);
            Log::warning("Percobaan login gagal untuk: {$email} dari IP: " . $request->ip());
            return $this->error('Email atau kata sandi tidak valid.', 401);
        }

        // Hapus token lama untuk user ini agar sesi rapi dan aman
        $user->tokens()->where('name', 'mepal-auth-token')->delete();
        $token = $user->createToken('mepal-auth-token', ['*'], now()->addDays(7))->plainTextToken;

        return $this->success([
            'token' => $token,
            'token_type' => 'Bearer',
            'user' => [
                'id' => $user->id,
                'name' => $user->name,
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
