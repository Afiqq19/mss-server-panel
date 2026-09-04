import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/container_model.dart';
import '../services/api_service.dart';

class ContainersScreen extends StatefulWidget {
  const ContainersScreen({super.key});

  @override
  State<ContainersScreen> createState() => _ContainersScreenState();
}

class _ContainersScreenState extends State<ContainersScreen> {
  bool _isLoading = true;
  String? _errorMessage;
  List<ContainerModel> _containers = [];
  String _searchQuery = '';
  String _filterStatus = 'all'; // all, running, stopped
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
      final data = await api.fetchContainers();
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
      final data = await api.fetchContainers();
      if (mounted) setState(() => _containers = data);
    } catch (_) {}
  }

  Future<void> _handleAction(String id, String action) async {
    final api = context.read<ApiService>();
    try {
      await api.executeContainerAction(id, action);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Aksi "$action" berhasil dikirim!'),
            backgroundColor: const Color(0xFF10B981),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
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
          ),
        );
      }
    }
  }

  List<ContainerModel> get _filteredContainers {
    return _containers.where((c) {
      final matchSearch = _searchQuery.isEmpty ||
          c.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          c.image.toLowerCase().contains(_searchQuery.toLowerCase());
      final matchFilter = _filterStatus == 'all' ||
          (_filterStatus == 'running' && c.isRunning) ||
          (_filterStatus == 'stopped' && !c.isRunning);
      return matchSearch && matchFilter;
    }).toList();
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
            const Icon(Icons.error, color: Color(0xFFF43F5E), size: 48),
            const SizedBox(height: 16),
            const Text('Gagal Memuat Container', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(_errorMessage!, style: const TextStyle(color: Color(0xFF94A3B8)), textAlign: TextAlign.center),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF3B82F6), foregroundColor: Colors.white),
              onPressed: _loadContainers,
              icon: const Icon(Icons.refresh),
              label: const Text('Coba Lagi'),
            ),
          ],
        ),
      );
    }

    final runningCount = _containers.where((c) => c.isRunning).length;
    final stoppedCount = _containers.length - runningCount;
    final filtered = _filteredContainers;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Summary Cards
          LayoutBuilder(
            builder: (context, constraints) {
              final isNarrow = constraints.maxWidth < 600;
              final cards = [
                _buildSummaryCard('Total', '${_containers.length}', Icons.view_in_ar, const Color(0xFF3B82F6)),
                _buildSummaryCard('Running', '$runningCount', Icons.play_circle, const Color(0xFF10B981)),
                _buildSummaryCard('Stopped', '$stoppedCount', Icons.stop_circle, const Color(0xFFF43F5E)),
              ];
              if (isNarrow) {
                return Column(children: cards.map((c) => Padding(padding: const EdgeInsets.only(bottom: 12), child: c)).toList());
              }
              return Row(children: cards.map((c) => Expanded(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 6), child: c))).toList());
            },
          ),

          const SizedBox(height: 24),

          // Search & Filter Bar
          LayoutBuilder(
            builder: (context, constraints) {
              final isNarrow = constraints.maxWidth < 500;
              final searchField = Container(
                height: 44,
                decoration: BoxDecoration(
                  color: const Color(0xFF1E293B),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFF334155)),
                ),
                child: TextField(
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                  decoration: const InputDecoration(
                    hintText: 'Cari container...',
                    hintStyle: TextStyle(color: Color(0xFF64748B)),
                    prefixIcon: Icon(Icons.search, color: Color(0xFF64748B), size: 20),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(vertical: 12),
                  ),
                  onChanged: (v) => setState(() => _searchQuery = v),
                ),
              );

              final filterChips = Row(
                children: [
                  _buildFilterChip('Semua', 'all'),
                  const SizedBox(width: 8),
                  _buildFilterChip('Running', 'running'),
                  const SizedBox(width: 8),
                  _buildFilterChip('Stopped', 'stopped'),
                ],
              );

              if (isNarrow) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
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

          const SizedBox(height: 20),

          // Container List
          if (filtered.isEmpty)
            _buildEmptyState()
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
                    mainAxisExtent: 200,
                  ),
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    return _buildContainerCard(filtered[index]);
                  },
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF1E293B)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1)),
              const SizedBox(height: 4),
              Text(value, style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, String value) {
    final isActive = _filterStatus == value;
    return GestureDetector(
      onTap: () => setState(() => _filterStatus = value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isActive ? const Color(0xFF3B82F6).withOpacity(0.2) : const Color(0xFF1E293B),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: isActive ? const Color(0xFF3B82F6) : const Color(0xFF334155)),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isActive ? const Color(0xFF3B82F6) : const Color(0xFF94A3B8),
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(40),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF1E293B)),
      ),
      child: Column(
        children: [
          const Icon(Icons.search_off, size: 48, color: Color(0xFF64748B)),
          const SizedBox(height: 16),
          Text(
            _searchQuery.isNotEmpty ? 'Tidak ditemukan container "$_searchQuery"' : 'Tidak ada container terdeteksi.',
            style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 14),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildContainerCard(ContainerModel container) {
    final statusColor = container.isRunning ? const Color(0xFF10B981) : const Color(0xFFF43F5E);
    final statusLabel = container.isRunning ? 'RUNNING' : 'EXITED';

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF1E293B)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Name + Status
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  container.name,
                  style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: statusColor.withOpacity(0.4)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.circle, size: 6, color: statusColor),
                    const SizedBox(width: 4),
                    Text(statusLabel, style: TextStyle(color: statusColor, fontSize: 10, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Image
          Text(container.image, style: const TextStyle(color: Color(0xFF64748B), fontSize: 12), overflow: TextOverflow.ellipsis),
          const SizedBox(height: 6),
          // Ports & ID
          if (container.ports.isNotEmpty)
            Row(
              children: [
                const Icon(Icons.lan, size: 14, color: Color(0xFF64748B)),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(container.ports, style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11), overflow: TextOverflow.ellipsis),
                ),
              ],
            ),
          const SizedBox(height: 4),
          Row(
            children: [
              const Icon(Icons.tag, size: 14, color: Color(0xFF64748B)),
              const SizedBox(width: 6),
              Flexible(
                child: Text('#${container.id.substring(0, container.id.length > 12 ? 12 : container.id.length)}',
                    style: const TextStyle(color: Color(0xFF64748B), fontSize: 11, fontFamily: 'monospace')),
              ),
            ],
          ),
          const Spacer(),
          // Action Buttons
          Row(
            children: [
              if (!container.isRunning)
                Expanded(
                  child: _buildActionButton('Start', Icons.play_arrow, const Color(0xFF10B981), () => _handleAction(container.id, 'start')),
                ),
              if (container.isRunning) ...[
                Expanded(
                  child: _buildActionButton('Restart', Icons.refresh, const Color(0xFF3B82F6), () => _handleAction(container.id, 'restart')),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildActionButton('Stop', Icons.stop, const Color(0xFFF43F5E), () => _handleAction(container.id, 'stop')),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton(String label, IconData icon, Color color, VoidCallback onTap) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: color.withOpacity(0.3)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 14, color: color),
              const SizedBox(width: 6),
              Text(label, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.bold)),
            ],
          ),
        ),
      ),
    );
  }
}
