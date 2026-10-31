class ContainerModel {
  final String id;
  final String name;
  final String state;
  final String status;
  final String image;
  final String ports;
  final String? rawStack;
  final String? rawService;

  ContainerModel({
    required this.id,
    required this.name,
    required this.state,
    required this.status,
    required this.image,
    required this.ports,
    this.rawStack,
    this.rawService,
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
      rawStack: json['stack']?.toString(),
      rawService: json['service']?.toString(),
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
      'stack': rawStack,
      'service': rawService,
    };
  }

  /// Nama ekosistem / stack kelompok container
  String get stackName {
    final n = name.toLowerCase();
    final s = (rawStack ?? '').toLowerCase();

    if (n.startsWith('mss-') || n.startsWith('mss_') || s.contains('mss-server-panel')) {
      return 'MSS Cyber-Panel Core';
    }
    if (n.contains('easpira') || s.contains('easpira')) {
      return 'Easpira DPM Stack';
    }
    if (n.contains('portofolio') || s.contains('portofolio')) {
      return 'Portfolio Syafiq';
    }
    if (n.contains('quiz') || s.contains('quiz')) {
      return 'Quiz Arena';
    }
    if (n.contains('capital') || s.contains('capital')) {
      return 'Capital Federation';
    }
    if (n.contains('monopoly') || s.contains('monopoly')) {
      return 'Monopoly Corp';
    }
    if (n.contains('tunnel') || n.contains('cloudflared')) {
      return 'Cloudflare Zero Trust';
    }
    if (n.contains('nextcloud') || n.contains('nas')) {
      return 'Private NAS & Storage';
    }
    if (n.contains('database') || n.contains('adminer') || n.contains('phpmyadmin')) {
      return 'Database Visualizer';
    }
    if (n.contains('portainer')) {
      return 'DevOps & Docker Engine';
    }

    if (rawStack != null && rawStack!.isNotEmpty) {
      return rawStack!.replaceAll('-', ' ').replaceAll('_', ' ').toUpperCase();
    }
    return 'Standalone Services';
  }

  /// Urutan prioritas stack agar tampilan rapi
  int get stackPriority {
    switch (stackName) {
      case 'MSS Cyber-Panel Core':
        return 1;
      case 'Easpira DPM Stack':
        return 2;
      case 'Portfolio Syafiq':
        return 3;
      case 'Capital Federation':
        return 4;
      case 'Quiz Arena':
        return 5;
      case 'Monopoly Corp':
        return 6;
      case 'Cloudflare Zero Trust':
        return 7;
      case 'Private NAS & Storage':
        return 8;
      case 'Database Visualizer':
        return 9;
      case 'DevOps & Docker Engine':
        return 10;
      default:
        return 99;
    }
  }

  /// Peran fungsional container dalam ekosistemnya
  String get role {
    final n = name.toLowerCase();
    final img = image.toLowerCase();

    if (n == 'mss-backend') return 'Laravel API Gateway & Daemon';
    if (n == 'mss-frontend') return 'Nginx Web UI (Flutter Client)';
    if (n == 'mss-db') return 'Core MariaDB 10.11 Relational DB';
    if (n == 'mss-ttyd') return 'Interactive Linux Web Terminal';
    if (n == 'web_easpira') return 'Frontend Web Application';
    if (n == 'db-easpira') return 'MariaDB Database Engine';
    if (n == 'syafiq_portofolio') return 'Personal Portfolio (Laravel/PHP)';
    if (n == 'web_quizarena') return 'Interactive Quiz Game Web';
    if (n == 'tunnel-servermss') return 'Zero Trust Ingress Gateway';
    if (n == 'nextcloud_nas') return 'Private Cloud NAS & Backup Vault';
    if (n == 'web-database') return 'Visual DB Explorer (Admin GUI)';
    if (n == 'portainer') return 'Docker Container Supervisor';

    if (n.contains('capital')) return 'Stock Market Simulator (Node.js)';
    if (n.contains('monopoly')) return 'Board Game Simulator (Node.js)';

    if (img.contains('mariadb') || img.contains('mysql') || img.contains('postgres') || img.contains('mongo')) {
      return 'Database Service Engine';
    }
    if (img.contains('nginx') || img.contains('apache') || img.contains('httpd')) {
      return 'Web Application Server';
    }
    if (n.contains('api') || n.contains('backend')) {
      return 'Backend REST Service';
    }
    return 'Container Service';
  }

  /// Nama pasangan / relasi container
  String get pairName {
    final n = name.toLowerCase();

    if (n == 'web_easpira') return 'db-easpira';
    if (n == 'db-easpira') return 'web_easpira';
    if (n == 'mss-backend') return 'mss-frontend • mss-db';
    if (n == 'mss-frontend') return 'mss-backend';
    if (n == 'mss-db') return 'mss-backend • syafiq_portofolio';
    if (n == 'mss-ttyd') return 'Host Linux Shell';
    if (n == 'syafiq_portofolio') return 'mss-db (db_portofolio)';
    if (n == 'web-database') return 'mss-db (MariaDB 10.11)';
    if (n == 'tunnel-servermss') return '*.xie.my.id (Semua Domain Host)';
    if (n == 'nextcloud_nas') return 'MSS Automated Backup System';
    if (n == 'portainer') return 'Docker Host Socket (/var/run)';
    if (n == 'web_quizarena') return 'Standalone App Engine';

    if (n.contains('capital')) return 'SQLite Volume (backend/data/)';
    if (n.contains('monopoly')) return 'SQLite Volume (backend/data/)';

    return 'Service Mandiri';
  }

  /// Hubungan spesifik dengan pasangannya
  String get pairRelationBadge {
    final n = name.toLowerCase();

    if (n == 'web_easpira') return 'Terhubung ke Database';
    if (n == 'db-easpira') return 'Melayani Web Frontend';
    if (n == 'mss-backend') return 'Otak Core Server Panel';
    if (n == 'mss-frontend') return 'Tampilan Visual Panel';
    if (n == 'mss-db') return 'Pusat Penyimpanan SQL Host';
    if (n == 'mss-ttyd') return 'Akses Direct Root Terminal';
    if (n == 'syafiq_portofolio') return 'Database di mss-db';
    if (n == 'web-database') return 'Inspeksi Visual Tabel MariaDB';
    if (n == 'tunnel-servermss') return 'Pintu Keluar-Masuk Publik Cloudflare';
    if (n == 'nextcloud_nas') return 'Wadah Sinkronisasi Backup SQL';
    if (n == 'portainer') return 'Penyedia Metrik & Status Kontainer';
    if (n == 'web_quizarena') return 'Aplikasi Web Berdiri Sendiri';

    return 'Relasi Ekosistem';
  }

  /// Kategori warna tema aksen untuk visual container
  String get categoryType {
    final n = name.toLowerCase();
    if (n.startsWith('mss-') || n.startsWith('mss_')) return 'core';
    if (n.contains('easpira')) return 'app_pair';
    if (n.contains('portofolio') || n.contains('quiz') || n.contains('capital') || n.contains('monopoly')) return 'web';
    if (n.contains('tunnel')) return 'network';
    if (n.contains('nextcloud') || n.contains('nas')) return 'storage';
    if (n.contains('db') || n.contains('database')) return 'database';
    return 'default';
  }
}
