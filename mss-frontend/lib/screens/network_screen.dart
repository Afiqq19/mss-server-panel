import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/network_model.dart';
import '../services/api_service.dart';

class NetworkScreen extends StatefulWidget {
  const NetworkScreen({super.key});

  @override
  State<NetworkScreen> createState() => _NetworkScreenState();
}

class _NetworkScreenState extends State<NetworkScreen> {
  bool _isLoading = true;
  String? _errorMessage;
  NetworkInfoModel? _networkInfo;

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

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(color: Color(0xFF3B82F6)));
    }

    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.wifi_off, color: Color(0xFFF43F5E), size: 48),
            const SizedBox(height: 16),
            const Text('Gagal Memuat Info Jaringan', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(_errorMessage!, style: const TextStyle(color: Color(0xFF94A3B8)), textAlign: TextAlign.center),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF3B82F6), foregroundColor: Colors.white),
              onPressed: _loadNetworkInfo,
              icon: const Icon(Icons.refresh),
              label: const Text('Coba Lagi'),
            ),
          ],
        ),
      );
    }

    if (_networkInfo == null) return const SizedBox.shrink();

    return RefreshIndicator(
      onRefresh: _loadNetworkInfo,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Overview Cards
            _buildOverviewCards(),
            const SizedBox(height: 28),
            // Network Interfaces
            _buildInterfacesSection(),
            const SizedBox(height: 28),
            // Listening Ports Table
            _buildPortsSection(),
            const SizedBox(height: 28),
            // DNS Servers
            _buildDnsSection(),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildOverviewCards() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 600;
        final cards = [
          _buildInfoCard(
            title: 'PUBLIC IP',
            value: _networkInfo!.publicIp,
            icon: Icons.public,
            color: const Color(0xFF3B82F6),
          ),
          _buildInfoCard(
            title: 'HOSTNAME',
            value: _networkInfo!.hostname,
            icon: Icons.dns,
            color: const Color(0xFF8B5CF6),
          ),
          _buildInfoCard(
            title: 'INTERFACES',
            value: '${_networkInfo!.interfaces.length} aktif',
            icon: Icons.settings_ethernet,
            color: const Color(0xFF10B981),
          ),
          _buildInfoCard(
            title: 'PORTS',
            value: '${_networkInfo!.listening.length} listening',
            icon: Icons.lan,
            color: const Color(0xFFF59E0B),
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
          childAspectRatio: 2.5,
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
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF1E293B)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(title, style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
                const SizedBox(height: 4),
                Text(value, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon, Color color) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.15),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 20, color: color),
        ),
        const SizedBox(width: 12),
        Text(
          title,
          style: const TextStyle(fontSize: 15, letterSpacing: 1.2, fontWeight: FontWeight.bold, color: Colors.white),
        ),
      ],
    );
  }

  Widget _buildInterfacesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader('NETWORK INTERFACES', Icons.settings_ethernet, const Color(0xFF10B981)),
        const SizedBox(height: 16),
        LayoutBuilder(
          builder: (context, constraints) {
            final isNarrow = constraints.maxWidth < 500;
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
                crossAxisCount: constraints.maxWidth > 900 ? 3 : 2,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                mainAxisExtent: 140,
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
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF1E293B)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(iface.name, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: stateColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(iface.state, style: TextStyle(color: stateColor, fontSize: 10, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Icon(Icons.computer, size: 14, color: Color(0xFF64748B)),
              const SizedBox(width: 6),
              Flexible(child: Text(iface.ip.isNotEmpty ? iface.ip : 'No IP', style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13))),
            ],
          ),
          const SizedBox(height: 6),
          if (iface.mac.isNotEmpty)
            Row(
              children: [
                const Icon(Icons.link, size: 14, color: Color(0xFF64748B)),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(iface.mac, style: const TextStyle(color: Color(0xFF64748B), fontSize: 11, fontFamily: 'monospace')),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildPortsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader('LISTENING PORTS', Icons.lan, const Color(0xFFF59E0B)),
        const SizedBox(height: 16),
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: const Color(0xFF0F172A),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFF1E293B)),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                headingRowColor: WidgetStateProperty.all(const Color(0xFF1E293B).withOpacity(0.8)),
                dataRowMinHeight: 48,
                dataRowMaxHeight: 48,
                columns: const [
                  DataColumn(label: Text('PORT', style: TextStyle(color: Color(0xFF94A3B8), fontWeight: FontWeight.bold))),
                  DataColumn(label: Text('PROTO', style: TextStyle(color: Color(0xFF94A3B8), fontWeight: FontWeight.bold))),
                  DataColumn(label: Text('BIND', style: TextStyle(color: Color(0xFF94A3B8), fontWeight: FontWeight.bold))),
                  DataColumn(label: Text('PROCESS', style: TextStyle(color: Color(0xFF94A3B8), fontWeight: FontWeight.bold))),
                ],
                rows: _networkInfo!.listening.map((port) {
                  return DataRow(cells: [
                    DataCell(Text(port.port, style: const TextStyle(color: Color(0xFF06B6D4), fontWeight: FontWeight.bold, fontFamily: 'monospace'))),
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
                    DataCell(Text(port.bind, style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13))),
                    DataCell(Text(port.process.isNotEmpty ? port.process : '-', style: const TextStyle(color: Color(0xFFCBD5E1), fontSize: 13))),
                  ]);
                }).toList(),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDnsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader('DNS SERVERS', Icons.dns, const Color(0xFF8B5CF6)),
        const SizedBox(height: 16),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: _networkInfo!.dns.map((dns) {
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              decoration: BoxDecoration(
                color: const Color(0xFF0F172A),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF1E293B)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.dns, size: 16, color: Color(0xFF8B5CF6)),
                  const SizedBox(width: 10),
                  Text(dns, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600, fontFamily: 'monospace')),
                ],
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}
