import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AccentTheme {
  final String id;
  final String name;
  final Color primary;
  final Color secondary;
  final Color glow;

  const AccentTheme({
    required this.id,
    required this.name,
    required this.primary,
    required this.secondary,
    required this.glow,
  });
}

class ThemeProvider extends ChangeNotifier {
  static const _prefsKey = 'mss_accent_theme';

  String _currentThemeId = 'cyan';

  static const List<AccentTheme> availableThemes = [
    AccentTheme(
      id: 'cyan',
      name: 'Cyber Cyan',
      primary: Color(0xFF06B6D4),
      secondary: Color(0xFF3B82F6),
      glow: Color(0xFF06B6D4),
    ),
    AccentTheme(
      id: 'blue',
      name: 'Electric Sapphire',
      primary: Color(0xFF3B82F6),
      secondary: Color(0xFF6366F1),
      glow: Color(0xFF3B82F6),
    ),
    AccentTheme(
      id: 'purple',
      name: 'Neon Purple',
      primary: Color(0xFF8B5CF6),
      secondary: Color(0xFFA78BFA),
      glow: Color(0xFF8B5CF6),
    ),
    AccentTheme(
      id: 'green',
      name: 'Emerald Matrix',
      primary: Color(0xFF10B981),
      secondary: Color(0xFF34D399),
      glow: Color(0xFF10B981),
    ),
    AccentTheme(
      id: 'orange',
      name: 'Sunset Orange',
      primary: Color(0xFFF97316),
      secondary: Color(0xFFFBBF24),
      glow: Color(0xFFF97316),
    ),
    AccentTheme(
      id: 'red',
      name: 'Cyberpunk Red',
      primary: Color(0xFFEF4444),
      secondary: Color(0xFFF97316),
      glow: Color(0xFFEF4444),
    ),
    AccentTheme(
      id: 'pink',
      name: 'Synthwave Pink',
      primary: Color(0xFFEC4899),
      secondary: Color(0xFF8B5CF6),
      glow: Color(0xFFEC4899),
    ),
  ];

  ThemeProvider() {
    _loadSavedTheme();
  }

  String get currentThemeId => _currentThemeId;

  AccentTheme get currentTheme =>
      availableThemes.firstWhere((t) => t.id == _currentThemeId,
          orElse: () => availableThemes.first);

  Color get primary => currentTheme.primary;
  Color get secondary => currentTheme.secondary;
  Color get glow => currentTheme.glow;

  LinearGradient get accentGradient => LinearGradient(
        colors: [primary, secondary],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );

  List<BoxShadow> glowShadow({double blur = 18, double spread = 0, double opacity = 0.25}) {
    return [
      BoxShadow(
        color: glow.withOpacity(opacity),
        blurRadius: blur,
        spreadRadius: spread,
        offset: const Offset(0, 4),
      ),
    ];
  }

  Future<void> _loadSavedTheme() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_prefsKey);
    if (saved != null && availableThemes.any((t) => t.id == saved)) {
      _currentThemeId = saved;
      notifyListeners();
    }
  }

  Future<void> setTheme(String themeId) async {
    if (!availableThemes.any((t) => t.id == themeId)) return;
    _currentThemeId = themeId;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, themeId);
    notifyListeners();
  }
}
