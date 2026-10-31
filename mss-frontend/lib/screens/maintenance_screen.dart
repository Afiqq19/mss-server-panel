import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../services/api_service.dart';
import '../providers/theme_provider.dart';

class MaintenanceScreen extends StatefulWidget {
  const MaintenanceScreen({super.key});

  @override
  State<MaintenanceScreen> createState() => _MaintenanceScreenState();
}

class _MaintenanceScreenState extends State<MaintenanceScreen> {
  List<Map<String, dynamic>> _tasks = [];
  bool _isLoading = true;
  String _activeTask = '';
  final Map<String, String> _taskOutputs = {};

  @override
  void initState() {
    super.initState();
    _tasks = [
      {
        'id': 'apt_clean',
        'name': 'Bersihkan Cache APT',
        'description': 'Menghapus file cache paket .deb di /var/cache/apt/archives yang tidak lagi diperlukan.',
        'command': 'apt-get clean',
        'danger': false,
        'icon': Icons.cleaning_services_rounded,
      },
      {
        'id': 'apt_autoremove',
        'name': 'Hapus Paket Dependensi Usang',
        'description': 'Menghapus paket pustaka (dependencies) yang otomatis terinstall tapi sudah tidak dipakai.',
        'command': 'apt-get autoremove -y',
        'danger': false,
        'icon': Icons.layers_clear_rounded,
      },
      {
        'id': 'docker_prune',
        'name': 'Bersihkan Docker Prune (Deep)',
        'description': 'Menghapus image menggantung (dangling), container mati, volume tak bernama, dan network.',
        'command': 'docker system prune -af',
        'danger': true,
        'icon': Icons.delete_sweep_rounded,
      },
      {
        'id': 'clear_journal',
        'name': 'Pangkas System Log Journal',
        'description': 'Menghapus log journal systemd yang lebih lawas dari 3 hari untuk menghemat ruang disk.',
        'command': 'journalctl --vacuum-time=3d',
        'danger': false,
        'icon': Icons.receipt_long_rounded,
      },
      {
        'id': 'clear_tmp',
        'name': 'Bersihkan File Sementara /tmp',
        'description': 'Menghapus file cache dan temporary di folder /tmp yang berumur lebih dari 7 hari.',
        'command': 'find /tmp -type f -mtime +7 -delete',
        'danger': false,
        'icon': Icons.folder_delete_rounded,
      },
      {
        'id': 'system_update',
        'name': 'Update Seluruh Paket OS',
        'description': 'Menjalankan apt-get update && apt-get upgrade -y untuk memperbarui kernel dan aplikasi server.',
        'command': 'apt-get update && apt-get upgrade -y',
        'danger': true,
        'icon': Icons.system_update_alt_rounded,
      },
    ];
    _isLoading = false;
  }

