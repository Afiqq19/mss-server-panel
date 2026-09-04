import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/backup_model.dart';
import '../services/api_service.dart';

class BackupScreen extends StatefulWidget {
  const BackupScreen({super.key});

  @override
  State<BackupScreen> createState() => _BackupScreenState();
}

class _BackupScreenState extends State<BackupScreen> {
  bool _isLoading = true;
  bool _isBackingUp = false;
  String? _errorMessage;
  BackupHistoryModel? _backupData;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _loadBackups();
    // Auto refresh every 30 seconds
    _refreshTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted && !_isBackingUp) _refreshBackupsQuietly();
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadBackups() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final api = context.read<ApiService>();
      final data = await api.fetchBackups();
      if (mounted) {
        setState(() {
          _backupData = data;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString().replaceAll('Exception: ', '');
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _refreshBackupsQuietly() async {
    try {
      final api = context.read<ApiService>();
      final data = await api.fetchBackups();
      if (mounted) {
        setState(() {
          _backupData = data;
        });
      }
    } catch (_) {}
  }

  Future<void> _triggerBackup(String project) async {
    if (_isBackingUp) return;

    setState(() => _isBackingUp = true);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
            ),
            const SizedBox(width: 12),
            Text('Memproses backup untuk proyek $project...'),
          ],
        ),
        backgroundColor: const Color(0xFF3B82F6),
        duration: const Duration(minutes: 1),
        behavior: SnackBarBehavior.floating,
      ),
    );

    try {
      final api = context.read<ApiService>();
      final msg = await api.triggerBackup(project: project);
      
      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(msg),
            backgroundColor: const Color(0xFF10B981),
            behavior: SnackBarBehavior.floating,
          ),
        );
        _loadBackups();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceAll('Exception: ', '')),
            backgroundColor: const Color(0xFFF43F5E),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isBackingUp = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(color: Color(0xFF3B82F6)));
    }

    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.cloud_off_rounded, color: Color(0xFFF43F5E), size: 48),
            const SizedBox(height: 16),
            const Text(
              'Gagal Membaca Storage NAS',
              style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              _errorMessage!,
              style: const TextStyle(color: Color(0xFF94A3B8)),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF3B82F6),
                foregroundColor: Colors.white,
              ),
              onPressed: _loadBackups,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Coba Lagi'),
            ),
          ],
        ),
      );
    }

    if (_backupData == null) return const SizedBox.shrink();

    return RefreshIndicator(
      onRefresh: _loadBackups,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildOverviewCards(),
            const SizedBox(height: 32),
            _buildProjectsGrid(),
            const SizedBox(height: 40),
            if (_backupData!.files.isEmpty)
              _buildEmptyState()
            else
              _buildHistoryTable(),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF1E293B)),
      ),
      child: Center(
        child: Column(
          children: const [
            Icon(Icons.folder_off_rounded, size: 40, color: Color(0xFF64748B)),
            SizedBox(height: 12),
            Text(
              'Belum ada file backup di NAS Nextcloud.',
              style: TextStyle(color: Color(0xFF94A3B8), fontSize: 14),
            ),
            SizedBox(height: 4),
            Text(
              'Klik tombol Backup di atas untuk membuat backup pertama Anda.',
              style: TextStyle(color: Color(0xFF64748B), fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOverviewCards() {
    return Row(
      children: [
        Expanded(
          child: _buildStatCard(
            title: 'TOTAL BACKUP',
            value: '${_backupData!.totalBackups} File',
            icon: Icons.folder_zip_rounded,
            color: const Color(0xFF3B82F6),
          ),
        ),
        const SizedBox(width: 24),
        Expanded(
          child: _buildStatCard(
            title: 'BACKUP TERAKHIR',
            value: _backupData!.lastBackup ?? 'Belum ada',
            icon: Icons.history_rounded,
            color: const Color(0xFF10B981),
            isDate: true,
          ),
        ),
        const SizedBox(width: 24),
        Expanded(
          child: _buildStatCard(
            title: 'TOTAL PROYEK',
            value: '${_backupData!.projects.length} Proyek',
            icon: Icons.layers_rounded,
            color: const Color(0xFF8B5CF6),
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
    bool isDate = false,
  }) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF1E293B)),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.05),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 28),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Color(0xFF94A3B8),
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  value,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: isDate ? 16 : 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProjectsGrid() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF8B5CF6).withOpacity(0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.source_rounded, size: 20, color: Color(0xFF8B5CF6)),
            ),
            const SizedBox(width: 12),
            const Text(
              'PROYEK DATABASE',
              style: TextStyle(
                fontSize: 15,
                letterSpacing: 1.2,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: 350,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            mainAxisExtent: 100,
          ),
          itemCount: _backupData!.projects.length,
          itemBuilder: (context, index) {
            final project = _backupData!.projects[index];
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B).withOpacity(0.5),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF334155)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.folder_shared_rounded, color: Color(0xFF64748B), size: 32),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      project,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF3B82F6),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      elevation: 0,
                    ),
                    onPressed: _isBackingUp ? null : () => _triggerBackup(project),
                    child: const Text('Backup', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildHistoryTable() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF10B981).withOpacity(0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.table_chart_rounded, size: 20, color: Color(0xFF10B981)),
            ),
            const SizedBox(width: 12),
            const Text(
              'RIWAYAT FILE NEXTCLOUD NAS',
              style: TextStyle(
                fontSize: 15,
                letterSpacing: 1.2,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: const Color(0xFF0F172A),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFF1E293B)),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: DataTable(
              headingRowColor: WidgetStateProperty.all(const Color(0xFF1E293B).withOpacity(0.8)),
              dataRowMinHeight: 60,
              dataRowMaxHeight: 60,
              columns: const [
                DataColumn(label: Text('NAMA FILE', style: TextStyle(color: Color(0xFF94A3B8), fontWeight: FontWeight.bold))),
                DataColumn(label: Text('PROYEK', style: TextStyle(color: Color(0xFF94A3B8), fontWeight: FontWeight.bold))),
                DataColumn(label: Text('UKURAN', style: TextStyle(color: Color(0xFF94A3B8), fontWeight: FontWeight.bold))),
                DataColumn(label: Text('TANGGAL BACKUP', style: TextStyle(color: Color(0xFF94A3B8), fontWeight: FontWeight.bold))),
                DataColumn(label: Text('STATUS', style: TextStyle(color: Color(0xFF94A3B8), fontWeight: FontWeight.bold))),
              ],
              rows: _backupData!.files.map((file) {
                return DataRow(
                  cells: [
                    DataCell(
                      Row(
                        children: [
                          const Icon(Icons.dataset_rounded, color: Color(0xFF3B82F6), size: 20),
                          const SizedBox(width: 12),
                          Flexible(
                            child: Text(
                              file.filename,
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                    DataCell(
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFF334155).withOpacity(0.5),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          file.project,
                          style: const TextStyle(color: Color(0xFFCBD5E1), fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                    DataCell(Text('${file.sizeMb.toStringAsFixed(2)} MB', style: const TextStyle(color: Color(0xFF94A3B8)))),
                    DataCell(Text(file.createdAt, style: const TextStyle(color: Color(0xFF94A3B8)))),
                    DataCell(
                      Row(
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              color: Color(0xFF10B981),
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Text('Tersimpan di NAS', style: TextStyle(color: Color(0xFF10B981), fontSize: 13, fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ),
                  ],
                );
              }).toList(),
            ),
          ),
        ),
      ],
    );
  }
}
