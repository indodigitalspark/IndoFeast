import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../models/app_user.dart';
import 'secure_storage_backend.dart';

class AppStorageService {
  const AppStorageService._();

  static const String authTokenKey = 'auth_token';
  static const String authUserKey = 'auth_user';
  static final SecureStorageBackend _secureStorage =
      createSecureStorageBackend();

  static Future<void> saveAuthSession({
    required String token,
    required AppUser user,
  }) async {
    final preferences = await SharedPreferences.getInstance();
    await _secureStorage.write(authTokenKey, token);
    await preferences.setString(authUserKey, jsonEncode(user.toMap()));
  }

  static Future<String?> getAuthToken() async {
    return _secureStorage.read(authTokenKey);
  }

  static Future<AppUser?> getStoredUser() async {
    final preferences = await SharedPreferences.getInstance();
    final raw = preferences.getString(authUserKey);
    if (raw == null || raw.isEmpty) {
      return null;
    }

    return AppUser.fromMap(jsonDecode(raw) as Map<String, dynamic>);
  }

  static Future<void> clearAuthSession() async {
    final preferences = await SharedPreferences.getInstance();
    await _secureStorage.delete(authTokenKey);
    await preferences.remove(authUserKey);
  }
}