  Future<void> _executeTask(String taskId, String taskName, bool isDanger) async {
    if (isDanger) {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: const Color(0xFF0F172A),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: const BorderSide(color: Color(0xFF1E293B)),
          ),
          title: Row(
            children: const [
              Icon(Icons.warning_amber_rounded, color: Color(0xFFF43F5E), size: 24),
              SizedBox(width: 10),
              Text('Konfirmasi Eksekusi', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
            ],
          ),
          content: Text(
            'Anda akan menjalankan task "$taskName". Aksi ini berpotensi menghapus data cache/docker atau membutuhkan waktu beberapa menit. Lanjutkan?',
            style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13, height: 1.5),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Batal', style: TextStyle(color: Color(0xFF64748B))),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFF43F5E),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Ya, Lanjutkan'),
            ),
          ],
        ),
      );
      if (confirm != true) return;
    }

    setState(() {
      _activeTask = taskId;
      _taskOutputs[taskId] = '>> Memulai eksekusi task [$taskName]...\n>> Mengirim sinyal ke root host Toshiba...';
    });

    try {
      final api = Provider.of<ApiService>(context, listen: false);
      final result = await api.executeMaintenanceTask(taskId);
      if (mounted) {
        setState(() {
          _taskOutputs[taskId] = result['output'] ?? 'Selesai tanpa output';
        });
        _showToast('Task $taskName berhasil dijalankan!');
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _taskOutputs[taskId] = 'ERROR:\n$e';
        });
        _showToast('Error menjalankan $taskName: $e', isError: true);
      }
    } finally {
      if (mounted) {
        setState(() => _activeTask = '');
      }
    }
  }

  void _showToast(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(isError ? Icons.error_outline : Icons.check_circle_outline, color: Colors.white, size: 20),
            const SizedBox(width: 10),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: isError ? const Color(0xFFF43F5E) : const Color(0xFF10B981),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    final isMobile = MediaQuery.of(context).size.width < 768;

    return SingleChildScrollView(
      padding: EdgeInsets.all(isMobile ? 16 : 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Hero
          _buildHeader(themeProvider, isMobile),
          const SizedBox(height: 24),

          // Overview Tips Card
          _buildTipsCard(themeProvider, isMobile),
          const SizedBox(height: 28),

          // Tasks Grid
          LayoutBuilder(
            builder: (context, constraints) {
              final double cardWidth = constraints.maxWidth < 680
                  ? constraints.maxWidth
                  : (constraints.maxWidth < 1140 ? (constraints.maxWidth - 20) / 2 : (constraints.maxWidth - 40) / 3);

              return Wrap(
                spacing: 20,
                runSpacing: 20,
                children: _tasks.map((task) => _buildTaskCard(task, themeProvider, cardWidth)).toList(),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(ThemeProvider themeProvider, bool isMobile) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          padding: EdgeInsets.all(isMobile ? 18 : 24),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                themeProvider.primary.withOpacity(0.12),
                const Color(0xFF0F172A).withOpacity(0.8),
              ],
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: themeProvider.primary.withOpacity(0.25)),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [themeProvider.primary, themeProvider.secondary],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: themeProvider.glow.withOpacity(0.35),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Icon(Icons.handyman_rounded, color: Colors.white, size: 28),
              ),
              const SizedBox(width: 18),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Text(
                          'System Maintenance',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                            letterSpacing: 0.3,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFF10B981).withOpacity(0.15),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: const Color(0xFF10B981).withOpacity(0.3)),
                          ),
                          child: const Text(
                            'OS OPTIMIZER',
                            style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF10B981)),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Pembersihan cache, pemulihan ruang disk, dan pembaruan paket OS Ubuntu',
                      style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTipsCard(ThemeProvider themeProvider, bool isMobile) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A).withOpacity(0.85),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFF06B6D4).withOpacity(0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.lightbulb_outline_rounded, color: Color(0xFF06B6D4), size: 20),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Tips Perawatan Berkala Server Toshiba',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13.5),
                ),
                SizedBox(height: 2),
                Text(
                  'Jalankan APT Clean & Docker Prune seminggu sekali untuk mencegah disk NVMe penuh karena build artifacts.',
                  style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTaskCard(Map<String, dynamic> task, ThemeProvider themeProvider, double width) {
    final String id = task['id'];
    final String name = task['name'];
    final String description = task['description'];
    final String command = task['command'] ?? '';
    final bool isDanger = task['danger'] == true;
    final IconData icon = task['icon'] ?? Icons.settings_rounded;
    final bool isRunning = _activeTask == id;
    final String? output = _taskOutputs[id];

    final accentColor = isDanger ? const Color(0xFFF43F5E) : const Color(0xFF10B981);

    return SizedBox(
      width: width,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0xFF0F172A).withOpacity(0.85),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isDanger ? const Color(0xFFF43F5E).withOpacity(0.25) : Colors.white.withOpacity(0.08),
                width: 1.2,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.3),
                  blurRadius: 18,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Header with Icon and Badge
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: accentColor.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: accentColor.withOpacity(0.3)),
                            ),
                            child: Icon(icon, color: accentColor, size: 22),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: accentColor.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: accentColor.withOpacity(0.3)),
                            ),
                            child: Text(
                              isDanger ? 'PERINGATAN' : 'AMAN',
                              style: TextStyle(
                                color: accentColor,
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Text(
                        name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        description,
                        style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12.5, height: 1.4),
                      ),
                      const SizedBox(height: 10),
                      // Command snippet
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFF020617),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: const Color(0xFF1E293B)),
                        ),
                        child: Text(
                          command,
                          style: const TextStyle(
                            color: Color(0xFF06B6D4),
                            fontFamily: 'monospace',
                            fontSize: 11,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Terminal Output Window if ran
                if (output != null) ...[
                  Container(
                    width: double.infinity,
                    margin: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF020617),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFF1E293B)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // macOS window bar
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: const BoxDecoration(
                            color: Color(0xFF0B132B),
                            borderRadius: BorderRadius.vertical(top: Radius.circular(10)),
                          ),
                          child: Row(
                            children: [
                              Container(width: 8, height: 8, decoration: const BoxDecoration(color: Color(0xFFF43F5E), shape: BoxShape.circle)),
                              const SizedBox(width: 5),
                              Container(width: 8, height: 8, decoration: const BoxDecoration(color: Color(0xFFF59E0B), shape: BoxShape.circle)),
                              const SizedBox(width: 5),
                              Container(width: 8, height: 8, decoration: const BoxDecoration(color: Color(0xFF10B981), shape: BoxShape.circle)),
                              const Spacer(),
                              InkWell(
                                onTap: () {
                                  Clipboard.setData(ClipboardData(text: output));
                                  _showToast('Output berhasil disalin');
                                },
                                child: const Icon(Icons.copy_rounded, size: 13, color: Color(0xFF64748B)),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          constraints: const BoxConstraints(maxHeight: 140),
                          padding: const EdgeInsets.all(12),
                          child: SingleChildScrollView(
                            child: SelectableText(
                              output,
                              style: const TextStyle(
                                color: Color(0xFF34D399),
                                fontFamily: 'monospace',
                                fontSize: 11,
                                height: 1.4,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                ],

                // Action Button
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: SizedBox(
                    width: double.infinity,
                    height: 44,
                    child: ElevatedButton(
                      onPressed: isRunning || _activeTask.isNotEmpty ? null : () => _executeTask(id, name, isDanger),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isDanger ? const Color(0xFFF43F5E) : themeProvider.primary,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      child: isRunning
                          ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                          : Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(isDanger ? Icons.warning_rounded : Icons.play_arrow_rounded, size: 16),
                                const SizedBox(width: 6),
                                Text(
                                  isDanger ? 'Jalankan (Resiko)' : 'Jalankan Task',
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                ),
                              ],
                            ),
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
