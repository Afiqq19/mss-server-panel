class AppLauncherModel {
  final int id;
  final String name;
  final String url;
  final String icon;
  final String? description;
  final String category;
  final int order;
  final bool isActive;

  AppLauncherModel({
    required this.id,
    required this.name,
    required this.url,
    required this.icon,
    this.description,
    required this.category,
    required this.order,
    required this.isActive,
  });

  factory AppLauncherModel.fromJson(Map<String, dynamic> json) {
    return AppLauncherModel(
      id: json['id'] ?? 0,
      name: json['name'] ?? '',
      url: json['url'] ?? '',
      icon: json['icon'] ?? 'apps',
      description: json['description'],
      category: json['category'] ?? 'General',
      order: json['order'] ?? 0,
      isActive: json['is_active'] == 1 || json['is_active'] == true,
    );
  }
}
