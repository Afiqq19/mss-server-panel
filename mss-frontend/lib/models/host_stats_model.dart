class HostStatsModel {
  final double cpuUsagePercent;
  final double ramTotalGb;
  final double ramUsedGb;
  final double diskTotalGb;
  final double diskUsedGb;
  final double? cpuTemperature;
  final int batteryPercent;
  final bool isCharging;

  HostStatsModel({
    required this.cpuUsagePercent,
    required this.ramTotalGb,
    required this.ramUsedGb,
    required this.diskTotalGb,
    required this.diskUsedGb,
    this.cpuTemperature,
    required this.batteryPercent,
    required this.isCharging,
  });

  double get ramUsagePercent =>
      ramTotalGb > 0 ? (ramUsedGb / ramTotalGb) * 100 : 0.0;

  double get diskUsagePercent =>
      diskTotalGb > 0 ? (diskUsedGb / diskTotalGb) * 100 : 0.0;

  factory HostStatsModel.fromJson(Map<String, dynamic> json) {
    return HostStatsModel(
      cpuUsagePercent: (json['cpu_usage_percent'] as num?)?.toDouble() ?? 0.0,
      ramTotalGb: (json['ram_total_gb'] as num?)?.toDouble() ?? 8.0,
      ramUsedGb: (json['ram_used_gb'] as num?)?.toDouble() ?? 0.0,
      diskTotalGb: (json['disk_total_gb'] as num?)?.toDouble() ?? 256.0,
      diskUsedGb: (json['disk_used_gb'] as num?)?.toDouble() ?? 0.0,
      cpuTemperature: (json['cpu_temperature'] as num?)?.toDouble(),
      batteryPercent: (json['battery_percent'] as num?)?.toInt() ?? 100,
      isCharging: json['is_charging'] ?? true,
    );
  }
}
