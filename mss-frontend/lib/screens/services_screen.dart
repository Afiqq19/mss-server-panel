import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/api_service.dart';
import '../providers/theme_provider.dart';

class ServicesScreen extends StatefulWidget {
  const ServicesScreen({super.key});

  @override
  State<ServicesScreen> createState() => _ServicesScreenState();
}

class _ServicesScreenState extends State<ServicesScreen> {
  bool _isLoading = true;
  bool _isRefreshing = false;
  String? _activeActionService;
  List<dynamic> _services = [];
  List<dynamic> _processes = [];
  String _processFilter = '';

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData({bool showIndicator = true}) async {
    if (showIndicator) {
      setState(() => _isLoading = true);
    } else {
      setState(() => _isRefreshing = true);
    }

    try {
      final api = Provider.of<ApiService>(context, listen: false);
      final results = await Future.wait([
        api.get('/services'),
        api.get('/services/top'),
      ]);
      final svcRes = results[0];
      final procRes = results[1];
      if (mounted) {
        setState(() {
          _services = svcRes['data']['services'] ?? [];
          _processes = procRes['data']['processes'] ?? [];
          _isLoading = false;
          _isRefreshing = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isRefreshing = false;
        });
        final err = e.toString().replaceAll('Exception: ', '');
        if (!err.contains('Sesi login telah berakhir')) {
          _showToast(err, isError: true);
        }
      }
    }
  }

