import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeService extends ChangeNotifier {
  static const String _themeKey = 'theme_mode';
  ThemeMode _themeMode = ThemeMode.dark;
  bool _isToggling = false;
  Timer? _cooldownTimer;

  ThemeService() {
    _loadTheme();
  }

  ThemeMode get themeMode => _themeMode;
  bool get isDarkMode => _themeMode == ThemeMode.dark;
  bool get isToggling => _isToggling;

  Future<void> _loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    final themeIndex = prefs.getInt(_themeKey);
    if (themeIndex != null) {
      _themeMode = ThemeMode.values[themeIndex];
      notifyListeners();
    }
  }

  Future<void> toggleTheme() async {
    if (_isToggling) return;

    _isToggling = true;
    _themeMode = isDarkMode ? ThemeMode.light : ThemeMode.dark;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_themeKey, _themeMode.index);

    _cooldownTimer?.cancel();
    _cooldownTimer = Timer(const Duration(milliseconds: 300), () {
      _isToggling = false;
      notifyListeners();
    });
  }

  @override
  void dispose() {
    _cooldownTimer?.cancel();
    super.dispose();
  }
}
