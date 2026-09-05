import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/app_launcher_model.dart';
import '../models/backup_model.dart';
import '../models/container_model.dart';
import '../models/host_stats_model.dart';
import '../models/user_model.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ApiService extends ChangeNotifier {
  late String _baseUrl;
  String? _token;
  UserModel? _user;
  bool _isAuthenticated = false;

  ApiService() {
    _initBaseUrl();
    _loadToken();
  }

  Future<void> _loadToken() async {
    final prefs = await SharedPreferences.getInstance();
    final savedToken = prefs.getString('mss_token');
    if (savedToken != null) {
      _token = savedToken;
      _isAuthenticated = true;
      // Ideally we would fetch user details here using token, 
      // but for now we just mark as authenticated to prevent logout on reload
      notifyListeners();
    }
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
        
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('mss_token', _token!);
        
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
    
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('mss_token');
    
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

  Future<bool> createAppLauncher({
    required String name,
    required String url,
    required String icon,
    String? description,
    required String category,
    int order = 0,
    bool isActive = true,
  }) async {
    final response = await http
        .post(
          Uri.parse('$_baseUrl/app-launchers'),
          headers: _headers,
          body: jsonEncode({
            'name': name,
            'url': url,
            'icon': icon,
            'description': description ?? '',
            'category': category,
            'order': order,
            'is_active': isActive,
          }),
        )
        .timeout(const Duration(seconds: 10));

    final data = jsonDecode(response.body);
    if (response.statusCode == 200 || response.statusCode == 201) {
      return true;
    } else {
      throw Exception(data['message'] ?? 'Gagal menambahkan App Launcher');
    }
  }

  Future<bool> updateAppLauncher({
    required int id,
    required String name,
    required String url,
    required String icon,
    String? description,
    required String category,
    int order = 0,
    bool isActive = true,
  }) async {
    final response = await http
        .put(
          Uri.parse('$_baseUrl/app-launchers/$id'),
          headers: _headers,
          body: jsonEncode({
            'name': name,
            'url': url,
            'icon': icon,
            'description': description ?? '',
            'category': category,
            'order': order,
            'is_active': isActive,
          }),
        )
        .timeout(const Duration(seconds: 10));

    final data = jsonDecode(response.body);
    if (response.statusCode == 200) {
      return true;
    } else {
      throw Exception(data['message'] ?? 'Gagal mengupdate App Launcher');
    }
  }

  Future<bool> deleteAppLauncher(int id) async {
    final response = await http
        .delete(
          Uri.parse('$_baseUrl/app-launchers/$id'),
          headers: _headers,
        )
        .timeout(const Duration(seconds: 10));

    if (response.statusCode == 200 || response.statusCode == 204) {
      return true;
    } else {
      final data = jsonDecode(response.body);
      throw Exception(data['message'] ?? 'Gagal menghapus App Launcher');
    }
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

  // =================================================================
  // NETWORK MONITORING
  // =================================================================
  Future<Map<String, dynamic>> fetchNetworkInfo() async {
    try {
      final response = await http
          .get(Uri.parse('$_baseUrl/network-info'), headers: _headers)
          .timeout(const Duration(seconds: 10));

      final data = jsonDecode(response.body);
      if (response.statusCode == 200 && data['status'] == 'success') {
        return data['data'] as Map<String, dynamic>;
      }
    } catch (e) {
      debugPrint('fetchNetworkInfo error: $e');
    }
    return {};
  }

  // =================================================================
  // TERMINAL
  // =================================================================
  Future<String> executeTerminalCommand(String command) async {
    try {
      final response = await http
          .post(
            Uri.parse('$_baseUrl/terminal/execute'),
            headers: _headers,
            body: jsonEncode({'command': command}),
          )
          .timeout(const Duration(seconds: 45));

      final data = jsonDecode(response.body);
      if (response.statusCode == 200 && data['status'] == 'success') {
        return data['output'] ?? '';
      } else {
        throw Exception(data['message'] ?? data['output'] ?? 'Gagal eksekusi perintah');
      }
    } catch (e) {
      throw Exception('Network error: $e');
    }
  }

  // =================================================================
  // SETTINGS
  // =================================================================
  Future<void> updateAccount({
    required String username,
    required String currentPassword,
    String? newPassword,
  }) async {
    final body = {
      'username': username,
      'current_password': currentPassword,
    };
    if (newPassword != null && newPassword.isNotEmpty) {
      body['new_password'] = newPassword;
    }
    
    final response = await http
        .post(
          Uri.parse('$_baseUrl/settings/update-account'),
          headers: _headers,
          body: jsonEncode(body),
        )
        .timeout(const Duration(seconds: 10));

    final data = jsonDecode(response.body);
    if (response.statusCode != 200 || data['status'] != 'success') {
      throw Exception(data['message'] ?? 'Gagal update akun');
    }
  }

  Future<void> updateEnv({
    required String portainerUrl,
    required String portainerApiKey,
    required int portainerEndpointId,
  }) async {
    final response = await http
        .post(
          Uri.parse('$_baseUrl/settings/update-env'),
          headers: _headers,
          body: jsonEncode({
            'portainer_url': portainerUrl,
            'portainer_api_key': portainerApiKey,
            'portainer_endpoint_id': portainerEndpointId,
          }),
        )
        .timeout(const Duration(seconds: 10));
    
    final data = jsonDecode(response.body);
    if (response.statusCode != 200 || data['status'] != 'success') {
      throw Exception(data['message'] ?? 'Gagal update konfigurasi');
    }
  }

  // =================================================================
  // CONTAINER LOGS
  // =================================================================
  Future<String> getContainerLogs(String id, {int tail = 100}) async {
    try {
      final response = await http
          .get(Uri.parse('$_baseUrl/containers/$id/logs?tail=$tail'), headers: _headers)
          .timeout(const Duration(seconds: 15));

      final data = jsonDecode(response.body);
      if (response.statusCode == 200 && data['status'] == 'success') {
        return data['data']?['logs'] ?? 'No logs available';
      }
      return data['message'] ?? 'Gagal mengambil log';
    } catch (e) {
      debugPrint('getContainerLogs error: $e');
      return 'Error: $e';
    }
  }

  // =================================================================
  // SYSTEM MAINTENANCE
  // =================================================================
  Future<List<Map<String, dynamic>>> fetchMaintenanceTasks() async {
    try {
      final response = await http
          .get(Uri.parse('$_baseUrl/maintenance'), headers: _headers)
          .timeout(const Duration(seconds: 10));

      final data = jsonDecode(response.body);
      if (response.statusCode == 200 && data['status'] == 'success') {
        final list = data['data'] as List? ?? [];
        return list.map((item) => Map<String, dynamic>.from(item)).toList();
      }
    } catch (e) {
      debugPrint('fetchMaintenanceTasks error: $e');
    }
    return [];
  }

  Future<Map<String, dynamic>> executeMaintenanceTask(String taskId) async {
    try {
      final response = await http
          .post(
            Uri.parse('$_baseUrl/maintenance/execute'),
            headers: _headers,
            body: jsonEncode({'task_id': taskId}),
          )
          .timeout(const Duration(seconds: 120));

      final data = jsonDecode(response.body);
      if (response.statusCode == 200 && data['status'] == 'success') {
        return Map<String, dynamic>.from(data['data'] ?? {});
      } else {
        throw Exception(data['message'] ?? 'Gagal menjalankan maintenance task');
      }
    } catch (e) {
      throw Exception('Maintenance error: $e');
    }
  }
}
