<?php

namespace App\Http\Controllers;

use App\Models\User;
use App\Traits\ApiResponse;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Hash;
use Illuminate\Validation\ValidationException;

class AuthController extends Controller
{
    use ApiResponse;

    /**
     * Login dan generate Sanctum Bearer Token (Bab 5)
     */
    public function login(Request $request): JsonResponse
    {
        $request->validate([
            'email' => 'required|email',
            'password' => 'required|string',
        ]);

        $user = User::where('email', $request->email)->first();

        if (!$user || !Hash::check($request->password, $user->password)) {
            return $this->error('Kredensial yang diberikan tidak cocok.', 401);
        }

        // Hapus token lama jika perlu, lalu buat token baru
        $token = $user->createToken('mepal-auth-token')->plainTextToken;

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
