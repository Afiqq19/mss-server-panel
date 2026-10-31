import 'dart:ui';
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
  String? _activeActionService;
  List<dynamic> _services = [];
  List<dynamic> _processes = [];
  String _processFilter = '';

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
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

  Future<void> _actionService(String service, String action) async {
    setState(() => _activeActionService = '$service:$action');
    try {
      final api = Provider.of<ApiService>(context, listen: false);
      await api.post('/services/action', {
        'service': service,
        'action': action,
      });
      _showToast('Layanan $service berhasil di-$action');
      await _loadData();
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
      case 'nginx':
        return Icons.public_rounded;
      case 'mysql':
      case 'mariadb':
        return Icons.storage_rounded;
      case 'docker':
        return Icons.layers_rounded;
      case 'ssh':
        return Icons.key_rounded;
      default:
        return Icons.miscellaneous_services_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    final isMobile = MediaQuery.of(context).size.width < 768;

    final activeCount = _services.where((s) => s['status'] == 'active').length;

    return SingleChildScrollView(
      padding: EdgeInsets.all(isMobile ? 16 : 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Hero
          _buildHeader(themeProvider, isMobile, activeCount),
          const SizedBox(height: 28),

          if (_isLoading)
            Padding(
              padding: const EdgeInsets.all(60.0),
              child: Center(
                child: Column(
                  children: [
                    CircularProgressIndicator(color: themeProvider.primary),
                    const SizedBox(height: 16),
                    const Text('Memeriksa status systemd & top processes...', style: TextStyle(color: Color(0xFF94A3B8))),
                  ],
                ),
              ),
            )
          else ...[
            // Core Services Grid
            _buildServicesSection(themeProvider, isMobile),
            const SizedBox(height: 32),

            // Top Processes Table
            _buildTopProcessSection(themeProvider, isMobile),
          ],
        ],
      ),
    );
  }

  Widget _buildHeader(ThemeProvider themeProvider, bool isMobile, int activeCount) {
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
                child: const Icon(Icons.memory_rounded, color: Colors.white, size: 28),
              ),
              const SizedBox(width: 18),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Text(
                          'Services & Processes',
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
                          child: Text(
                            '$activeCount / ${_services.length} ACTIVE',
                            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF10B981)),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Monitoring systemd daemon Linux dan proses beban CPU/RAM',
                      style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
                    ),
                  ],
                ),
              ),
              IconButton.filledTonal(
                tooltip: 'Segarkan Status Layanan',
                style: IconButton.styleFrom(
                  backgroundColor: const Color(0xFF1E293B),
                  foregroundColor: Colors.white,
                ),
                onPressed: _loadData,
                icon: const Icon(Icons.refresh_rounded, size: 20),
              ),
            ],
          ),
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
              'DAEMON SERVICES (SYSTEMD)',
              style: TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.0,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        LayoutBuilder(
          builder: (context, constraints) {
            final double cardWidth = constraints.maxWidth < 640
                ? constraints.maxWidth
                : (constraints.maxWidth < 1100 ? (constraints.maxWidth - 16) / 2 : (constraints.maxWidth - 32) / 3);

            return Wrap(
              spacing: 16,
              runSpacing: 16,
              children: _services.map((svc) {
                final String name = svc['name'].toString();
                final bool isActive = svc['status'] == 'active';
                final statusColor = isActive ? const Color(0xFF10B981) : const Color(0xFFF43F5E);
                final bool isWorking = _activeActionService?.startsWith('$name:') ?? false;

                return SizedBox(
                  width: cardWidth,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(18),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                      child: Container(
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0F172A).withOpacity(0.85),
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                            color: isActive ? statusColor.withOpacity(0.3) : Colors.white.withOpacity(0.08),
                            width: 1.2,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: statusColor.withOpacity(isActive ? 0.08 : 0.02),
                              blurRadius: 16,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: statusColor.withOpacity(0.15),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: statusColor.withOpacity(0.3)),
                                  ),
                                  child: Icon(_getServiceIcon(name), color: statusColor, size: 22),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        name.toUpperCase(),
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 15,
                                          fontWeight: FontWeight.w800,
                                          letterSpacing: 0.5,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Row(
                                        children: [
                                          Container(
                                            width: 7,
                                            height: 7,
                                            decoration: BoxDecoration(
                                              shape: BoxShape.circle,
                                              color: statusColor,
                                              boxShadow: [
                                                BoxShadow(color: statusColor, blurRadius: 6, spreadRadius: 1),
                                              ],
                                            ),
                                          ),
                                          const SizedBox(width: 6),
                                          Text(
                                            isActive ? 'RUNNING / ACTIVE' : 'INACTIVE / STOPPED',
                                            style: TextStyle(
                                              color: statusColor,
                                              fontSize: 10.5,
                                              fontWeight: FontWeight.w700,
                                              letterSpacing: 0.3,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 18),
                            // Action Buttons
                            if (isWorking)
                              Center(
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 6.0),
                                  child: SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(strokeWidth: 2, color: themeProvider.primary),
                                  ),
                                ),
                              )
                            else
                              Row(
                                children: [
                                  Expanded(
                                    child: OutlinedButton.icon(
                                      onPressed: () => _actionService(name, isActive ? 'stop' : 'start'),
                                      icon: Icon(
                                        isActive ? Icons.stop_rounded : Icons.play_arrow_rounded,
                                        size: 16,
                                      ),
                                      label: Text(isActive ? 'Stop' : 'Start'),
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: isActive ? const Color(0xFFF43F5E) : const Color(0xFF10B981),
                                        side: BorderSide(
                                          color: (isActive ? const Color(0xFFF43F5E) : const Color(0xFF10B981)).withOpacity(0.35),
                                        ),
                                        padding: const EdgeInsets.symmetric(vertical: 8),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: ElevatedButton.icon(
                                      onPressed: () => _actionService(name, 'restart'),
                                      icon: const Icon(Icons.refresh_rounded, size: 16),
                                      label: const Text('Restart'),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: const Color(0xFF3B82F6).withOpacity(0.15),
                                        foregroundColor: const Color(0xFF60A5FA),
                                        elevation: 0,
                                        padding: const EdgeInsets.symmetric(vertical: 8),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(10),
                                          side: BorderSide(color: const Color(0xFF3B82F6).withOpacity(0.3)),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
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
          (p['user']?.toString().toLowerCase().contains(query) ?? false) ||
          (p['pid']?.toString().contains(query) ?? false);
    }).toList();

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
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF59E0B).withOpacity(0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.speed_rounded, size: 16, color: Color(0xFFF59E0B)),
                      ),
                      const SizedBox(width: 10),
                      const Text(
                        'TOP PROCESSES (CPU & RAM CONSUMPTION)',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.0,
                        ),
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
                      '${filtered.length} PROSES',
                      style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Search bar
              TextField(
                onChanged: (val) => setState(() => _processFilter = val.trim()),
                style: const TextStyle(color: Colors.white, fontSize: 13),
                decoration: InputDecoration(
                  hintText: 'Cari proses berdasarkan nama perintah, user, atau PID...',
                  hintStyle: TextStyle(color: Colors.white.withOpacity(0.25), fontSize: 13),
                  prefixIcon: const Icon(Icons.search_rounded, size: 18, color: Color(0xFF64748B)),
                  filled: true,
                  fillColor: const Color(0xFF020617).withOpacity(0.6),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: Colors.white.withOpacity(0.08)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: themeProvider.primary),
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Table
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  horizontalMargin: 12,
                  columnSpacing: 24,
                  headingRowColor: WidgetStateProperty.all(const Color(0xFF020617).withOpacity(0.6)),
                  columns: const [
                    DataColumn(label: Text('PID', style: TextStyle(color: Color(0xFF94A3B8), fontWeight: FontWeight.bold, fontSize: 12))),
                    DataColumn(label: Text('USER', style: TextStyle(color: Color(0xFF94A3B8), fontWeight: FontWeight.bold, fontSize: 12))),
                    DataColumn(label: Text('CPU %', style: TextStyle(color: Color(0xFF94A3B8), fontWeight: FontWeight.bold, fontSize: 12))),
                    DataColumn(label: Text('MEM %', style: TextStyle(color: Color(0xFF94A3B8), fontWeight: FontWeight.bold, fontSize: 12))),
                    DataColumn(label: Text('COMMAND', style: TextStyle(color: Color(0xFF94A3B8), fontWeight: FontWeight.bold, fontSize: 12))),
                  ],
                  rows: filtered.map((proc) {
                    final cpuStr = proc['cpu']?.toString().replaceAll('%', '') ?? '0';
                    final memStr = proc['mem']?.toString().replaceAll('%', '') ?? '0';
                    final double cpuVal = double.tryParse(cpuStr) ?? 0.0;
                    final double memVal = double.tryParse(memStr) ?? 0.0;

                    final cpuColor = cpuVal > 30 ? const Color(0xFFF43F5E) : (cpuVal > 10 ? const Color(0xFFF59E0B) : const Color(0xFF10B981));
                    final memColor = memVal > 20 ? const Color(0xFF8B5CF6) : const Color(0xFF06B6D4);

                    return DataRow(
                      cells: [
                        DataCell(
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFF1E293B),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              '#${proc['pid']}',
                              style: const TextStyle(color: Color(0xFFCBD5E1), fontFamily: 'monospace', fontSize: 11, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                        DataCell(
                          Text(
                            proc['user'].toString(),
                            style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12, fontWeight: FontWeight.w600),
                          ),
                        ),
                        DataCell(
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 8,
                                height: 8,
                                decoration: BoxDecoration(shape: BoxShape.circle, color: cpuColor),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                '${proc['cpu']}',
                                style: TextStyle(color: cpuColor, fontFamily: 'monospace', fontWeight: FontWeight.bold, fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                        DataCell(
                          Text(
                            '${proc['mem']}',
                            style: TextStyle(color: memColor, fontFamily: 'monospace', fontWeight: FontWeight.bold, fontSize: 12),
                          ),
                        ),
                        DataCell(
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: const Color(0xFF020617),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: const Color(0xFF1E293B)),
                            ),
                            child: Text(
                              proc['command'].toString(),
                              style: const TextStyle(color: Color(0xFFE2E8F0), fontFamily: 'monospace', fontSize: 12),
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
      ),
    );
  }
}
