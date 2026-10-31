import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/api_service.dart';
import '../providers/theme_provider.dart';

class AppInstallerScreen extends StatefulWidget {
  const AppInstallerScreen({super.key});

  @override
  State<AppInstallerScreen> createState() => _AppInstallerScreenState();
}

class _AppInstallerScreenState extends State<AppInstallerScreen> {
  bool _isLoading = true;
  List<dynamic> _apps = [];
  String? _installingAppId;
  String _searchQuery = '';
  String _selectedCategory = 'all';

  @override
  void initState() {
    super.initState();
    _loadApps();
  }

  Future<void> _loadApps() async {
    setState(() => _isLoading = true);
    try {
      final api = Provider.of<ApiService>(context, listen: false);
      final res = await api.get('/installer/apps');
      if (mounted) {
        setState(() {
          _apps = res['data']['apps'] ?? [];
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

  Map<String, dynamic> _getAppMeta(String appId) {
    switch (appId) {
      case 'nginx_proxy_manager':
        return {
          'icon': Icons.alt_route_rounded,
          'color': const Color(0xFF06B6D4),
          'ports': '80, 81, 443',
          'category': 'web',
          'tags': ['Proxy', 'SSL / TLS', 'Nginx'],
        };
      case 'phpmyadmin':
        return {
          'icon': Icons.storage_rounded,
          'color': const Color(0xFFF59E0B),
          'ports': '8081',
          'category': 'database',
          'tags': ['Database', 'MySQL', 'Web GUI'],
        };
      case 'wordpress':
        return {
          'icon': Icons.language_rounded,
          'color': const Color(0xFF3B82F6),
          'ports': '8080, 8081',
          'category': 'cms',
          'tags': ['CMS', 'MySQL', 'phpMyAdmin'],
        };
      default:
        return {
          'icon': Icons.apps_rounded,
          'color': const Color(0xFF8B5CF6),
          'ports': '80',
          'category': 'tools',
          'tags': ['Docker', 'App'],
        };
    }
  }

  Future<void> _installApp(String appId, String appName) async {
    final meta = _getAppMeta(appId);
    final ports = meta['ports'] ?? '';

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
                color: (meta['color'] as Color).withOpacity(0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(meta['icon'] as IconData, color: meta['color'] as Color, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text('Pasang $appName?', style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Server akan mengunduh Docker image resmi dan membuat compose stack baru di server.',
              style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13, height: 1.4),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF020617),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFF1E293B)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.hub_rounded, size: 16, color: Color(0xFF06B6D4)),
                  const SizedBox(width: 8),
                  Text('Port Target: $ports', style: const TextStyle(color: Color(0xFFCBD5E1), fontFamily: 'monospace', fontSize: 12)),
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
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: meta['color'] as Color,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Ya, Pasang Sekarang'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _installingAppId = appId);

    try {
      final api = Provider.of<ApiService>(context, listen: false);
      final result = await api.post('/installer/install', {'app_id': appId});

      if (!mounted) return;
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: const Color(0xFF0F172A),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: const BorderSide(color: Color(0xFF10B981), width: 1.2),
          ),
          title: Row(
            children: const [
              Icon(Icons.check_circle_rounded, color: Color(0xFF10B981), size: 24),
              SizedBox(width: 10),
              Text('Instalasi Dimulai', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                result['data']['output'] ?? 'Proses instalasi sedang berjalan di latar belakang.',
                style: const TextStyle(color: Color(0xFFCBD5E1), fontSize: 13, height: 1.5),
              ),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFF020617),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.info_outline, size: 14, color: Color(0xFF64748B)),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Anda dapat memeriksa prosesnya di tab Containers atau Terminal.',
                        style: TextStyle(color: Color(0xFF64748B), fontSize: 11),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF10B981),
                foregroundColor: Colors.white,
              ),
              child: const Text('Mengerti'),
            ),
          ],
        ),
      );
    } catch (e) {
      _showToast('Gagal pasang: $e', isError: true);
    } finally {
      if (mounted) setState(() => _installingAppId = null);
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

    final filteredApps = _apps.where((app) {
      final name = app['name']?.toString().toLowerCase() ?? '';
      final desc = app['description']?.toString().toLowerCase() ?? '';
      final meta = _getAppMeta(app['id']?.toString() ?? '');
      final category = meta['category'] as String;

      final matchesQuery = _searchQuery.isEmpty || name.contains(_searchQuery.toLowerCase()) || desc.contains(_searchQuery.toLowerCase());
      final matchesCategory = _selectedCategory == 'all' || category == _selectedCategory;

      return matchesQuery && matchesCategory;
    }).toList();

    return SingleChildScrollView(
      padding: EdgeInsets.all(isMobile ? 16 : 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Hero
          _buildHeader(themeProvider, isMobile),
          const SizedBox(height: 24),

          // Search and Category Chips
          _buildFilterBar(themeProvider, isMobile),
          const SizedBox(height: 24),

          if (_isLoading)
            Padding(
              padding: const EdgeInsets.all(60.0),
              child: Center(
                child: Column(
                  children: [
                    CircularProgressIndicator(color: themeProvider.primary),
                    const SizedBox(height: 16),
                    const Text('Memuat katalog aplikasi Docker...', style: TextStyle(color: Color(0xFF94A3B8))),
                  ],
                ),
              ),
            )
          else if (filteredApps.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(48),
              decoration: BoxDecoration(
                color: const Color(0xFF0F172A).withOpacity(0.5),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white.withOpacity(0.08)),
              ),
              child: Column(
                children: const [
                  Icon(Icons.search_off_rounded, size: 48, color: Color(0xFF64748B)),
                  SizedBox(height: 12),
                  Text('Tidak ada aplikasi yang cocok', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                ],
              ),
            )
          else
            LayoutBuilder(
              builder: (context, constraints) {
                final double cardWidth = constraints.maxWidth < 680
                    ? constraints.maxWidth
                    : (constraints.maxWidth < 1140 ? (constraints.maxWidth - 20) / 2 : (constraints.maxWidth - 40) / 3);

                return Wrap(
                  spacing: 20,
                  runSpacing: 20,
                  children: filteredApps.map((app) => _buildAppCard(app, themeProvider, cardWidth)).toList(),
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
                child: const Icon(Icons.rocket_launch_rounded, color: Colors.white, size: 28),
              ),
              const SizedBox(width: 18),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text(
                      'App Installer (1-Click Hub)',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        letterSpacing: 0.3,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Pasang aplikasi Docker populer langsung ke server hanya dalam 1 klik',
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

  Widget _buildFilterBar(ThemeProvider themeProvider, bool isMobile) {
    final categories = [
      {'id': 'all', 'label': 'Semua Kategori'},
      {'id': 'web', 'label': 'Web & Proxy'},
      {'id': 'database', 'label': 'Database'},
      {'id': 'cms', 'label': 'CMS & Blog'},
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Search Input
        Container(
          height: 44,
          decoration: BoxDecoration(
            color: const Color(0xFF0F172A).withOpacity(0.85),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withOpacity(0.08)),
          ),
          child: TextField(
            onChanged: (val) => setState(() => _searchQuery = val.trim()),
            style: const TextStyle(color: Colors.white, fontSize: 13),
            decoration: InputDecoration(
              hintText: 'Cari aplikasi (WordPress, phpMyAdmin, Nginx Proxy Manager)...',
              hintStyle: TextStyle(color: Colors.white.withOpacity(0.25), fontSize: 13),
              prefixIcon: const Icon(Icons.search_rounded, size: 18, color: Color(0xFF64748B)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              border: InputBorder.none,
            ),
          ),
        ),
        const SizedBox(height: 12),

        // Category filter chips
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: categories.map((cat) {
              final isSelected = _selectedCategory == cat['id'];
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: InkWell(
                  onTap: () => setState(() => _selectedCategory = cat['id']!),
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: isSelected ? themeProvider.primary.withOpacity(0.2) : const Color(0xFF0F172A).withOpacity(0.6),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isSelected ? themeProvider.primary : Colors.white.withOpacity(0.08),
                      ),
                    ),
                    child: Text(
                      cat['label']!,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                        color: isSelected ? themeProvider.primary : const Color(0xFF94A3B8),
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildAppCard(Map<String, dynamic> app, ThemeProvider themeProvider, double width) {
    final String id = app['id']?.toString() ?? '';
    final String name = app['name']?.toString() ?? '';
    final String description = app['description']?.toString() ?? '';
    final bool isInstalling = _installingAppId == id;

    final meta = _getAppMeta(id);
    final Color appColor = meta['color'];
    final IconData icon = meta['icon'];
    final String ports = meta['ports'];
    final List<String> tags = List<String>.from(meta['tags'] ?? []);

    return SizedBox(
      width: width,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              color: const Color(0xFF0F172A).withOpacity(0.85),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: appColor.withOpacity(0.25),
                width: 1.2,
              ),
              boxShadow: [
                BoxShadow(
                  color: appColor.withOpacity(0.08),
                  blurRadius: 18,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top row with app icon and port tag
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: appColor.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: appColor.withOpacity(0.35)),
                      ),
                      child: Icon(icon, color: appColor, size: 28),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFF020617),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: const Color(0xFF1E293B)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.settings_ethernet_rounded, size: 12, color: Color(0xFF94A3B8)),
                          const SizedBox(width: 5),
                          Text(
                            'Port $ports',
                            style: const TextStyle(
                              color: Color(0xFFCBD5E1),
                              fontFamily: 'monospace',
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Name and Description
                Text(
                  name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  description,
                  style: const TextStyle(
                    color: Color(0xFF94A3B8),
                    fontSize: 12.5,
                    height: 1.4,
                  ),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 14),

                // Tags
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: tags.map((tag) {
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E293B).withOpacity(0.6),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        tag,
                        style: const TextStyle(fontSize: 10, color: Color(0xFF94A3B8), fontWeight: FontWeight.w600),
                      ),
                    );
                  }).toList(),
                ),

                const SizedBox(height: 20),

                // Install Button
                SizedBox(
                  width: double.infinity,
                  height: 44,
                  child: ElevatedButton(
                    onPressed: isInstalling ? null : () => _installApp(id, name),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: appColor,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      shadowColor: appColor.withOpacity(0.4),
                    ),
                    child: isInstalling
                        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: const [
                              Icon(Icons.download_rounded, size: 18),
                              SizedBox(width: 6),
                              Text('Pasang Sekarang (1-Click)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                            ],
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
