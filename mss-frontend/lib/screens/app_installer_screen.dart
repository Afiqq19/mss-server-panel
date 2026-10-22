import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/api_service.dart';
import '../providers/theme_provider.dart';

class AppInstallerScreen extends StatefulWidget {
  const AppInstallerScreen({Key? key}) : super(key: key);

  @override
  _AppInstallerScreenState createState() => _AppInstallerScreenState();
}

class _AppInstallerScreenState extends State<AppInstallerScreen> {
  bool _isLoading = true;
  List<dynamic> _apps = [];
  String? _installingAppId;

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
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(err), backgroundColor: const Color(0xFFF43F5E)),
          );
        }
      }
    }
  }

  Future<void> _installApp(String appId, String appName) async {
    bool? confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: Text('Install $appName?', style: const TextStyle(color: Colors.white)),
        content: const Text(
          'Ini akan mengunduh image Docker dan menjalankan kontainer baru di server Anda.',
          style: TextStyle(color: Color(0xFF94A3B8)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
            child: const Text('Install', style: TextStyle(color: Colors.white)),
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
          backgroundColor: const Color(0xFF1E293B),
          title: const Text('Instalasi Berhasil', style: TextStyle(color: Colors.green)),
          content: SingleChildScrollView(
            child: Text(
              result['data']['output'] ?? 'Selesai',
              style: const TextStyle(color: Color(0xFF34D399), fontFamily: 'monospace', fontSize: 12),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Tutup', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal install: $e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _installingAppId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    return SingleChildScrollView(
      padding: EdgeInsets.all(MediaQuery.of(context).size.width < 600 ? 16 : 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: themeProvider.primary.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.rocket_launch, color: themeProvider.primary, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text(
                      'App Installer (1-Click)',
                      style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                    Text(
                      'Install aplikasi populer dengan Docker Compose',
                      style: TextStyle(color: Color(0xFF94A3B8), fontSize: 14),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),

          if (_isLoading)
            Center(child: CircularProgressIndicator(color: themeProvider.primary))
          else
            Wrap(
              spacing: 24,
              runSpacing: 24,
              children: _apps.map((app) => _buildAppCard(app, themeProvider)).toList(),
            ),
        ],
      ),
    );
  }

  Widget _buildAppCard(Map<String, dynamic> app, ThemeProvider themeProvider) {
    final bool isInstalling = _installingAppId == app['id'];

    return Container(
      width: 320,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.apps, color: Colors.white, size: 32),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  app['name'],
                  style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            app['description'],
            style: const TextStyle(color: Color(0xFF94A3B8), height: 1.5),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: isInstalling ? null : () => _installApp(app['id'], app['name']),
              style: ElevatedButton.styleFrom(
                backgroundColor: themeProvider.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: isInstalling
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Text('Install Sekarang', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }
}
