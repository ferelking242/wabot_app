import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeState {
  final ThemeMode mode;
  final Color accent;
  const ThemeState({required this.mode, required this.accent});
  ThemeState copyWith({ThemeMode? mode, Color? accent}) =>
      ThemeState(mode: mode ?? this.mode, accent: accent ?? this.accent);
}

class ThemeController extends StateNotifier<ThemeState> {
  ThemeController()
      : super(const ThemeState(mode: ThemeMode.dark, accent: Color(0xFF25D366))) {
    _load();
  }

  Future<void> _load() async {
    final p      = await SharedPreferences.getInstance();
    final isDark = p.getBool('dark_mode') ?? true;
    final rgb    = p.getInt('accent') ?? 0xFF25D366;
    state = ThemeState(
      mode:   isDark ? ThemeMode.dark : ThemeMode.light,
      accent: Color(rgb),
    );
  }

  Future<void> toggleBrightness() async {
    final next = state.mode == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
    state = state.copyWith(mode: next);
    (await SharedPreferences.getInstance()).setBool('dark_mode', next == ThemeMode.dark);
  }

  Future<void> setAccent(Color c) async {
    state = state.copyWith(accent: c);
    (await SharedPreferences.getInstance()).setInt('accent', c.value);
  }
}

final themeControllerProvider =
    StateNotifierProvider<ThemeController, ThemeState>((ref) => ThemeController());
