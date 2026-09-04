import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/api_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({Key? key}) : super(key: key);

  @override
  _SettingsScreenState createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _accountFormKey = GlobalKey<FormState>();

  final _usernameController = TextEditingController();
  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();

  final _webhookUrlController = TextEditingController(text: 'https://panel.xie.my.id/api/update-rahasia-panel?key=...');
  final _backupPathController = TextEditingController(text: '/var/backups/mss/');

  bool _isSavingAccount = false;
  bool _isLoadingAction = false;
  String _activeAction = '';

  @override
  void dispose() {
    _usernameController.dispose();
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _webhookUrlController.dispose();
    _backupPathController.dispose();
    super.dispose();
  }

  void _showSnackBar(String message, bool isError) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? const Color(0xFFF43F5E) : const Color(0xFF10B981),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  Future<void> _submitAccount() async {
    if (!_accountFormKey.currentState!.validate()) return;
    setState(() => _isSavingAccount = true);

    try {
      final apiService = Provider.of<ApiService>(context, listen: false);
      await apiService.updateAccount(
        username: _usernameController.text,
        currentPassword: _currentPasswordController.text,
        newPassword: _newPasswordController.text,
      );
      
      _currentPasswordController.clear();
      _newPasswordController.clear();
      _showSnackBar('Akun Administrator berhasil diperbarui.', false);
    } catch (e) {
      _showSnackBar(e.toString().replaceAll('Exception: ', ''), true);
    } finally {
      setState(() => _isSavingAccount = false);
    }
  }

  Future<void> _triggerSystemAction(String actionId, String title) async {
    bool? confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: Text('Konfirmasi $title', style: const TextStyle(color: Colors.white)),
        content: Text('Apakah Anda yakin ingin menjalankan aksi "$title"? Ini mungkin memutus koneksi sementara.', style: const TextStyle(color: Color(0xFFCBD5E1))),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal', style: TextStyle(color: Color(0xFF94A3B8))),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFF43F5E)),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Ya, Lanjutkan', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() {
      _isLoadingAction = true;
      _activeAction = actionId;
    });

    try {
      // Simulasi API call untuk action sistem
      await Future.delayed(const Duration(seconds: 2));
      _showSnackBar('Aksi $title berhasil dieksekusi!', false);
    } catch (e) {
      _showSnackBar('Gagal: $e', true);
    } finally {
      setState(() {
        _isLoadingAction = false;
        _activeAction = '';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFF3B82F6).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.settings, color: Color(0xFF3B82F6), size: 24),
              ),
              const SizedBox(width: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text(
                    'Settings & Preferences',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                  Text(
                    'Konfigurasi sistem, akun, dan integrasi panel',
                    style: TextStyle(color: Color(0xFF94A3B8), fontSize: 14),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 32),
          
          Wrap(
            spacing: 24,
            runSpacing: 24,
            crossAxisAlignment: WrapCrossAlignment.start,
            children: [
              // Kolom Kiri
              SizedBox(
                width: 480,
                child: Column(
                  children: [
                    _buildAdminAccountCard(),
                    const SizedBox(height: 24),
                    _buildServerPreferencesCard(),
                  ],
                ),
              ),
              
              // Kolom Kanan
              SizedBox(
                width: 480,
                child: Column(
                  children: [
                    _buildSystemActionsCard(),
                    const SizedBox(height: 24),
                    _buildAboutCard(),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAdminAccountCard() {
    return _buildSettingsSection(
      title: 'Admin Account',
      icon: Icons.shield,
      color: const Color(0xFF10B981),
      child: Form(
        key: _accountFormKey,
        child: Column(
          children: [
            _buildTextField(
              controller: _usernameController,
              label: 'Username',
              icon: Icons.person,
              validator: (v) => v!.isEmpty ? 'Wajib diisi' : null,
            ),
            const SizedBox(height: 16),
            _buildTextField(
              controller: _newPasswordController,
              label: 'Password Baru (Opsional)',
              icon: Icons.lock_reset,
              isPassword: true,
            ),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Divider(color: Color(0xFF1E293B), height: 1),
            ),
            _buildTextField(
              controller: _currentPasswordController,
              label: 'Password Saat Ini (Wajib untuk simpan)',
              icon: Icons.password,
              isPassword: true,
              validator: (v) => v!.isEmpty ? 'Wajib diisi' : null,
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 44,
              child: ElevatedButton(
                onPressed: _isSavingAccount ? null : _submitAccount,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF10B981),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                child: _isSavingAccount
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                    : const Text('Save Changes', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildServerPreferencesCard() {
    return _buildSettingsSection(
      title: 'Server Integration',
      icon: Icons.webhook,
      color: const Color(0xFF8B5CF6),
      child: Column(
        children: [
          _buildTextField(
            controller: _webhookUrlController,
            label: 'GitHub Webhook URL (Auto-Deploy)',
            icon: Icons.link,
            isReadOnly: true,
          ),
          const SizedBox(height: 16),
          _buildTextField(
            controller: _backupPathController,
            label: 'Local NAS Mount Path',
            icon: Icons.folder,
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            height: 44,
            child: ElevatedButton.icon(
              onPressed: () => _showSnackBar('Konfigurasi server berhasil disimpan.', false),
              icon: const Icon(Icons.save, size: 18, color: Colors.white),
              label: const Text('Update Settings', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF8B5CF6),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSystemActionsCard() {
    return _buildSettingsSection(
      title: 'System Actions',
      icon: Icons.power_settings_new,
      color: const Color(0xFFF43F5E),
      child: Column(
        children: [
          _buildActionRow(
            id: 'restart_docker',
            title: 'Restart Docker Engine',
            description: 'Memulai ulang service docker pada Host Ubuntu.',
            icon: Icons.dns,
            btnColor: const Color(0xFFF59E0B),
            btnText: 'Restart',
          ),
          const Divider(color: Color(0xFF1E293B), height: 32),
          _buildActionRow(
            id: 'clear_cache',
            title: 'Clear System Cache',
            description: 'Menghapus log, cache, dan image dangling Docker.',
            icon: Icons.delete_sweep,
            btnColor: const Color(0xFF3B82F6),
            btnText: 'Clear',
          ),
          const Divider(color: Color(0xFF1E293B), height: 32),
          _buildActionRow(
            id: 'reboot_host',
            title: 'Reboot Host OS',
            description: 'Memulai ulang VPS Ubuntu (Hard Reboot).',
            icon: Icons.warning,
            btnColor: const Color(0xFFF43F5E),
            btnText: 'Reboot',
          ),
        ],
      ),
    );
  }

  Widget _buildActionRow({
    required String id,
    required String title,
    required String description,
    required IconData icon,
    required Color btnColor,
    required String btnText,
  }) {
    bool isProcessing = _isLoadingAction && _activeAction == id;
    
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: const Color(0xFF0F172A),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFF1E293B)),
          ),
          child: Icon(icon, color: const Color(0xFF94A3B8), size: 20),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 14)),
              const SizedBox(height: 2),
              Text(description, style: const TextStyle(color: Color(0xFF64748B), fontSize: 12)),
            ],
          ),
        ),
        const SizedBox(width: 12),
        ElevatedButton(
          onPressed: _isLoadingAction ? null : () => _triggerSystemAction(id, title),
          style: ElevatedButton.styleFrom(
            backgroundColor: btnColor.withOpacity(0.15),
            foregroundColor: btnColor,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
              side: BorderSide(color: btnColor.withOpacity(0.5)),
            ),
          ),
          child: isProcessing
              ? SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: btnColor))
              : Text(btnText, style: const TextStyle(fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }

  Widget _buildAboutCard() {
    return _buildSettingsSection(
      title: 'About System',
      icon: Icons.info_outline,
      color: const Color(0xFF06B6D4),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: const [
              Text('MSS Panel Version', style: TextStyle(color: Color(0xFF94A3B8))),
              Text('v1.0.0 (Beta)', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
            ],
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Divider(color: Color(0xFF1E293B), height: 1),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: const [
              Text('Core Framework', style: TextStyle(color: Color(0xFF94A3B8))),
              Text('Flutter Web & Laravel', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
            ],
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Divider(color: Color(0xFF1E293B), height: 1),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: const [
              Text('License', style: TextStyle(color: Color(0xFF94A3B8))),
              Text('Private', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsSection({required String title, required IconData icon, required Color color, required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF0B1120),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF1E293B)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 10),
              Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 0.5)),
            ],
          ),
          const SizedBox(height: 24),
          child,
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool isPassword = false,
    bool isReadOnly = false,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: isPassword,
      readOnly: isReadOnly,
      style: TextStyle(color: isReadOnly ? const Color(0xFF94A3B8) : Colors.white, fontSize: 14),
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Color(0xFF64748B), fontSize: 13),
        prefixIcon: Icon(icon, color: const Color(0xFF475569), size: 18),
        filled: true,
        fillColor: const Color(0xFF0F172A),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFF1E293B)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFF1E293B)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFF3B82F6)),
        ),
      ),
    );
  }
}
