import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/constants/app_constants.dart';

/// Auth state: has the user paired WhatsApp at least once?
/// null  → first launch  → show pairing screen
/// true  → already set up → go straight to dashboard
class AuthNotifier extends StateNotifier<bool?> {
  AuthNotifier() : super(null) { _load(); }

  bool loaded = false;

  /// GoRouter listens to this to re-evaluate redirect after async init.
  final loadedNotifier = ChangeNotifier();

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final done  = prefs.getBool(AppConstants.keySetupDone);
    loaded = true;
    state  = done; // null first launch, true after first pairing
    loadedNotifier.notifyListeners();
  }

  /// Called by PairingNotifier when WhatsApp connection is confirmed.
  Future<void> markSetupDone() async {
    await (await SharedPreferences.getInstance())
        .setBool(AppConstants.keySetupDone, true);
    if (state != true) {
      state = true;
      loadedNotifier.notifyListeners();
    }
  }

  /// Reset — clears setup flag → back to pairing screen.
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
