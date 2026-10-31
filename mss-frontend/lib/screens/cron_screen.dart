import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../services/api_service.dart';
import '../providers/theme_provider.dart';

class CronScreen extends StatefulWidget {
  const CronScreen({super.key});

  @override
  State<CronScreen> createState() => _CronScreenState();
}

class _CronScreenState extends State<CronScreen> {
  bool _isLoading = true;
  bool _isSubmitting = false;
  List<dynamic> _crons = [];

  final _scheduleController = TextEditingController();
  final _commandController = TextEditingController();

  final List<Map<String, String>> _schedulePresets = [
    {'label': 'Tiap Menit', 'cron': '* * * * *'},
    {'label': 'Tiap 15 Mnt', 'cron': '*/15 * * * *'},
    {'label': 'Tiap Jam', 'cron': '0 * * * *'},
    {'label': 'Tengah Malam (00:00)', 'cron': '0 0 * * *'},
    {'label': 'Subuh (03:00)', 'cron': '0 3 * * *'},
    {'label': 'Mingguan (Minggu)', 'cron': '0 0 * * 0'},
  ];

  final List<String> _commandPresets = [
    'php /var/www/artisan schedule:run',
    'docker system prune -af --volumes',
    'certbot renew --quiet',
    'curl -fsS --retry 3 https://panel.xie.my.id/api/health',
  ];

  @override
  void initState() {
    super.initState();
    _loadCrons();
  }

  @override
  void dispose() {
    _scheduleController.dispose();
    _commandController.dispose();
    super.dispose();
  }

