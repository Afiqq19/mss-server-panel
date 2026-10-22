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
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          width: 268,
          decoration: BoxDecoration(
            color: const Color(0xFF090D1A).withOpacity(0.75),
            border: const Border(
              right: BorderSide(
                color: Color(0xFF1E293B),
                width: 1.0,
              ),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Logo Area
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
                child: Row(
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            primaryColor.withOpacity(0.3),
                            const Color(0xFF3B82F6).withOpacity(0.1),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: primaryColor.withOpacity(0.4),
                          width: 1.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: primaryColor.withOpacity(0.25),
                            blurRadius: 12,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: Image.asset(
                          'assets/images/mss_logo.png',
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return Icon(Icons.dns_rounded, color: primaryColor, size: 22);
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
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 1.2,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                decoration: BoxDecoration(
                                  color: primaryColor.withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(color: primaryColor.withOpacity(0.3)),
                                ),
                                child: Text(
                                  'PRO',
                                  style: TextStyle(
                                    color: primaryColor,
                                    fontSize: 9,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          const Text(
                            'panel.xie.my.id',
                            style: TextStyle(
                              color: Color(0xFF64748B),
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // Menu Items
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
                      title: 'Network',
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
                      title: 'Security / Firewall',
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
                      title: 'Maintenance',
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

              // Server Health Pill
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFF0F172A),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFF1E293B)),
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
                            color: const Color(0xFF10B981).withOpacity(0.5),
                            blurRadius: 6,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Text(
                        'panel.xie.my.id • Live',
                        style: TextStyle(
                          color: Color(0xFF94A3B8),
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ),
                    const Icon(Icons.wifi_tethering, size: 14, color: Color(0xFF64748B)),
                  ],
                ),
              ),

              // User Profile Area at bottom
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: const BoxDecoration(
                  color: Color(0xFF070B14),
                  border: Border(
                    top: BorderSide(color: Color(0xFF1E293B), width: 1.0),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          colors: [
                            primaryColor.withOpacity(0.3),
                            const Color(0xFF3B82F6).withOpacity(0.2),
                          ],
                        ),
                        border: Border.all(color: primaryColor.withOpacity(0.4), width: 1.5),
                      ),
                      child: const Center(
                        child: Icon(Icons.person_rounded, color: Colors.white, size: 18),
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
                                'Superuser',
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
                      tooltip: 'Logout',
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
      padding: const EdgeInsets.only(left: 12, right: 12, top: 12, bottom: 6),
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
              color: const Color(0xFF1E293B),
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
          borderRadius: BorderRadius.circular(10),
          hoverColor: primaryColor.withOpacity(0.08),
          splashColor: primaryColor.withOpacity(0.15),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              color: isSelected ? primaryColor.withOpacity(0.12) : Colors.transparent,
              border: Border.all(
                color: isSelected ? primaryColor.withOpacity(0.35) : Colors.transparent,
                width: 1,
              ),
            ),
            child: Row(
              children: [
                // Glowing active line indicator
                AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  width: 3,
                  height: isSelected ? 18 : 0,
                  margin: EdgeInsets.only(right: isSelected ? 10 : 0),
                  decoration: BoxDecoration(
                    color: primaryColor,
                    borderRadius: BorderRadius.circular(2),
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                              color: primaryColor,
                              blurRadius: 6,
                              spreadRadius: 0.5,
                            )
                          ]
                        : [],
                  ),
                ),
                // Icon with subtle container
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? primaryColor.withOpacity(0.2)
                        : const Color(0xFF1E293B).withOpacity(0.4),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    iconData,
                    size: 17,
                    color: isSelected ? primaryColor : const Color(0xFF94A3B8),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      color: isSelected ? Colors.white : const Color(0xFFCBD5E1),
                      fontSize: 13.5,
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
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
                        color: (badgeColor ?? primaryColor).withOpacity(0.3),
                        width: 0.8,
                      ),
                    ),
                    child: Text(
                      badge,
                      style: TextStyle(
                        color: badgeColor ?? primaryColor,
                        fontSize: 9.5,
                        fontWeight: FontWeight.w700,
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
