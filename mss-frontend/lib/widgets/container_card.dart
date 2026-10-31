import 'dart:ui';
import 'package:flutter/material.dart';
import '../models/container_model.dart';
import 'container_log_dialog.dart';

class ContainerCard extends StatefulWidget {
  final ContainerModel container;
  final Future<void> Function(String id, String action) onAction;
  final void Function(String pairName)? onFilterPair;

  const ContainerCard({
    super.key,
    required this.container,
    required this.onAction,
    this.onFilterPair,
  });

  @override
  State<ContainerCard> createState() => _ContainerCardState();
}

class _ContainerCardState extends State<ContainerCard> {
  bool _isLoading = false;

  void _confirmAndExecute(BuildContext context, String action) {
    final actionLabel = action.toUpperCase();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF0F172A),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: Color(0xFF1E293B)),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: action == 'stop'
                    ? const Color(0xFFF43F5E).withOpacity(0.15)
                    : const Color(0xFF06B6D4).withOpacity(0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                action == 'stop' ? Icons.warning_amber_rounded : Icons.help_outline_rounded,
                color: action == 'stop'
                    ? const Color(0xFFF43F5E)
                    : const Color(0xFF06B6D4),
                size: 22,
              ),
            ),
            const SizedBox(width: 12),
            Text(
              'Konfirmasi $actionLabel',
              style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: Text(
          'Apakah Anda yakin ingin mengeksekusi aksi "$actionLabel" pada container "${widget.container.name}"?',
          style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 14, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text(
              'Batal',
              style: TextStyle(color: Color(0xFF64748B)),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: action == 'stop'
                  ? const Color(0xFFF43F5E)
                  : (action == 'restart'
                        ? const Color(0xFFF59E0B)
                        : const Color(0xFF10B981)),
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              setState(() => _isLoading = true);
              try {
                await widget.onAction(widget.container.id, action);
              } finally {
                if (mounted) {
                  setState(() => _isLoading = false);
                }
              }
            },
            child: Text('Ya, $actionLabel', style: const TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  IconData _getRoleIcon() {
    final cat = widget.container.categoryType;
    if (cat == 'database') return Icons.storage_rounded;
    if (cat == 'core') return Icons.security_rounded;
    if (cat == 'network') return Icons.cloud_sync_rounded;
    if (cat == 'storage') return Icons.cloud_done_rounded;
    if (cat == 'web') return Icons.language_rounded;
    if (cat == 'app_pair') return Icons.hub_rounded;
    return Icons.developer_board_rounded;
  }

  Color _getCategoryAccent() {
    final cat = widget.container.categoryType;
    if (cat == 'database') return const Color(0xFFF59E0B); // Amber
    if (cat == 'core') return const Color(0xFF06B6D4); // Cyan
    if (cat == 'network') return const Color(0xFF38BDF8); // Sky blue
    if (cat == 'storage') return const Color(0xFF10B981); // Emerald
    if (cat == 'web') return const Color(0xFF8B5CF6); // Purple
    if (cat == 'app_pair') return const Color(0xFFEC4899); // Pink
    return const Color(0xFF64748B);
  }

  @override
  Widget build(BuildContext context) {
    final isRunning = widget.container.isRunning;
    final statusColor = isRunning
        ? const Color(0xFF10B981)
        : const Color(0xFFF43F5E);
    final accent = _getCategoryAccent();

    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                const Color(0xFF0F172A).withOpacity(0.92),
                const Color(0xFF090E1A).withOpacity(0.85),
              ],
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isRunning ? accent.withOpacity(0.4) : statusColor.withOpacity(0.35),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: (isRunning ? accent : statusColor).withOpacity(0.08),
                blurRadius: 18,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Top Section: Info & Identitas
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Row 1: Icon, Nama Container, & Status
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(7),
                        decoration: BoxDecoration(
                          color: accent.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: accent.withOpacity(0.35)),
                        ),
                        child: Icon(
                          _getRoleIcon(),
                          size: 16,
                          color: accent,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.container.name,
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                                letterSpacing: 0.2,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 1),
                            Text(
                              widget.container.role,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                                color: accent.withOpacity(0.9),
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Status Badge
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: statusColor.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: statusColor.withOpacity(0.4),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 6,
                              height: 6,
                              decoration: BoxDecoration(
                                color: statusColor,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: statusColor.withOpacity(0.6),
                                    blurRadius: 6,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 5),
                            Text(
                              widget.container.state.toUpperCase(),
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                color: statusColor,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 10),

                  // KOTAK PASANGAN / RELASI (HIGHLIGHT FITUR BARU)
                  InkWell(
                    onTap: widget.onFilterPair != null
                        ? () => widget.onFilterPair!(widget.container.pairName)
                        : null,
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            const Color(0xFF0284C7).withOpacity(0.18),
                            const Color(0xFF6366F1).withOpacity(0.12),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: const Color(0xFF38BDF8).withOpacity(0.35),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: const Color(0xFF38BDF8).withOpacity(0.2),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.link_rounded,
                              size: 13,
                              color: Color(0xFF38BDF8),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const Text(
                                      'PASANGAN: ',
                                      style: TextStyle(
                                        fontSize: 9.5,
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: 0.8,
                                        color: Color(0xFF94A3B8),
                                      ),
                                    ),
                                    Expanded(
                                      child: Text(
                                        widget.container.pairName,
                                        style: const TextStyle(
                                          fontSize: 11.5,
                                          fontWeight: FontWeight.w800,
                                          color: Color(0xFF38BDF8),
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  widget.container.pairRelationBadge,
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w500,
                                    color: Colors.white.withOpacity(0.75),
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 8),

                  // Metadata: Image & Ports
                  Row(
                    children: [
                      // Image Tag
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xFF020617).withOpacity(0.6),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: const Color(0xFF1E293B)),
                          ),
                          child: Text(
                            widget.container.image,
                            style: const TextStyle(
                              fontSize: 10.5,
                              fontFamily: 'monospace',
                              color: Color(0xFF94A3B8),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      // Ports
                      if (widget.container.ports.isNotEmpty) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xFF06B6D4).withOpacity(0.12),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: const Color(0xFF06B6D4).withOpacity(0.3)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.settings_ethernet_rounded,
                                size: 11,
                                color: Color(0xFF06B6D4),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                widget.container.ports,
                                style: const TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF06B6D4),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 6),
                      ],
                      // Short ID
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E293B).withOpacity(0.5),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          '#${widget.container.id.substring(0, widget.container.id.length > 7 ? 7 : widget.container.id.length)}',
                          style: const TextStyle(
                            fontSize: 10,
                            fontFamily: 'monospace',
                            color: Color(0xFF64748B),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),

              const SizedBox(height: 10),

              // Action Buttons Bar (Start, Logs, Restart, Stop)
              _isLoading
                  ? const Center(
                      child: SizedBox(
                        height: 22,
                        width: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Color(0xFF06B6D4),
                          ),
                        ),
                      ),
                    )
                  : Row(
                      children: [
                        if (!isRunning)
                          Expanded(
                            child: _buildActionButton(
                              label: 'Start Container',
                              icon: Icons.play_arrow_rounded,
                              color: const Color(0xFF10B981),
                              onPressed: () =>
                                  _confirmAndExecute(context, 'start'),
                            ),
                          ),
                        if (isRunning) ...[
                          // Logs Button
                          _buildActionButton(
                            label: 'Logs',
                            icon: Icons.terminal_rounded,
                            color: const Color(0xFF06B6D4),
                            onPressed: () {
                              showDialog(
                                context: context,
                                builder: (ctx) => ContainerLogDialog(container: widget.container),
                              );
                            },
                          ),
                          const SizedBox(width: 8),

                          // Restart Button
                          Expanded(
                            child: _buildActionButton(
                              label: 'Restart',
                              icon: Icons.refresh_rounded,
                              color: const Color(0xFFF59E0B),
                              onPressed: () =>
                                  _confirmAndExecute(context, 'restart'),
                            ),
                          ),
                          const SizedBox(width: 8),

                          // Stop Button
                          Expanded(
                            child: _buildActionButton(
                              label: 'Stop',
                              icon: Icons.stop_rounded,
                              color: const Color(0xFFF43F5E),
                              onPressed: () =>
                                  _confirmAndExecute(context, 'stop'),
                            ),
                          ),
                        ],
                      ],
                    ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 7.5, horizontal: 9),
          decoration: BoxDecoration(
            color: color.withOpacity(0.12),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: color.withOpacity(0.35)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 14, color: color),
              const SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
