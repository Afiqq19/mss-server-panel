import 'package:flutter/material.dart';
import '../models/backup_model.dart';
import '../services/api_service.dart';

class BackupModal extends StatefulWidget {
  final ApiService apiService;

  const BackupModal({super.key, required this.apiService});

  static void show(BuildContext context, ApiService apiService) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => BackupModal(apiService: apiService),
    );
  }

  @override
  State<BackupModal> createState() => _BackupModalState();
}

class _BackupModalState extends State<BackupModal> {
  late Future<BackupHistoryModel> _backupFuture;
  bool _isTriggering = false;
  String _selectedFilter = 'Semua';
  List<String> _availableProjects = ['E-Aspira', 'portofolio', 'Panel-MSS'];

  @override
  void initState() {
    super.initState();
    _loadBackups();
  }

  void _loadBackups() {
    _backupFuture = widget.apiService.fetchBackups().then((data) {
      if (mounted) {
        setState(() {
          _availableProjects = data.projects;
        });
      }
      return data;
    });
  }

  Future<void> _triggerBackup() async {
    String selectedOption = 'all';
    final customProjectController = TextEditingController();
    bool isCustom = false;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          return AlertDialog(
            backgroundColor: const Color(0xFF1E293B),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Row(
              children: const [
                Icon(Icons.cloud_upload, color: Color(0xFF06B6D4)),
                SizedBox(width: 10),
                Text('Trigger Backup NAS', style: TextStyle(color: Colors.white, fontSize: 18)),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Pilih proyek yang ada atau buat folder proyek baru di volume Nextcloud NAS:',
                    style: TextStyle(color: Color(0xFFCBD5E1), fontSize: 13),
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    value: selectedOption,
                    dropdownColor: const Color(0xFF0F172A),
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: 'Pilih Target Proyek',
                      labelStyle: const TextStyle(color: Color(0xFF06B6D4)),
                      filled: true,
                      fillColor: const Color(0xFF0B1120),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: Color(0xFF334155)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: Color(0xFF334155)),
                      ),
                    ),
                    items: [
                      const DropdownMenuItem(value: 'all', child: Text('🌐 Semua Proyek (All Folders)')),
                      ..._availableProjects.map((p) => DropdownMenuItem(
                        value: p,
                        child: Text('📁 $p'),
                      )),
                      const DropdownMenuItem(
                        value: '__custom__',
                        child: Text('➕ Buat Folder / Proyek Baru...'),
                      ),
                    ],
                    onChanged: (val) {
                      if (val != null) {
                        setModalState(() {
                          selectedOption = val;
                          isCustom = (val == '__custom__');
                        });
                      }
                    },
                  ),
                  if (isCustom) ...[
                    const SizedBox(height: 14),
                    TextField(
                      controller: customProjectController,
                      style: const TextStyle(color: Colors.white),
                      autofocus: true,
                      decoration: InputDecoration(
                        labelText: 'Nama Folder Proyek Baru',
                        hintText: 'misal: portofolio, web-klien, db-toko',
                        hintStyle: TextStyle(color: Colors.grey[600], fontSize: 12),
                        labelStyle: const TextStyle(color: Color(0xFF10B981)),
                        filled: true,
                        fillColor: const Color(0xFF0B1120),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: Color(0xFF10B981)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: Color(0xFF10B981)),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Batal', style: TextStyle(color: Color(0xFF94A3B8))),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF06B6D4),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: () {
                  if (isCustom && customProjectController.text.trim().isEmpty) {
                    return;
                  }
                  Navigator.pop(ctx, true);
                },
                child: const Text('Jalankan Backup', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
              ),
            ],
          );
        },
      ),
    );

    if (confirmed != true) return;

    String finalProject = selectedOption;
    if (selectedOption == '__custom__') {
      finalProject = customProjectController.text.trim();
    }

    setState(() => _isTriggering = true);
    try {
      final msg = await widget.apiService.triggerBackup(project: finalProject);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(msg),
            backgroundColor: const Color(0xFF10B981),
          ),
        );
        setState(() {
          _loadBackups();
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceAll('Exception: ', '')),
            backgroundColor: const Color(0xFFF43F5E),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isTriggering = false);
      }
    }
  }

  Color _getProjectBadgeColor(String project) {
    final lower = project.toLowerCase();
    if (lower.contains('aspira')) {
      return const Color(0xFF10B981);
    } else if (lower.contains('portofolio') || lower.contains('portfolio') || lower.contains('wordpress')) {
      return const Color(0xFF38BDF8);
    } else if (lower.contains('panel') || lower.contains('mss')) {
      return const Color(0xFFF59E0B);
    } else if (lower.contains('nextcloud')) {
      return const Color(0xFFA855F7);
    }
    return const Color(0xFF06B6D4);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: const BoxDecoration(
        color: Color(0xFF030712),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        border: Border(top: BorderSide(color: Color(0xFF1E293B), width: 1.5)),
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 48,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFF334155),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF06B6D4).withOpacity(0.12),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFF06B6D4).withOpacity(0.3)),
                    ),
                    child: const Icon(Icons.dns, color: Color(0xFF06B6D4), size: 22),
                  ),
                  const SizedBox(width: 14),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text(
                        'Pusat Backup Database NAS',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      Text(
                        'Nextcloud Storage: E-Aspira, WordPress & Semua Proyek',
                        style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                      ),
                    ],
                  ),
                ],
              ),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close, color: Color(0xFF64748B)),
              ),
            ],
          ),
          const SizedBox(height: 18),

          // Stats Bar & Trigger Button
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFF0B1120),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFF1E293B)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: FutureBuilder<BackupHistoryModel>(
                    future: _backupFuture,
                    builder: (context, snapshot) {
                      final count = snapshot.data?.totalBackups ?? 0;
                      final last = snapshot.data?.lastBackup ?? 'Belum ada data';
                      return Row(
                        children: [
                          _buildStatBadge('Total Berkas', '$count file', Icons.folder_zip),
                          const SizedBox(width: 24),
                          _buildStatBadge('Backup Terakhir', last, Icons.schedule),
                        ],
                      );
                    },
                  ),
                ),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF06B6D4),
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: _isTriggering ? null : _triggerBackup,
                  icon: _isTriggering
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                        )
                      : const Icon(Icons.play_circle_fill, size: 18),
                  label: Text(
                    _isTriggering ? 'Memproses...' : 'Trigger Backup',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Project Filter Chips (Dinamis dari Folder Proyek yang Ada)
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildFilterChip('Semua'),
                ..._availableProjects.map((proj) => Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child: _buildFilterChip(proj),
                )),
              ],
            ),
          ),
          const SizedBox(height: 12),
          const Divider(color: Color(0xFF1E293B)),
          const SizedBox(height: 8),

          // Backups List
          Expanded(
            child: FutureBuilder<BackupHistoryModel>(
              future: _backupFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(color: Color(0xFF06B6D4)),
                  );
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.info_outline, size: 40, color: Color(0xFFF59E0B)),
                        const SizedBox(height: 10),
                        Text(
                          snapshot.error.toString().replaceAll('Exception: ', ''),
                          style: const TextStyle(color: Color(0xFF94A3B8)),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 14),
                        OutlinedButton(
                          onPressed: () => setState(() => _loadBackups()),
                          child: const Text('Coba Lagi'),
                        ),
                      ],
                    ),
                  );
                }

                final allFiles = snapshot.data!.files;
                final filteredFiles = _selectedFilter == 'Semua'
                    ? allFiles
                    : allFiles.where((f) => f.project == _selectedFilter).toList();

                if (filteredFiles.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.inventory_2, size: 44, color: Color(0xFF475569)),
                        const SizedBox(height: 12),
                        Text(
                          _selectedFilter == 'Semua'
                              ? 'Belum ada berkas backup di volume Nextcloud NAS.'
                              : 'Tidak ada berkas backup untuk proyek $_selectedFilter.',
                          style: const TextStyle(color: Color(0xFF94A3B8)),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.separated(
                  itemCount: filteredFiles.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final file = filteredFiles[index];
                    final badgeColor = _getProjectBadgeColor(file.project);

                    return Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0B1120),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFF1E293B)),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: badgeColor.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(Icons.storage, color: badgeColor, size: 20),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: badgeColor.withOpacity(0.15),
                                        borderRadius: BorderRadius.circular(4),
                                        border: Border.all(color: badgeColor.withOpacity(0.4)),
                                      ),
                                      child: Text(
                                        file.project,
                                        style: TextStyle(
                                          color: badgeColor,
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        file.filename,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                          fontFamily: 'monospace',
                                          fontSize: 12,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  file.createdAt,
                                  style: const TextStyle(color: Color(0xFF64748B), fontSize: 11),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFF1E293B),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              '${file.sizeMb.toStringAsFixed(1)} MB',
                              style: const TextStyle(
                                color: Color(0xFF06B6D4),
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label) {
    final isSelected = _selectedFilter == label;
    return InkWell(
      onTap: () => setState(() => _selectedFilter = label),
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF06B6D4) : const Color(0xFF0B1120),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? const Color(0xFF06B6D4) : const Color(0xFF1E293B),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.black : const Color(0xFF94A3B8),
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  Widget _buildStatBadge(String title, String value, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 16, color: const Color(0xFF94A3B8)),
        const SizedBox(width: 6),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontSize: 10, color: Color(0xFF64748B))),
            Text(
              value,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
            ),
          ],
        ),
      ],
    );
  }
}
