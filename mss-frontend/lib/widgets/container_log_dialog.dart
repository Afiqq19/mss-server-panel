import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/api_service.dart';
import '../models/container_model.dart';
import 'dart:async';

class ContainerLogDialog extends StatefulWidget {
  final ContainerModel container;

  const ContainerLogDialog({super.key, required this.container});

  @override
  State<ContainerLogDialog> createState() => _ContainerLogDialogState();
}

class _ContainerLogDialogState extends State<ContainerLogDialog> {
  String _logs = 'Memuat logs...';
  bool _isLoading = true;
  Timer? _refreshTimer;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _fetchLogs();
    // Auto refresh logs every 3 seconds
    _refreshTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      _fetchLogs(silent: true);
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _fetchLogs({bool silent = false}) async {
    if (!silent && mounted) {
      setState(() => _isLoading = true);
    }
    try {
      final api = context.read<ApiService>();
      final logs = await api.getContainerLogs(widget.container.id);
      if (mounted) {
        setState(() {
          _logs = logs;
          _isLoading = false;
        });
        // Auto scroll to bottom when new logs arrive
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _logs = 'Gagal memuat log: $e';
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(20),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
          child: Container(
            width: 800,
            height: MediaQuery.of(context).size.height * 0.8,
            decoration: BoxDecoration(
              color: const Color(0xFF0F172A).withOpacity(0.8),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFF1E293B)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.5),
                  blurRadius: 30,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  decoration: const BoxDecoration(
                    border: Border(
                      bottom: BorderSide(color: Color(0xFF1E293B)),
                    ),
                    color: Color(0xFF0B1120),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.terminal, color: Color(0xFF06B6D4)),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Logs: ${widget.container.name}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              widget.container.id,
                              style: const TextStyle(
                                color: Color(0xFF64748B),
                                fontSize: 12,
                                fontFamily: 'monospace',
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (_isLoading)
                        const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Color(0xFF06B6D4),
                          ),
                        ),
                      const SizedBox(width: 16),
                      IconButton(
                        icon: const Icon(Icons.close, color: Color(0xFF94A3B8)),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                ),
                // Log Body
                Expanded(
                  child: Container(
                    color: const Color(0xFF030712),
                    padding: const EdgeInsets.all(16),
                    child: SingleChildScrollView(
                      controller: _scrollController,
                      child: Text(
                        _logs,
                        style: const TextStyle(
                          color: Color(0xFF34D399),
                          fontFamily: 'monospace',
                          fontSize: 12,
                          height: 1.5,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
