import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/constants/app_constants.dart';

class AuthNotifier extends StateNotifier<bool?> {
  AuthNotifier() : super(null) { _load(); }

  bool loaded          = false;
  bool onboardingDone  = false;

  final loadedNotifier = ChangeNotifier();

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final done     = prefs.getBool(AppConstants.keySetupDone);
    onboardingDone = prefs.getBool(AppConstants.keyOnboardingDone) ?? false;
    loaded = true;
    state  = done;
    loadedNotifier.notifyListeners();
  }

  Future<void> markSetupDone() async {
    await (await SharedPreferences.getInstance())
        .setBool(AppConstants.keySetupDone, true);
    if (state != true) {
      state = true;
      loadedNotifier.notifyListeners();
    }
  }

  Future<void> markOnboardingDone() async {
    await (await SharedPreferences.getInstance())
        .setBool(AppConstants.keyOnboardingDone, true);
    onboardingDone = true;
    loadedNotifier.notifyListeners();
  }

  Future<void> signIn(String apiKey) async {
    final prefs = await SharedPreferences.getInstance();
    if (apiKey.isNotEmpty) {
      await prefs.setString(AppConstants.keyApiKey, apiKey);
    }
    await prefs.setBool(AppConstants.keySetupDone, true);
    state = true;
    loadedNotifier.notifyListeners();
  }

  Future<void> signOut() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(AppConstants.keySetupDone);
    await prefs.remove(AppConstants.keyApiKey);
    await prefs.remove(AppConstants.keyApiUrl);
    state = null;
    loadedNotifier.notifyListeners();
  }
}

final authProvider =
    StateNotifierProvider<AuthNotifier, bool?>((ref) => AuthNotifier());
