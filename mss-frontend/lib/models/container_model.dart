class ContainerModel {
  final String id;
  final String name;
  final String state;
  final String status;
  final String image;
  final String ports;

  ContainerModel({
    required this.id,
    required this.name,
    required this.state,
    required this.status,
    required this.image,
    required this.ports,
  });

  bool get isRunning => state.toLowerCase() == 'running';

  factory ContainerModel.fromJson(Map<String, dynamic> json) {
    return ContainerModel(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      state: json['state'] ?? 'unknown',
      status: json['status'] ?? '',
      image: json['image'] ?? '',
      ports: json['ports'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'state': state,
      'status': status,
      'image': image,
      'ports': ports,
    };
  }
}
