import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/api_service.dart';
import '../providers/theme_provider.dart';

class SecurityScreen extends StatefulWidget {
  const SecurityScreen({Key? key}) : super(key: key);

  @override
  _SecurityScreenState createState() => _SecurityScreenState();
}

class _SecurityScreenState extends State<SecurityScreen> {
  bool _isLoading = true;
  bool _isActive = false;
  List<dynamic> _rules = [];
  String _rawOutput = '';

  final _portController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadUfwStatus();
  }

  @override
  void dispose() {
    _portController.dispose();
    super.dispose();
  }

  Future<void> _loadUfwStatus() async {
    setState(() => _isLoading = true);
    try {
      final api = Provider.of<ApiService>(context, listen: false);
      final response = await api.get('/security/ufw');
      if (mounted) {
        setState(() {
          _isActive = response['data']['is_active'] ?? false;
          _rules = response['data']['rules'] ?? [];
          _rawOutput = response['data']['raw_output'] ?? '';
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _toggleUfw(bool enable) async {
    try {
      final api = Provider.of<ApiService>(context, listen: false);
      await api.post('/security/ufw/toggle', {
        'action': enable ? 'enable' : 'disable'
      });
      _loadUfwStatus();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal mengubah status: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _managePort(String action, String port, {String? protocol}) async {
    try {
      final api = Provider.of<ApiService>(context, listen: false);
      await api.post('/security/ufw/port', {
        'port': port,
        'action': action,
        if (protocol != null) 'protocol': protocol,
      });
      _portController.clear();
      _loadUfwStatus();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal mengubah port: $e'), backgroundColor: Colors.red),
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
                child: Icon(Icons.security, color: themeProvider.primary, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text(
                      'Security & Firewall',
                      style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                    Text(
                      'Manajemen UFW (Uncomplicated Firewall)',
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
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildStatusCard(themeProvider),
              const SizedBox(height: 24),
              _buildAddRuleCard(themeProvider),
            ],
          ),
        ),
        const SizedBox(width: 24),
        Expanded(
          flex: 3,
          child: _buildRulesTable(themeProvider),
        ),
      ],
    );
  }

  Widget _buildStatusCard(ThemeProvider themeProvider) {
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
          const Text('Status UFW', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _isActive ? 'Aktif (Melindungi)' : 'Nonaktif (Tidak Aman)',
                style: TextStyle(color: _isActive ? Colors.green : Colors.red, fontWeight: FontWeight.bold),
              ),
              Switch(
                value: _isActive,
                activeColor: Colors.green,
                onChanged: (val) => _toggleUfw(val),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAddRuleCard(ThemeProvider themeProvider) {
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
          const Text('Buka / Tutup Port', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          TextField(
            controller: _portController,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              labelText: 'Nomor Port (contoh: 80, 443, 3306)',
              labelStyle: const TextStyle(color: Color(0xFF94A3B8)),
              enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.white.withOpacity(0.1))),
              focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: themeProvider.primary)),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _managePort('allow', _portController.text, protocol: 'tcp'),
                  icon: const Icon(Icons.check, size: 16),
                  label: const Text('Allow TCP'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _managePort('deny', _portController.text, protocol: 'tcp'),
                  icon: const Icon(Icons.block, size: 16),
                  label: const Text('Deny TCP'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRulesTable(ThemeProvider themeProvider) {
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
          const Text('Daftar Aturan Aktif', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          if (!_isActive)
            const Text('UFW sedang nonaktif.', style: TextStyle(color: Color(0xFF94A3B8)))
          else if (_rules.isEmpty)
            const Text('Tidak ada aturan port khusus.', style: TextStyle(color: Color(0xFF94A3B8)))
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _rules.length,
              itemBuilder: (ctx, i) {
                final rule = _rules[i];
                final isAllow = rule['action'].toString().contains('ALLOW');
                return ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: isAllow ? Colors.green.withOpacity(0.1) : Colors.red.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(isAllow ? Icons.check : Icons.block, color: isAllow ? Colors.green : Colors.red, size: 16),
                  ),
                  title: Text(rule['port'], style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  subtitle: Text('${rule['action']} from ${rule['from']} (ID: ${rule['id']})', style: const TextStyle(color: Color(0xFF94A3B8))),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red),
                    onPressed: () => _managePort('delete', rule['id']),
                    tooltip: 'Hapus Rule',
                  ),
                );
              },
            ),
        ],
      ),
    );
  }
}
