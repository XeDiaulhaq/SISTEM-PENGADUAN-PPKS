import 'package:shared_preferences/shared_preferences.dart';

class AuthStorage {
  static const _tokenKey = 'auth_token';
  static const _expiryKey = 'auth_token_expiry';

  Future<void> saveToken(String token, int expiresInSeconds) async {
    final prefs = await SharedPreferences.getInstance();
    final expiry = DateTime.now().add(Duration(seconds: expiresInSeconds));
    await prefs.setString(_tokenKey, token);
    await prefs.setString(_expiryKey, expiry.toIso8601String());
  }

  Future<String?> getValidToken() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(_tokenKey);
    final expiryRaw = prefs.getString(_expiryKey);
    if (token == null || expiryRaw == null) {
      return null;
    }
    final expiry = DateTime.tryParse(expiryRaw);
    if (expiry == null || DateTime.now().isAfter(expiry)) {
      await clear();
      return null;
    }
    return token;
  }

  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
    await prefs.remove(_expiryKey);
  }
}
