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
  final _envFormKey = GlobalKey<FormState>();

  // Account form controllers
  final _usernameController = TextEditingController();
  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();

  // Env form controllers
  final _portainerUrlController = TextEditingController();
  final _portainerApiKeyController = TextEditingController();
  final _portainerEndpointIdController = TextEditingController();

  bool _isSavingAccount = false;
  bool _isSavingEnv = false;

  @override
  void initState() {
    super.initState();
    _loadCurrentSettings();
  }

  void _loadCurrentSettings() {
    // Ideally we would fetch current settings from a GET /api/settings endpoint,
    // but for now, we'll just leave the ENV fields blank or let the user type them.
    // In a future update, we can prepopulate this.
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _portainerUrlController.dispose();
    _portainerApiKeyController.dispose();
    _portainerEndpointIdController.dispose();
    super.dispose();
  }

  void _showSnackBar(String message, bool isError) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red.shade700 : Colors.green.shade700,
        behavior: SnackBarBehavior.floating,
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
      _showSnackBar('Akun berhasil diperbarui.', false);
    } catch (e) {
      _showSnackBar(e.toString(), true);
    } finally {
      setState(() => _isSavingAccount = false);
    }
  }

  Future<void> _submitEnv() async {
    if (!_envFormKey.currentState!.validate()) return;

    setState(() => _isSavingEnv = true);

    try {
      final apiService = Provider.of<ApiService>(context, listen: false);
      await apiService.updateEnv(
        portainerUrl: _portainerUrlController.text,
        portainerApiKey: _portainerApiKeyController.text,
        portainerEndpointId: int.tryParse(_portainerEndpointIdController.text) ?? 3,
      );
      
      _showSnackBar('Konfigurasi Portainer berhasil diperbarui.', false);
    } catch (e) {
      _showSnackBar(e.toString(), true);
    } finally {
      setState(() => _isSavingEnv = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Settings & Konfigurasi',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 24),
          
          Wrap(
            spacing: 24,
            runSpacing: 24,
            crossAxisAlignment: WrapCrossAlignment.start,
            children: [
              // Card Ganti Akun
              _buildSettingsCard(
                title: 'Akun Administrator',
                icon: Icons.person,
                child: Form(
                  key: _accountFormKey,
                  child: Column(
                    children: [
                      _buildTextField(
                        controller: _usernameController,
                        label: 'Username Baru',
                        icon: Icons.badge,
                        validator: (v) => v!.isEmpty ? 'Wajib diisi' : null,
                      ),
                      const SizedBox(height: 16),
                      _buildTextField(
                        controller: _newPasswordController,
                        label: 'Password Baru (Opsional)',
                        icon: Icons.lock_outline,
                        isPassword: true,
                        validator: (v) {
                          if (v != null && v.isNotEmpty && v.length < 6) {
                            return 'Minimal 6 karakter';
                          }
                          return null;
                        },
                      ),
                      const Divider(height: 32, color: Color(0xFF334155)),
                      _buildTextField(
                        controller: _currentPasswordController,
                        label: 'Password Saat Ini (Wajib)',
                        icon: Icons.key,
                        isPassword: true,
                        validator: (v) => v!.isEmpty ? 'Wajib diisi untuk konfirmasi' : null,
                      ),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: ElevatedButton(
                          onPressed: _isSavingAccount ? null : _submitAccount,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF10B981),
                            foregroundColor: Colors.black,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          child: _isSavingAccount
                              ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                              : const Text('Simpan Akun', style: TextStyle(fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Card Ganti Konfigurasi Portainer
              _buildSettingsCard(
                title: 'Konfigurasi Portainer',
                icon: Icons.api,
                child: Form(
                  key: _envFormKey,
                  child: Column(
                    children: [
                      _buildTextField(
                        controller: _portainerUrlController,
                        label: 'Portainer URL',
                        icon: Icons.link,
                        hint: 'https://192.168.1.100:9443',
                        validator: (v) => v!.isEmpty ? 'Wajib diisi' : null,
                      ),
                      const SizedBox(height: 16),
                      _buildTextField(
                        controller: _portainerApiKeyController,
                        label: 'Portainer API Key',
                        icon: Icons.vpn_key,
                        isPassword: true,
                        validator: (v) => v!.isEmpty ? 'Wajib diisi' : null,
                      ),
                      const SizedBox(height: 16),
                      _buildTextField(
                        controller: _portainerEndpointIdController,
                        label: 'Endpoint ID',
                        icon: Icons.dns,
                        keyboardType: TextInputType.number,
                        hint: '3',
                        validator: (v) => v!.isEmpty ? 'Wajib diisi' : null,
                      ),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: ElevatedButton(
                          onPressed: _isSavingEnv ? null : _submitEnv,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF3B82F6),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          child: _isSavingEnv
                              ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                              : const Text('Simpan Konfigurasi', style: TextStyle(fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsCard({required String title, required IconData icon, required Widget child}) {
    return Container(
      width: 450,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF334155)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: const Color(0xFF94A3B8), size: 24),
              const SizedBox(width: 12),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
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
    String? hint,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: isPassword,
      keyboardType: keyboardType,
      style: const TextStyle(color: Colors.white),
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        labelStyle: const TextStyle(color: Color(0xFF94A3B8)),
        hintStyle: const TextStyle(color: Color(0xFF475569)),
        prefixIcon: Icon(icon, color: const Color(0xFF64748B)),
        filled: true,
        fillColor: const Color(0xFF0F172A),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFF334155)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFF334155)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFF10B981)),
        ),
      ),
    );
  }
}
