import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'screens/dashboard_screen.dart';
import 'screens/login_screen.dart';
import 'screens/update_screen.dart';
import 'services/api_service.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ApiService()),
      ],
      child: const MssServerPanelApp(),
    ),
  );
}

class MssServerPanelApp extends StatelessWidget {
  const MssServerPanelApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MSS Server Panel',
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.dark,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF0A0F1D),
        primaryColor: const Color(0xFF06B6D4),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF06B6D4),
          secondary: Color(0xFF3B82F6),
          surface: Color(0xFF0F172A),
          error: Color(0xFFF43F5E),
        ),
        cardTheme: CardThemeData(
          color: const Color(0xFF0F172A),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: Color(0xFF1E293B)),
          ),
        ),
        dialogTheme: DialogThemeData(
          backgroundColor: const Color(0xFF0F172A),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: const BorderSide(color: Color(0xFF1E293B)),
          ),
        ),
        snackBarTheme: const SnackBarThemeData(
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(12)),
          ),
        ),
      ),
      home: Builder(
        builder: (context) {
          final uri = Uri.base;
          if (uri.path.contains('update-rahasia-panel')) {
            final key = uri.queryParameters['key'] ?? '';
            return UpdateScreen(secretKey: key);
          }

          return Consumer<ApiService>(
            builder: (context, apiService, _) {
              if (apiService.isAuthenticated) {
                return const DashboardScreen();
              }
              return const LoginScreen();
            },
          );
        },
      ),
    );
  }
}
