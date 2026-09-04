import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/app_launcher_model.dart';

class AppLauncherCard extends StatefulWidget {
  final AppLauncherModel launcher;

  const AppLauncherCard({super.key, required this.launcher});

  @override
  State<AppLauncherCard> createState() => _AppLauncherCardState();
}

class _AppLauncherCardState extends State<AppLauncherCard> {
  bool _isHovered = false;

  IconData _getIconData(String iconName) {
    switch (iconName.toLowerCase()) {
      case 'docker':
        return Icons.dns;
      case 'cloud':
        return Icons.cloud_circle;
      case 'school':
        return Icons.school;
      case 'storage':
        return Icons.storage;
      case 'database':
        return Icons.dataset;
      case 'web':
        return Icons.language;
      default:
        return Icons.rocket_launch;
    }
  }

  Color _getCategoryColor(String category) {
    switch (category.toLowerCase()) {
      case 'infrastructure':
        return const Color(0xFF06B6D4);
      case 'storage':
        return const Color(0xFF3B82F6);
      case 'application':
      case 'app':
        return const Color(0xFF10B981);
      case 'database':
        return const Color(0xFFF59E0B);
      default:
        return const Color(0xFF8B5CF6);
    }
  }

  Future<void> _launch() async {
    final uri = Uri.parse(widget.launcher.url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Tidak dapat membuka URL: ${widget.launcher.url}'),
            backgroundColor: const Color(0xFFF43F5E),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _getCategoryColor(widget.launcher.category);

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: _launch,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF0F172A),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: _isHovered
                  ? color.withOpacity(0.8)
                  : const Color(0xFF1E293B),
              width: _isHovered ? 1.5 : 1.0,
            ),
            boxShadow: [
              BoxShadow(
                color: _isHovered
                    ? color.withOpacity(0.2)
                    : Colors.black.withOpacity(0.2),
                blurRadius: _isHovered ? 16 : 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              // Dynamic Icon Box
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: color.withOpacity(0.3)),
                ),
                child: Icon(
                  _getIconData(widget.launcher.icon),
                  color: color,
                  size: 26,
                ),
              ),
              const SizedBox(width: 14),
              // App Details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            widget.launcher.name,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: color.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            widget.launcher.category.toUpperCase(),
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              color: color,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      widget.launcher.description ?? widget.launcher.url,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF94A3B8),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.open_in_new,
                size: 18,
                color: _isHovered ? color : const Color(0xFF475569),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
