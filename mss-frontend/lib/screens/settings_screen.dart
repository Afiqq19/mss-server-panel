import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/app_launcher_model.dart';
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

  // Portainer Config Controllers
  final _portainerUrlController = TextEditingController(text: 'https://portainer.xie.my.id');
  final _portainerApiKeyController = TextEditingController();
  final _portainerEndpointIdController = TextEditingController(text: '3');

  bool _isSavingAccount = false;
  bool _isSavingPortainer = false;
  bool _isLoadingAction = false;
  String _activeAction = '';

  // App Launcher Management
  List<AppLauncherModel> _launchers = [];
  bool _isLoadingLaunchers = true;

  @override
  void initState() {
    super.initState();
    _loadLaunchers();
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

  Future<void> _loadLaunchers() async {
    final api = Provider.of<ApiService>(context, listen: false);
    setState(() => _isLoadingLaunchers = true);
    try {
      final data = await api.fetchAppLaunchers();
      if (mounted) {
        setState(() {
          _launchers = data;
          _isLoadingLaunchers = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingLaunchers = false);
    }
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

  Future<void> _submitPortainerConfig() async {
    setState(() => _isSavingPortainer = true);
    try {
      final apiService = Provider.of<ApiService>(context, listen: false);
      await apiService.updateEnv(
        portainerUrl: _portainerUrlController.text,
        portainerApiKey: _portainerApiKeyController.text,
        portainerEndpointId: int.tryParse(_portainerEndpointIdController.text) ?? 2,
      );
      _showSnackBar('Konfigurasi Portainer berhasil diperbarui. Restart backend mungkin diperlukan.', false);
    } catch (e) {
      _showSnackBar(e.toString().replaceAll('Exception: ', ''), true);
    } finally {
      setState(() => _isSavingPortainer = false);
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
      final api = Provider.of<ApiService>(context, listen: false);
      await api.executeTerminalCommand(
        actionId == 'restart_docker' ? 'sudo systemctl restart docker' :
        actionId == 'clear_cache' ? 'sudo docker system prune -f && sudo apt-get clean' :
        'sudo reboot',
      );
      _showSnackBar('Aksi $title berhasil dieksekusi!', false);
    } catch (e) {
      _showSnackBar('Gagal: ${e.toString().replaceAll("Exception: ", "")}', true);
    } finally {
      setState(() {
        _isLoadingAction = false;
        _activeAction = '';
      });
    }
  }

  Future<void> _confirmLogout() async {
    bool? confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: const [
            Icon(Icons.logout, color: Color(0xFFF43F5E), size: 22),
            SizedBox(width: 10),
            Text('Logout', style: TextStyle(color: Colors.white)),
          ],
        ),
        content: const Text(
          'Apakah Anda yakin ingin keluar dari MSS Panel? Anda harus login kembali untuk mengakses dashboard.',
          style: TextStyle(color: Color(0xFFCBD5E1)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal', style: TextStyle(color: Color(0xFF94A3B8))),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFF43F5E),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Ya, Logout', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final api = Provider.of<ApiService>(context, listen: false);
      await api.logout();
    }
  }

  // ==========================================
  // APP LAUNCHER CRUD DIALOGS
  // ==========================================
  void _showAddLauncherDialog() {
    _showLauncherFormDialog(null);
  }

  void _showEditLauncherDialog(AppLauncherModel launcher) {
    _showLauncherFormDialog(launcher);
  }

  void _showLauncherFormDialog(AppLauncherModel? existing) {
    final isEdit = existing != null;
    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    final urlCtrl = TextEditingController(text: existing?.url ?? '');
    final descCtrl = TextEditingController(text: existing?.description ?? '');
    String selectedIcon = existing?.icon ?? 'web';
    String selectedCategory = existing?.category ?? 'General';
    bool isActive = existing?.isActive ?? true;
    bool isSaving = false;

    final iconOptions = ['web', 'docker', 'cloud', 'school', 'storage', 'database'];
    final categoryOptions = ['General', 'Infrastructure', 'Application', 'Storage', 'Database'];

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return AlertDialog(
              backgroundColor: const Color(0xFF0F172A),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: const BorderSide(color: Color(0xFF1E293B)),
              ),
              title: Row(
                children: [
                  Icon(
                    isEdit ? Icons.edit : Icons.add_circle_outline,
                    color: const Color(0xFF8B5CF6),
                    size: 22,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    isEdit ? 'Edit App Launcher' : 'Tambah App Launcher Baru',
                    style: const TextStyle(color: Colors.white, fontSize: 16),
                  ),
                ],
              ),
              content: SizedBox(
                width: 420,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildDialogTextField(nameCtrl, 'Nama Aplikasi', Icons.label, 'contoh: Portainer'),
                      const SizedBox(height: 12),
                      _buildDialogTextField(urlCtrl, 'URL / Link', Icons.link, 'https://...'),
                      const SizedBox(height: 12),
                      _buildDialogTextField(descCtrl, 'Deskripsi (opsional)', Icons.description, 'Keterangan singkat'),
                      const SizedBox(height: 16),
                      // Icon Selector
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Icon', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12)),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: iconOptions.map((iconName) {
                              final isSelected = selectedIcon == iconName;
                              return GestureDetector(
                                onTap: () => setDialogState(() => selectedIcon = iconName),
                                child: Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: isSelected ? const Color(0xFF8B5CF6).withOpacity(0.2) : const Color(0xFF1E293B),
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                      color: isSelected ? const Color(0xFF8B5CF6) : const Color(0xFF334155),
                                    ),
                                  ),
                                  child: Column(
                                    children: [
                                      Icon(_iconFromString(iconName), color: isSelected ? const Color(0xFF8B5CF6) : const Color(0xFF64748B), size: 22),
                                      const SizedBox(height: 4),
                                      Text(iconName, style: TextStyle(fontSize: 9, color: isSelected ? Colors.white : const Color(0xFF64748B))),
                                    ],
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      // Category Dropdown
                      DropdownButtonFormField<String>(
                        value: selectedCategory,
                        dropdownColor: const Color(0xFF1E293B),
                        style: const TextStyle(color: Colors.white, fontSize: 14),
                        decoration: InputDecoration(
                          labelText: 'Kategori',
                          labelStyle: const TextStyle(color: Color(0xFF64748B), fontSize: 13),
                          prefixIcon: const Icon(Icons.category, color: Color(0xFF475569), size: 18),
                          filled: true,
                          fillColor: const Color(0xFF0B1120),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: const BorderSide(color: Color(0xFF1E293B)),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: const BorderSide(color: Color(0xFF1E293B)),
                          ),
                        ),
                        items: categoryOptions.map((cat) => DropdownMenuItem(value: cat, child: Text(cat))).toList(),
                        onChanged: (val) => setDialogState(() => selectedCategory = val!),
                      ),
                      const SizedBox(height: 16),
                      // Active Toggle
                      SwitchListTile(
                        value: isActive,
                        onChanged: (val) => setDialogState(() => isActive = val),
                        title: const Text('Aktif', style: TextStyle(color: Colors.white, fontSize: 14)),
                        subtitle: Text(
                          isActive ? 'Shortcut akan ditampilkan di Dashboard' : 'Shortcut disembunyikan',
                          style: const TextStyle(color: Color(0xFF64748B), fontSize: 11),
                        ),
                        activeColor: const Color(0xFF10B981),
                        contentPadding: EdgeInsets.zero,
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Batal', style: TextStyle(color: Color(0xFF94A3B8))),
                ),
                ElevatedButton(
                  onPressed: isSaving ? null : () async {
                    if (nameCtrl.text.isEmpty || urlCtrl.text.isEmpty) {
                      _showSnackBar('Nama dan URL wajib diisi!', true);
                      return;
                    }
                    setDialogState(() => isSaving = true);
                    try {
                      final api = Provider.of<ApiService>(context, listen: false);
                      if (isEdit) {
                        await api.updateAppLauncher(
                          id: existing.id,
                          name: nameCtrl.text,
                          url: urlCtrl.text,
                          icon: selectedIcon,
                          description: descCtrl.text,
                          category: selectedCategory,
                          isActive: isActive,
                        );
                        _showSnackBar('App Launcher "${nameCtrl.text}" berhasil diupdate!', false);
                      } else {
                        await api.createAppLauncher(
                          name: nameCtrl.text,
                          url: urlCtrl.text,
                          icon: selectedIcon,
                          description: descCtrl.text,
                          category: selectedCategory,
                          isActive: isActive,
                        );
                        _showSnackBar('App Launcher "${nameCtrl.text}" berhasil ditambahkan!', false);
                      }
                      Navigator.pop(ctx);
                      _loadLaunchers();
                    } catch (e) {
                      _showSnackBar(e.toString().replaceAll('Exception: ', ''), true);
                      setDialogState(() => isSaving = false);
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF8B5CF6),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: isSaving
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : Text(isEdit ? 'Update' : 'Simpan', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _confirmDeleteLauncher(AppLauncherModel launcher) async {
    bool? confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: const [
            Icon(Icons.delete_forever, color: Color(0xFFF43F5E), size: 22),
            SizedBox(width: 10),
            Text('Hapus App Launcher', style: TextStyle(color: Colors.white)),
          ],
        ),
        content: Text(
          'Apakah Anda yakin ingin menghapus "${launcher.name}"? Shortcut ini akan hilang dari Dashboard.',
          style: const TextStyle(color: Color(0xFFCBD5E1)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal', style: TextStyle(color: Color(0xFF94A3B8))),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFF43F5E)),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Ya, Hapus', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        final api = Provider.of<ApiService>(context, listen: false);
        await api.deleteAppLauncher(launcher.id);
        _showSnackBar('"${launcher.name}" berhasil dihapus!', false);
        _loadLaunchers();
      } catch (e) {
        _showSnackBar(e.toString().replaceAll('Exception: ', ''), true);
      }
    }
  }

  Widget _buildDialogTextField(TextEditingController ctrl, String label, IconData icon, String hint) {
    return TextFormField(
      controller: ctrl,
      style: const TextStyle(color: Colors.white, fontSize: 14),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        hintStyle: const TextStyle(color: Color(0xFF334155), fontSize: 13),
        labelStyle: const TextStyle(color: Color(0xFF64748B), fontSize: 13),
        prefixIcon: Icon(icon, color: const Color(0xFF475569), size: 18),
        filled: true,
        fillColor: const Color(0xFF0B1120),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFF1E293B))),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFF1E293B))),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFF8B5CF6))),
      ),
    );
  }

  IconData _iconFromString(String iconName) {
    switch (iconName.toLowerCase()) {
      case 'docker': return Icons.dns;
      case 'cloud': return Icons.cloud_circle;
      case 'school': return Icons.school;
      case 'storage': return Icons.storage;
      case 'database': return Icons.dataset;
      case 'web': return Icons.language;
      default: return Icons.rocket_launch;
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
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
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text(
                      'Settings & Preferences',
                      style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                    Text(
                      'Kelola akun, shortcut, integrasi Portainer, dan aksi sistem',
                      style: TextStyle(color: Color(0xFF94A3B8), fontSize: 14),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),

          // ==================== APP LAUNCHER MANAGER ====================
          _buildAppLauncherManagerCard(),

          const SizedBox(height: 24),
          
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
                    _buildPortainerConfigCard(),
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
                    const SizedBox(height: 24),
                    _buildLogoutCard(),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ==========================================
  // APP LAUNCHER MANAGER CARD
  // ==========================================
  Widget _buildAppLauncherManagerCard() {
    return _buildSettingsSection(
      title: 'App Launcher Manager',
      icon: Icons.rocket_launch,
      color: const Color(0xFF8B5CF6),
      description: 'Kelola shortcut aplikasi yang muncul di halaman Dashboard. Anda bisa menambah, mengedit, atau menghapus link aplikasi.',
      headerAction: ElevatedButton.icon(
        onPressed: _showAddLauncherDialog,
        icon: const Icon(Icons.add, size: 16, color: Colors.white),
        label: const Text('Tambah Baru', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 12)),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF8B5CF6),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
      child: _isLoadingLaunchers
          ? const Center(child: Padding(
              padding: EdgeInsets.all(20),
              child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF8B5CF6)),
            ))
          : _launchers.isEmpty
              ? Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F172A),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFF1E293B)),
                  ),
                  child: Center(
                    child: Column(
                      children: const [
                        Icon(Icons.apps, size: 32, color: Color(0xFF475569)),
                        SizedBox(height: 8),
                        Text('Belum ada App Launcher. Klik "Tambah Baru" untuk membuat shortcut pertama.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Color(0xFF64748B), fontSize: 13)),
                      ],
                    ),
                  ),
                )
              : Column(
                  children: _launchers.map((launcher) => _buildLauncherRow(launcher)).toList(),
                ),
    );
  }

  Widget _buildLauncherRow(AppLauncherModel launcher) {
    final color = _getCategoryColor(launcher.category);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF1E293B)),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(_iconFromString(launcher.icon), color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(launcher.name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14), overflow: TextOverflow.ellipsis),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(launcher.category.toUpperCase(), style: TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: color)),
                    ),
                    if (!launcher.isActive) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF43F5E).withOpacity(0.12),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text('HIDDEN', style: TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: Color(0xFFF43F5E))),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(launcher.url, style: const TextStyle(color: Color(0xFF64748B), fontSize: 11), maxLines: 1, overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.edit_outlined, size: 18, color: Color(0xFF3B82F6)),
            tooltip: 'Edit',
            onPressed: () => _showEditLauncherDialog(launcher),
            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
            padding: EdgeInsets.zero,
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, size: 18, color: Color(0xFFF43F5E)),
            tooltip: 'Hapus',
            onPressed: () => _confirmDeleteLauncher(launcher),
            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
            padding: EdgeInsets.zero,
          ),
        ],
      ),
    );
  }

  Color _getCategoryColor(String category) {
    switch (category.toLowerCase()) {
      case 'infrastructure': return const Color(0xFF06B6D4);
      case 'storage': return const Color(0xFF3B82F6);
      case 'application': case 'app': return const Color(0xFF10B981);
      case 'database': return const Color(0xFFF59E0B);
      default: return const Color(0xFF8B5CF6);
    }
  }

  // ==========================================
  // ADMIN ACCOUNT CARD
  // ==========================================
  Widget _buildAdminAccountCard() {
    return _buildSettingsSection(
      title: 'Admin Account',
      icon: Icons.shield,
      color: const Color(0xFF10B981),
      description: 'Ubah username dan password administrator panel. Password saat ini wajib diisi untuk verifikasi.',
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

  // ==========================================
  // PORTAINER CONFIG CARD (baru)
  // ==========================================
  Widget _buildPortainerConfigCard() {
    return _buildSettingsSection(
      title: 'Portainer Integration',
      icon: Icons.dns,
      color: const Color(0xFF06B6D4),
      description: 'Konfigurasi koneksi ke Portainer untuk manajemen Docker Container. Pastikan API Key dan Endpoint ID sesuai dengan environment server.',
      child: Column(
        children: [
          _buildTextField(
            controller: _portainerUrlController,
            label: 'Portainer URL',
            icon: Icons.link,
          ),
          const SizedBox(height: 16),
          _buildTextField(
            controller: _portainerApiKeyController,
            label: 'Portainer API Key',
            icon: Icons.vpn_key,
            isPassword: true,
          ),
          const SizedBox(height: 16),
          _buildTextField(
            controller: _portainerEndpointIdController,
            label: 'Endpoint ID',
            icon: Icons.numbers,
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            height: 44,
            child: ElevatedButton.icon(
              onPressed: _isSavingPortainer ? null : _submitPortainerConfig,
              icon: _isSavingPortainer
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.save, size: 18, color: Colors.white),
              label: const Text('Simpan Konfigurasi', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF06B6D4),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // SYSTEM ACTIONS CARD
  // ==========================================
  Widget _buildSystemActionsCard() {
    return _buildSettingsSection(
      title: 'System Actions',
      icon: Icons.power_settings_new,
      color: const Color(0xFFF43F5E),
      description: 'Aksi server level root. Hati-hati — beberapa aksi bisa memutus koneksi sementara atau merestart service.',
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
            description: 'Memulai ulang VPS Ubuntu (Hard Reboot). Koneksi akan terputus.',
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

  // ==========================================
  // ABOUT CARD
  // ==========================================
  Widget _buildAboutCard() {
    return _buildSettingsSection(
      title: 'About System',
      icon: Icons.info_outline,
      color: const Color(0xFF06B6D4),
      description: 'Informasi tentang versi dan teknologi yang digunakan oleh MSS Server Panel.',
      child: Column(
        children: [
          _buildInfoRow('MSS Panel Version', 'v1.0.3 (Beta)'),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Divider(color: Color(0xFF1E293B), height: 1),
          ),
          _buildInfoRow('Core Framework', 'Flutter Web & Laravel'),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Divider(color: Color(0xFF1E293B), height: 1),
          ),
          _buildInfoRow('Docker Manager', 'Portainer API v2'),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Divider(color: Color(0xFF1E293B), height: 1),
          ),
          _buildInfoRow('Backup Target', 'Nextcloud NAS'),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Divider(color: Color(0xFF1E293B), height: 1),
          ),
          _buildInfoRow('License', 'Private'),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13)),
        Text(value, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 13)),
      ],
    );
  }

  // ==========================================
  // LOGOUT CARD (baru)
  // ==========================================
  Widget _buildLogoutCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF0B1120),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFF43F5E).withOpacity(0.3)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFF43F5E).withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFF43F5E).withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.logout, color: Color(0xFFF43F5E), size: 20),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text('Logout dari Panel', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 15)),
                SizedBox(height: 2),
                Text('Keluar dari sesi login. Token akan dihapus dari server dan browser.', style: TextStyle(color: Color(0xFF64748B), fontSize: 12)),
              ],
            ),
          ),
          const SizedBox(width: 12),
          ElevatedButton.icon(
            onPressed: _confirmLogout,
            icon: const Icon(Icons.logout, size: 16, color: Colors.white),
            label: const Text('Logout', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFF43F5E),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // SHARED WIDGETS
  // ==========================================
  Widget _buildSettingsSection({
    required String title,
    required IconData icon,
    required Color color,
    required Widget child,
    String? description,
    Widget? headerAction,
  }) {
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
              Expanded(
                child: Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 0.5)),
              ),
              if (headerAction != null) headerAction,
            ],
          ),
          if (description != null) ...[
            const SizedBox(height: 8),
            Text(description, style: const TextStyle(color: Color(0xFF64748B), fontSize: 12)),
          ],
          const SizedBox(height: 20),
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
