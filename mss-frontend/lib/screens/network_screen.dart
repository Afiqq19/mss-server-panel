import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/network_model.dart';
import '../services/api_service.dart';
import '../providers/theme_provider.dart';

class NetworkScreen extends StatefulWidget {
  const NetworkScreen({super.key});

  @override
  State<NetworkScreen> createState() => _NetworkScreenState();
}

class _NetworkScreenState extends State<NetworkScreen> {
  bool _isLoading = true;
  String? _errorMessage;
  NetworkInfoModel? _networkInfo;
  String _portSearchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadNetworkInfo();
  }

  Future<void> _loadNetworkInfo() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final api = context.read<ApiService>();
      final data = await api.fetchNetworkInfo();
      if (data.isNotEmpty && mounted) {
        setState(() {
          _networkInfo = NetworkInfoModel.fromJson(data);
          _isLoading = false;
        });
      } else if (mounted) {
        setState(() {
          _errorMessage = 'Data jaringan kosong dari server.';
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString().replaceAll('Exception: ', '');
          _isLoading = false;
        });
      }
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

    if (_isLoading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: themeProvider.primary),
            const SizedBox(height: 16),
            const Text('Memindai konfigurasi jaringan & socket server...', style: TextStyle(color: Color(0xFF94A3B8))),
          ],
        ),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Container(
          padding: const EdgeInsets.all(32),
          constraints: const BoxConstraints(maxWidth: 480),
          decoration: BoxDecoration(
            color: const Color(0xFF0F172A),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFFF43F5E).withOpacity(0.3)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.wifi_off_rounded, color: Color(0xFFF43F5E), size: 48),
              const SizedBox(height: 16),
              const Text('Gagal Memuat Jaringan', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text(_errorMessage!, style: const TextStyle(color: Color(0xFF94A3B8)), textAlign: TextAlign.center),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(backgroundColor: themeProvider.primary, foregroundColor: Colors.white),
                onPressed: _loadNetworkInfo,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Coba Lagi'),
              ),
            ],
          ),
        ),
      );
    }

    if (_networkInfo == null) return const SizedBox.shrink();

    return RefreshIndicator(
      onRefresh: _loadNetworkInfo,
      color: themeProvider.primary,
      backgroundColor: const Color(0xFF0F172A),
      child: SingleChildScrollView(
        padding: EdgeInsets.all(isMobile ? 16 : 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Hero
            _buildHeader(themeProvider, isMobile),
            const SizedBox(height: 24),

            // Overview Metric Cards
            _buildOverviewCards(themeProvider),
            const SizedBox(height: 28),

            // Network Interfaces Grid
            _buildInterfacesSection(themeProvider),
            const SizedBox(height: 28),

            // Listening Ports Section with Live Filter
            _buildPortsSection(themeProvider),
            const SizedBox(height: 28),

            // DNS Servers
            _buildDnsSection(themeProvider),
          ],
        ),
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
                child: const Icon(Icons.router_rounded, color: Colors.white, size: 28),
              ),
              const SizedBox(width: 18),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text(
                      'Network & Interfaces Cockpit',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        letterSpacing: 0.3,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Monitoring IP Publik, adapter jaringan, port soket listening, dan DNS',
                      style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
                    ),
                  ],
                ),
              ),
              IconButton.filledTonal(
                tooltip: 'Segarkan Jaringan',
                style: IconButton.styleFrom(
                  backgroundColor: const Color(0xFF1E293B),
                  foregroundColor: Colors.white,
                ),
                onPressed: _loadNetworkInfo,
                icon: const Icon(Icons.refresh_rounded, size: 20),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOverviewCards(ThemeProvider themeProvider) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 640;
        final cards = [
          _buildInfoCard(
            title: 'IP PUBLIK SERVER',
            value: _networkInfo!.publicIp,
            icon: Icons.public_rounded,
            color: const Color(0xFF06B6D4),
            canCopy: true,
          ),
          _buildInfoCard(
            title: 'HOSTNAME SYSTEM',
            value: _networkInfo!.hostname,
            icon: Icons.dns_rounded,
            color: const Color(0xFF8B5CF6),
            canCopy: false,
          ),
          _buildInfoCard(
            title: 'ADAPTER JARINGAN',
            value: '${_networkInfo!.interfaces.length} Interface',
            icon: Icons.settings_ethernet_rounded,
            color: const Color(0xFF10B981),
            canCopy: false,
          ),
          _buildInfoCard(
            title: 'PORT LISTENING',
            value: '${_networkInfo!.listening.length} Soket Aktif',
            icon: Icons.lan_rounded,
            color: const Color(0xFFF59E0B),
            canCopy: false,
          ),
        ];

        if (isNarrow) {
          return Column(
            children: cards.map((c) => Padding(padding: const EdgeInsets.only(bottom: 12), child: c)).toList(),
          );
        }
        return GridView.count(
          crossAxisCount: constraints.maxWidth > 1000 ? 4 : 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          childAspectRatio: constraints.maxWidth > 1000 ? 2.4 : 2.6,
          children: cards,
        );
      },
    );
  }

  Widget _buildInfoCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
    required bool canCopy,
  }) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: const Color(0xFF0F172A).withOpacity(0.85),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: color.withOpacity(0.25)),
            boxShadow: [
              BoxShadow(
                color: color.withOpacity(0.06),
                blurRadius: 14,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: color.withOpacity(0.3)),
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: Color(0xFF64748B),
                        fontSize: 10.5,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.0,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      value,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        fontFamily: 'monospace',
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              if (canCopy)
                IconButton(
                  tooltip: 'Salin IP Publik',
                  icon: const Icon(Icons.copy_rounded, size: 16, color: Color(0xFF94A3B8)),
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: value));
                    _showToast('IP Publik berhasil disalin');
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInterfacesSection(ThemeProvider themeProvider) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: const Color(0xFF10B981).withOpacity(0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.settings_ethernet_rounded, size: 16, color: Color(0xFF10B981)),
            ),
            const SizedBox(width: 10),
            const Text(
              'NETWORK ADAPTERS & INTERFACES',
              style: TextStyle(fontSize: 14, letterSpacing: 1.0, fontWeight: FontWeight.w800, color: Colors.white),
            ),
          ],
        ),
        const SizedBox(height: 16),
        LayoutBuilder(
          builder: (context, constraints) {
            final isNarrow = constraints.maxWidth < 640;
            if (isNarrow) {
              return Column(
                children: _networkInfo!.interfaces
                    .map((iface) => Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _buildInterfaceCard(iface),
                        ))
                    .toList(),
              );
            }
            return GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: constraints.maxWidth > 960 ? 3 : 2,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                mainAxisExtent: 148,
              ),
              itemCount: _networkInfo!.interfaces.length,
              itemBuilder: (context, index) => _buildInterfaceCard(_networkInfo!.interfaces[index]),
            );
          },
        ),
      ],
    );
  }

  Widget _buildInterfaceCard(NetworkInterfaceModel iface) {
    final stateColor = iface.isUp ? const Color(0xFF10B981) : const Color(0xFFF43F5E);
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF0F172A).withOpacity(0.85),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: stateColor.withOpacity(0.25)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    iface.name,
                    style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800, fontFamily: 'monospace'),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: stateColor.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: stateColor.withOpacity(0.3)),
                    ),
                    child: Text(
                      iface.state.toUpperCase(),
                      style: TextStyle(color: stateColor, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 0.5),
                    ),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.hub_rounded, size: 14, color: Color(0xFF06B6D4)),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          iface.ip.isNotEmpty ? iface.ip : 'No IPv4 Assigned',
                          style: TextStyle(
                            color: iface.ip.isNotEmpty ? const Color(0xFFCBD5E1) : const Color(0xFF64748B),
                            fontSize: 12.5,
                            fontFamily: 'monospace',
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  if (iface.mac.isNotEmpty)
                    Row(
                      children: [
                        const Icon(Icons.fingerprint_rounded, size: 14, color: Color(0xFF64748B)),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            iface.mac,
                            style: const TextStyle(color: Color(0xFF64748B), fontSize: 11, fontFamily: 'monospace'),
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPortsSection(ThemeProvider themeProvider) {
    final filtered = _networkInfo!.listening.where((p) {
      if (_portSearchQuery.isEmpty) return true;
      final q = _portSearchQuery.toLowerCase();
      return p.port.toLowerCase().contains(q) ||
          p.proto.toLowerCase().contains(q) ||
          p.bind.toLowerCase().contains(q) ||
          p.process.toLowerCase().contains(q);
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF59E0B).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.lan_rounded, size: 16, color: Color(0xFFF59E0B)),
                ),
                const SizedBox(width: 10),
                const Text(
                  'LISTENING PORTS & SOCKETS',
                  style: TextStyle(fontSize: 14, letterSpacing: 1.0, fontWeight: FontWeight.w800, color: Colors.white),
                ),
              ],
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(color: const Color(0xFF1E293B), borderRadius: BorderRadius.circular(10)),
              child: Text('${filtered.length} Soket', style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Search Filter
        Container(
          height: 40,
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: const Color(0xFF0F172A).withOpacity(0.85),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.white.withOpacity(0.08)),
          ),
          child: TextField(
            onChanged: (val) => setState(() => _portSearchQuery = val.trim()),
            style: const TextStyle(color: Colors.white, fontSize: 13),
            decoration: InputDecoration(
              hintText: 'Filter port (contoh: 80, 443, 3306, nginx, docker)...',
              hintStyle: TextStyle(color: Colors.white.withOpacity(0.25), fontSize: 12),
              prefixIcon: const Icon(Icons.search_rounded, size: 17, color: Color(0xFF64748B)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              border: InputBorder.none,
            ),
          ),
        ),

        // Ports Table
        ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: const Color(0xFF0F172A).withOpacity(0.85),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withOpacity(0.08)),
            ),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                headingRowColor: WidgetStateProperty.all(const Color(0xFF020617).withOpacity(0.6)),
                dataRowMinHeight: 46,
                dataRowMaxHeight: 46,
                columns: const [
                  DataColumn(label: Text('PORT', style: TextStyle(color: Color(0xFF94A3B8), fontWeight: FontWeight.bold, fontSize: 12))),
                  DataColumn(label: Text('PROTOKOL', style: TextStyle(color: Color(0xFF94A3B8), fontWeight: FontWeight.bold, fontSize: 12))),
                  DataColumn(label: Text('BIND ADDRESS', style: TextStyle(color: Color(0xFF94A3B8), fontWeight: FontWeight.bold, fontSize: 12))),
                  DataColumn(label: Text('DAEMON / PROCESS', style: TextStyle(color: Color(0xFF94A3B8), fontWeight: FontWeight.bold, fontSize: 12))),
                ],
                rows: filtered.map((port) {
                  return DataRow(cells: [
                    DataCell(
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFF06B6D4).withOpacity(0.12),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: const Color(0xFF06B6D4).withOpacity(0.25)),
                        ),
                        child: Text(
                          port.port,
                          style: const TextStyle(color: Color(0xFF06B6D4), fontWeight: FontWeight.bold, fontFamily: 'monospace', fontSize: 12),
                        ),
                      ),
                    ),
                    DataCell(
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFF3B82F6).withOpacity(0.15),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(port.proto, style: const TextStyle(color: Color(0xFF3B82F6), fontSize: 11, fontWeight: FontWeight.bold)),
                      ),
                    ),
                    DataCell(Text(port.bind, style: const TextStyle(color: Color(0xFF94A3B8), fontFamily: 'monospace', fontSize: 12))),
                    DataCell(
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.memory_rounded, size: 14, color: Color(0xFF64748B)),
                          const SizedBox(width: 6),
                          Text(
                            port.process.isNotEmpty ? port.process : 'system/kernel',
                            style: const TextStyle(color: Color(0xFFCBD5E1), fontSize: 12.5, fontWeight: FontWeight.w500),
                          ),
                        ],
                      ),
                    ),
                  ]);
                }).toList(),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDnsSection(ThemeProvider themeProvider) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: const Color(0xFF8B5CF6).withOpacity(0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.dns_rounded, size: 16, color: Color(0xFF8B5CF6)),
            ),
            const SizedBox(width: 10),
            const Text(
              'RESOLVED DNS NAMESERVERS',
              style: TextStyle(fontSize: 14, letterSpacing: 1.0, fontWeight: FontWeight.w800, color: Colors.white),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: _networkInfo!.dns.map((dns) {
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFF0F172A).withOpacity(0.85),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF8B5CF6).withOpacity(0.25)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.public_rounded, size: 16, color: Color(0xFF8B5CF6)),
                  const SizedBox(width: 10),
                  Text(
                    dns,
                    style: const TextStyle(color: Colors.white, fontSize: 13.5, fontWeight: FontWeight.bold, fontFamily: 'monospace'),
                  ),
                ],
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}
