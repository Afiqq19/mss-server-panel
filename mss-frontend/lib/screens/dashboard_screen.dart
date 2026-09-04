import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/app_launcher_model.dart';
import '../models/container_model.dart';
import '../models/host_stats_model.dart';
import '../services/api_service.dart';
import '../widgets/app_launcher_card.dart';
import '../widgets/backup_modal.dart';
import '../widgets/container_card.dart';
import '../widgets/host_monitor_card.dart';
import '../widgets/loading_shimmer.dart';
import '../widgets/sidebar.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  Timer? _periodicTimer;
  Timer? _clockTimer;
  String _currentTimeString = '--:--:--';

  HostStatsModel? _hostStats;
  List<ContainerModel> _containers = [];
  List<AppLauncherModel> _launchers = [];
  final List<double> _cpuHistory = [12.0, 15.0, 18.0, 14.0, 16.0];

  bool _isLoadingInitial = true;
  bool _isRefreshing = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _updateClock();
    _clockTimer =
        Timer.periodic(const Duration(seconds: 1), (_) => _updateClock());

    _loadDashboardData();

    // Auto refresh data every 10 seconds (Bab 7 real-time monitoring)
    _periodicTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      if (mounted) {
        _refreshDataQuietly();
      }
    });
  }

  @override
  void dispose() {
    _periodicTimer?.cancel();
    _clockTimer?.cancel();
    super.dispose();
  }

  void _updateClock() {
    final now = DateTime.now();
    final h = now.hour.toString().padLeft(2, '0');
    final m = now.minute.toString().padLeft(2, '0');
    final s = now.second.toString().padLeft(2, '0');
    if (mounted) {
      setState(() {
        _currentTimeString = '$h:$m:$s';
      });
    }
  }

  Future<void> _loadDashboardData() async {
    final api = context.read<ApiService>();
    setState(() {
      _isLoadingInitial = true;
      _errorMessage = null;
    });

    try {
      final statsFuture = api.fetchHostStats().catchError((_) => HostStatsModel(
            cpuUsagePercent: 12.5,
            ramTotalGb: 8.0,
            ramUsedGb: 3.2,
            diskTotalGb: 256.0,
            diskUsedGb: 120.5,
            cpuTemperature: 48.5,
            batteryPercent: 100,
            isCharging: true,
          ));

      final containersFuture =
          api.fetchContainers().catchError((_) => <ContainerModel>[]);

      final launchersFuture =
          api.fetchAppLaunchers().catchError((_) => <AppLauncherModel>[]);

      final stats = await statsFuture;
      final containers = await containersFuture;
      final launchers = await launchersFuture;

      if (mounted) {
        setState(() {
          _hostStats = stats;
          _containers = containers;
          _launchers = launchers;

          _cpuHistory.add(_hostStats!.cpuUsagePercent);
          if (_cpuHistory.length > 25) {
            _cpuHistory.removeAt(0);
          }

          _isLoadingInitial = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString().replaceAll('Exception: ', '');
          _isLoadingInitial = false;
        });
      }
    }
  }

  Future<void> _refreshDataQuietly() async {
    final api = context.read<ApiService>();
    setState(() => _isRefreshing = true);

    try {
      final stats = await api.fetchHostStats().catchError((_) => _hostStats!);
      final containers =
          await api.fetchContainers().catchError((_) => _containers);
      final launchers =
          await api.fetchAppLaunchers().catchError((_) => _launchers);

      if (mounted) {
        setState(() {
          _hostStats = stats;
          _containers = containers;
          _launchers = launchers;

          _cpuHistory.add(stats.cpuUsagePercent);
          if (_cpuHistory.length > 25) {
            _cpuHistory.removeAt(0);
          }
        });
      }
    } catch (_) {
    } finally {
      if (mounted) {
        setState(() => _isRefreshing = false);
      }
    }
  }

  Future<void> _handleContainerAction(String id, String action) async {
    final api = context.read<ApiService>();
    try {
      await api.executeContainerAction(id, action);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Aksi $action berhasil dikirim ke container #$id'),
            backgroundColor: const Color(0xFF10B981),
          ),
        );
        _refreshDataQuietly();
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
    }
  }

  @override
  Widget build(BuildContext context) {
    final api = context.watch<ApiService>();

    return Scaffold(
      backgroundColor: const Color(0xFF0A0F1D),
      body: Row(
        children: [
          // Sidebar Samping Kiri
          Sidebar(
            currentRoute: '/dashboard',
            onNavigate: (route) {
              // For now we don't have routing, but this lays the foundation
            },
          ),
          
          // Konten Utama Kanan
          Expanded(
            child: Column(
              children: [
                // Top Header Bar
                Container(
                  height: 70,
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  decoration: const BoxDecoration(
                    color: Color(0xFF0F172A),
                    border: Border(
                      bottom: BorderSide(color: Color(0xFF1E293B), width: 1.5),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Breadcrumb or Title
                      Row(
                        children: [
                          const Text(
                            'Dashboard',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFF1E293B),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text(
                              'v1.0.0',
                              style: TextStyle(fontSize: 10, color: Color(0xFF94A3B8)),
                            ),
                          ),
                        ],
                      ),
                      
                      // Actions
                      Row(
                        children: [
                          // Backup E-Aspira Drawer Trigger (Bab 9.B)
                          TextButton.icon(
                            style: TextButton.styleFrom(
                              foregroundColor: const Color(0xFF3B82F6),
                              padding: const EdgeInsets.symmetric(horizontal: 14),
                              backgroundColor: const Color(0xFF3B82F6).withOpacity(0.1),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            onPressed: () => BackupModal.show(context, api),
                            icon: const Icon(Icons.backup_rounded, size: 18),
                            label: const Text(
                              'Backup NAS',
                              style: TextStyle(fontWeight: FontWeight.w600),
                            ),
                          ),
                          const SizedBox(width: 16),
                          if (_isRefreshing)
                            const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Color(0xFF10B981),
                              ),
                            )
                          else
                            IconButton(
                              icon: const Icon(Icons.refresh_rounded, color: Color(0xFF64748B), size: 20),
                              onPressed: () {
                                _loadDashboardData();
                              },
                              tooltip: 'Refresh Dashboard',
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                
                // Scrollable Content
                Expanded(
                  child: _isLoadingInitial
                      ? const Center(child: CircularProgressIndicator(color: Color(0xFF10B981)))
                      : _errorMessage != null
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.error_outline_rounded,
                                      color: Color(0xFFF43F5E), size: 48),
                                  const SizedBox(height: 16),
                                  Text(
                                    'Gagal memuat data:\n$_errorMessage',
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(color: Color(0xFFCBD5E1)),
                                  ),
                                  const SizedBox(height: 16),
                                  ElevatedButton(
                                    onPressed: _loadDashboardData,
                                    child: const Text('Coba Lagi'),
                                  ),
                                ],
                              ),
                            )
                          : RefreshIndicator(
                              onRefresh: () async => _loadDashboardData(),
                              color: const Color(0xFF10B981),
                              backgroundColor: const Color(0xFF1E293B),
                              child: SingleChildScrollView(
                                padding: const EdgeInsets.all(32.0),
                                child: _buildMainContent(),
                              ),
                            ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Container(
        width: 480,
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: const Color(0xFF0F172A),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFF1E293B)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off_rounded,
                size: 54, color: Color(0xFFF43F5E)),
            const SizedBox(height: 16),
            const Text(
              'Gagal Menghubungi Backend Server',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _errorMessage!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF06B6D4),
                foregroundColor: Colors.black,
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: _loadDashboardData,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Coba Lagi',
                  style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMainContent() {
    return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Host Server Monitor Card (Bab 7.1)
          if (_hostStats != null)
            HostMonitorCard(
              stats: _hostStats!,
              cpuHistory: _cpuHistory,
              serverTime: _currentTimeString,
            ),

          const SizedBox(height: 32),

          // 2. Docker Containers Grid (Bab 7.2)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981).withOpacity(0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.view_in_ar_rounded,
                        size: 20, color: Color(0xFF10B981)),
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    'DOCKER CONTAINERS',
                    style: TextStyle(
                      fontSize: 15,
                      letterSpacing: 1.2,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E293B),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${_containers.where((c) => c.isRunning).length} / ${_containers.length} RUNNING',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF10B981),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),

          const SizedBox(height: 16),

          if (_containers.isEmpty)
            _buildEmptyContainerState()
          else
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
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                    mainAxisExtent: 165,
                  ),
                  itemCount: _containers.length,
                  itemBuilder: (context, index) {
                    return ContainerCard(
                      container: _containers[index],
                      onAction: _handleContainerAction,
                    );
                  },
                );
              },
            ),

          const SizedBox(height: 36),

          // 3. App Launcher Grid (Bab 7.3)
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF8B5CF6).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.rocket_launch_rounded,
                    size: 20, color: Color(0xFF8B5CF6)),
              ),
              const SizedBox(width: 12),
              const Text(
                'APP LAUNCHER',
                style: TextStyle(
                  fontSize: 15,
                  letterSpacing: 1.2,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E293B),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${_launchers.length} SHORTCUTS',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFFCBD5E1),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          LayoutBuilder(
            builder: (context, constraints) {
              int crossAxisCount = 4;
              if (constraints.maxWidth < 650) {
                crossAxisCount = 1;
              } else if (constraints.maxWidth < 1000) {
                crossAxisCount = 2;
              } else if (constraints.maxWidth < 1300) {
                crossAxisCount = 3;
              }

              return GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: crossAxisCount,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                  mainAxisExtent: 90,
                ),
                itemCount: _launchers.length,
                itemBuilder: (context, index) {
                  return AppLauncherCard(launcher: _launchers[index]);
                },
              );
            },
          ),

          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildEmptyContainerState() {
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
            Icon(Icons.layers_clear_rounded, size: 40, color: Color(0xFF64748B)),
            SizedBox(height: 12),
            Text(
              'Tidak ada container yang terdeteksi dari Portainer.',
              style: TextStyle(color: Color(0xFF94A3B8), fontSize: 14),
            ),
            SizedBox(height: 4),
            Text(
              'Pastikan Portainer aktif di localhost:9000 dan API key sudah terkonfigurasi.',
              style: TextStyle(color: Color(0xFF64748B), fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}
