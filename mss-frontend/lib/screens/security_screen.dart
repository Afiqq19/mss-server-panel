import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../services/api_service.dart';
import '../providers/theme_provider.dart';

class SecurityScreen extends StatefulWidget {
  const SecurityScreen({super.key});

  @override
  State<SecurityScreen> createState() => _SecurityScreenState();
}

class _SecurityScreenState extends State<SecurityScreen> {
  bool _isLoading = true;
  bool _isToggling = false;
  bool _isManagingPort = false;
  bool _isActive = false;
  List<dynamic> _rules = [];
  String _rawOutput = '';
  bool _showRawOutput = false;

  final _portController = TextEditingController();
  String _selectedProtocol = 'tcp';
  String _selectedAction = 'allow';

  final List<Map<String, String>> _portPresets = [
    {'label': 'HTTP (80)', 'port': '80', 'proto': 'tcp'},
    {'label': 'HTTPS (443)', 'port': '443', 'proto': 'tcp'},
    {'label': 'SSH (22)', 'port': '22', 'proto': 'tcp'},
    {'label': 'MySQL (3306)', 'port': '3306', 'proto': 'tcp'},
    {'label': 'Portainer (9443)', 'port': '9443', 'proto': 'tcp'},
    {'label': 'MSS Panel (8000)', 'port': '8000', 'proto': 'tcp'},
  ];

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
        setState(() => _isLoading = false);
        final err = e.toString().replaceAll('Exception: ', '');
        if (!err.contains('Sesi login telah berakhir')) {
          _showToast(err, isError: true);
        }
      }
    }
  }

  Future<void> _confirmToggleUfw(bool targetState) async {
    final action = targetState ? 'enable' : 'disable';
    final actionLabel = targetState ? 'Mengaktifkan' : 'Menonaktifkan';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF0F172A),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: Color(0xFF1E293B)),
        ),
        title: Row(
          children: [
            Icon(
              targetState ? Icons.security_rounded : Icons.warning_amber_rounded,
              color: targetState ? const Color(0xFF10B981) : const Color(0xFFF43F5E),
              size: 24,
            ),
            const SizedBox(width: 10),
            Text('$actionLabel UFW Firewall?', style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Text(
          targetState
              ? 'Firewall akan diaktifkan dan menerapkan seluruh aturan port keamanan pada server host Toshiba.'
              : 'PERINGATAN: Mematikan UFW akan membuka seluruh port yang sedang mendengarkan ke jaringan publik!',
          style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal', style: TextStyle(color: Color(0xFF64748B))),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: targetState ? const Color(0xFF10B981) : const Color(0xFFF43F5E),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Ya, $actionLabel'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      setState(() => _isToggling = true);
      try {
        final api = Provider.of<ApiService>(context, listen: false);
        await api.post('/security/ufw/toggle', {'action': action});
        _showToast('Firewall berhasil di-$action!');
        await _loadUfwStatus();
      } catch (e) {
        _showToast('Gagal mengubah status: $e', isError: true);
      } finally {
        if (mounted) setState(() => _isToggling = false);
      }
    }
  }

  Future<void> _submitPortRule() async {
    final port = _portController.text.trim();
    if (port.isEmpty) {
      _showToast('Masukkan nomor port yang valid', isError: true);
      return;
    }

    setState(() => _isManagingPort = true);
    try {
      final api = Provider.of<ApiService>(context, listen: false);
      await api.post('/security/ufw/port', {
        'port': port,
        'action': _selectedAction,
        if (_selectedProtocol != 'any') 'protocol': _selectedProtocol,
      });
      _portController.clear();
      _showToast('Aturan port $port ($_selectedAction) berhasil diterapkan');
      await _loadUfwStatus();
    } catch (e) {
      _showToast('Gagal mengubah aturan port: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isManagingPort = false);
    }
  }

  Future<void> _deleteRule(String ruleId, String port, String action) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF0F172A),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: Color(0xFF1E293B)),
        ),
        title: Row(
          children: const [
            Icon(Icons.delete_outline_rounded, color: Color(0xFFF43F5E), size: 24),
            SizedBox(width: 10),
            Text('Hapus Aturan Firewall?', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Text(
          'Aturan #$ruleId ($port - $action) akan dihapus dari konfigurasi UFW.',
          style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal', style: TextStyle(color: Color(0xFF64748B))),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFF43F5E),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Hapus Aturan'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        final api = Provider.of<ApiService>(context, listen: false);
        await api.post('/security/ufw/port', {
          'port': ruleId,
          'action': 'delete',
        });
        _showToast('Aturan #$ruleId berhasil dihapus');
        await _loadUfwStatus();
      } catch (e) {
        _showToast('Gagal menghapus aturan: $e', isError: true);
      }
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

    return SingleChildScrollView(
      padding: EdgeInsets.all(isMobile ? 16 : 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Hero
          _buildHeader(themeProvider, isMobile),
          const SizedBox(height: 24),

          if (_isLoading)
            Padding(
              padding: const EdgeInsets.all(60.0),
              child: Center(
                child: Column(
                  children: [
                    CircularProgressIndicator(color: themeProvider.primary),
                    const SizedBox(height: 16),
                    const Text('Memeriksa status firewall UFW...', style: TextStyle(color: Color(0xFF94A3B8))),
                  ],
                ),
              ),
            )
          else ...[
            // Status Firewall Banner
            _buildStatusBanner(themeProvider, isMobile),
            const SizedBox(height: 24),

            // Form + Rules Grid
            LayoutBuilder(
              builder: (context, constraints) {
                final isWide = constraints.maxWidth >= 960;
                if (isWide) {
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(flex: 5, child: _buildPortForm(themeProvider)),
                      const SizedBox(width: 24),
                      Expanded(flex: 6, child: _buildRulesList(themeProvider)),
                    ],
                  );
                }
                return Column(
                  children: [
                    _buildPortForm(themeProvider),
                    const SizedBox(height: 24),
                    _buildRulesList(themeProvider),
                  ],
                );
              },
            ),

            const SizedBox(height: 24),
            // Raw Output Toggle
            _buildRawOutputSection(themeProvider),
          ],
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
                child: const Icon(Icons.shield_rounded, color: Colors.white, size: 28),
              ),
              const SizedBox(width: 18),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Text(
                          'Security & Firewall',
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
                            color: (_isActive ? const Color(0xFF10B981) : const Color(0xFFF43F5E)).withOpacity(0.15),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: (_isActive ? const Color(0xFF10B981) : const Color(0xFFF43F5E)).withOpacity(0.3)),
                          ),
                          child: Text(
                            _isActive ? 'SHIELD ONLINE' : 'SHIELD DISABLED',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: _isActive ? const Color(0xFF10B981) : const Color(0xFFF43F5E),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Kontrol filter paket Linux UFW (Uncomplicated Firewall)',
                      style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
                    ),
                  ],
                ),
              ),
              IconButton.filledTonal(
                tooltip: 'Segarkan Status Firewall',
                style: IconButton.styleFrom(
                  backgroundColor: const Color(0xFF1E293B),
                  foregroundColor: Colors.white,
                ),
                onPressed: _loadUfwStatus,
                icon: const Icon(Icons.refresh_rounded, size: 20),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusBanner(ThemeProvider themeProvider, bool isMobile) {
    final statusColor = _isActive ? const Color(0xFF10B981) : const Color(0xFFF43F5E);

    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            color: const Color(0xFF0F172A).withOpacity(0.85),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: statusColor.withOpacity(0.3), width: 1.2),
            boxShadow: [
              BoxShadow(
                color: statusColor.withOpacity(0.1),
                blurRadius: 24,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: statusColor.withOpacity(0.15),
                  border: Border.all(color: statusColor.withOpacity(0.4), width: 1.5),
                ),
                child: Center(
                  child: Icon(
                    _isActive ? Icons.verified_user_rounded : Icons.gpp_bad_rounded,
                    color: statusColor,
                    size: 26,
                  ),
                ),
              ),
              const SizedBox(width: 18),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _isActive ? 'UFW Firewall Aktif & Melindungi Server' : 'UFW Firewall Nonaktif!',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _isActive
                          ? 'Seluruh port masuk yang tidak diizinkan secara eksplisit otomatis diblokir.'
                          : 'Server rentan terhadap port scanning publik. Sangat disarankan untuk mengaktifkan firewall.',
                      style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12.5),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              if (_isToggling)
                const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2))
              else
                ElevatedButton.icon(
                  onPressed: () => _confirmToggleUfw(!_isActive),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _isActive ? const Color(0xFFF43F5E) : const Color(0xFF10B981),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  icon: Icon(_isActive ? Icons.power_settings_new_rounded : Icons.shield_rounded, size: 18),
                  label: Text(
                    _isActive ? 'Nonaktifkan' : 'Aktifkan UFW',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPortForm(ThemeProvider themeProvider) {
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
                children: [
                  Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      color: themeProvider.primary.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(Icons.add_moderator_rounded, color: themeProvider.primary, size: 18),
                  ),
                  const SizedBox(width: 10),
                  const Text(
                    'Kelola Port Masuk',
                    style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              const SizedBox(height: 18),

              // Presets selector
              const Text(
                'PRESET PORT POPULER',
                style: TextStyle(color: Color(0xFF64748B), fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.0),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _portPresets.map((preset) {
                  return InkWell(
                    onTap: () {
                      setState(() {
                        _portController.text = preset['port']!;
                        _selectedProtocol = preset['proto']!;
                      });
                    },
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E293B).withOpacity(0.6),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.white.withOpacity(0.08)),
                      ),
                      child: Text(
                        preset['label']!,
                        style: const TextStyle(fontSize: 11.5, color: Color(0xFFCBD5E1), fontWeight: FontWeight.w500),
                      ),
                    ),
                  );
                }).toList(),
              ),

              const SizedBox(height: 18),

              // Port input
              TextField(
                controller: _portController,
                keyboardType: TextInputType.number,
                style: const TextStyle(color: Colors.white, fontFamily: 'monospace', fontSize: 14),
                decoration: InputDecoration(
                  labelText: 'Nomor Port atau Rentang Port',
                  hintText: 'Contoh: 8080 atau 8000:8010',
                  hintStyle: TextStyle(color: Colors.white.withOpacity(0.2)),
                  prefixIcon: const Icon(Icons.input_rounded, color: Color(0xFF06B6D4), size: 20),
                  filled: true,
                  fillColor: const Color(0xFF020617).withOpacity(0.6),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.white.withOpacity(0.08)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: themeProvider.primary, width: 1.5),
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Protocol and Action selectors
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('PROTOKOL', style: TextStyle(color: Color(0xFF64748B), fontSize: 11, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          decoration: BoxDecoration(
                            color: const Color(0xFF020617).withOpacity(0.6),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Colors.white.withOpacity(0.08)),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: _selectedProtocol,
                              isExpanded: true,
                              dropdownColor: const Color(0xFF0F172A),
                              style: const TextStyle(color: Colors.white, fontSize: 13),
                              items: const [
                                DropdownMenuItem(value: 'tcp', child: Text('TCP')),
                                DropdownMenuItem(value: 'udp', child: Text('UDP')),
                                DropdownMenuItem(value: 'any', child: Text('TCP & UDP (Any)')),
                              ],
                              onChanged: (val) {
                                if (val != null) setState(() => _selectedProtocol = val);
                              },
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('AKSI ATURAN', style: TextStyle(color: Color(0xFF64748B), fontSize: 11, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          decoration: BoxDecoration(
                            color: const Color(0xFF020617).withOpacity(0.6),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Colors.white.withOpacity(0.08)),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: _selectedAction,
                              isExpanded: true,
                              dropdownColor: const Color(0xFF0F172A),
                              style: const TextStyle(color: Colors.white, fontSize: 13),
                              items: const [
                                DropdownMenuItem(
                                  value: 'allow',
                                  child: Text('ALLOW (Izinkan)', style: TextStyle(color: Color(0xFF10B981), fontWeight: FontWeight.bold)),
                                ),
                                DropdownMenuItem(
                                  value: 'deny',
                                  child: Text('DENY (Tolak)', style: TextStyle(color: Color(0xFFF43F5E), fontWeight: FontWeight.bold)),
                                ),
                              ],
                              onChanged: (val) {
                                if (val != null) setState(() => _selectedAction = val);
                              },
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 22),

              // Submit Button
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: _isManagingPort ? null : _submitPortRule,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: themeProvider.primary,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _isManagingPort
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: const [
                            Icon(Icons.check_rounded, size: 18),
                            SizedBox(width: 8),
                            Text('Terapkan Aturan Port', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                          ],
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRulesList(ThemeProvider themeProvider) {
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
                        padding: const EdgeInsets.all(7),
                        decoration: BoxDecoration(
                          color: const Color(0xFF06B6D4).withOpacity(0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.format_list_bulleted_rounded, color: Color(0xFF06B6D4), size: 18),
                      ),
                      const SizedBox(width: 10),
                      const Text(
                        'Aturan Aktif Firewall',
                        style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold),
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
                      '${_rules.length} RULES',
                      style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),

              if (_rules.isEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
                  decoration: BoxDecoration(
                    color: const Color(0xFF020617).withOpacity(0.4),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFF1E293B)),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: const [
                      Icon(Icons.shield_outlined, size: 48, color: Color(0xFF475569)),
                      SizedBox(height: 14),
                      Text(
                        'Tidak ada aturan khusus aktif',
                        style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
                      ),
                      SizedBox(height: 6),
                      Text(
                        'Tambahkan aturan port untuk mengizinkan layanan eksternal.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Color(0xFF64748B), fontSize: 12),
                      ),
                    ],
                  ),
                )
              else
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _rules.length,
                  separatorBuilder: (ctx, i) => const SizedBox(height: 10),
                  itemBuilder: (ctx, i) {
                    final rule = _rules[i];
                    final String ruleId = rule['id']?.toString() ?? '${i + 1}';
                    final String port = rule['port']?.toString() ?? '';
                    final String action = rule['action']?.toString() ?? 'ALLOW';
                    final String from = rule['from']?.toString() ?? 'Anywhere';

                    final isAllow = action.toUpperCase().contains('ALLOW');
                    final actionColor = isAllow ? const Color(0xFF10B981) : const Color(0xFFF43F5E);

                    return Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF020617).withOpacity(0.6),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFF1E293B)),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFF1E293B),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              '#$ruleId',
                              style: const TextStyle(color: Color(0xFF94A3B8), fontFamily: 'monospace', fontWeight: FontWeight.bold, fontSize: 11),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(
                                      port,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontFamily: 'monospace',
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: actionColor.withOpacity(0.12),
                                        borderRadius: BorderRadius.circular(4),
                                        border: Border.all(color: actionColor.withOpacity(0.3)),
                                      ),
                                      child: Text(
                                        action,
                                        style: TextStyle(
                                          color: actionColor,
                                          fontSize: 9.5,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  'Sumber: $from',
                                  style: const TextStyle(color: Color(0xFF64748B), fontSize: 11),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            tooltip: 'Hapus Aturan #$ruleId',
                            icon: const Icon(Icons.delete_outline_rounded, color: Color(0xFFF43F5E), size: 18),
                            onPressed: () => _deleteRule(ruleId, port, action),
                          ),
                        ],
                      ),
                    );
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRawOutputSection(ThemeProvider themeProvider) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A).withOpacity(0.5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
      ),
      child: ExpansionTile(
        initiallyExpanded: false,
        onExpansionChanged: (exp) => setState(() => _showRawOutput = exp),
        shape: const Border(),
        leading: const Icon(Icons.terminal_rounded, color: Color(0xFF94A3B8), size: 20),
        title: const Text('Log Output Mentah UFW (Raw Status)', style: TextStyle(color: Color(0xFFCBD5E1), fontSize: 13, fontWeight: FontWeight.w600)),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.copy_rounded, size: 16, color: Color(0xFF94A3B8)),
              tooltip: 'Salin Raw Output',
              onPressed: () {
                Clipboard.setData(ClipboardData(text: _rawOutput));
                _showToast('Raw output berhasil disalin');
              },
            ),
            Icon(_showRawOutput ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down, color: Colors.white),
          ],
        ),
        children: [
          Container(
            width: double.infinity,
            margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFF020617),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFF1E293B)),
            ),
            child: SelectableText(
              _rawOutput.isEmpty ? 'Tidak ada output.' : _rawOutput,
              style: const TextStyle(color: Color(0xFF34D399), fontFamily: 'monospace', fontSize: 11.5, height: 1.5),
            ),
          ),
        ],
      ),
    );
  }
}