  Future<void> _actionService(String service, String action) async {
    final actionLabel = action.toUpperCase();

    // Dialog Konfirmasi sebelum eksekusi aksi berbahaya
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF0F172A),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: Color(0xFF1E293B)),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: action == 'stop'
                    ? const Color(0xFFF43F5E).withOpacity(0.15)
                    : const Color(0xFF06B6D4).withOpacity(0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                action == 'stop' ? Icons.warning_amber_rounded : Icons.help_outline_rounded,
                color: action == 'stop' ? const Color(0xFFF43F5E) : const Color(0xFF06B6D4),
                size: 22,
              ),
            ),
            const SizedBox(width: 12),
            Text(
              'Konfirmasi $actionLabel',
              style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: Text(
          'Apakah Anda yakin ingin mengeksekusi "$actionLabel" pada layanan "$service"?',
          style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 14, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal', style: TextStyle(color: Color(0xFF64748B))),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: action == 'stop'
                  ? const Color(0xFFF43F5E)
                  : (action == 'restart' ? const Color(0xFFF59E0B) : const Color(0xFF10B981)),
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Ya, $actionLabel', style: const TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    if (!mounted) return;
    setState(() => _activeActionService = '$service:$action');
    try {
      final api = Provider.of<ApiService>(context, listen: false);
      await api.post('/services/action', {
        'service': service,
        'action': action,
      });
      _showToast('Layanan $service berhasil di-$action!');
      await _loadData(showIndicator: false);
    } catch (e) {
      _showToast('Gagal $action $service: $e', isError: true);
    } finally {
      if (mounted) setState(() => _activeActionService = null);
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

  IconData _getServiceIcon(String name) {
    switch (name.toLowerCase()) {
      case 'docker':
        return Icons.layers_rounded;
      case 'ssh':
        return Icons.vpn_key_rounded;
      case 'cron':
        return Icons.schedule_rounded;
      case 'cloudflared':
        return Icons.cloud_sync_rounded;
      case 'mariadb':
      case 'mysql':
        return Icons.storage_rounded;
      case 'nginx':
        return Icons.dns_rounded;
      default:
        return Icons.miscellaneous_services_rounded;
    }
  }

  Color _getServiceAccent(String name) {
    switch (name.toLowerCase()) {
      case 'docker':
        return const Color(0xFF0284C7);
      case 'ssh':
        return const Color(0xFFF59E0B);
      case 'cron':
        return const Color(0xFF8B5CF6);
      case 'cloudflared':
        return const Color(0xFF06B6D4);
      case 'mariadb':
      case 'mysql':
        return const Color(0xFF10B981);
      case 'nginx':
        return const Color(0xFF14B8A6);
      default:
        return const Color(0xFF64748B);
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    final isMobile = MediaQuery.of(context).size.width < 768;

    final activeCount = _services.where((s) => s['status'] == 'active').length;

    return SingleChildScrollView(
      padding: EdgeInsets.all(isMobile ? 16 : 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Hero
          _buildHeader(themeProvider, isMobile, activeCount),
          const SizedBox(height: 24),

          if (_isLoading)
            Padding(
              padding: const EdgeInsets.all(60.0),
              child: Center(
                child: Column(
                  children: [
                    CircularProgressIndicator(color: themeProvider.primary),
                    const SizedBox(height: 16),
                    const Text(
                      'Memeriksa status daemon Linux & beban proses CPU...',
                      style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
                    ),
                  ],
                ),
              ),
            )
          else ...[
            // Core Services Grid
            _buildServicesSection(themeProvider, isMobile),
            const SizedBox(height: 28),

            // Top Processes Table
            _buildTopProcessSection(themeProvider, isMobile),
          ],
        ],
      ),
    );
  }

  Widget _buildHeader(ThemeProvider themeProvider, bool isMobile, int activeCount) {
    return RepaintBoundary(
      child: Container(
        padding: EdgeInsets.all(isMobile ? 16 : 22),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              themeProvider.primary.withOpacity(0.12),
              const Color(0xFF0F172A).withOpacity(0.85),
            ],
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: themeProvider.primary.withOpacity(0.25)),
          boxShadow: [
            BoxShadow(
              color: themeProvider.glow.withOpacity(0.15),
              blurRadius: 18,
              offset: const Offset(0, 4),
            ),
          ],
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
              child: const Icon(Icons.memory_rounded, color: Colors.white, size: 26),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Text(
                        'Services & Processes',
                        style: TextStyle(
                          fontSize: 19,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          letterSpacing: 0.3,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
                        decoration: BoxDecoration(
                          color: const Color(0xFF10B981).withOpacity(0.15),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: const Color(0xFF10B981).withOpacity(0.35)),
                        ),
                        child: Text(
                          '$activeCount / ${_services.length} ACTIVE',
                          style: const TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF10B981),
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  const Text(
                    'Pemantauan status daemon Linux (systemd) dan task manager beban CPU/RAM',
                    style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12.5),
                  ),
                ],
              ),
            ),
            IconButton(
              tooltip: 'Segarkan Status Layanan',
              style: IconButton.styleFrom(
                backgroundColor: const Color(0xFF1E293B),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: _isRefreshing ? null : () => _loadData(showIndicator: false),
              icon: _isRefreshing
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF06B6D4)),
                    )
                  : const Icon(Icons.refresh_rounded, size: 20, color: Color(0xFF06B6D4)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildServicesSection(ThemeProvider themeProvider, bool isMobile) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: themeProvider.primary.withOpacity(0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(Icons.dns_rounded, size: 16, color: themeProvider.primary),
            ),
            const SizedBox(width: 10),
            const Text(
              'DAEMON SERVICES (SYSTEMD & DAEMON HOST)',
              style: TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.8,
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        LayoutBuilder(
          builder: (context, constraints) {
            int crossAxisCount = 3;
            if (constraints.maxWidth < 650) {
              crossAxisCount = 1;
            } else if (constraints.maxWidth < 1100) {
              crossAxisCount = 2;
            }

            return GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: crossAxisCount,
                crossAxisSpacing: 14,
                mainAxisSpacing: 14,
                mainAxisExtent: 185,
              ),
              itemCount: _services.length,
              itemBuilder: (context, index) {
                final svc = _services[index];
                final String name = svc['name'].toString();
                final String label = svc['label']?.toString() ?? name.toUpperCase();
                final String desc = svc['description']?.toString() ?? 'Layanan sistem Linux host';
                final bool isActive = svc['status'] == 'active';
                final statusColor = isActive ? const Color(0xFF10B981) : const Color(0xFFF43F5E);
                final accent = _getServiceAccent(name);
                final bool isWorking = _activeActionService?.startsWith('$name:') ?? false;

                return RepaintBoundary(
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          const Color(0xFF0F172A).withOpacity(0.92),
                          const Color(0xFF090E1A).withOpacity(0.85),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: isActive ? accent.withOpacity(0.35) : statusColor.withOpacity(0.3),
                        width: 1.2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: (isActive ? accent : statusColor).withOpacity(0.06),
                          blurRadius: 14,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Row 1: Icon, Nama, Status
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(9),
                              decoration: BoxDecoration(
                                color: accent.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: accent.withOpacity(0.35)),
                              ),
                              child: Icon(_getServiceIcon(name), color: accent, size: 20),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    label,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 14.5,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 0.2,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    desc,
                                    style: const TextStyle(
                                      color: Color(0xFF94A3B8),
                                      fontSize: 10.5,
                                      height: 1.3,
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),

                        // Status Badge Row
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                          decoration: BoxDecoration(
                            color: statusColor.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: statusColor.withOpacity(0.3)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 6,
                                height: 6,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: statusColor,
                                  boxShadow: [
                                    BoxShadow(color: statusColor.withOpacity(0.6), blurRadius: 6),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                isActive ? 'AKTIF BERJALAN' : 'NON-AKTIF / BERHENTI',
                                style: TextStyle(
                                  color: statusColor,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ],
                          ),
                        ),

                        // Action Buttons Bar
                        if (isWorking)
                          const Center(
                            child: SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF06B6D4)),
                            ),
                          )
                        else
                          Row(
                            children: [
                              Expanded(
                                child: InkWell(
                                  onTap: () => _actionService(name, isActive ? 'stop' : 'start'),
                                  borderRadius: BorderRadius.circular(9),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(vertical: 6.5),
                                    decoration: BoxDecoration(
                                      color: (isActive ? const Color(0xFFF43F5E) : const Color(0xFF10B981)).withOpacity(0.12),
                                      borderRadius: BorderRadius.circular(9),
                                      border: Border.all(
                                        color: (isActive ? const Color(0xFFF43F5E) : const Color(0xFF10B981)).withOpacity(0.35),
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          isActive ? Icons.stop_rounded : Icons.play_arrow_rounded,
                                          size: 14,
                                          color: isActive ? const Color(0xFFF43F5E) : const Color(0xFF10B981),
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          isActive ? 'Stop' : 'Start',
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w700,
                                            color: isActive ? const Color(0xFFF43F5E) : const Color(0xFF10B981),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: InkWell(
                                  onTap: () => _actionService(name, 'restart'),
                                  borderRadius: BorderRadius.circular(9),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(vertical: 6.5),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF38BDF8).withOpacity(0.12),
                                      borderRadius: BorderRadius.circular(9),
                                      border: Border.all(color: const Color(0xFF38BDF8).withOpacity(0.35)),
                                    ),
                                    child: const Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(Icons.refresh_rounded, size: 14, color: Color(0xFF38BDF8)),
                                        SizedBox(width: 4),
                                        Text(
                                          'Restart',
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w700,
                                            color: Color(0xFF38BDF8),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        ),
      ],
    );
  }

  Widget _buildTopProcessSection(ThemeProvider themeProvider, bool isMobile) {
    final filtered = _processes.where((p) {
      if (_processFilter.isEmpty) return true;
      final query = _processFilter.toLowerCase();
      return (p['command']?.toString().toLowerCase().contains(query) ?? false) ||
          (p['friendly']?.toString().toLowerCase().contains(query) ?? false) ||
          (p['user']?.toString().toLowerCase().contains(query) ?? false) ||
          (p['pid']?.toString().contains(query) ?? false);
    }).toList();

    return RepaintBoundary(
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: const Color(0xFF0F172A).withOpacity(0.9),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFF1E293B)),
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
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(7),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF59E0B).withOpacity(0.15),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFF59E0B).withOpacity(0.35)),
                      ),
                      child: const Icon(Icons.speed_rounded, size: 18, color: Color(0xFFF59E0B)),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'TOP PROCESSES (TASK MONITOR BEBAN CPU & RAM)',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.8,
                          ),
                        ),
                        const SizedBox(height: 2),
                        const Text(
                          'Daftar proses host Linux yang aktif menggunakan resource hardware',
                          style: TextStyle(color: Color(0xFF94A3B8), fontSize: 11),
                        ),
                      ],
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E293B),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFF334155)),
                  ),
                  child: Text(
                    '${filtered.length} PROSES TERPANTAU',
                    style: const TextStyle(
                      color: Color(0xFF38BDF8),
                      fontSize: 10.5,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Search bar
            Container(
              height: 42,
              decoration: BoxDecoration(
                color: const Color(0xFF020617).withOpacity(0.6),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF1E293B)),
              ),
              child: TextField(
                onChanged: (val) => setState(() => _processFilter = val.trim()),
                style: const TextStyle(color: Colors.white, fontSize: 13),
                decoration: InputDecoration(
                  hintText: 'Cari proses berdasarkan nama perintah, user, atau PID (contoh: node, mariadb, root)...',
                  hintStyle: const TextStyle(color: Color(0xFF64748B), fontSize: 12.5),
                  prefixIcon: const Icon(Icons.search_rounded, size: 18, color: Color(0xFF06B6D4)),
                  suffixIcon: _processFilter.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.close_rounded, size: 16, color: Color(0xFF94A3B8)),
                          onPressed: () => setState(() => _processFilter = ''),
                        )
                      : null,
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Process Table
            if (filtered.isEmpty)
              Container(
                padding: const EdgeInsets.all(32),
                alignment: Alignment.center,
                child: const Text(
                  'Tidak ada proses yang sesuai dengan filter pencarian.',
                  style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
                ),
              )
            else
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  horizontalMargin: 12,
                  columnSpacing: 22,
                  headingRowColor: WidgetStateProperty.all(const Color(0xFF020617).withOpacity(0.7)),
                  dataRowMinHeight: 52,
                  dataRowMaxHeight: 56,
                  columns: const [
                    DataColumn(label: Text('PID', style: TextStyle(color: Color(0xFF94A3B8), fontWeight: FontWeight.bold, fontSize: 11.5))),
                    DataColumn(label: Text('USER', style: TextStyle(color: Color(0xFF94A3B8), fontWeight: FontWeight.bold, fontSize: 11.5))),
                    DataColumn(label: Text('PERINTAH & LAYANAN', style: TextStyle(color: Color(0xFF94A3B8), fontWeight: FontWeight.bold, fontSize: 11.5))),
                    DataColumn(label: Text('BEBAN CPU %', style: TextStyle(color: Color(0xFF94A3B8), fontWeight: FontWeight.bold, fontSize: 11.5))),
                    DataColumn(label: Text('BEBAN MEM %', style: TextStyle(color: Color(0xFF94A3B8), fontWeight: FontWeight.bold, fontSize: 11.5))),
                  ],
                  rows: filtered.map((proc) {
                    final cpuStr = proc['cpu']?.toString().replaceAll('%', '') ?? '0';
                    final memStr = proc['mem']?.toString().replaceAll('%', '') ?? '0';
                    final double cpuVal = double.tryParse(cpuStr) ?? 0.0;
                    final double memVal = double.tryParse(memStr) ?? 0.0;

                    final cpuColor = cpuVal > 50
                        ? const Color(0xFFF43F5E)
                        : (cpuVal > 15 ? const Color(0xFFF59E0B) : const Color(0xFF10B981));
                    final memColor = memVal > 20 ? const Color(0xFF8B5CF6) : const Color(0xFF06B6D4);

                    final String comm = proc['command']?.toString() ?? '-';
                    final String friendly = proc['friendly']?.toString() ?? 'Proses Sistem';

                    return DataRow(
                      cells: [
                        // PID
                        DataCell(
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                            decoration: BoxDecoration(
                              color: const Color(0xFF1E293B),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              '#${proc['pid']}',
                              style: const TextStyle(
                                color: Color(0xFF38BDF8),
                                fontFamily: 'monospace',
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                        // USER
                        DataCell(
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                            decoration: BoxDecoration(
                              color: const Color(0xFF020617).withOpacity(0.5),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: const Color(0xFF1E293B)),
                            ),
                            child: Text(
                              proc['user'].toString(),
                              style: const TextStyle(
                                color: Color(0xFFCBD5E1),
                                fontSize: 11.5,
                                fontFamily: 'monospace',
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                        // COMMAND & FRIENDLY LABEL
                        DataCell(
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    comm,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontFamily: 'monospace',
                                      fontWeight: FontWeight.w800,
                                      fontSize: 12.5,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF06B6D4).withOpacity(0.12),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      friendly,
                                      style: const TextStyle(
                                        color: Color(0xFF38BDF8),
                                        fontSize: 9.5,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        // CPU USAGE BAR + TEXT
                        DataCell(
                          SizedBox(
                            width: 140,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      '${proc['cpu']}',
                                      style: TextStyle(
                                        color: cpuColor,
                                        fontFamily: 'monospace',
                                        fontWeight: FontWeight.w800,
                                        fontSize: 11.5,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 3),
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(4),
                                  child: LinearProgressIndicator(
                                    value: (cpuVal / 100).clamp(0.02, 1.0),
                                    backgroundColor: const Color(0xFF1E293B),
                                    valueColor: AlwaysStoppedAnimation<Color>(cpuColor),
                                    minHeight: 4,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        // MEM USAGE BAR + TEXT
                        DataCell(
                          SizedBox(
                            width: 120,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      '${proc['mem']}',
                                      style: TextStyle(
                                        color: memColor,
                                        fontFamily: 'monospace',
                                        fontWeight: FontWeight.w800,
                                        fontSize: 11.5,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 3),
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(4),
                                  child: LinearProgressIndicator(
                                    value: (memVal / 100).clamp(0.02, 1.0),
                                    backgroundColor: const Color(0xFF1E293B),
                                    valueColor: AlwaysStoppedAnimation<Color>(memColor),
                                    minHeight: 4,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    );
                  }).toList(),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

