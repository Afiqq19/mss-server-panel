import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/api_service.dart';

class TerminalScreen extends StatefulWidget {
  const TerminalScreen({Key? key}) : super(key: key);

  @override
  _TerminalScreenState createState() => _TerminalScreenState();
}

class _TerminalScreenState extends State<TerminalScreen> {
  final TextEditingController _commandController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _focusNode = FocusNode();
  
  final List<String> _logs = [
    'MSS Server Panel - Web Terminal Session',
    'Warning: Anda memiliki akses ROOT ke host system.',
    'Terminal ini stateless. Command seperti `cd` tidak tersimpan state-nya.',
    'Gunakan `cd /path && command` untuk menjalankan dari spesifik path.',
    '-------------------------------------------------------',
  ];
  
  bool _isRunning = false;

  @override
  void dispose() {
    _commandController.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _executeCommand(String command) async {
    final cmd = command.trim();
    if (cmd.isEmpty) return;

    setState(() {
      _logs.add('root@mss-host:~# $cmd');
      _isRunning = true;
    });
    
    _commandController.clear();
    _scrollToBottom();

    if (cmd == 'clear') {
      setState(() {
        _logs.clear();
        _isRunning = false;
      });
      return;
    }

    try {
      final apiService = Provider.of<ApiService>(context, listen: false);
      final output = await apiService.executeTerminalCommand(cmd);
      
      setState(() {
        if (output.isNotEmpty) {
          _logs.add(output);
        }
      });
    } catch (e) {
      setState(() {
        _logs.add('Error: ${e.toString()}');
      });
    } finally {
      setState(() {
        _isRunning = false;
      });
      _scrollToBottom();
      _focusNode.requestFocus();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        const Text(
          'Web Terminal (Host Root)',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 24),

        // Terminal Box
        Expanded(
          child: Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: const Color(0xFF020617), // Black terminal background
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF334155)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.5),
                  blurRadius: 10,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: Column(
              children: [
                // Output Area
                Expanded(
                  child: GestureDetector(
                    onTap: () => _focusNode.requestFocus(),
                    child: ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.all(16),
                      itemCount: _logs.length,
                      itemBuilder: (context, index) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: SelectableText(
                            _logs[index],
                            style: const TextStyle(
                              fontFamily: 'Courier', // Monospace font
                              color: Color(0xFF10B981), // Green hacker color
                              fontSize: 14,
                              height: 1.5,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                
                // Input Area
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: const BoxDecoration(
                    border: Border(top: BorderSide(color: Color(0xFF334155))),
                  ),
                  child: Row(
                    children: [
                      const Text(
                        'root@mss-host:~# ',
                        style: TextStyle(
                          fontFamily: 'Courier',
                          color: Color(0xFF10B981),
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Expanded(
                        child: TextField(
                          controller: _commandController,
                          focusNode: _focusNode,
                          style: const TextStyle(
                            fontFamily: 'Courier',
                            color: Color(0xFFF8FAFC),
                            fontSize: 14,
                          ),
                          decoration: const InputDecoration(
                            border: InputBorder.none,
                            isDense: true,
                            contentPadding: EdgeInsets.symmetric(vertical: 8),
                          ),
                          onSubmitted: _isRunning ? null : _executeCommand,
                          enabled: !_isRunning,
                          autofocus: true,
                        ),
                      ),
                      if (_isRunning)
                        const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF10B981)),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
