import 'dart:ui';
import 'package:flutter/material.dart';

class Sidebar extends StatelessWidget {
  final String currentRoute;
  final Function(String) onNavigate;
  final VoidCallback? onLogout;

  const Sidebar({
    super.key,
    required this.currentRoute,
    required this.onNavigate,
    this.onLogout,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          width: 260,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.02),
            border: Border(
              right: BorderSide(
                color: Colors.white.withOpacity(0.1),
                width: 1.0,
              ),
            ),
          ),
          child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Logo Area
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF10B981).withOpacity(0.3),
                        blurRadius: 8,
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image.asset(
                      'assets/images/mss_logo.png',
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return const Icon(Icons.broken_image, color: Colors.white, size: 20);
                      },
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                const Text(
                  'MSS PANEL',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                  ),
                ),
              ],
            ),
          ),

          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 24, vertical: 8),
            child: Text(
              'MAIN MENU',
              style: TextStyle(
                color: Color(0xFF64748B),
                fontSize: 11,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.5,
              ),
            ),
          ),

          // Menu Items
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                _buildMenuItem(
                  title: 'Dashboard',
                  iconWidget: Icon(
                    Icons.dashboard,
                    size: 20,
                    color: currentRoute == '/dashboard' ? const Color(0xFF06B6D4) : const Color(0xFF64748B),
                  ),
                  route: '/dashboard',
                ),
                _buildMenuItem(
                  title: 'Containers',
                  iconWidget: Icon(
                    Icons.data_object,
                    size: 20,
                    color: currentRoute == '/containers' ? const Color(0xFF06B6D4) : const Color(0xFF64748B),
                  ),
                  route: '/containers',
                ),
                _buildMenuItem(
                  title: 'Storage & Backup',
                  iconWidget: Icon(
                    Icons.cloud_sync,
                    size: 20,
                    color: currentRoute == '/backup' ? const Color(0xFF06B6D4) : const Color(0xFF64748B),
                  ),
                  route: '/backup',
                  badge: 'Auto',
                ),
                _buildMenuItem(
                  title: 'Network',
                  iconWidget: Icon(
                    Icons.router,
                    size: 20,
                    color: currentRoute == '/network' ? const Color(0xFF06B6D4) : const Color(0xFF64748B),
                  ),
                  route: '/network',
                ),
                const SizedBox(height: 24),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                  child: Text(
                    'SYSTEM',
                    style: TextStyle(
                      color: Color(0xFF64748B),
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.5,
                    ),
                  ),
                ),
                _buildMenuItem(
                  title: 'Maintenance',
                  iconWidget: Icon(
                    Icons.handyman,
                    size: 20,
                    color: currentRoute == '/maintenance' ? const Color(0xFF06B6D4) : const Color(0xFF64748B),
                  ),
                  route: '/maintenance',
                ),
                _buildMenuItem(
                  title: 'Web Terminal',
                  iconWidget: Icon(
                    Icons.terminal,
                    size: 20,
                    color: currentRoute == '/terminal' ? const Color(0xFF06B6D4) : const Color(0xFF64748B),
                  ),
                  route: '/terminal',
                ),
                _buildMenuItem(
                  title: 'Settings',
                  iconWidget: Icon(
                    Icons.settings,
                    size: 20,
                    color: currentRoute == '/settings' ? const Color(0xFF06B6D4) : const Color(0xFF64748B),
                  ),
                  route: '/settings',
                ),
              ],
            ),
          ),

          // User Profile Area at bottom
          Container(
            padding: const EdgeInsets.all(20),
            decoration: const BoxDecoration(
              border: Border(
                top: BorderSide(color: Color(0xFF1E293B), width: 1.5),
              ),
            ),
            child: Row(
              children: [
                const CircleAvatar(
                  radius: 18,
                  backgroundColor: Color(0xFF1E293B),
                  child: Icon(Icons.person, color: Color(0xFF94A3B8), size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text(
                        'Administrator',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'Root Access',
                        style: TextStyle(
                          color: Color(0xFF64748B),
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.logout, color: Color(0xFF64748B), size: 20),
                  onPressed: onLogout,
                ),
              ],
            ),
          ),
        ],
      ),
    ),
    ),
    );
  }

  Widget _buildMenuItem({
    required String title,
    required Widget iconWidget,
    required String route,
    String? badge,
  }) {
    final isSelected = currentRoute == route;

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            if (!isSelected) {
              onNavigate(route);
            }
          },
          borderRadius: BorderRadius.circular(12),
          hoverColor: const Color(0xFF1E293B).withOpacity(0.8),
          highlightColor: const Color(0xFF1E293B).withOpacity(0.4),
          splashColor: const Color(0xFF06B6D4).withOpacity(0.2),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: isSelected ? const Color(0xFF06B6D4).withOpacity(0.15) : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected ? const Color(0xFF06B6D4).withOpacity(0.4) : Colors.transparent,
              ),
            ),
            child: Row(
              children: [
                iconWidget,
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      color: isSelected ? Colors.white : const Color(0xFF94A3B8),
                      fontSize: 14,
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                    ),
                  ),
                ),
                if (badge != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981).withOpacity(0.2),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      badge,
                      style: const TextStyle(
                        color: Color(0xFF10B981),
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
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
