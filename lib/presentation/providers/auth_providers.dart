import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AuthNotifier extends StateNotifier<String?> {
  AuthNotifier() : super(null) { _load(); }

  Future<void> _load() async {
    state = (await SharedPreferences.getInstance()).getString('wabot_api_key');
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
