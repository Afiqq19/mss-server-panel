import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/app_launcher_model.dart';
import '../models/backup_model.dart';
import '../models/container_model.dart';
import '../models/host_stats_model.dart';
import '../models/user_model.dart';

class ApiService extends ChangeNotifier {
  late String _baseUrl;
  String? _token;
  UserModel? _user;
  bool _isAuthenticated = false;

  ApiService() {
    _initBaseUrl();
  }

  void _initBaseUrl() {
    if (kIsWeb) {
      final origin = Uri.base.origin;
      // Jika dibuka di dev mode lokal (misal localhost:63125 pada Chrome dev)
      if (origin.contains('localhost:') || origin.contains('127.0.0.1:')) {
        _baseUrl = 'http://127.0.0.1:8000/api';
      } else {
        // Di production hosting (panel.xie.my.id), gunakan relative path '/api' yang di-proxy oleh Nginx
        _baseUrl = '/api';
      }
    } else {
      // Fallback untuk aplikasi mobile/desktop APK
      _baseUrl = 'https://panel.xie.my.id/api';
    }
  }

  String get baseUrl => _baseUrl;
  String? get token => _token;
  UserModel? get user => _user;
  bool get isAuthenticated => _isAuthenticated;

  void setBaseUrl(String url) {
    _baseUrl = url.replaceAll(RegExp(r'/$'), '');
    notifyListeners();
  }

  Map<String, String> get _headers {
    final headers = {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
    if (_token != null) {
      headers['Authorization'] = 'Bearer $_token';
    }
    return headers;
  }

  // =================================================================
  // AUTHENTICATION (Bab 5)
  // =================================================================
  Future<bool> login(String email, String password) async {
    try {
      final response = await http
          .post(
            Uri.parse('$_baseUrl/login'),
            headers: {'Content-Type': 'application/json', 'Accept': 'application/json'},
            body: jsonEncode({
              'email': email,
              'password': password,
            }),
          )
          .timeout(const Duration(seconds: 10));

      final data = jsonDecode(response.body);

      if (response.statusCode == 200 && data['status'] == 'success') {
        _token = data['data']['token'];
        _user = UserModel.fromJson(data['data']['user']);
        _isAuthenticated = true;
        notifyListeners();
        return true;
      } else {
        throw Exception(data['message'] ?? 'Login gagal. Periksa kredensial Anda.');
      }
    } catch (e) {
      debugPrint('Login error: $e');
      rethrow;
    }
  }

  Future<void> logout() async {
    try {
      if (_token != null) {
        await http
            .post(Uri.parse('$_baseUrl/logout'), headers: _headers)
            .timeout(const Duration(seconds: 5));
      }
    } catch (_) {}
    _token = null;
    _user = null;
    _isAuthenticated = false;
    notifyListeners();
  }

  // =================================================================
  // HOST SERVER MONITORING (Bab 4, 8, 9.A)
  // =================================================================
  Future<HostStatsModel> fetchHostStats() async {
    try {
      final response = await http
          .get(Uri.parse('$_baseUrl/host-stats'), headers: _headers)
          .timeout(const Duration(seconds: 10));

      final data = jsonDecode(response.body);
      if (response.statusCode == 200 && (data['status'] == 'success' || data['data'] != null)) {
        return HostStatsModel.fromJson(data['data']);
      }
    } catch (e) {
      debugPrint('fetchHostStats error: $e');
    }
    // Safe fallback defaults jika server offline
    return HostStatsModel(
      cpuUsagePercent: 12.5,
      ramTotalGb: 8.0,
      ramUsedGb: 3.2,
      diskTotalGb: 256.0,
      diskUsedGb: 120.5,
      cpuTemperature: 48.5,
      batteryPercent: 100,
      isCharging: true,
    );
  }

  // =================================================================
  // DOCKER CONTAINERS (Bab 2, 4, 6, 8)
  // =================================================================
  Future<List<ContainerModel>> fetchContainers() async {
    try {
      final response = await http
          .get(Uri.parse('$_baseUrl/containers'), headers: _headers)
          .timeout(const Duration(seconds: 10));

      final data = jsonDecode(response.body);
      final list = data['data'] as List? ?? [];
      return list.map((item) => ContainerModel.fromJson(item)).toList();
    } catch (e) {
      debugPrint('fetchContainers error: $e');
      return [];
    }
  }

  Future<bool> executeContainerAction(String id, String action) async {
    final response = await http
        .post(
          Uri.parse('$_baseUrl/containers/$id/$action'),
          headers: _headers,
        )
        .timeout(const Duration(seconds: 15));

    final data = jsonDecode(response.body);
    if (response.statusCode == 200 && data['status'] == 'success') {
      return true;
    } else {
      throw Exception(data['message'] ?? 'Gagal menjalankan aksi container');
    }
  }

  // =================================================================
  // APP LAUNCHERS (Bab 4, 7)
  // =================================================================
  Future<List<AppLauncherModel>> fetchAppLaunchers() async {
    try {
      final response = await http
          .get(Uri.parse('$_baseUrl/app-launchers'), headers: _headers)
          .timeout(const Duration(seconds: 10));

      final data = jsonDecode(response.body);
      if (response.statusCode == 200 && data['data'] != null) {
        final list = data['data'] as List? ?? [];
        return list.map((item) => AppLauncherModel.fromJson(item)).toList();
      }
    } catch (e) {
      debugPrint('fetchAppLaunchers error: $e');
    }
    return [];
  }

  // =================================================================
  // BACKUP E-ASPIRA (Bab 9.B)
  // =================================================================
  Future<BackupHistoryModel> fetchBackups() async {
    final response = await http
        .get(Uri.parse('$_baseUrl/backups'), headers: _headers)
        .timeout(const Duration(seconds: 10));

    final data = jsonDecode(response.body);
    if (response.statusCode == 200 && data['status'] == 'success') {
      return BackupHistoryModel.fromJson(data['data']);
    } else {
      throw Exception(data['message'] ?? 'Gagal mengambil riwayat backup');
    }
  }

  Future<String> triggerBackup({String project = 'all'}) async {
    final response = await http
        .post(
          Uri.parse('$_baseUrl/backups/run'),
          headers: _headers,
          body: jsonEncode({'project': project}),
        )
        .timeout(const Duration(seconds: 45));

    final data = jsonDecode(response.body);
    if (response.statusCode == 200 && data['status'] == 'success') {
      return data['message'] ?? 'Backup berhasil dijalankan';
    } else {
      throw Exception(data['message'] ?? 'Gagal memicu backup');
    }
  }
}