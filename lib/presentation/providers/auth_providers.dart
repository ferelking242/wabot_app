import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AuthNotifier extends StateNotifier<String?> {
  AuthNotifier() : super(null) { _load(); }

  bool loaded = false;

  // A listenable that fires once loading completes — GoRouter uses this.
  final loadedNotifier = ChangeNotifier();

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final key   = prefs.getString('wabot_api_key');
    loaded = true;
    state  = key;
    // Notify GoRouter even if state didn't change (null → null case).
    loadedNotifier.notifyListeners();
  }

  Future<void> signIn(String apiKey) async {
    await (await SharedPreferences.getInstance()).setString('wabot_api_key', apiKey);
    state = apiKey;
  }

  Future<void> signOut() async {
    await (await SharedPreferences.getInstance()).remove('wabot_api_key');
    state = null;
  }
}

final authProvider =
    StateNotifierProvider<AuthNotifier, String?>((ref) => AuthNotifier());
