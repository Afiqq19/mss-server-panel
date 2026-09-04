class NetworkInterfaceModel {
  final String name;
  final String ip;
  final String mac;
  final String state;

  NetworkInterfaceModel({
    required this.name,
    required this.ip,
    required this.mac,
    required this.state,
  });

  bool get isUp => state.toUpperCase() == 'UP';

  factory NetworkInterfaceModel.fromJson(Map<String, dynamic> json) {
    return NetworkInterfaceModel(
      name: json['name'] ?? '',
      ip: json['ip'] ?? '',
      mac: json['mac'] ?? '',
      state: json['state'] ?? 'UNKNOWN',
    );
  }
}

class ListeningPortModel {
  final String port;
  final String bind;
  final String process;
  final String proto;

  ListeningPortModel({
    required this.port,
    required this.bind,
    required this.process,
    required this.proto,
  });

  factory ListeningPortModel.fromJson(Map<String, dynamic> json) {
    return ListeningPortModel(
      port: json['port']?.toString() ?? '',
      bind: json['bind'] ?? '0.0.0.0',
      process: json['process'] ?? '',
      proto: json['proto'] ?? 'TCP',
    );
  }
}

class NetworkInfoModel {
  final String publicIp;
  final String hostname;
  final List<NetworkInterfaceModel> interfaces;
  final List<ListeningPortModel> listening;
  final List<String> dns;

  NetworkInfoModel({
    required this.publicIp,
    required this.hostname,
    required this.interfaces,
    required this.listening,
    required this.dns,
  });

  factory NetworkInfoModel.fromJson(Map<String, dynamic> json) {
    return NetworkInfoModel(
      publicIp: json['public_ip'] ?? 'N/A',
      hostname: json['hostname'] ?? 'unknown',
      interfaces: (json['interfaces'] as List? ?? [])
          .map((e) => NetworkInterfaceModel.fromJson(e))
          .toList(),
      listening: (json['listening'] as List? ?? [])
          .map((e) => ListeningPortModel.fromJson(e))
          .toList(),
      dns: (json['dns'] as List? ?? []).map((e) => e.toString()).toList(),
    );
  }
}
