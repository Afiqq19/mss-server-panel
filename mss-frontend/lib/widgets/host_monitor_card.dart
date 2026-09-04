import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../models/host_stats_model.dart';

class HostMonitorCard extends StatelessWidget {
  final HostStatsModel stats;
  final List<double> cpuHistory;
  final String serverTime;

  const HostMonitorCard({
    super.key,
    required this.stats,
    required this.cpuHistory,
    required this.serverTime,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF1E293B)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.4),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Bar: Host Info & Live Clock
          LayoutBuilder(
            builder: (context, constraints) {
              final isNarrow = constraints.maxWidth < 700;

              final hostInfo = Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF06B6D4).withOpacity(0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.dns,
                      color: Color(0xFF06B6D4),
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'HOST SERVER MONITOR',
                        style: TextStyle(
                          fontSize: 12,
                          letterSpacing: 1.5,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF94A3B8),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Flexible(
                            child: Text(
                              'Toshiba Linux VPS',
                              style: TextStyle(
                                fontSize: isNarrow ? 14 : 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFF10B981).withOpacity(0.15),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                  color: const Color(0xFF10B981).withOpacity(0.4)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: const [
                                Icon(Icons.circle,
                                    size: 6, color: Color(0xFF10B981)),
                                SizedBox(width: 4),
                                Text(
                                  'ONLINE',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF10B981),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              );

              final badges = Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  // Battery Badge
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E293B),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          stats.isCharging
                              ? Icons.battery_charging_full
                              : Icons.battery_std,
                          color: stats.batteryPercent > 20
                              ? const Color(0xFF10B981)
                              : const Color(0xFFF43F5E),
                          size: 18,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '${stats.batteryPercent}%',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Temperature Badge
                  if (stats.cpuTemperature != null)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E293B),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.thermostat,
                            color: Color(0xFFF59E0B),
                            size: 18,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${stats.cpuTemperature!.toStringAsFixed(1)}°C',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  // Live Server Time
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          const Color(0xFF3B82F6).withOpacity(0.2),
                          const Color(0xFF06B6D4).withOpacity(0.2),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: const Color(0xFF06B6D4).withOpacity(0.3),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.schedule,
                            size: 16, color: Color(0xFF06B6D4)),
                        const SizedBox(width: 8),
                        Text(
                          serverTime,
                          style: const TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFFE2E8F0),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              );

              if (isNarrow) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    hostInfo,
                    const SizedBox(height: 12),
                    badges,
                  ],
                );
              }

              return Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(child: hostInfo),
                  badges,
                ],
              );
            },
          ),

          const SizedBox(height: 24),

          // Main Stats Grid & FlChart Line Chart
          LayoutBuilder(
            builder: (context, constraints) {
              final isNarrow = constraints.maxWidth < 900;
              return isNarrow
                  ? Column(
                      children: [
                        _buildCpuChart(constraints.maxWidth),
                        const SizedBox(height: 16),
                        _buildMetricsCards(isRow: false),
                      ],
                    )
                  : Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Left: CPU Realtime Line Chart
                        Expanded(
                          flex: 6,
                          child: _buildCpuChart(constraints.maxWidth * 0.55),
                        ),
                        const SizedBox(width: 20),
                        // Right: RAM, Storage & Core gauges
                        Expanded(
                          flex: 4,
                          child: _buildMetricsCards(isRow: true),
                        ),
                      ],
                    );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildCpuChart(double width) {
    List<FlSpot> spots = [];
    for (int i = 0; i < cpuHistory.length; i++) {
      spots.add(FlSpot(i.toDouble(), cpuHistory[i]));
    }
    if (spots.isEmpty) {
      spots = [const FlSpot(0, 10), const FlSpot(1, 15)];
    }

    return Container(
      height: 180,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
      decoration: BoxDecoration(
        color: const Color(0xFF0B1120),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF1E293B)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.speed,
                      size: 18, color: Color(0xFF06B6D4)),
                  const SizedBox(width: 8),
                  const Text(
                    'CPU Load History',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFFCBD5E1),
                    ),
                  ),
                ],
              ),
              Text(
                '${stats.cpuUsagePercent.toStringAsFixed(1)}%',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF06B6D4),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Expanded(
            child: LineChart(
              LineChartData(
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  getDrawingHorizontalLine: (value) => FlLine(
                    color: const Color(0xFF1E293B),
                    strokeWidth: 1,
                    dashArray: [4, 4],
                  ),
                ),
                titlesData: const FlTitlesData(show: false),
                borderData: FlBorderData(show: false),
                minX: 0,
                maxX: (cpuHistory.length - 1).toDouble().clamp(1.0, 30.0),
                minY: 0,
                maxY: 100,
                lineBarsData: [
                  LineChartBarData(
                    spots: spots,
                    isCurved: true,
                    curveSmoothness: 0.35,
                    color: const Color(0xFF06B6D4),
                    barWidth: 3,
                    isStrokeCapRound: true,
                    dotData: const FlDotData(show: false),
                    belowBarData: BarAreaData(
                      show: true,
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          const Color(0xFF06B6D4).withOpacity(0.35),
                          const Color(0xFF06B6D4).withOpacity(0.0),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricsCards({required bool isRow}) {
    return Column(
      children: [
        // RAM Card
        _buildMetricBar(
          title: 'Memory (RAM)',
          usedText: '${stats.ramUsedGb.toStringAsFixed(1)} GB',
          totalText: '${stats.ramTotalGb.toStringAsFixed(1)} GB',
          percent: stats.ramUsagePercent,
          color: const Color(0xFF8B5CF6),
          icon: Icons.memory,
        ),
        const SizedBox(height: 14),
        // Storage Card
        _buildMetricBar(
          title: 'Storage (NVMe/SSD)',
          usedText: '${stats.diskUsedGb.toStringAsFixed(1)} GB',
          totalText: '${stats.diskTotalGb.toStringAsFixed(1)} GB',
          percent: stats.diskUsagePercent,
          color: const Color(0xFF10B981),
          icon: Icons.storage,
        ),
      ],
    );
  }

  Widget _buildMetricBar({
    required String title,
    required String usedText,
    required String totalText,
    required double percent,
    required Color color,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF0B1120),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF1E293B)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(icon, size: 16, color: color),
                  const SizedBox(width: 8),
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFFCBD5E1),
                    ),
                  ),
                ],
              ),
              Text(
                '$usedText / $totalText (${percent.toStringAsFixed(0)}%)',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF94A3B8),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: (percent / 100).clamp(0.0, 1.0),
              minHeight: 8,
              backgroundColor: const Color(0xFF1E293B),
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
        ],
      ),
    );
  }
}
