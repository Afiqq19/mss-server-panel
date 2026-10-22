import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/api_service.dart';
import '../providers/theme_provider.dart';

class ServicesScreen extends StatefulWidget {
  const ServicesScreen({Key? key}) : super(key: key);

  @override
  _ServicesScreenState createState() => _ServicesScreenState();
}

class _ServicesScreenState extends State<ServicesScreen> {
  bool _isLoading = true;
  List<dynamic> _services = [];
  List<dynamic> _processes = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final api = Provider.of<ApiService>(context, listen: false);
      final results = await Future.wait([
        api.get('/services'),
        api.get('/services/top'),
      ]);
      final svcRes = results[0];
      final procRes = results[1];
      if (mounted) {
        setState(() {
          _services = svcRes['data']['services'] ?? [];
          _processes = procRes['data']['processes'] ?? [];
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _actionService(String service, String action) async {
    try {
      final api = Provider.of<ApiService>(context, listen: false);
      await api.post('/services/action', {
        'service': service,
        'action': action,
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$service berhasil di-$action'), backgroundColor: Colors.green),
      );
      _loadData();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal $action $service: $e'), backgroundColor: Colors.red),
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
                child: Icon(Icons.memory, color: themeProvider.primary, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text(
                      'Services & Processes',
                      style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                    Text(
                      'Monitoring systemd dan proses aktif',
                      style: TextStyle(color: Color(0xFF94A3B8), fontSize: 14),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.refresh, color: Colors.white),
                onPressed: _loadData,
              )
            ],
          ),
          const SizedBox(height: 32),

          if (_isLoading)
            Center(child: CircularProgressIndicator(color: themeProvider.primary))
          else
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildServicesGrid(themeProvider),
                const SizedBox(height: 32),
                _buildTopProcessTable(themeProvider),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildServicesGrid(ThemeProvider themeProvider) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Core Services', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 16),
        Wrap(
          spacing: 16,
          runSpacing: 16,
          children: _services.map((svc) {
            final isActive = svc['status'] == 'active';
            return Container(
              width: 280,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: isActive ? Colors.green.withOpacity(0.3) : Colors.red.withOpacity(0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(svc['name'].toString().toUpperCase(), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      Container(
                        width: 12, height: 12,
                        decoration: BoxDecoration(color: isActive ? Colors.green : Colors.red, shape: BoxShape.circle),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      TextButton(
                        onPressed: () => _actionService(svc['name'], isActive ? 'stop' : 'start'),
                        child: Text(isActive ? 'Stop' : 'Start', style: TextStyle(color: isActive ? Colors.red : Colors.green)),
                      ),
                      TextButton(
                        onPressed: () => _actionService(svc['name'], 'restart'),
                        child: const Text('Restart', style: TextStyle(color: Colors.blue)),
                      ),
                    ],
                  )
                ],
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildTopProcessTable(ThemeProvider themeProvider) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Top Processes (CPU/RAM)', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              columns: const [
                DataColumn(label: Text('PID', style: TextStyle(color: Color(0xFF94A3B8)))),
                DataColumn(label: Text('USER', style: TextStyle(color: Color(0xFF94A3B8)))),
                DataColumn(label: Text('CPU %', style: TextStyle(color: Color(0xFF94A3B8)))),
                DataColumn(label: Text('MEM %', style: TextStyle(color: Color(0xFF94A3B8)))),
                DataColumn(label: Text('COMMAND', style: TextStyle(color: Color(0xFF94A3B8)))),
              ],
              rows: _processes.map((proc) {
                return DataRow(cells: [
                  DataCell(Text(proc['pid'].toString(), style: const TextStyle(color: Colors.white))),
                  DataCell(Text(proc['user'].toString(), style: const TextStyle(color: Colors.white))),
                  DataCell(Text(proc['cpu'].toString(), style: const TextStyle(color: Colors.orange))),
                  DataCell(Text(proc['mem'].toString(), style: const TextStyle(color: Colors.blue))),
                  DataCell(Text(proc['command'].toString(), style: const TextStyle(color: Colors.white))),
                ]);
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}
