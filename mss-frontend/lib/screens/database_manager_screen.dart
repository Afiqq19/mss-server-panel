import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../services/api_service.dart';

class DatabaseManagerScreen extends StatefulWidget {
  const DatabaseManagerScreen({super.key});

  @override
  State<DatabaseManagerScreen> createState() => _DatabaseManagerScreenState();
}

class _DatabaseManagerScreenState extends State<DatabaseManagerScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // Visual Explorer State
  bool _isLoadingDbs = true;
  List<String> _databases = [];
  String? _selectedDb;
  String _dbSearchQuery = '';

  bool _isLoadingTables = false;
  List<String> _tables = [];
  String? _selectedTable;
  String _tableSearchQuery = '';

  bool _isLoadingRows = false;
  List<String> _columns = [];
  List<List<String>> _rows = [];
  String _rowSearchQuery = '';

  // SQL Console State
  String? _selectedConsoleDb;
  final TextEditingController _queryController = TextEditingController(
    text: 'SHOW TABLES;',
  );
  bool _isExecutingQuery = false;
  String _queryResult = '';

  // Import / Export State
  bool _isExporting = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadDatabases();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _queryController.dispose();
    super.dispose();
  }

  // Parse raw string: "[container-name] db_name"
  Map<String, String> _parseDbName(String raw) {
    final match = RegExp(r'^\[(.*?)\]\s+(.*)$').firstMatch(raw);
    if (match != null) {
      return {
        'container': match.group(1) ?? 'host',
        'name': match.group(2) ?? raw,
      };
    }
    return {
      'container': 'host',
      'name': raw,
    };
  }

  List<String> _getUniqueContainers() {
    final containers = <String>{};
    for (final db in _databases) {
      final info = _parseDbName(db);
      containers.add(info['container']!);
    }
    return containers.toList();
  }

  Future<void> _loadDatabases() async {
    setState(() => _isLoadingDbs = true);
    try {
      final api = Provider.of<ApiService>(context, listen: false);
      final res = await api.get('/database');
      if (mounted) {
        final dbs = List<String>.from(res['data']['databases'] ?? []);
        setState(() {
          _databases = dbs;
          _isLoadingDbs = false;
          if (_selectedDb == null && dbs.isNotEmpty) {
            _selectedDb = dbs.first;
            _selectedConsoleDb = dbs.first;
            _loadTables(dbs.first);
          } else if (_selectedDb != null && !dbs.contains(_selectedDb)) {
            _selectedDb = dbs.isNotEmpty ? dbs.first : null;
            _selectedConsoleDb = _selectedDb;
            if (_selectedDb != null) _loadTables(_selectedDb!);
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingDbs = false);
        _showError('Gagal memuat database: $e');
      }
    }
  }

  Future<void> _createDatabase(String name, String? container) async {
    try {
      final api = Provider.of<ApiService>(context, listen: false);
      final payload = {'name': name};
      if (container != null && container.isNotEmpty) {
        payload['container'] = container;
      }
      await api.post('/database/create', payload);
      _showSuccess('Database $name berhasil dibuat!');
      await _loadDatabases();
    } catch (e) {
      _showError('Gagal membuat database: $e');
    }
  }

  Future<void> _loadTables(String db) async {
    setState(() {
      _selectedDb = db;
      _isLoadingTables = true;
      _selectedTable = null;
      _columns = [];
      _rows = [];
      _tableSearchQuery = '';
      _rowSearchQuery = '';
    });
    try {
      final api = Provider.of<ApiService>(context, listen: false);
      final res = await api.get('/database/tables?db=$db');
      if (mounted) {
        final tables = List<String>.from(res['data']['tables'] ?? []);
        setState(() {
          _tables = tables;
          _isLoadingTables = false;
          if (tables.isNotEmpty) {
            _loadTableRows(tables.first);
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingTables = false);
        _showError('Gagal memuat tabel: $e');
      }
    }
  }

  Future<void> _loadTableRows(String table) async {
    setState(() {
      _selectedTable = table;
      _isLoadingRows = true;
      _rowSearchQuery = '';
    });
    try {
      final api = Provider.of<ApiService>(context, listen: false);
      final res = await api.get('/database/rows?db=$_selectedDb&table=$table');
      if (mounted) {
        setState(() {
          _columns = List<String>.from(res['data']['columns'] ?? []);
          var rawRows = res['data']['rows'] as List<dynamic>? ?? [];
          _rows = rawRows.map((e) => List<String>.from(e)).toList();
          _isLoadingRows = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingRows = false);
        _showError('Gagal memuat isi tabel: $e');
      }
    }
  }

  Future<void> _executeQuery() async {
    if (_queryController.text.trim().isEmpty) return;
    setState(() {
      _isExecutingQuery = true;
      _queryResult = 'Mengeksekusi kueri ke ${_selectedConsoleDb ?? "database"}...';
    });
    try {
      final api = Provider.of<ApiService>(context, listen: false);
      final payload = {
        'query': _queryController.text.trim(),
        'db': _selectedConsoleDb ?? '',
      };
      final res = await api.post('/database/query', payload);
      if (mounted) {
        setState(() {
          _queryResult = res['data']['output'] ?? 'Sukses (Query OK, 0 baris kembali)';
          _isExecutingQuery = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _queryResult = 'Error:\n$e';
          _isExecutingQuery = false;
        });
      }
    }
  }

  Future<void> _exportDatabase() async {
    final targetDb = _selectedDb ?? (_databases.isNotEmpty ? _databases.first : null);
    if (targetDb == null) {
      _showError('Belum ada database yang dapat diekspor!');
      return;
    }
    setState(() => _isExporting = true);
    _showSuccess('Mengekspor $targetDb... Harap tunggu sebentar.');
    try {
      final api = Provider.of<ApiService>(context, listen: false);
      final res = await api.get('/database/export?db=$targetDb');
      final url = res['data']['download_url'];
      if (mounted) {
        setState(() => _isExporting = false);
        _showSuccess('Backup selesai! File siap diunduh.');
        _showExportSuccessDialog(url, targetDb);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isExporting = false);
        _showError('Gagal export database: $e');
      }
    }
  }

  void _exportCurrentTableToCsv() {
    if (_columns.isEmpty || _rows.isEmpty) {
      _showError('Tidak ada data untuk diekspor ke CSV!');
      return;
    }
    final buffer = StringBuffer();
    buffer.writeln(_columns.map((c) => '"$c"').join(','));
    for (final row in _rows) {
      buffer.writeln(row.map((cell) => '"${cell.replaceAll('"', '""')}"').join(','));
    }
    Clipboard.setData(ClipboardData(text: buffer.toString()));
    _showSuccess('Data tabel ${_selectedTable ?? ""} (${_rows.length} baris) berhasil disalin sebagai CSV ke Clipboard!');
  }

  void _showExportSuccessDialog(String url, String dbName) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF0F172A),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Color(0xFF334155)),
        ),
        title: Row(
          children: const [
            Icon(Icons.check_circle_rounded, color: Color(0xFF10B981), size: 24),
            SizedBox(width: 10),
            Text('Backup SQL Selesai', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('File dump untuk database $dbName telah berhasil dibuat di server.', style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13)),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.white.withOpacity(0.06)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.link_rounded, color: Color(0xFF60A5FA), size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      url,
                      style: const TextStyle(color: Color(0xFF93C5FD), fontSize: 12, fontFamily: 'monospace'),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.copy_rounded, color: Colors.white70, size: 16),
                    tooltip: 'Salin Link',
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: url));
                      _showSuccess('Link download disalin ke clipboard!');
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Tutup', style: TextStyle(color: Color(0xFF94A3B8))),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF3B82F6),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            icon: const Icon(Icons.download_rounded, size: 18),
            label: const Text('Buka Download'),
            onPressed: () {
              Navigator.pop(ctx);
              Clipboard.setData(ClipboardData(text: url));
              _showSuccess('Link download telah disalin! Silakan paste di tab baru browser.');
            },
          ),
        ],
      ),
    );
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline_rounded, color: Colors.white, size: 20),
            const SizedBox(width: 10),
            Expanded(child: Text(msg)),
          ],
        ),
        backgroundColor: const Color(0xFFE11D48),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  void _showSuccess(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle_outline_rounded, color: Colors.white, size: 20),
            const SizedBox(width: 10),
            Expanded(child: Text(msg)),
          ],
        ),
        backgroundColor: const Color(0xFF059669),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  void _showCreateDbDialog() {
    final nameController = TextEditingController();
    final containers = _getUniqueContainers();
    String? selectedContainer = containers.isNotEmpty ? containers.first : null;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF0F172A),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: Color(0xFF334155)),
          ),
          title: Row(
            children: const [
              Icon(Icons.add_circle_outline_rounded, color: Color(0xFF3B82F6), size: 22),
              SizedBox(width: 10),
              Text('Buat Database Baru', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
            ],
          ),
          content: SizedBox(
            width: 400,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (containers.length > 1) ...[
                  const Text('Pilih Target Container:', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E293B),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFF334155)),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        isExpanded: true,
                        dropdownColor: const Color(0xFF1E293B),
                        value: selectedContainer,
                        style: const TextStyle(color: Colors.white, fontSize: 13),
                        items: containers.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                        onChanged: (v) {
                          setDialogState(() => selectedContainer = v);
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                const Text('Nama Database:', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12, fontWeight: FontWeight.w600)),
                const SizedBox(height: 6),
                TextField(
                  controller: nameController,
                  autofocus: true,
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                  decoration: InputDecoration(
                    hintText: 'contoh: db_ecommerce_baru',
                    hintStyle: const TextStyle(color: Color(0xFF64748B), fontSize: 13),
                    filled: true,
                    fillColor: const Color(0xFF1E293B),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: Color(0xFF334155)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: Color(0xFF3B82F6), width: 1.5),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Gunakan huruf kecil, angka, dan garis bawah (underscore).',
                  style: TextStyle(color: Color(0xFF64748B), fontSize: 11),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Batal', style: TextStyle(color: Color(0xFF94A3B8))),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF3B82F6),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: () {
                final name = nameController.text.trim();
                if (name.isNotEmpty) {
                  Navigator.pop(ctx);
                  _createDatabase(name, selectedContainer);
                }
              },
              child: const Text('Buat Database'),
            ),
          ],
        ),
      ),
    );
  }

  // Modern Card Container
  Widget _buildModernCard({required Widget child, EdgeInsetsGeometry? padding}) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A).withOpacity(0.8),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.25),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Padding(
            padding: padding ?? EdgeInsets.zero,
            child: child,
          ),
        ),
      ),
    );
  }

  // Search Field Component
  Widget _buildCompactSearchField({
    required String hint,
    required String value,
    required ValueChanged<String> onChanged,
    required VoidCallback onClear,
  }) {
    return Container(
      height: 36,
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B).withOpacity(0.9),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF334155)),
      ),
      child: TextField(
        style: const TextStyle(color: Colors.white, fontSize: 12),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(color: Color(0xFF64748B), fontSize: 12),
          prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFF64748B), size: 16),
          suffixIcon: value.isNotEmpty
              ? GestureDetector(
                  onTap: onClear,
                  child: const Icon(Icons.close_rounded, color: Color(0xFF94A3B8), size: 14),
                )
              : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 8),
        ),
        onChanged: onChanged,
      ),
    );
  }

  // Visual Explorer: Databases Panel
  Widget _buildDatabasesPanel() {
    final filteredDbs = _databases.where((db) {
      if (_dbSearchQuery.isEmpty) return true;
      return db.toLowerCase().contains(_dbSearchQuery.toLowerCase());
    }).toList();

    return _buildModernCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 12, 12),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF3B82F6).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.storage_rounded, color: Color(0xFF60A5FA), size: 16),
                ),
                const SizedBox(width: 8),
                const Text(
                  'Databases',
                  style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
                ),
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E293B),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '${filteredDbs.length}',
                    style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11, fontWeight: FontWeight.w600),
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.add_circle_outline_rounded, color: Color(0xFF3B82F6), size: 20),
                  tooltip: 'Buat Database Baru',
                  onPressed: _showCreateDbDialog,
                ),
              ],
            ),
          ),
          // Search input
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: _buildCompactSearchField(
              hint: 'Cari database...',
              value: _dbSearchQuery,
              onChanged: (v) => setState(() => _dbSearchQuery = v),
              onClear: () => setState(() => _dbSearchQuery = ''),
            ),
          ),
          const SizedBox(height: 10),
          const Divider(color: Color(0xFF1E293B), height: 1),

          // List content
          Expanded(
            child: _isLoadingDbs
                ? const Center(
                    child: SizedBox(
                      width: 28,
                      height: 28,
                      child: CircularProgressIndicator(strokeWidth: 2.5, color: Color(0xFF3B82F6)),
                    ),
                  )
                : filteredDbs.isEmpty
                    ? Center(
                        child: Text(
                          _databases.isEmpty ? 'Tidak ada database.' : 'Pencarian tidak ditemukan.',
                          style: const TextStyle(color: Color(0xFF64748B), fontSize: 12),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
                        itemCount: filteredDbs.length,
                        itemBuilder: (ctx, i) {
                          final db = filteredDbs[i];
                          final isSelected = db == _selectedDb;
                          final info = _parseDbName(db);
                          final container = info['container']!;
                          final dbName = info['name']!;

                          return Container(
                            margin: const EdgeInsets.symmetric(vertical: 3),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(10),
                              color: isSelected
                                  ? const Color(0xFF1E3A8A).withOpacity(0.3)
                                  : Colors.transparent,
                              border: Border.all(
                                color: isSelected
                                    ? const Color(0xFF3B82F6).withOpacity(0.5)
                                    : Colors.transparent,
                              ),
                            ),
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                borderRadius: BorderRadius.circular(10),
                                onTap: () => _loadTables(db),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                  child: Row(
                                    children: [
                                      // Left active indicator
                                      Container(
                                        width: 3,
                                        height: 32,
                                        decoration: BoxDecoration(
                                          color: isSelected ? const Color(0xFF3B82F6) : Colors.transparent,
                                          borderRadius: BorderRadius.circular(2),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      // Database details
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            // Container pill badge
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                              decoration: BoxDecoration(
                                                color: isSelected
                                                    ? const Color(0xFF2563EB).withOpacity(0.25)
                                                    : const Color(0xFF1E293B),
                                                borderRadius: BorderRadius.circular(4),
                                                border: Border.all(
                                                  color: isSelected
                                                      ? const Color(0xFF60A5FA).withOpacity(0.3)
                                                      : Colors.white.withOpacity(0.06),
                                                ),
                                              ),
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Icon(
                                                    Icons.layers_rounded,
                                                    size: 10,
                                                    color: isSelected ? const Color(0xFF93C5FD) : const Color(0xFF64748B),
                                                  ),
                                                  const SizedBox(width: 4),
                                                  Text(
                                                    container,
                                                    style: TextStyle(
                                                      fontSize: 10,
                                                      fontWeight: FontWeight.w600,
                                                      color: isSelected ? const Color(0xFF93C5FD) : const Color(0xFF94A3B8),
                                                      letterSpacing: 0.2,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            // Database Name
                                            Text(
                                              dbName,
                                              style: TextStyle(
                                                fontSize: 13,
                                                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                                color: isSelected ? Colors.white : const Color(0xFFE2E8F0),
                                              ),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ],
                                        ),
                                      ),
                                      if (isSelected)
                                        const Icon(Icons.chevron_right_rounded, color: Color(0xFF60A5FA), size: 18),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }

  // Visual Explorer: Tables Panel
  Widget _buildTablesPanel() {
    final filteredTables = _tables.where((t) {
      if (_tableSearchQuery.isEmpty) return true;
      return t.toLowerCase().contains(_tableSearchQuery.toLowerCase());
    }).toList();

    return _buildModernCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 12, 12),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF8B5CF6).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.table_chart_rounded, color: Color(0xFFA78BFA), size: 16),
                ),
                const SizedBox(width: 8),
                const Text(
                  'Tabel',
                  style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
                ),
                if (_selectedDb != null) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E293B),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '${filteredTables.length}',
                      style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
                const Spacer(),
                if (_selectedDb != null)
                  IconButton(
                    icon: const Icon(Icons.refresh_rounded, color: Color(0xFF94A3B8), size: 18),
                    tooltip: 'Segarkan Tabel',
                    onPressed: () => _loadTables(_selectedDb!),
                  ),
              ],
            ),
          ),

          if (_selectedDb != null) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: _buildCompactSearchField(
                hint: 'Cari tabel...',
                value: _tableSearchQuery,
                onChanged: (v) => setState(() => _tableSearchQuery = v),
                onClear: () => setState(() => _tableSearchQuery = ''),
              ),
            ),
            const SizedBox(height: 10),
          ],
          const Divider(color: Color(0xFF1E293B), height: 1),

          // Content
          Expanded(
            child: _isLoadingTables
                ? const Center(
                    child: SizedBox(
                      width: 28,
                      height: 28,
                      child: CircularProgressIndicator(strokeWidth: 2.5, color: Color(0xFF8B5CF6)),
                    ),
                  )
                : _selectedDb == null
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: const Color(0xFF3B82F6).withOpacity(0.08),
                                shape: BoxShape.circle,
                                border: Border.all(color: const Color(0xFF3B82F6).withOpacity(0.15)),
                              ),
                              child: const Icon(Icons.storage_rounded, color: Color(0xFF60A5FA), size: 32),
                            ),
                            const SizedBox(height: 12),
                            const Text(
                              'Pilih Database',
                              style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 4),
                            const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 24),
                              child: Text(
                                'Pilih salah satu database di sebelah kiri untuk melihat daftar tabel.',
                                textAlign: TextAlign.center,
                                style: TextStyle(color: Color(0xFF64748B), fontSize: 12),
                              ),
                            ),
                          ],
                        ),
                      )
                    : filteredTables.isEmpty
                        ? Center(
                            child: Text(
                              _tables.isEmpty ? 'Database ini tidak memiliki tabel.' : 'Tabel tidak ditemukan.',
                              style: const TextStyle(color: Color(0xFF64748B), fontSize: 12),
                            ),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
                            itemCount: filteredTables.length,
                            itemBuilder: (ctx, i) {
                              final table = filteredTables[i];
                              final isSelected = table == _selectedTable;

                              return Container(
                                margin: const EdgeInsets.symmetric(vertical: 2),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(8),
                                  color: isSelected
                                      ? const Color(0xFF8B5CF6).withOpacity(0.2)
                                      : Colors.transparent,
                                  border: Border.all(
                                    color: isSelected
                                        ? const Color(0xFF8B5CF6).withOpacity(0.4)
                                        : Colors.transparent,
                                  ),
                                ),
                                child: ListTile(
                                  dense: true,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                  leading: Container(
                                    padding: const EdgeInsets.all(5),
                                    decoration: BoxDecoration(
                                      color: isSelected
                                          ? const Color(0xFF8B5CF6).withOpacity(0.3)
                                          : const Color(0xFF1E293B),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Icon(
                                      Icons.grid_view_rounded,
                                      color: isSelected ? const Color(0xFFC4B5FD) : const Color(0xFF94A3B8),
                                      size: 14,
                                    ),
                                  ),
                                  title: Text(
                                    table,
                                    style: TextStyle(
                                      fontSize: 12.5,
                                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                      color: isSelected ? Colors.white : const Color(0xFFCBD5E1),
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  trailing: isSelected
                                      ? const Icon(Icons.chevron_right_rounded, color: Color(0xFFA78BFA), size: 16)
                                      : null,
                                  onTap: () => _loadTableRows(table),
                                ),
                              );
                            },
                          ),
          ),
        ],
      ),
    );
  }

  // Visual Explorer: Data Rows Panel
  Widget _buildDataRowsPanel() {
    final filteredRows = _rows.where((row) {
      if (_rowSearchQuery.isEmpty) return true;
      final q = _rowSearchQuery.toLowerCase();
      return row.any((cell) => cell.toLowerCase().contains(q));
    }).toList();

    return _buildModernCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header Toolbar
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.view_agenda_rounded, color: Color(0xFF34D399), size: 16),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Row(
                    children: [
                      Flexible(
                        child: Text(
                          _selectedTable == null ? 'Data Rows' : _selectedTable!,
                          style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (_selectedTable != null) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1E293B),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Colors.white.withOpacity(0.06)),
                          ),
                          child: Text(
                            '${filteredRows.length} baris',
                            style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11, fontWeight: FontWeight.w600),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1E293B),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Colors.white.withOpacity(0.06)),
                          ),
                          child: Text(
                            '${_columns.length} kolom',
                            style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (_selectedTable != null) ...[
                  // Row search box
                  SizedBox(
                    width: 180,
                    child: _buildCompactSearchField(
                      hint: 'Cari dalam tabel...',
                      value: _rowSearchQuery,
                      onChanged: (v) => setState(() => _rowSearchQuery = v),
                      onClear: () => setState(() => _rowSearchQuery = ''),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.copy_rounded, color: Color(0xFF94A3B8), size: 18),
                    tooltip: 'Salin sebagai CSV',
                    onPressed: _exportCurrentTableToCsv,
                  ),
                  IconButton(
                    icon: const Icon(Icons.refresh_rounded, color: Color(0xFF94A3B8), size: 18),
                    tooltip: 'Muat Ulang Data',
                    onPressed: () => _loadTableRows(_selectedTable!),
                  ),
                ],
              ],
            ),
          ),
          const Divider(color: Color(0xFF1E293B), height: 1),

          // Content
          Expanded(
            child: _isLoadingRows
                ? const Center(
                    child: SizedBox(
                      width: 28,
                      height: 28,
                      child: CircularProgressIndicator(strokeWidth: 2.5, color: Color(0xFF10B981)),
                    ),
                  )
                : _selectedTable == null
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: const Color(0xFF818CF8).withOpacity(0.08),
                                shape: BoxShape.circle,
                                border: Border.all(color: const Color(0xFF818CF8).withOpacity(0.15)),
                              ),
                              child: const Icon(Icons.table_view_rounded, color: Color(0xFFA5B4FC), size: 36),
                            ),
                            const SizedBox(height: 14),
                            const Text(
                              'Pratinjau Data Tabel',
                              style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 4),
                            const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 32),
                              child: Text(
                                'Klik pada salah satu tabel di panel tengah untuk melihat isi data dan kolom.',
                                textAlign: TextAlign.center,
                                style: TextStyle(color: Color(0xFF64748B), fontSize: 12),
                              ),
                            ),
                          ],
                        ),
                      )
                    : filteredRows.isEmpty
                        ? Center(
                            child: Text(
                              _rows.isEmpty ? 'Tabel ini tidak memiliki data (0 baris).' : 'Tidak ada baris yang cocok dengan pencarian.',
                              style: const TextStyle(color: Color(0xFF64748B), fontSize: 12),
                            ),
                          )
                        : Scrollbar(
                            thumbVisibility: true,
                            child: SingleChildScrollView(
                              scrollDirection: Axis.vertical,
                              child: Scrollbar(
                                thumbVisibility: true,
                                notificationPredicate: (n) => n.depth == 1,
                                child: SingleChildScrollView(
                                  scrollDirection: Axis.horizontal,
                                  child: DataTable(
                                    headingRowHeight: 40,
                                    dataRowMinHeight: 38,
                                    dataRowMaxHeight: 46,
                                    horizontalMargin: 16,
                                    columnSpacing: 24,
                                    headingRowColor: MaterialStateProperty.all(const Color(0xFF0F172A)),
                                    border: TableBorder(
                                      horizontalInside: BorderSide(color: Colors.white.withOpacity(0.04), width: 1),
                                    ),
                                    columns: _columns.map((c) {
                                      return DataColumn(
                                        label: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            const Icon(Icons.tag_rounded, size: 12, color: Color(0xFF60A5FA)),
                                            const SizedBox(width: 4),
                                            Text(
                                              c,
                                              style: const TextStyle(
                                                color: Color(0xFFF1F5F9),
                                                fontWeight: FontWeight.w700,
                                                fontSize: 12,
                                                letterSpacing: 0.3,
                                              ),
                                            ),
                                          ],
                                        ),
                                      );
                                    }).toList(),
                                    rows: filteredRows.asMap().entries.map((entry) {
                                      final idx = entry.key;
                                      final row = entry.value;
                                      return DataRow(
                                        color: MaterialStateProperty.all(
                                          idx % 2 == 0 ? Colors.transparent : Colors.white.withOpacity(0.02),
                                        ),
                                        cells: row.map((cell) {
                                          final isNull = cell.isEmpty || cell == 'NULL';
                                          return DataCell(
                                            isNull
                                                ? Container(
                                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                    decoration: BoxDecoration(
                                                      color: const Color(0xFF1E293B),
                                                      borderRadius: BorderRadius.circular(4),
                                                    ),
                                                    child: const Text(
                                                      'NULL',
                                                      style: TextStyle(
                                                        color: Color(0xFF64748B),
                                                        fontSize: 10,
                                                        fontStyle: FontStyle.italic,
                                                        fontWeight: FontWeight.w600,
                                                      ),
                                                    ),
                                                  )
                                                : SelectableText(
                                                    cell,
                                                    style: const TextStyle(
                                                      color: Color(0xFFCBD5E1),
                                                      fontSize: 12,
                                                      fontFamily: 'monospace',
                                                    ),
                                                  ),
                                          );
                                        }).toList(),
                                      );
                                    }).toList(),
                                  ),
                                ),
                              ),
                            ),
                          ),
          ),

          // Footer Status Bar
          if (_selectedTable != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: const BoxDecoration(
                color: Color(0xFF0F172A),
                border: Border(top: BorderSide(color: Color(0xFF1E293B))),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline_rounded, size: 14, color: Color(0xFF64748B)),
                  const SizedBox(width: 6),
                  Text(
                    'Menampilkan ${filteredRows.length} baris (Maksimal 100 baris pertama)',
                    style: const TextStyle(color: Color(0xFF64748B), fontSize: 11),
                  ),
                  const Spacer(),
                  const Text(
                    'Gunakan SQL Console untuk pagination atau query lanjutan',
                    style: TextStyle(color: Color(0xFF475569), fontSize: 11),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  // Visual Explorer View Layout
  Widget _buildVisualExplorer() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Left: Databases
        Expanded(
          flex: 3,
          child: _buildDatabasesPanel(),
        ),
        const SizedBox(width: 14),

        // Middle: Tables
        Expanded(
          flex: 3,
          child: _buildTablesPanel(),
        ),
        const SizedBox(width: 14),

        // Right: Data Rows
        Expanded(
          flex: 7,
          child: _buildDataRowsPanel(),
        ),
      ],
    );
  }

  // SQL Console View Layout
  Widget _buildSqlConsole() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Left: Query Editor
        Expanded(
          flex: 6,
          child: _buildModernCard(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header & Target DB Dropdown
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF3B82F6).withOpacity(0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.terminal_rounded, color: Color(0xFF60A5FA), size: 20),
                    ),
                    const SizedBox(width: 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Text('SQL Query Editor', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                        Text('MariaDB / MySQL Terminal Client', style: TextStyle(color: Color(0xFF64748B), fontSize: 11)),
                      ],
                    ),
                    const Spacer(),
                    // Target Database Selector
                    if (_databases.isNotEmpty) ...[
                      const Text('Target DB: ', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12)),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        height: 34,
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E293B),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFF334155)),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: _selectedConsoleDb ?? (_databases.isNotEmpty ? _databases.first : null),
                            dropdownColor: const Color(0xFF1E293B),
                            style: const TextStyle(color: Colors.white, fontSize: 12),
                            items: _databases.map((db) => DropdownMenuItem(value: db, child: Text(db))).toList(),
                            onChanged: (v) {
                              setState(() => _selectedConsoleDb = v);
                            },
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 16),

                // Quick Snippet Chips
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    _buildSnippetChip('SHOW DATABASES;', () => _queryController.text = 'SHOW DATABASES;'),
                    _buildSnippetChip('SHOW TABLES;', () => _queryController.text = 'SHOW TABLES;'),
                    _buildSnippetChip('SHOW PROCESSLIST;', () => _queryController.text = 'SHOW PROCESSLIST;'),
                    if (_selectedTable != null)
                      _buildSnippetChip('SELECT * FROM `$_selectedTable` LIMIT 20;', () {
                        _queryController.text = 'SELECT * FROM `$_selectedTable` LIMIT 20;';
                      }),
                    if (_selectedTable != null)
                      _buildSnippetChip('DESCRIBE `$_selectedTable`;', () {
                        _queryController.text = 'DESCRIBE `$_selectedTable`;';
                      }),
                  ],
                ),
                const SizedBox(height: 14),

                // Editor Frame
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFF070D19),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFF1E293B)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Window Bar
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: const BoxDecoration(
                            color: Color(0xFF0F172A),
                            borderRadius: BorderRadius.vertical(top: Radius.circular(9)),
                            border: Border(bottom: BorderSide(color: Color(0xFF1E293B))),
                          ),
                          child: Row(
                            children: [
                              Row(
                                children: [
                                  Container(width: 8, height: 8, decoration: const BoxDecoration(color: Color(0xFFEF4444), shape: BoxShape.circle)),
                                  const SizedBox(width: 6),
                                  Container(width: 8, height: 8, decoration: const BoxDecoration(color: Color(0xFFF59E0B), shape: BoxShape.circle)),
                                  const SizedBox(width: 6),
                                  Container(width: 8, height: 8, decoration: const BoxDecoration(color: Color(0xFF10B981), shape: BoxShape.circle)),
                                ],
                              ),
                              const SizedBox(width: 12),
                              const Text('query.sql', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 11, fontFamily: 'monospace')),
                              const Spacer(),
                              GestureDetector(
                                onTap: () => _queryController.clear(),
                                child: const Text('Bersihkan', style: TextStyle(color: Color(0xFF64748B), fontSize: 11)),
                              ),
                            ],
                          ),
                        ),
                        // Text input
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: TextField(
                              controller: _queryController,
                              maxLines: null,
                              expands: true,
                              style: const TextStyle(
                                color: Color(0xFF34D399),
                                fontFamily: 'monospace',
                                fontSize: 13,
                                height: 1.5,
                              ),
                              decoration: const InputDecoration(
                                hintText: '-- Tulis kueri SQL di sini...\nSELECT * FROM users LIMIT 10;',
                                hintStyle: TextStyle(color: Color(0xFF334155), fontFamily: 'monospace'),
                                border: InputBorder.none,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 14),

                // Execute Button
                Align(
                  alignment: Alignment.centerRight,
                  child: ElevatedButton.icon(
                    onPressed: _isExecutingQuery ? null : _executeQuery,
                    icon: _isExecutingQuery
                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : const Icon(Icons.play_arrow_rounded, size: 20),
                    label: const Text('Jalankan Kueri (Run)', style: TextStyle(fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2563EB),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      elevation: 4,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 14),

        // Right: Query Results
        Expanded(
          flex: 6,
          child: _buildModernCard(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981).withOpacity(0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.receipt_long_rounded, color: Color(0xFF34D399), size: 20),
                    ),
                    const SizedBox(width: 10),
                    const Text('Hasil Eksekusi', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                    const Spacer(),
                    if (_queryResult.isNotEmpty)
                      IconButton(
                        icon: const Icon(Icons.copy_rounded, color: Color(0xFF94A3B8), size: 18),
                        tooltip: 'Salin Hasil',
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: _queryResult));
                          _showSuccess('Hasil output disalin ke clipboard!');
                        },
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF070D19),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFF1E293B)),
                    ),
                    child: _queryResult.isEmpty
                        ? const Center(
                            child: Text(
                              'Hasil kueri SQL akan ditampilkan di sini.',
                              style: TextStyle(color: Color(0xFF475569), fontSize: 13, fontFamily: 'monospace'),
                            ),
                          )
                        : Scrollbar(
                            thumbVisibility: true,
                            child: SingleChildScrollView(
                              child: SelectableText(
                                _queryResult,
                                style: TextStyle(
                                  color: _queryResult.startsWith('Error:')
                                      ? const Color(0xFFF87171)
                                      : const Color(0xFFE2E8F0),
                                  fontFamily: 'monospace',
                                  fontSize: 12.5,
                                  height: 1.4,
                                ),
                              ),
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSnippetChip(String label, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: const Color(0xFF1E293B),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: Colors.white.withOpacity(0.06)),
        ),
        child: Text(
          label,
          style: const TextStyle(color: Color(0xFF93C5FD), fontSize: 11, fontFamily: 'monospace'),
        ),
      ),
    );
  }

  // Backup & Restore View Layout
  Widget _buildImportExport() {
    final activeDb = _selectedDb ?? (_databases.isNotEmpty ? _databases.first : 'Tidak ada');

    return _buildModernCard(
      padding: const EdgeInsets.all(28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF3B82F6), Color(0xFF1D4ED8)],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.cloud_sync_rounded, color: Colors.white, size: 24),
              ),
              const SizedBox(width: 14),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text('Backup & Restore Database', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                  SizedBox(height: 2),
                  Text('Ekspor struktur dan data database menjadi file .sql murni menggunakan utilitas native container.', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Active Database Banner
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF1E293B).withOpacity(0.7),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF334155)),
            ),
            child: Row(
              children: [
                const Icon(Icons.dns_rounded, color: Color(0xFF60A5FA), size: 20),
                const SizedBox(width: 10),
                const Text('Database Aktif:', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13, fontWeight: FontWeight.w600)),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF3B82F6).withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFF3B82F6).withOpacity(0.4)),
                  ),
                  child: Text(
                    activeDb,
                    style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold, fontFamily: 'monospace'),
                  ),
                ),
                const Spacer(),
                if (_databases.isNotEmpty) ...[
                  const Text('Ganti Database: ', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12)),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    height: 34,
                    decoration: BoxDecoration(
                      color: const Color(0xFF0F172A),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFF334155)),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _selectedDb ?? (_databases.isNotEmpty ? _databases.first : null),
                        dropdownColor: const Color(0xFF0F172A),
                        style: const TextStyle(color: Colors.white, fontSize: 12),
                        items: _databases.map((db) => DropdownMenuItem(value: db, child: Text(db))).toList(),
                        onChanged: (v) {
                          if (v != null) _loadTables(v);
                        },
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Cards
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Export Card
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: const Color(0xFF131D33),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFF1E3A8A).withOpacity(0.5)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFF3B82F6).withOpacity(0.15),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.file_download_outlined, color: Color(0xFF60A5FA), size: 32),
                        ),
                        const SizedBox(height: 16),
                        const Text('Export Database (.sql)', style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        const Text(
                          'Mendownload seluruh skema, tabel, trigger, dan seluruh baris data dari database yang aktif sebagai file .sql terkompresi.',
                          style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13, height: 1.4),
                        ),
                        const Spacer(),
                        ElevatedButton.icon(
                          onPressed: _isExporting ? null : _exportDatabase,
                          icon: _isExporting
                              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                              : const Icon(Icons.download_rounded),
                          label: Text(_isExporting ? 'Mengekspor...' : 'Export SQL Sekarang', style: const TextStyle(fontWeight: FontWeight.bold)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF3B82F6),
                            foregroundColor: Colors.white,
                            minimumSize: const Size(double.infinity, 48),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 20),

                // Import Card
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: const Color(0xFF122426),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFF065F46).withOpacity(0.5)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFF10B981).withOpacity(0.15),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.file_upload_outlined, color: Color(0xFF34D399), size: 32),
                        ),
                        const SizedBox(height: 16),
                        const Text('Import & Restore Database (.sql)', style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        const Text(
                          'Pulihkan atau masukkan data baru dari file backup .sql langsung ke database aktif tanpa batas ukuran timeout PHP.',
                          style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13, height: 1.4),
                        ),
                        const Spacer(),
                        ElevatedButton.icon(
                          onPressed: () {
                            _showSuccess('Gunakan tab "SQL Query Console" untuk menjalankan script DDL/DML, atau upload file SQL ke server via File Manager / SSH.');
                          },
                          icon: const Icon(Icons.upload_file_rounded),
                          label: const Text('Petunjuk Restore SQL', style: TextStyle(fontWeight: FontWeight.bold)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF10B981),
                            foregroundColor: Colors.white,
                            minimumSize: const Size(double.infinity, 48),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Modern Top Header & Segmented Pill Navigation
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Icon & Title
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF3B82F6), Color(0xFF1D4ED8)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF3B82F6).withOpacity(0.35),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: const Icon(Icons.storage_rounded, color: Colors.white, size: 22),
            ),
            const SizedBox(width: 14),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text(
                      'Database Manager',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFF3B82F6).withOpacity(0.15),
                        border: Border.all(color: const Color(0xFF3B82F6).withOpacity(0.3)),
                        borderRadius: BorderRadius.circular(16),
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
                            'Multi-Container MariaDB',
                            style: TextStyle(
                              color: Color(0xFF93C5FD),
                              fontSize: 10.5,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                const Text(
                  'Kelola skema tabel, telusuri isi data, dan eksekusi kueri multi-container.',
                  style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
                ),
              ],
            ),
            const Spacer(),

            // Modern Segmented Pill TabBar
            Container(
              height: 42,
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                color: const Color(0xFF0F172A).withOpacity(0.9),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.white.withOpacity(0.08)),
              ),
              child: TabBar(
                controller: _tabController,
                isScrollable: true,
                tabAlignment: TabAlignment.start,
                indicator: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF2563EB), Color(0xFF1D4ED8)],
                  ),
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF2563EB).withOpacity(0.4),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                indicatorSize: TabBarIndicatorSize.tab,
                dividerColor: Colors.transparent,
                labelColor: Colors.white,
                unselectedLabelColor: const Color(0xFF94A3B8),
                labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5),
                unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500, fontSize: 12.5),
                tabs: const [
                  Tab(
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: 10),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.dashboard_customize_rounded, size: 16),
                          SizedBox(width: 6),
                          Text('Visual Explorer'),
                        ],
                      ),
                    ),
                  ),
                  Tab(
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: 10),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.terminal_rounded, size: 16),
                          SizedBox(width: 6),
                          Text('SQL Console'),
                        ],
                      ),
                    ),
                  ),
                  Tab(
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: 10),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.swap_vert_rounded, size: 16),
                          SizedBox(width: 6),
                          Text('Backup & Restore'),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),

        // Tab Views
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildVisualExplorer(),
              _buildSqlConsole(),
              _buildImportExport(),
            ],
          ),
        ),
      ],
    );
  }
}
