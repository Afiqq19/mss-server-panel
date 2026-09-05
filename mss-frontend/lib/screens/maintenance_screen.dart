import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/api_service.dart';
import '../providers/theme_provider.dart';

class MaintenanceScreen extends StatefulWidget {
  const MaintenanceScreen({Key? key}) : super(key: key);

  @override
  _MaintenanceScreenState createState() => _MaintenanceScreenState();
}

class _MaintenanceScreenState extends State<MaintenanceScreen> {
  List<Map<String, dynamic>> _tasks = [];
  bool _isLoading = true;
  String _activeTask = '';
  Map<String, String> _taskOutputs = {};

  @override
  void initState() {
    super.initState();
    // Langsung pakai data hardcoded - tidak perlu fetch API untuk daftar task
    // karena daftar task sudah fixed. API hanya dipakai untuk EXECUTE task.
    _tasks = [
      {'id': 'apt_clean', 'name': 'Bersihkan Cache APT', 'description': 'Menghapus file cache paket apt yang tidak diperlukan (apt-get clean)', 'danger': false, 'icon': Icons.delete_sweep},
      {'id': 'apt_autoremove', 'name': 'Hapus Paket Tidak Digunakan', 'description': 'Menghapus paket dependensi yang tidak lagi diperlukan (apt-get autoremove -y)', 'danger': false, 'icon': Icons.layers_clear},
      {'id': 'docker_prune', 'name': 'Bersihkan Docker (Prune)', 'description': 'Menghapus image, container, volume, dan network Docker yang tidak terpakai', 'danger': true, 'icon': Icons.storage},
      {'id': 'clear_journal', 'name': 'Bersihkan System Log', 'description': 'Menghapus journal systemd yang lebih dari 3 hari (journalctl --vacuum-time=3d)', 'danger': false, 'icon': Icons.terminal},
      {'id': 'clear_tmp', 'name': 'Bersihkan /tmp', 'description': 'Menghapus file sementara di folder /tmp yang lebih dari 7 hari', 'danger': false, 'icon': Icons.delete},
      {'id': 'system_update', 'name': 'Update Sistem (apt upgrade)', 'description': 'Menjalankan apt-get update && apt-get upgrade -y untuk memperbarui seluruh paket OS', 'danger': true, 'icon': Icons.settings},
    ];
    _isLoading = false;
  }

  Future<void> _executeTask(String taskId, String taskName, bool isDanger) async {
    if (isDanger) {
      bool? confirm = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: const Color(0xFF1E293B),
          title: Row(
            children: const [
              Icon(Icons.warning_amber, color: Color(0xFFF43F5E)),
              SizedBox(width: 10),
              Text('Peringatan', style: TextStyle(color: Colors.white)),
            ],
          ),
          content: Text(
            'Anda akan menjalankan task "$taskName". Aksi ini mungkin menghapus data atau menghentikan layanan sementara. Lanjutkan?',
            style: const TextStyle(color: Color(0xFFCBD5E1)),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Batal', style: TextStyle(color: Color(0xFF94A3B8))),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFF43F5E)),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Ya, Lanjutkan', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      );
      if (confirm != true) return;
    }

    setState(() {
      _activeTask = taskId;
      _taskOutputs[taskId] = 'Memulai task...\n';
    });

    try {
      final api = Provider.of<ApiService>(context, listen: false);
      final result = await api.executeMaintenanceTask(taskId);
      setState(() {
        _taskOutputs[taskId] = result['output'] ?? 'Selesai tanpa output';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Task $taskName berhasil!'), backgroundColor: const Color(0xFF10B981)),
      );
    } catch (e) {
      setState(() {
        _taskOutputs[taskId] = 'Gagal: ${e.toString()}';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error menjalankan $taskName'), backgroundColor: const Color(0xFFF43F5E)),
      );
    } finally {
      setState(() {
        _activeTask = '';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();

    return SingleChildScrollView(
      padding: EdgeInsets.all(MediaQuery.of(context).size.width < 600 ? 16 : 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: themeProvider.primary.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.settings, color: themeProvider.primary, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text(
                      'System Maintenance',
                      style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                    Text(
                      'Pembersihan sistem, update paket, dan maintenance OS Ubuntu',
                      style: TextStyle(color: Color(0xFF94A3B8), fontSize: 14),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),

          if (_isLoading)
            Center(child: CircularProgressIndicator(color: themeProvider.primary))
          else if (_tasks.isEmpty)
            const Center(child: Text('Tidak ada task maintenance tersedia.', style: TextStyle(color: Colors.white)))
          else
            Center(
              child: Wrap(
                spacing: 24,
                runSpacing: 24,
                alignment: WrapAlignment.center,
                children: _tasks.map((task) => _buildTaskCard(task, themeProvider)).toList(),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTaskCard(Map<String, dynamic> task, ThemeProvider themeProvider) {
    final String id = task['id'];
    final String name = task['name'];
    final String description = task['description'];
    final bool isDanger = task['danger'] == true;
    final IconData icon = task['icon'] ?? Icons.settings;
    final bool isRunning = _activeTask == id;
    final String? output = _taskOutputs[id];

    return SizedBox(
      width: MediaQuery.of(context).size.width < 600 ? double.infinity : 400,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.02),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withOpacity(0.1)),
            ),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isDanger ? const Color(0xFFF43F5E).withOpacity(0.1) : themeProvider.primary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(icon, color: isDanger ? const Color(0xFFF43F5E) : themeProvider.primary, size: 24),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(name, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 16)),
                            const SizedBox(height: 4),
                            Text(description, style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12, height: 1.4)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                if (output != null)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    color: const Color(0xFF030712),
                    constraints: const BoxConstraints(maxHeight: 150),
                    child: SingleChildScrollView(
                      child: Text(
                        output,
                        style: const TextStyle(color: Color(0xFF34D399), fontFamily: 'monospace', fontSize: 11),
                      ),
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: isRunning || _activeTask.isNotEmpty ? null : () => _executeTask(id, name, isDanger),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isDanger ? const Color(0xFFF43F5E) : themeProvider.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      child: isRunning
                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                          : Text(isDanger ? 'Jalankan (Resiko)' : 'Jalankan Task', style: const TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
