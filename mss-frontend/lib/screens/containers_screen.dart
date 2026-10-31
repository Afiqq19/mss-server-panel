import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/container_model.dart';
import '../services/api_service.dart';
import '../widgets/container_card.dart';

class ContainersScreen extends StatefulWidget {
  const ContainersScreen({super.key});

  @override
  State<ContainersScreen> createState() => _ContainersScreenState();
}

class _ContainersScreenState extends State<ContainersScreen> {
  bool _isLoading = true;
  bool _isRefreshing = false;
  String? _errorMessage;
  List<ContainerModel> _containers = [];
  String _searchQuery = '';
  String _filterStatus = 'all'; // all, running, stopped
  String _viewMode = 'grouped'; // grouped, grid
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _loadContainers();
    _refreshTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      if (mounted) _refreshQuietly();
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadContainers() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final api = context.read<ApiService>();
      final data = await api.fetchContainers(forceRefresh: true);
      if (mounted) {
        setState(() {
          _containers = data;
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

  Future<void> _refreshQuietly() async {
    try {
      final api = context.read<ApiService>();
      final data = await api.fetchContainers(forceRefresh: true);
      if (mounted) setState(() => _containers = data);
    } catch (_) {}
  }

  Future<void> _manualRefresh() async {
    setState(() => _isRefreshing = true);
    final api = context.read<ApiService>();
    api.clearCache('containers');
    try {
      final data = await api.fetchContainers(forceRefresh: true);
      if (mounted) {
        setState(() {
          _containers = data;
          _isRefreshing = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isRefreshing = false);
      }
    }
  }

  Future<void> _handleAction(String id, String action) async {
    final api = context.read<ApiService>();
    try {
      await api.executeContainerAction(id, action);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
                const SizedBox(width: 10),
                Text('Aksi "$action" berhasil dikirim ke container!'),
              ],
            ),
            backgroundColor: const Color(0xFF10B981),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
        _refreshQuietly();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceAll('Exception: ', '')),
            backgroundColor: const Color(0xFFF43F5E),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    }
  }

  List<ContainerModel> get _filteredContainers {
    return _containers.where((c) {
      final q = _searchQuery.toLowerCase();
      final matchSearch = q.isEmpty ||
          c.name.toLowerCase().contains(q) ||
          c.image.toLowerCase().contains(q) ||
          c.ports.toLowerCase().contains(q) ||
          c.stackName.toLowerCase().contains(q) ||
          c.role.toLowerCase().contains(q) ||
          c.pairName.toLowerCase().contains(q) ||
          c.pairRelationBadge.toLowerCase().contains(q);
      final matchFilter = _filterStatus == 'all' ||
          (_filterStatus == 'running' && c.isRunning) ||
          (_filterStatus == 'stopped' && !c.isRunning);
      return matchSearch && matchFilter;
    }).toList();
  }

  Map<String, List<ContainerModel>> get _groupedContainers {
    final filtered = _filteredContainers;
    final map = <String, List<ContainerModel>>{};
    for (final c in filtered) {
      map.putIfAbsent(c.stackName, () => []).add(c);
    }
    return map;
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF0F172A),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFF06B6D4).withOpacity(0.3)),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF06B6D4).withOpacity(0.15),
                    blurRadius: 30,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: const SizedBox(
                width: 32,
                height: 32,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF06B6D4)),
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Memindai Docker Socket & Portainer...',
              style: TextStyle(
                color: Color(0xFF94A3B8),
                fontSize: 13,
                fontWeight: FontWeight.w500,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Container(
          margin: const EdgeInsets.all(24),
          padding: const EdgeInsets.all(32),
          constraints: const BoxConstraints(maxWidth: 480),
          decoration: BoxDecoration(
            color: const Color(0xFF0F172A).withOpacity(0.9),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: const Color(0xFFF43F5E).withOpacity(0.4)),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFF43F5E).withOpacity(0.15),
                blurRadius: 30,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFF43F5E).withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.cloud_off_rounded, color: Color(0xFFF43F5E), size: 40),
              ),
              const SizedBox(height: 18),
              const Text(
                'Gagal Mengambil Data Container',
                style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                _errorMessage!,
                style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13, height: 1.5),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF06B6D4),
                  foregroundColor: const Color(0xFF020617),
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
                onPressed: _loadContainers,
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text('Coba Lagi', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
      );
    }

    final runningCount = _containers.where((c) => c.isRunning).length;
    final stoppedCount = _containers.length - runningCount;
    final totalStacks = _containers.map((c) => c.stackName).toSet().length;
    final filtered = _filteredContainers;
    final isMobile = MediaQuery.of(context).size.width < 768;

    return SingleChildScrollView(
      padding: EdgeInsets.all(isMobile ? 16 : 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Bar dengan Title, View Mode Switcher, & Refresh Button
          LayoutBuilder(
            builder: (context, constraints) {
              final isNarrowHeader = constraints.maxWidth < 650;

              final titleSection = Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF0284C7), Color(0xFF06B6D4)],
                      ),
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF06B6D4).withOpacity(0.35),
                          blurRadius: 12,
                        ),
                      ],
                    ),
                    child: const Icon(Icons.view_in_ar_rounded, color: Colors.white, size: 22),
                  ),
                  const SizedBox(width: 14),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Text(
                            'Docker Containers',
                            style: TextStyle(
                              fontSize: 18,
                              letterSpacing: 0.5,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFF06B6D4).withOpacity(0.15),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: const Color(0xFF06B6D4).withOpacity(0.35)),
                            ),
                            child: const Text(
                              'v1.5.1-ECOSYSTEM',
                              style: TextStyle(
                                color: Color(0xFF06B6D4),
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.6,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Relasi Pasangan Web & DB • $runningCount Aktif • $totalStacks Stack/Proyek',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF94A3B8),
                        ),
                      ),
                    ],
                  ),
                ],
              );

              final controlsSection = Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // View Mode Toggle (Grouped vs Grid)
                  Container(
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0F172A),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFF1E293B)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildViewModeButton(
                          mode: 'grouped',
                          icon: Icons.hub_rounded,
                          tooltip: 'Grup Stack & Pasangan',
                        ),
                        _buildViewModeButton(
                          mode: 'grid',
                          icon: Icons.grid_view_rounded,
                          tooltip: 'Semua Kartu (Grid)',
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  // Refresh Button
                  IconButton(
                    tooltip: 'Segarkan Data Docker',
                    style: IconButton.styleFrom(
                      backgroundColor: const Color(0xFF0F172A),
                      side: const BorderSide(color: Color(0xFF1E293B)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    icon: _isRefreshing
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF06B6D4)),
                          )
                        : const Icon(Icons.refresh_rounded, size: 20, color: Color(0xFF06B6D4)),
                    onPressed: _isRefreshing ? null : _manualRefresh,
                  ),
                ],
              );

              if (isNarrowHeader) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    titleSection,
                    const SizedBox(height: 14),
                    controlsSection,
                  ],
                );
              }

              return Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  titleSection,
                  controlsSection,
                ],
              );
            },
          ),

          const SizedBox(height: 22),

          // 3 Vibrant Glassmorphism Summary Cards
          LayoutBuilder(
            builder: (context, constraints) {
              final isNarrow = constraints.maxWidth < 700;
              final cards = [
                _buildModernSummaryCard(
                  label: 'TOTAL MICROSERVICES',
                  value: '${_containers.length}',
                  subtitle: '$totalStacks Ekosistem Stack',
                  icon: Icons.layers_rounded,
                  gradient: const [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                  accentColor: const Color(0xFF8B5CF6),
                ),
                _buildModernSummaryCard(
                  label: 'AKTIF BERJALAN',
                  value: '$runningCount',
                  subtitle: 'Siap melayani request',
                  icon: Icons.bolt_rounded,
                  gradient: const [Color(0xFF059669), Color(0xFF10B981)],
                  accentColor: const Color(0xFF10B981),
                  isLive: true,
                ),
                _buildModernSummaryCard(
                  label: 'OFFLINE / STOPPED',
                  value: '$stoppedCount',
                  subtitle: 'Container tidak aktif',
                  icon: Icons.pause_circle_filled_rounded,
                  gradient: const [Color(0xFFE11D48), Color(0xFFF43F5E)],
                  accentColor: const Color(0xFFF43F5E),
                ),
              ];
              if (isNarrow) {
                return Column(
                  children: cards.map((c) => Padding(padding: const EdgeInsets.only(bottom: 12), child: c)).toList(),
                );
              }
              return Row(
                children: cards.map((c) => Expanded(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 6), child: c))).toList(),
              );
            },
          ),

          const SizedBox(height: 24),

          // Search & Filter Bar Controls
          LayoutBuilder(
            builder: (context, constraints) {
              final isNarrow = constraints.maxWidth < 620;

              final searchField = Container(
                height: 46,
                decoration: BoxDecoration(
                  color: const Color(0xFF0F172A).withOpacity(0.8),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFF1E293B)),
                ),
                child: TextField(
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                  decoration: InputDecoration(
                    hintText: 'Cari container, pasangan, image, stack, port (contoh: db-easpira, 8080)...',
                    hintStyle: const TextStyle(color: Color(0xFF64748B), fontSize: 13),
                    prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFF06B6D4), size: 20),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.close_rounded, size: 16, color: Color(0xFF94A3B8)),
                            onPressed: () => setState(() => _searchQuery = ''),
                          )
                        : null,
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                  ),
                  onChanged: (v) => setState(() => _searchQuery = v),
                ),
              );

              final filterChips = Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildModernFilterChip('Semua', 'all', _containers.length),
                  const SizedBox(width: 8),
                  _buildModernFilterChip('Running', 'running', runningCount),
                  const SizedBox(width: 8),
                  _buildModernFilterChip('Stopped', 'stopped', stoppedCount),
                ],
              );

              if (isNarrow) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [searchField, const SizedBox(height: 12), filterChips],
                );
              }
              return Row(
                children: [
                  Expanded(child: searchField),
                  const SizedBox(width: 16),
                  filterChips,
                ],
              );
            },
          ),

          const SizedBox(height: 24),

          // TAMPILAN UTAMA (MODE GRUP STACK & PASANGAN ATAU GRID)
          if (filtered.isEmpty)
            _buildModernEmptyState()
          else if (_viewMode == 'grouped')
            _buildGroupedStackView(filtered)
          else
            _buildClassicGridView(filtered),
        ],
      ),
    );
  }

  Widget _buildViewModeButton({
    required String mode,
    required IconData icon,
    required String tooltip,
  }) {
    final isActive = _viewMode == mode;
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: () => setState(() => _viewMode = mode),
        borderRadius: BorderRadius.circular(10),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          decoration: BoxDecoration(
            color: isActive ? const Color(0xFF06B6D4).withOpacity(0.2) : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isActive ? const Color(0xFF06B6D4).withOpacity(0.5) : Colors.transparent,
            ),
          ),
          child: Icon(
            icon,
            size: 18,
            color: isActive ? const Color(0xFF06B6D4) : const Color(0xFF64748B),
          ),
        ),
      ),
    );
  }

  /// Tampilan Stack & Pasangan Berkelompok
  Widget _buildGroupedStackView(List<ContainerModel> filtered) {
    final grouped = _groupedContainers;
    final sortedKeys = grouped.keys.toList()
      ..sort((a, b) {
        final pA = grouped[a]!.first.stackPriority;
        final pB = grouped[b]!.first.stackPriority;
        return pA.compareTo(pB);
      });

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: sortedKeys.map((stackName) {
        final items = grouped[stackName]!;
        final runningInStack = items.where((c) => c.isRunning).length;
        final isAllRunning = runningInStack == items.length;
        final isAllStopped = runningInStack == 0;

        Color stackStatusColor = const Color(0xFF10B981);
        String stackStatusText = 'SEMUA AKTIF';
        if (isAllStopped) {
          stackStatusColor = const Color(0xFFF43F5E);
          stackStatusText = 'OFFLINE';
        } else if (!isAllRunning) {
          stackStatusColor = const Color(0xFFF59E0B);
          stackStatusText = '$runningInStack/${items.length} AKTIF';
        }

        return Container(
          margin: const EdgeInsets.only(bottom: 26),
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: const Color(0xFF090E1A).withOpacity(0.65),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: const Color(0xFF1E293B).withOpacity(0.8),
              width: 1.2,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Stack
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF06B6D4).withOpacity(0.12),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFF06B6D4).withOpacity(0.3)),
                        ),
                        child: const Icon(Icons.hub_rounded, size: 18, color: Color(0xFF06B6D4)),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            stackName,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                              letterSpacing: 0.3,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${items.length} Microservice Berpasangan',
                            style: const TextStyle(
                              fontSize: 11.5,
                              color: Color(0xFF94A3B8),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  // Stack Health Badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: stackStatusColor.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: stackStatusColor.withOpacity(0.35)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            color: stackStatusColor,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          stackStatusText,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: stackStatusColor,
                            letterSpacing: 0.6,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // Grid Item di dalam Stack (Web & DB Berdampingan)
              LayoutBuilder(
                builder: (context, constraints) {
                  int crossAxisCount = 3;
                  if (constraints.maxWidth < 720) {
                    crossAxisCount = 1;
                  } else if (constraints.maxWidth < 1180) {
                    crossAxisCount = 2;
                  }
                  return GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: crossAxisCount,
                      crossAxisSpacing: 14,
                      mainAxisSpacing: 14,
                      mainAxisExtent: 228,
                    ),
                    itemCount: items.length,
                    itemBuilder: (context, index) {
                      return ContainerCard(
                        container: items[index],
                        onAction: _handleAction,
                        onFilterPair: (pair) {
                          setState(() => _searchQuery = pair);
                        },
                      );
                    },
                  );
                },
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  /// Tampilan Grid Klasik
  Widget _buildClassicGridView(List<ContainerModel> filtered) {
    return LayoutBuilder(
      builder: (context, constraints) {
        int crossAxisCount = 3;
        if (constraints.maxWidth < 720) {
          crossAxisCount = 1;
        } else if (constraints.maxWidth < 1180) {
          crossAxisCount = 2;
        }
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            mainAxisExtent: 228,
          ),
          itemCount: filtered.length,
          itemBuilder: (context, index) {
            return ContainerCard(
              container: filtered[index],
              onAction: _handleAction,
              onFilterPair: (pair) {
                setState(() => _searchQuery = pair);
              },
            );
          },
        );
      },
    );
  }

  Widget _buildModernSummaryCard({
    required String label,
    required String value,
    required String subtitle,
    required IconData icon,
    required List<Color> gradient,
    required Color accentColor,
    bool isLive = false,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A).withOpacity(0.85),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: accentColor.withOpacity(0.3), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: accentColor.withOpacity(0.12),
            blurRadius: 20,
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
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [gradient[0].withOpacity(0.3), gradient[1].withOpacity(0.15)],
                  ),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: accentColor.withOpacity(0.4)),
                ),
                child: Icon(icon, color: accentColor, size: 22),
              ),
              if (isLive)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFF10B981).withOpacity(0.4)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: const BoxDecoration(
                          color: Color(0xFF10B981),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 5),
                      const Text(
                        'ONLINE',
                        style: TextStyle(
                          color: Color(0xFF10B981),
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFF94A3B8),
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.1,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                value,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 32,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                subtitle,
                style: const TextStyle(
                  color: Color(0xFF64748B),
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildModernFilterChip(String label, String value, int count) {
    final isActive = _filterStatus == value;
    return GestureDetector(
      onTap: () => setState(() => _filterStatus = value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          gradient: isActive
              ? const LinearGradient(
                  colors: [Color(0xFF0284C7), Color(0xFF06B6D4)],
                )
              : null,
          color: isActive ? null : const Color(0xFF0F172A).withOpacity(0.8),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isActive ? const Color(0xFF06B6D4) : const Color(0xFF1E293B),
            width: 1.2,
          ),
          boxShadow: isActive
              ? [
                  BoxShadow(
                    color: const Color(0xFF06B6D4).withOpacity(0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                color: isActive ? const Color(0xFF020617) : const Color(0xFFCBD5E1),
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: isActive ? const Color(0xFF020617).withOpacity(0.25) : const Color(0xFF1E293B),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '$count',
                style: TextStyle(
                  color: isActive ? const Color(0xFF020617) : const Color(0xFF94A3B8),
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModernEmptyState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A).withOpacity(0.7),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFF1E293B)),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFF06B6D4).withOpacity(0.1),
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFF06B6D4).withOpacity(0.3)),
            ),
            child: const Icon(Icons.hub_outlined, size: 40, color: Color(0xFF06B6D4)),
          ),
          const SizedBox(height: 18),
          Text(
            _searchQuery.isNotEmpty
                ? 'Tidak ada container yang cocok dengan "$_searchQuery"'
                : 'Tidak Ada Container Docker Aktif',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            _searchQuery.isNotEmpty
                ? 'Coba ganti kata kunci pencarian atau periksa filter status di atas.'
                : 'Pastikan daemon Docker atau Portainer aktif di server Toshiba (port 9000).',
            style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
