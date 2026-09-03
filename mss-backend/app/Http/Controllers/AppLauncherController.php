<?php

namespace App\Http\Controllers;

use App\Models\AppLauncher;
use App\Traits\ApiResponse;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class AppLauncherController extends Controller
{
    use ApiResponse;

    /**
     * Menampilkan daftar semua shortcut aplikasi dinamis (Bab 4 & 7)
     */
    public function index(): JsonResponse
    {
        $launchers = AppLauncher::where('is_active', true)
            ->orderBy('order', 'asc')
            ->orderBy('id', 'asc')
            ->get();

        return $this->success($launchers, 'Daftar App Launcher berhasil dimuat');
    }

    /**
     * Menambahkan shortcut aplikasi baru
     */
    public function store(Request $request): JsonResponse
    {
        $validated = $request->validate([
            'name' => 'required|string|max:100',
            'url' => 'required|url',
            'icon' => 'nullable|string|max:100',
            'description' => 'nullable|string|max:255',
            'category' => 'nullable|string|max:50',
            'order' => 'nullable|integer',
            'is_active' => 'nullable|boolean',
        ]);

        $launcher = AppLauncher::create($validated);

        return $this->success($launcher, 'App Launcher berhasil ditambahkan', 201);
    }

    /**
     * Memperbarui shortcut aplikasi
     */
    public function update(Request $request, AppLauncher $appLauncher): JsonResponse
    {
        $validated = $request->validate([
            'name' => 'sometimes|required|string|max:100',
            'url' => 'sometimes|required|url',
            'icon' => 'nullable|string|max:100',
            'description' => 'nullable|string|max:255',
            'category' => 'nullable|string|max:50',
            'order' => 'nullable|integer',
            'is_active' => 'nullable|boolean',
        ]);

        $appLauncher->update($validated);

        return $this->success($appLauncher, 'App Launcher berhasil diperbarui');
    }

    /**
     * Menghapus shortcut aplikasi
     */
    public function destroy(AppLauncher $appLauncher): JsonResponse
    {
        $appLauncher->delete();

        return $this->success(null, 'App Launcher berhasil dihapus');
    }
}
