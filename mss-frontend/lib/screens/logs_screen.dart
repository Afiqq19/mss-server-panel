import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../services/api_service.dart';
import '../providers/theme_provider.dart';

class LogsScreen extends StatefulWidget {
  const LogsScreen({super.key});

  @override
  State<LogsScreen> createState() => _LogsScreenState();
}

class _LogsScreenState extends State<LogsScreen> {
  bool _isLoading = true;
  String _selectedLogType = 'syslog';
  int _selectedLines = 100;
  String _logContent = '';
  String _searchQuery = '';
  final ScrollController _scrollController = ScrollController();

  final Map<String, Map<String, dynamic>> _logTypes = {
    'syslog': {
      'title': 'Syslog (System)',
      'path': '/var/log/syslog',
      'icon': Icons.article_rounded,
      'color': Color(0xFF06B6D4),
    },
    'auth': {
      'title': 'Auth (SSH / Login)',
      'path': '/var/log/auth.log',
      'icon': Icons.vpn_key_rounded,
      'color': Color(0xFF8B5CF6),
    },
    'docker': {
      'title': 'Docker Daemon',
      'path': 'journalctl -u docker',
      'icon': Icons.layers_rounded,
      'color': Color(0xFF3B82F6),
    },
    'nginx_access': {
      'title': 'Nginx Access',
      'path': '/var/log/nginx/access.log',
      'icon': Icons.public_rounded,
      'color': Color(0xFF10B981),
    },
    'nginx_error': {
      'title': 'Nginx Error',
      'path': '/var/log/nginx/error.log',
      'icon': Icons.error_outline_rounded,
      'color': Color(0xFFF43F5E),
    },
  };

