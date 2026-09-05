import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/api_service.dart';
import '../providers/theme_provider.dart';

class CronScreen extends StatefulWidget {
  const CronScreen({Key? key}) : super(key: key);

  @override
  _CronScreenState createState() => _CronScreenState();
}

class _CronScreenState extends State<CronScreen> {
  bool _isLoading = true;
  List<dynamic> _crons = [];

  final _scheduleController = TextEditingController();
  final _commandController = TextEditingController();

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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _addCron() async {
    if (_scheduleController.text.isEmpty || _commandController.text.isEmpty) return;
    
    try {
      final api = Provider.of<ApiService>(context, listen: false);
      await api.post('/cron', {
        'schedule': _scheduleController.text,
        'command': _commandController.text,
      });
      _scheduleController.clear();
      _commandController.clear();
      _loadCrons();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal tambah cron: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _deleteCron(int index) async {
    try {
      final api = Provider.of<ApiService>(context, listen: false);
      await api.post('/cron/delete', {
        'index': index,
      });
      _loadCrons();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal hapus cron: $e'), backgroundColor: Colors.red),
      );
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
                child: Icon(Icons.schedule, color: themeProvider.primary, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text(
                      'Cron Jobs',
                      style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                    Text(
                      'Manajemen tugas terjadwal (crontab)',
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
            _buildContent(themeProvider),
        ],
      ),
    );
  }

  Widget _buildContent(ThemeProvider themeProvider) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 2,
          child: _buildAddForm(themeProvider),
        ),
        const SizedBox(width: 24),
        Expanded(
          flex: 3,
          child: _buildCronList(themeProvider),
        ),
      ],
    );
  }

  Widget _buildAddForm(ThemeProvider themeProvider) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Tambah Cron Baru', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          TextField(
            controller: _scheduleController,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              labelText: 'Jadwal (contoh: 0 3 * * *)',
              labelStyle: const TextStyle(color: Color(0xFF94A3B8)),
              enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.white.withOpacity(0.1))),
              focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: themeProvider.primary)),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _commandController,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              labelText: 'Perintah (contoh: /usr/bin/php /var/www/script.php)',
              labelStyle: const TextStyle(color: Color(0xFF94A3B8)),
              enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.white.withOpacity(0.1))),
              focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: themeProvider.primary)),
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _addCron,
              icon: const Icon(Icons.add, color: Colors.white),
              label: const Text('Simpan Jadwal'),
              style: ElevatedButton.styleFrom(
                backgroundColor: themeProvider.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCronList(ThemeProvider themeProvider) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Daftar Cron Aktif', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          if (_crons.isEmpty)
            const Text('Tidak ada cron job.', style: TextStyle(color: Color(0xFF94A3B8)))
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _crons.length,
              separatorBuilder: (ctx, i) => Divider(color: Colors.white.withOpacity(0.1)),
              itemBuilder: (ctx, i) {
                final cron = _crons[i];
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: themeProvider.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.timer, color: Colors.blue),
                  ),
                  title: Text(cron['schedule'], style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontFamily: 'monospace')),
                  subtitle: Text(cron['command'], style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12)),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red),
                    onPressed: () => _deleteCron(cron['id']),
                    tooltip: 'Hapus Cron',
                  ),
                );
              },
            ),
        ],
      ),
    );
  }
}
