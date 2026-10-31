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
    final primaryColor = Theme.of(context).primaryColor;

    return ClipRRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          width: 272,
          decoration: BoxDecoration(
            color: const Color(0xFF060A17).withOpacity(0.88),
            border: Border(
              right: BorderSide(
                color: Colors.white.withOpacity(0.07),
                width: 1.0,
              ),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Logo & Brand Header
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 18),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            primaryColor.withOpacity(0.35),
                            const Color(0xFF3B82F6).withOpacity(0.15),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: primaryColor.withOpacity(0.5),
                          width: 1.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: primaryColor.withOpacity(0.3),
                            blurRadius: 16,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.asset(
                          'assets/images/mss_logo.png',
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return Icon(Icons.cloud_circle_rounded, color: primaryColor, size: 24);
                          },
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Text(
                                'MSS PANEL',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 1.4,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                decoration: BoxDecoration(
                                  color: primaryColor.withOpacity(0.18),
                                  borderRadius: BorderRadius.circular(5),
                                  border: Border.all(color: primaryColor.withOpacity(0.4)),
                                ),
                                child: Text(
                                  'ULTRA',
                                  style: TextStyle(
                                    color: primaryColor,
                                    fontSize: 8.5,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 0.6,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 3),
                          Row(
                            children: [
                              Container(
                                width: 6,
                                height: 6,
                                decoration: const BoxDecoration(
                                  color: Color(0xFF10B981),
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 6),
                              const Text(
                                'panel.xie.my.id',
                                style: TextStyle(
                                  color: Color(0xFF94A3B8),
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // Menu Items List
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  children: [
                    _buildSectionHeader('CORE CLOUD'),
                    _buildMenuItem(
                      context,
                      title: 'Dashboard',
                      iconData: Icons.dashboard_rounded,
                      route: '/dashboard',
                    ),
                    _buildMenuItem(
                      context,
                      title: 'Containers',
                      iconData: Icons.layers_rounded,
                      route: '/containers',
                    ),
                    _buildMenuItem(
                      context,
                      title: 'Storage & Backup',
                      iconData: Icons.cloud_sync_rounded,
                      route: '/backup',
                      badge: 'Auto',
                      badgeColor: const Color(0xFF10B981),
                    ),
                    _buildMenuItem(
                      context,
                      title: 'Network & Ports',
                      iconData: Icons.router_rounded,
                      route: '/network',
                    ),
                    _buildMenuItem(
                      context,
                      title: 'App Installer',
                      iconData: Icons.rocket_launch_rounded,
                      route: '/installer',
                    ),
                    _buildMenuItem(
                      context,
                      title: 'Database Manager',
                      iconData: Icons.storage_rounded,
                      route: '/database',
                      badge: 'Live',
                      badgeColor: const Color(0xFF06B6D4),
                    ),
                    _buildMenuItem(
                      context,
                      title: 'Cron Jobs',
                      iconData: Icons.schedule_rounded,
                      route: '/cron',
                    ),

                    const SizedBox(height: 14),
                    _buildSectionHeader('SYSTEM OPS'),
                    _buildMenuItem(
                      context,
                      title: 'Security & Firewall',
                      iconData: Icons.shield_rounded,
                      route: '/security',
                    ),
                    _buildMenuItem(
                      context,
                      title: 'Services & Processes',
                      iconData: Icons.memory_rounded,
                      route: '/services',
                    ),
                    _buildMenuItem(
                      context,
                      title: 'System Logs',
                      iconData: Icons.receipt_long_rounded,
                      route: '/logs',
                    ),
                    _buildMenuItem(
                      context,
                      title: 'System Maintenance',
                      iconData: Icons.cleaning_services_rounded,
                      route: '/maintenance',
                    ),
                    _buildMenuItem(
                      context,
                      title: 'Web Terminal',
                      iconData: Icons.terminal_rounded,
                      route: '/terminal',
                      badge: 'Root',
                      badgeColor: const Color(0xFF8B5CF6),
                    ),

                    const SizedBox(height: 14),
                    _buildSectionHeader('PREFERENCES'),
                    _buildMenuItem(
                      context,
                      title: 'Settings',
                      iconData: Icons.tune_rounded,
                      route: '/settings',
                    ),
                    const SizedBox(height: 12),
                  ],
                ),
              ),

              // Server Live Ping Pill
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                decoration: BoxDecoration(
                  color: const Color(0xFF0F172A).withOpacity(0.8),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white.withOpacity(0.08)),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF10B981).withOpacity(0.6),
                            blurRadius: 8,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Text(
                        'Toshiba VPS • Connected',
                        style: TextStyle(
                          color: Color(0xFFCBD5E1),
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ),
                    const Icon(Icons.wifi_tethering, size: 14, color: Color(0xFF10B981)),
                  ],
                ),
              ),

              // User Profile Footer
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: const Color(0xFF040711),
                  border: Border(
                    top: BorderSide(color: Colors.white.withOpacity(0.07), width: 1.0),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          colors: [
                            primaryColor.withOpacity(0.35),
                            const Color(0xFF3B82F6).withOpacity(0.2),
                          ],
                        ),
                        border: Border.all(color: primaryColor.withOpacity(0.5), width: 1.5),
                        boxShadow: [
                          BoxShadow(
                            color: primaryColor.withOpacity(0.2),
                            blurRadius: 10,
                          ),
                        ],
                      ),
                      child: const Center(
                        child: Icon(Icons.person_rounded, color: Colors.white, size: 19),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Administrator',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Row(
                            children: [
                              Text(
                                'Superuser Host',
                                style: TextStyle(
                                  color: primaryColor,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: 'Logout dari MSS Panel',
                      icon: const Icon(Icons.logout_rounded, color: Color(0xFF94A3B8), size: 19),
                      hoverColor: const Color(0xFFF43F5E).withOpacity(0.15),
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

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 12, right: 12, top: 14, bottom: 6),
      child: Row(
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Color(0xFF475569),
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.4,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Container(
              height: 1,
              color: Colors.white.withOpacity(0.06),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMenuItem(
    BuildContext context, {
    required String title,
    required IconData iconData,
    required String route,
    String? badge,
    Color? badgeColor,
  }) {
    final isSelected = currentRoute == route;
    final primaryColor = Theme.of(context).primaryColor;

    return Container(
      margin: const EdgeInsets.only(bottom: 3),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            if (!isSelected) {
              onNavigate(route);
            }
          },
          borderRadius: BorderRadius.circular(12),
          hoverColor: primaryColor.withOpacity(0.08),
          splashColor: primaryColor.withOpacity(0.15),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9.5),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              gradient: isSelected
                  ? LinearGradient(
                      colors: [
                        primaryColor.withOpacity(0.2),
                        primaryColor.withOpacity(0.04),
                      ],
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                    )
                  : null,
              border: Border.all(
                color: isSelected ? primaryColor.withOpacity(0.4) : Colors.transparent,
                width: 1,
              ),
            ),
            child: Row(
              children: [
                // Glowing active bar indicator
                AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  width: 3.5,
                  height: isSelected ? 20 : 0,
                  margin: EdgeInsets.only(right: isSelected ? 10 : 0),
                  decoration: BoxDecoration(
                    color: primaryColor,
                    borderRadius: BorderRadius.circular(3),
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                              color: primaryColor,
                              blurRadius: 8,
                              spreadRadius: 1,
                            )
                          ]
                        : [],
                  ),
                ),
                // Icon Box
                Container(
                  padding: const EdgeInsets.all(6.5),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? primaryColor.withOpacity(0.25)
                        : const Color(0xFF1E293B).withOpacity(0.4),
                    borderRadius: BorderRadius.circular(9),
                    border: Border.all(
                      color: isSelected ? primaryColor.withOpacity(0.3) : Colors.transparent,
                    ),
                  ),
                  child: Icon(
                    iconData,
                    size: 17,
                    color: isSelected ? Colors.white : const Color(0xFF94A3B8),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      color: isSelected ? Colors.white : const Color(0xFFCBD5E1),
                      fontSize: 13.5,
                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w400,
                      letterSpacing: 0.2,
                    ),
                  ),
                ),
                if (badge != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: (badgeColor ?? primaryColor).withOpacity(0.15),
                      borderRadius: BorderRadius.circular(5),
                      border: Border.all(
                        color: (badgeColor ?? primaryColor).withOpacity(0.35),
                        width: 0.8,
                      ),
                    ),
                    child: Text(
                      badge,
                      style: TextStyle(
                        color: badgeColor ?? primaryColor,
                        fontSize: 9.5,
                        fontWeight: FontWeight.w800,
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
