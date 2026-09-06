import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/api_service.dart';

class DatabaseManagerScreen extends StatefulWidget {
  const DatabaseManagerScreen({Key? key}) : super(key: key);

  @override
  _DatabaseManagerScreenState createState() => _DatabaseManagerScreenState();
}

class _DatabaseManagerScreenState extends State<DatabaseManagerScreen> {
  // Visual Explorer State
  bool _isLoadingDbs = true;
  List<String> _databases = [];
  String? _selectedDb;
  
  bool _isLoadingTables = false;
  List<String> _tables = [];
  String? _selectedTable;

  bool _isLoadingRows = false;
  List<String> _columns = [];
  List<List<String>> _rows = [];

  // SQL Console State
  final TextEditingController _queryController = TextEditingController();
  bool _isExecutingQuery = false;
  String _queryResult = '';

  @override
  void initState() {
    super.initState();
    _loadDatabases();
  }

  Future<void> _loadDatabases() async {
    setState(() => _isLoadingDbs = true);
    try {
      final api = Provider.of<ApiService>(context, listen: false);
      final res = await api.get('/database');
      if (mounted) {
        setState(() {
          _databases = List<String>.from(res['data']['databases'] ?? []);
          _isLoadingDbs = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingDbs = false);
        _showError('Gagal memuat database: $e');
      }
    }
  }

  Future<void> _createDatabase(String name) async {
    try {
      final api = Provider.of<ApiService>(context, listen: false);
      await api.post('/database/create', {'name': name});
      _showSuccess('Database $name berhasil dibuat!');
      _loadDatabases();
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
    });
    try {
      final api = Provider.of<ApiService>(context, listen: false);
      final res = await api.get('/database/tables?db=$db');
      if (mounted) {
        setState(() {
          _tables = List<String>.from(res['data']['tables'] ?? []);
          _isLoadingTables = false;
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
      _queryResult = 'Mengeksekusi kueri...';
    });
    try {
      final api = Provider.of<ApiService>(context, listen: false);
      final res = await api.post('/database/query', {'query': _queryController.text});
      if (mounted) {
        setState(() {
          _queryResult = res['data']['output'] ?? 'Sukses (Tidak ada output)';
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
    if (_selectedDb == null) {
      _showError('Pilih database terlebih dahulu di tab Visual Explorer!');
      return;
    }
    _showSuccess('Mengekspor $_selectedDb... Harap tunggu.');
    try {
      final api = Provider.of<ApiService>(context, listen: false);
      final res = await api.get('/database/export?db=$_selectedDb');
      final url = res['data']['download_url'];
      _showSuccess('Backup selesai! Mendownload dari $url');
      // Here you would normally use url_launcher to open the url
    } catch (e) {
      _showError('Gagal export: $e');
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: Colors.red));
  }
  void _showSuccess(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: Colors.green));
  }

  void _showCreateDbDialog() {
    final tc = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: const Text('Buat Database Baru', style: TextStyle(color: Colors.white)),
        content: TextField(
          controller: tc,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            hintText: 'Nama database...',
            hintStyle: TextStyle(color: Colors.white54),
            enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal', style: TextStyle(color: Colors.grey))),
          ElevatedButton(
            onPressed: () {
              if (tc.text.isNotEmpty) {
                Navigator.pop(ctx);
                _createDatabase(tc.text.trim());
              }
            },
            child: const Text('Buat'),
          ),
        ],
      ),
    );
  }

  Widget _buildGlassCard({required Widget child}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xFF0F172A).withOpacity(0.6),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withOpacity(0.1)),
          ),
          child: child,
        ),
      ),
    );
  }

  Widget _buildVisualExplorer() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Left Panel (Databases)
        Expanded(
          flex: 2,
          child: _buildGlassCard(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Databases', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                      IconButton(
                        icon: const Icon(Icons.add_circle, color: Color(0xFF3B82F6)),
                        onPressed: _showCreateDbDialog,
                        tooltip: 'Buat Database Baru',
                      ),
                    ],
                  ),
                ),
                const Divider(color: Colors.white12, height: 1),
                if (_isLoadingDbs)
                  const Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator())
                else
                  Expanded(
                    child: ListView.builder(
                      itemCount: _databases.length,
                      itemBuilder: (ctx, i) {
                        final db = _databases[i];
                        final isSelected = db == _selectedDb;
                        return Container(
                          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(10),
                            color: isSelected ? Theme.of(context).primaryColor.withOpacity(0.15) : Colors.transparent,
                            border: Border.all(color: isSelected ? Theme.of(context).primaryColor.withOpacity(0.3) : Colors.transparent),
                          ),
                          child: ListTile(
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            leading: Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: isSelected ? Theme.of(context).primaryColor.withOpacity(0.2) : Colors.white.withOpacity(0.05),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Icon(Icons.storage, color: isSelected ? Theme.of(context).primaryColor : Colors.white70, size: 18),
                            ),
                            title: Text(db, style: TextStyle(color: isSelected ? Colors.white : Colors.white70, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal, fontSize: 13)),
                            onTap: () => _loadTables(db),
                          ),
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 16),
        
        // Middle Panel (Tables)
        Expanded(
          flex: 2,
          child: _buildGlassCard(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text(_selectedDb == null ? 'Tables' : 'Tables in $_selectedDb', style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                ),
                const Divider(color: Colors.white12, height: 1),
                if (_isLoadingTables)
                  const Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator())
                else if (_selectedDb == null)
                  const Padding(padding: EdgeInsets.all(20), child: Text('Pilih database di sebelah kiri.', style: TextStyle(color: Colors.white54)))
                else if (_tables.isEmpty)
                  const Padding(padding: EdgeInsets.all(20), child: Text('Tidak ada tabel.', style: TextStyle(color: Colors.white54)))
                else
                  Expanded(
                    child: ListView.builder(
                      itemCount: _tables.length,
                      itemBuilder: (ctx, i) {
                        final table = _tables[i];
                        final isSelected = table == _selectedTable;
                        return Container(
                          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(10),
                            color: isSelected ? Theme.of(context).primaryColor.withOpacity(0.15) : Colors.transparent,
                            border: Border.all(color: isSelected ? Theme.of(context).primaryColor.withOpacity(0.3) : Colors.transparent),
                          ),
                          child: ListTile(
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            leading: Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: isSelected ? Theme.of(context).primaryColor.withOpacity(0.2) : Colors.white.withOpacity(0.05),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Icon(Icons.grid_on_rounded, color: isSelected ? Theme.of(context).primaryColor : Colors.white70, size: 18),
                            ),
                            title: Text(table, style: TextStyle(color: isSelected ? Colors.white : Colors.white70, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal, fontSize: 13)),
                            onTap: () => _loadTableRows(table),
                          ),
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 16),

        // Right Panel (Data)
        Expanded(
          flex: 5,
          child: _buildGlassCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text(_selectedTable == null ? 'Data Rows' : 'Data in $_selectedTable', style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                ),
                const Divider(color: Colors.white12, height: 1),
                if (_isLoadingRows)
                  const Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator()))
                else if (_selectedTable == null)
                  const Center(child: Padding(padding: EdgeInsets.all(20), child: Text('Pilih tabel untuk melihat data.', style: TextStyle(color: Colors.white54))))
                else
                  Expanded(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: SingleChildScrollView(
                        child: DataTable(
                          headingRowColor: MaterialStateProperty.all(const Color(0xFF1E293B)),
                          border: TableBorder(
                            horizontalInside: BorderSide(color: Colors.white.withOpacity(0.05), width: 1),
                          ),
                          columns: _columns.map((c) => DataColumn(label: Text(c, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)))).toList(),
                          rows: _rows.asMap().entries.map((entry) {
                            final idx = entry.key;
                            final row = entry.value;
                            return DataRow(
                              color: MaterialStateProperty.all(idx % 2 == 0 ? Colors.transparent : Colors.white.withOpacity(0.02)),
                              cells: row.map((cell) => DataCell(Text(cell, style: const TextStyle(color: Colors.white70)))).toList(),
                            );
                          }).toList(),
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

  Widget _buildSqlConsole() {
    return _buildGlassCard(
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Raw SQL Console', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            TextField(
              controller: _queryController,
              maxLines: 8,
              style: const TextStyle(color: Color(0xFF34D399), fontFamily: 'monospace', fontSize: 14),
              decoration: InputDecoration(
                filled: true,
                fillColor: const Color(0xFF0F172A),
                hintText: 'Ketik kueri SQL di sini... (misal: SHOW DATABASES;)',
                hintStyle: const TextStyle(color: Colors.white24),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
              ),
            ),
            const SizedBox(height: 16),
            Align(
              alignment: Alignment.centerRight,
              child: ElevatedButton.icon(
                onPressed: _isExecutingQuery ? null : _executeQuery,
                icon: _isExecutingQuery ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Icon(Icons.play_arrow),
                label: const Text('Jalankan Kueri'),
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF3B82F6), padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16)),
              ),
            ),
            const SizedBox(height: 24),
            const Text('Output:', style: TextStyle(color: Colors.white70, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF0F172A),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: SingleChildScrollView(
                  child: Text(
                    _queryResult,
                    style: const TextStyle(color: Colors.white, fontFamily: 'monospace', fontSize: 13),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImportExport() {
    return _buildGlassCard(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Export & Import Database', style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(
              _selectedDb == null 
                  ? 'Pilih database terlebih dahulu di tab Visual Explorer untuk mengekspor.' 
                  : 'Database Terpilih: $_selectedDb',
              style: TextStyle(color: _selectedDb == null ? Colors.redAccent : const Color(0xFF34D399), fontSize: 16),
            ),
            const SizedBox(height: 32),
            Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E293B),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      children: [
                        const Icon(Icons.cloud_download, color: Color(0xFF3B82F6), size: 64),
                        const SizedBox(height: 16),
                        const Text('Export Database (.sql)', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        const Text('Unduh seluruh struktur dan data dari database yang terpilih.', textAlign: TextAlign.center, style: TextStyle(color: Colors.white54)),
                        const SizedBox(height: 24),
                        ElevatedButton.icon(
                          onPressed: _exportDatabase,
                          icon: const Icon(Icons.download),
                          label: const Text('Export Sekarang'),
                          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF3B82F6), minimumSize: const Size(double.infinity, 50)),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 32),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E293B),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      children: [
                        const Icon(Icons.cloud_upload, color: Color(0xFF10B981), size: 64),
                        const SizedBox(height: 16),
                        const Text('Import Database (.sql)', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        const Text('Unggah file .sql untuk di-restore ke dalam database yang terpilih.', textAlign: TextAlign.center, style: TextStyle(color: Colors.white54)),
                        const SizedBox(height: 24),
                        ElevatedButton.icon(
                          onPressed: () {
                            _showError('Fitur upload file masih dalam tahap pengembangan.');
                          },
                          icon: const Icon(Icons.upload),
                          label: const Text('Upload File'),
                          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF10B981), minimumSize: const Size(double.infinity, 50)),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            )
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Database Manager', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white)),
          const SizedBox(height: 4),
          const Text('Kelola database MariaDB/MySQL langsung dari panel.', style: TextStyle(color: Colors.white54)),
          const SizedBox(height: 24),
          const TabBar(
            indicatorColor: Color(0xFF3B82F6),
            labelColor: Color(0xFF3B82F6),
            unselectedLabelColor: Colors.white54,
            tabs: [
              Tab(icon: Icon(Icons.account_tree), text: 'Visual Explorer'),
              Tab(icon: Icon(Icons.code), text: 'SQL Console'),
              Tab(icon: Icon(Icons.import_export), text: 'Import / Export'),
            ],
          ),
          const SizedBox(height: 24),
          Expanded(
            child: TabBarView(
              children: [
                _buildVisualExplorer(),
                _buildSqlConsole(),
                _buildImportExport(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