  Future<void> _loadCrons() async {
    setState(() => _isLoading = true);
    try {
      final api = Provider.of<ApiService>(context, listen: false);
      final res = await api.get('/cron');
      if (mounted) {
        setState(() {
          _crons = res['data']['crons'] ?? [];
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        final err = e.toString().replaceAll('Exception: ', '');
        if (!err.contains('Sesi login telah berakhir')) {
          _showToast(err, isError: true);
        }
      }
    }
  }

  Future<void> _addCron() async {
    final schedule = _scheduleController.text.trim();
    final command = _commandController.text.trim();

    if (schedule.isEmpty || command.isEmpty) {
      _showToast('Mohon isi jadwal dan perintah cron job', isError: true);
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      final api = Provider.of<ApiService>(context, listen: false);
      await api.post('/cron', {
        'schedule': schedule,
        'command': command,
      });
      _scheduleController.clear();
      _commandController.clear();
      _showToast('Cron job berhasil dijadwalkan!');
      await _loadCrons();
    } catch (e) {
      _showToast('Gagal tambah cron: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _confirmDelete(int index, String schedule, String command) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF0F172A),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: Color(0xFF1E293B)),
        ),
        title: Row(
          children: const [
            Icon(Icons.delete_outline_rounded, color: Color(0xFFF43F5E), size: 24),
            SizedBox(width: 10),
            Text('Hapus Cron Job?', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Perintah cron berikut akan dihapus secara permanen dari server crontab:',
              style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF020617),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFF1E293B)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(schedule, style: const TextStyle(color: Color(0xFF06B6D4), fontFamily: 'monospace', fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text(command, style: const TextStyle(color: Color(0xFFCBD5E1), fontFamily: 'monospace', fontSize: 12)),
                ],
              ),
            ),
          ],
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
            child: const Text('Hapus Sekarang'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        final api = Provider.of<ApiService>(context, listen: false);
        await api.post('/cron/delete', {'index': index});
        _showToast('Cron job berhasil dihapus');
        _loadCrons();
      } catch (e) {
        _showToast('Gagal hapus cron: $e', isError: true);
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
          // Header Hero Card
          _buildHeader(themeProvider, isMobile),
          const SizedBox(height: 24),

          // Main Cockpit Grid
          if (_isLoading)
            Padding(
              padding: const EdgeInsets.all(60.0),
              child: Center(
                child: Column(
                  children: [
                    CircularProgressIndicator(color: themeProvider.primary),
                    const SizedBox(height: 16),
                    const Text('Membaca crontab server host...', style: TextStyle(color: Color(0xFF94A3B8))),
                  ],
                ),
              ),
            )
          else
            LayoutBuilder(
              builder: (context, constraints) {
                final isWide = constraints.maxWidth >= 960;
                if (isWide) {
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(flex: 5, child: _buildAddForm(themeProvider)),
                      const SizedBox(width: 24),
                      Expanded(flex: 6, child: _buildCronList(themeProvider)),
                    ],
                  );
                }
                return Column(
                  children: [
                    _buildAddForm(themeProvider),
                    const SizedBox(height: 24),
                    _buildCronList(themeProvider),
                  ],
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
                child: const Icon(Icons.schedule_rounded, color: Colors.white, size: 28),
              ),
              const SizedBox(width: 18),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Text(
                          'Cron Jobs Scheduler',
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
                            'DAEMON ACTIVE',
                            style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF10B981)),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Otomatisasi tugas server Linux dengan crontab real-time',
                      style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
                    ),
                  ],
                ),
              ),
              if (!isMobile) ...[
                IconButton.filledTonal(
                  tooltip: 'Segarkan Data Crontab',
                  style: IconButton.styleFrom(
                    backgroundColor: const Color(0xFF1E293B),
                    foregroundColor: Colors.white,
                  ),
                  onPressed: _loadCrons,
                  icon: const Icon(Icons.refresh_rounded, size: 20),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAddForm(ThemeProvider themeProvider) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            color: const Color(0xFF0F172A).withOpacity(0.85),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withOpacity(0.08)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.4),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      color: themeProvider.primary.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(Icons.add_task_rounded, color: themeProvider.primary, size: 18),
                  ),
                  const SizedBox(width: 10),
                  const Text(
                    'Tambah Jadwal Baru',
                    style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              const SizedBox(height: 18),

              // Presets selector
              const Text(
                'PRESET JADWAL CEPAT',
                style: TextStyle(color: Color(0xFF64748B), fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.0),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _schedulePresets.map((preset) {
                  final isSelected = _scheduleController.text == preset['cron'];
                  return InkWell(
                    onTap: () {
                      setState(() => _scheduleController.text = preset['cron']!);
                    },
                    borderRadius: BorderRadius.circular(8),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: isSelected ? themeProvider.primary.withOpacity(0.2) : const Color(0xFF1E293B).withOpacity(0.6),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isSelected ? themeProvider.primary : Colors.white.withOpacity(0.08),
                        ),
                      ),
                      child: Text(
                        preset['label']!,
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                          color: isSelected ? themeProvider.primary : const Color(0xFFCBD5E1),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),

              const SizedBox(height: 18),

              // Schedule TextField
              TextField(
                controller: _scheduleController,
                style: const TextStyle(color: Colors.white, fontFamily: 'monospace', fontSize: 14),
                decoration: InputDecoration(
                  labelText: 'Format Jadwal Cron',
                  hintText: '* * * * *',
                  hintStyle: TextStyle(color: Colors.white.withOpacity(0.2)),
                  prefixIcon: const Icon(Icons.access_time_filled_rounded, color: Color(0xFF06B6D4), size: 20),
                  filled: true,
                  fillColor: const Color(0xFF020617).withOpacity(0.6),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.white.withOpacity(0.08)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: themeProvider.primary, width: 1.5),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              // Cheatsheet indicator
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFF020617),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFF1E293B)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.info_outline, size: 14, color: Color(0xFF64748B)),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Format: [Menit] [Jam] [Hari/Bln] [Bulan] [Hari/Minggu]',
                        style: TextStyle(color: Color(0xFF64748B), fontSize: 10.5, fontFamily: 'monospace'),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Command Presets
              const Text(
                'PRESET PERINTAH POPULER',
                style: TextStyle(color: Color(0xFF64748B), fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.0),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _commandPresets.map((cmd) {
                  return InkWell(
                    onTap: () => setState(() => _commandController.text = cmd),
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E293B).withOpacity(0.4),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.white.withOpacity(0.06)),
                      ),
                      child: Text(
                        cmd.split(' ').first == 'php' ? 'Laravel Scheduler' : cmd.split(' ').take(2).join(' '),
                        style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
                      ),
                    ),
                  );
                }).toList(),
              ),

              const SizedBox(height: 12),

              // Command TextField
              TextField(
                controller: _commandController,
                maxLines: 2,
                minLines: 1,
                style: const TextStyle(color: Colors.white, fontFamily: 'monospace', fontSize: 13),
                decoration: InputDecoration(
                  labelText: 'Perintah Shell / Bash',
                  hintText: '/usr/bin/php /var/www/script.php',
                  hintStyle: TextStyle(color: Colors.white.withOpacity(0.2)),
                  prefixIcon: const Icon(Icons.terminal_rounded, color: Color(0xFF10B981), size: 20),
                  filled: true,
                  fillColor: const Color(0xFF020617).withOpacity(0.6),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.white.withOpacity(0.08)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: themeProvider.primary, width: 1.5),
                  ),
                ),
              ),

              const SizedBox(height: 22),

              // Submit button
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: _isSubmitting ? null : _addCron,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: themeProvider.primary,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    shadowColor: themeProvider.glow.withOpacity(0.4),
                  ),
                  child: _isSubmitting
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: const [
                            Icon(Icons.save_rounded, size: 18),
                            SizedBox(width: 8),
                            Text('Simpan Jadwal Cron', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                          ],
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCronList(ThemeProvider themeProvider) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            color: const Color(0xFF0F172A).withOpacity(0.85),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withOpacity(0.08)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.4),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(7),
                        decoration: BoxDecoration(
                          color: const Color(0xFF10B981).withOpacity(0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.playlist_play_rounded, color: Color(0xFF10B981), size: 18),
                      ),
                      const SizedBox(width: 10),
                      const Text(
                        'Daftar Crontab Aktif',
                        style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E293B),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${_crons.length} JOBS',
                      style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),

              if (_crons.isEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
                  decoration: BoxDecoration(
                    color: const Color(0xFF020617).withOpacity(0.4),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFF1E293B)),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.hourglass_empty_rounded, size: 48, color: const Color(0xFF475569)),
                      const SizedBox(height: 14),
                      const Text(
                        'Belum ada cron job aktif',
                        style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Gunakan form di samping untuk menjadwalkan tugas otomatis pertama Anda.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Color(0xFF64748B), fontSize: 12),
                      ),
                    ],
                  ),
                )
              else
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _crons.length,
                  separatorBuilder: (ctx, i) => const SizedBox(height: 12),
                  itemBuilder: (ctx, i) {
                    final cron = _crons[i];
                    final schedule = cron['schedule']?.toString() ?? '* * * * *';
                    final command = cron['command']?.toString() ?? '';
                    final cronIndex = cron['id'] is int ? cron['id'] as int : i;

                    return Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFF020617).withOpacity(0.6),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFF1E293B)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: themeProvider.primary.withOpacity(0.12),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: themeProvider.primary.withOpacity(0.3)),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.timer_outlined, size: 13, color: themeProvider.primary),
                                    const SizedBox(width: 5),
                                    Text(
                                      schedule,
                                      style: TextStyle(
                                        color: themeProvider.primary,
                                        fontFamily: 'monospace',
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const Spacer(),
                              IconButton(
                                tooltip: 'Salin Perintah',
                                visualDensity: VisualDensity.compact,
                                icon: const Icon(Icons.copy_rounded, size: 16, color: Color(0xFF94A3B8)),
                                onPressed: () {
                                  Clipboard.setData(ClipboardData(text: command));
                                  _showToast('Perintah berhasil disalin');
                                },
                              ),
                              IconButton(
                                tooltip: 'Hapus Cron Job',
                                visualDensity: VisualDensity.compact,
                                icon: const Icon(Icons.delete_outline_rounded, size: 18, color: Color(0xFFF43F5E)),
                                onPressed: () => _confirmDelete(cronIndex, schedule, command),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: const Color(0xFF0B132B).withOpacity(0.5),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: SelectableText(
                              command,
                              style: const TextStyle(
                                color: Color(0xFFE2E8F0),
                                fontFamily: 'monospace',
                                fontSize: 12,
                                height: 1.4,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }
}
