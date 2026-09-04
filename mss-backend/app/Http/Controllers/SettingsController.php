<?php

namespace App\Http\Controllers;

use Illuminate\Http\Request;
use Illuminate\Http\JsonResponse;
use App\Models\User;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Facades\File;

class SettingsController extends Controller
{
    /**
     * POST /api/settings/update-account
     */
    public function updateAccount(Request $request): JsonResponse
    {
        $request->validate([
            'username' => 'required|string',
            'current_password' => 'required|string',
            'new_password' => 'nullable|string|min:6',
        ]);

        $user = $request->user();

        if (!Hash::check($request->current_password, $user->password)) {
            return response()->json([
                'status' => 'error',
                'message' => 'Password saat ini salah.',
            ], 400);
        }

        $user->username = $request->username;
        if ($request->filled('new_password')) {
            $user->password = Hash::make($request->new_password);
        }
        $user->save();

        return response()->json([
            'status' => 'success',
            'message' => 'Akun berhasil diperbarui.',
        ]);
    }

    /**
     * POST /api/settings/update-env
     */
    public function updateEnv(Request $request): JsonResponse
    {
        $request->validate([
            'portainer_url' => 'required|url',
            'portainer_api_key' => 'required|string',
            'portainer_endpoint_id' => 'required|numeric',
        ]);

        $updates = [
            'PORTAINER_URL' => $request->portainer_url,
            'PORTAINER_API_KEY' => $request->portainer_api_key,
            'PORTAINER_ENDPOINT_ID' => $request->portainer_endpoint_id,
        ];

        try {
            $this->modifyEnv($updates);
            
            return response()->json([
                'status' => 'success',
                'message' => 'Konfigurasi Portainer berhasil diperbarui.',
            ]);
        } catch (\Exception $e) {
            return response()->json([
                'status' => 'error',
                'message' => 'Gagal memperbarui konfigurasi: ' . $e->getMessage(),
            ], 500);
        }
    }

    /**
     * Helper to write to .env file
     */
    private function modifyEnv(array $data)
    {
        $envPath = base_path('.env');
        
        if (!File::exists($envPath)) {
            throw new \Exception(".env file not found.");
        }

        $envContent = File::get($envPath);

        foreach ($data as $key => $value) {
            // Jika ada spasi, bungkus dengan kutip
            $escapedValue = preg_match('/\s/', $value) ? '"' . $value . '"' : $value;
            
            // Cek apakah key sudah ada di .env
            if (preg_match("/^{$key}=/m", $envContent)) {
                $envContent = preg_replace("/^{$key}=.*/m", "{$key}={$escapedValue}", $envContent);
            } else {
                $envContent .= "\n{$key}={$escapedValue}";
            }
        }

        File::put($envPath, $envContent);
    }
}
