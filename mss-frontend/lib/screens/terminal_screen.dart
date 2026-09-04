import 'package:flutter/material.dart';
import 'dart:ui_web' as ui_web;
import 'package:universal_html/html.dart' as html;

class TerminalScreen extends StatefulWidget {
  const TerminalScreen({super.key});

  @override
  State<TerminalScreen> createState() => _TerminalScreenState();
}

class _TerminalScreenState extends State<TerminalScreen> {
  final String _viewType = 'ttyd-terminal-iframe';
  bool _isIframeRegistered = false;

  @override
  void initState() {
    super.initState();
    _registerIframe();
  }

  void _registerIframe() {
    if (!_isIframeRegistered) {
      ui_web.platformViewRegistry.registerViewFactory(
        _viewType,
        (int viewId) => html.IFrameElement()
          ..src = '/ttyd/'
          ..style.border = 'none'
          ..style.width = '100%'
          ..style.height = '100%'
          ..allowFullscreen = true,
      );
      _isIframeRegistered = true;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF020617), // Black background for terminal
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: const BoxDecoration(
              color: Color(0xFF0F172A),
              border: Border(
                bottom: BorderSide(color: Color(0xFF1E293B), width: 1.5),
              ),
            ),
            child: Row(
              children: const [
                Icon(Icons.terminal, color: Color(0xFF10B981), size: 20),
                SizedBox(width: 8),
                Text(
                  'Web Terminal (Interactive PTY)',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                Spacer(),
                Text(
                  'Status: Connected via ttyd',
                  style: TextStyle(
                    color: Color(0xFF10B981),
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          
          // Terminal Iframe
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(2.0),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: HtmlElementView(viewType: _viewType),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
