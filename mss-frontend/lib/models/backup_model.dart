class BackupItemModel {
  final String filename;
  final String project;
  final double sizeMb;
  final String createdAt;

  BackupItemModel({
    required this.filename,
    this.project = 'General DB',
    required this.sizeMb,
    required this.createdAt,
  });

  factory BackupItemModel.fromJson(Map<String, dynamic> json) {
    return BackupItemModel(
      filename: json['filename'] ?? '',
      project: json['project'] ?? 'General DB',
      sizeMb: (json['size_mb'] as num?)?.toDouble() ?? 0.0,
      createdAt: json['created_at'] ?? '',
    );
  }
}

class BackupHistoryModel {
  final int totalBackups;
  final String? lastBackup;
  final List<BackupItemModel> files;

  BackupHistoryModel({
    required this.totalBackups,
    this.lastBackup,
    required this.files,
  });

  factory BackupHistoryModel.fromJson(Map<String, dynamic> json) {
    var rawFiles = json['files'] as List? ?? [];
    List<BackupItemModel> parsedFiles =
        rawFiles.map((i) => BackupItemModel.fromJson(i)).toList();

    return BackupHistoryModel(
      totalBackups: (json['total_backups'] as num?)?.toInt() ?? parsedFiles.length,
      lastBackup: json['last_backup'],
      files: parsedFiles,
    );
  }
}