  @override
  void initState() {
    super.initState();
    _loadLogs();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadLogs() async {
    setState(() => _isLoading = true);
    try {
      final api = Provider.of<ApiService>(context, listen: false);
      final res = await api.get('/logs?type=$_selectedLogType&lines=$_selectedLines');
      if (mounted) {
        setState(() {
          _logContent = res['data']['logs'] ?? '';
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _logContent = 'Gagal membaca logs: $e';
          _isLoading = false;
        });
      }
    }
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  void _showToast(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: const Color(0xFF10B981),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    final isMobile = MediaQuery.of(context).size.width < 768;

    final lines = _logContent.split('\n');
    final filteredLines = _searchQuery.isEmpty
        ? lines
        : lines.where((line) => line.toLowerCase().contains(_searchQuery.toLowerCase())).toList();

    return Padding(
      padding: EdgeInsets.all(isMobile ? 16 : 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Hero
          _buildHeader(themeProvider, isMobile),
          const SizedBox(height: 20),

          // Log Type Selector Tabs
          _buildLogTypeChips(themeProvider),
          const SizedBox(height: 16),

          // Search and Filter Bar
          _buildFilterToolbar(themeProvider, isMobile, filteredLines.length),
          const SizedBox(height: 14),

          // Terminal Viewport
          Expanded(
            child: _buildTerminalView(themeProvider, filteredLines),
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
          padding: EdgeInsets.symmetric(horizontal: isMobile ? 16 : 22, vertical: 16),
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
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [themeProvider.primary, themeProvider.secondary],
                  ),
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: themeProvider.glow.withOpacity(0.35),
                      blurRadius: 14,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Icon(Icons.receipt_long_rounded, color: Colors.white, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text(
                      'System Logs Viewer',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        letterSpacing: 0.3,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Live inspection log sistem Ubuntu, auth SSH, dan web server',
                      style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
                    ),
                  ],
                ),
              ),
              IconButton.filledTonal(
                tooltip: 'Muat Ulang Log',
                style: IconButton.styleFrom(
                  backgroundColor: const Color(0xFF1E293B),
                  foregroundColor: Colors.white,
                ),
                onPressed: _loadLogs,
                icon: const Icon(Icons.refresh_rounded, size: 18),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLogTypeChips(ThemeProvider themeProvider) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: _logTypes.entries.map((entry) {
          final isSelected = _selectedLogType == entry.key;
          final Color typeColor = entry.value['color'];
          final IconData icon = entry.value['icon'];
          final String title = entry.value['title'];

          return Padding(
            padding: const EdgeInsets.only(right: 10),
            child: InkWell(
              onTap: () {
                setState(() => _selectedLogType = entry.key);
                _loadLogs();
              },
              borderRadius: BorderRadius.circular(12),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: isSelected ? typeColor.withOpacity(0.18) : const Color(0xFF0F172A).withOpacity(0.8),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isSelected ? typeColor : Colors.white.withOpacity(0.08),
                    width: isSelected ? 1.5 : 1.0,
                  ),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: typeColor.withOpacity(0.25),
                            blurRadius: 10,
                            offset: const Offset(0, 2),
                          )
                        ]
                      : [],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(icon, size: 16, color: isSelected ? typeColor : const Color(0xFF94A3B8)),
                    const SizedBox(width: 8),
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                        color: isSelected ? Colors.white : const Color(0xFFCBD5E1),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildFilterToolbar(ThemeProvider themeProvider, bool isMobile, int resultCount) {
    return Row(
      children: [
        // Search Filter
        Expanded(
          child: Container(
            height: 40,
            decoration: BoxDecoration(
              color: const Color(0xFF0F172A).withOpacity(0.85),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.white.withOpacity(0.08)),
            ),
            child: TextField(
              onChanged: (val) => setState(() => _searchQuery = val.trim()),
              style: const TextStyle(color: Colors.white, fontSize: 13),
              decoration: InputDecoration(
                hintText: 'Cari kata kunci dalam baris log...',
                hintStyle: TextStyle(color: Colors.white.withOpacity(0.25), fontSize: 12),
                prefixIcon: const Icon(Icons.search_rounded, size: 17, color: Color(0xFF64748B)),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded, size: 15, color: Color(0xFF94A3B8)),
                        onPressed: () => setState(() => _searchQuery = ''),
                      )
                    : null,
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                border: InputBorder.none,
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),

        // Line Count Dropdown
        Container(
          height: 40,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: const Color(0xFF0F172A).withOpacity(0.85),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.white.withOpacity(0.08)),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<int>(
              value: _selectedLines,
              dropdownColor: const Color(0xFF0F172A),
              style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
              items: const [
                DropdownMenuItem(value: 50, child: Text('50 Baris')),
                DropdownMenuItem(value: 100, child: Text('100 Baris')),
                DropdownMenuItem(value: 200, child: Text('200 Baris')),
                DropdownMenuItem(value: 500, child: Text('500 Baris')),
              ],
              onChanged: (val) {
                if (val != null) {
                  setState(() => _selectedLines = val);
                  _loadLogs();
                }
              },
            ),
          ),
        ),
        const SizedBox(width: 8),

        // Copy button
        IconButton(
          tooltip: 'Salin Seluruh Log',
          style: IconButton.styleFrom(
            backgroundColor: const Color(0xFF1E293B),
            foregroundColor: Colors.white,
          ),
          icon: const Icon(Icons.copy_rounded, size: 16),
          onPressed: () {
            Clipboard.setData(ClipboardData(text: _logContent));
            _showToast('Seluruh teks log berhasil disalin');
          },
        ),

        // Scroll to bottom
        IconButton(
          tooltip: 'Scroll ke Bawah',
          style: IconButton.styleFrom(
            backgroundColor: const Color(0xFF1E293B),
            foregroundColor: Colors.white,
          ),
          icon: const Icon(Icons.arrow_downward_rounded, size: 16),
          onPressed: _scrollToBottom,
        ),
      ],
    );
  }

  Widget _buildTerminalView(ThemeProvider themeProvider, List<String> lines) {
    final activeType = _logTypes[_selectedLogType];
    final path = activeType?['path'] ?? '';

    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF030712),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFF1E293B), width: 1.2),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.5),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          children: [
            // Window Header Bar
            Container(
              height: 38,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: const BoxDecoration(
                color: Color(0xFF0B132B),
                border: Border(bottom: BorderSide(color: Color(0xFF1E293B))),
              ),
              child: Row(
                children: [
                  Container(width: 10, height: 10, decoration: const BoxDecoration(color: Color(0xFFF43F5E), shape: BoxShape.circle)),
                  const SizedBox(width: 6),
                  Container(width: 10, height: 10, decoration: const BoxDecoration(color: Color(0xFFF59E0B), shape: BoxShape.circle)),
                  const SizedBox(width: 6),
                  Container(width: 10, height: 10, decoration: const BoxDecoration(color: Color(0xFF10B981), shape: BoxShape.circle)),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      'root@toshiba-server:$path',
                      style: const TextStyle(
                        color: Color(0xFF94A3B8),
                        fontFamily: 'monospace',
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E293B),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      '${lines.length} lines',
                      style: const TextStyle(color: Color(0xFF64748B), fontSize: 10.5, fontFamily: 'monospace'),
                    ),
                  ),
                ],
              ),
            ),

            // Content
            Expanded(
              child: _isLoading
                  ? Center(
                      child: CircularProgressIndicator(color: themeProvider.primary),
                    )
                  : lines.isEmpty
                      ? const Center(
                          child: Text(
                            'Tidak ada log ditemukan.',
                            style: TextStyle(color: Color(0xFF64748B), fontFamily: 'monospace'),
                          ),
                        )
                      : ListView.builder(
                          controller: _scrollController,
                          padding: const EdgeInsets.all(14),
                          itemCount: lines.length,
                          itemBuilder: (context, index) {
                            final line = lines[index];
                            final lower = line.toLowerCase();

                            Color textColor = const Color(0xFFCBD5E1);
                            if (lower.contains('error') || lower.contains('fail') || lower.contains('fatal') || lower.contains('critical')) {
                              textColor = const Color(0xFFFDA4AF); // Rose red
                            } else if (lower.contains('warn') || lower.contains('warning')) {
                              textColor = const Color(0xFFFDE68A); // Amber
                            } else if (lower.contains('accepted') || lower.contains('success') || lower.contains('200 ok')) {
                              textColor = const Color(0xFF6EE7B7); // Emerald
                            } else if (lower.contains('info') || lower.contains('systemd')) {
                              textColor = const Color(0xFF67E8F9); // Cyan
                            }

                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 2.0),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  SizedBox(
                                    width: 38,
                                    child: Text(
                                      '${index + 1}',
                                      style: const TextStyle(
                                        color: Color(0xFF334155),
                                        fontFamily: 'monospace',
                                        fontSize: 11,
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                    child: SelectableText(
                                      line,
                                      style: TextStyle(
                                        color: textColor,
                                        fontFamily: 'monospace',
                                        fontSize: 11.5,
                                        height: 1.4,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }
}
