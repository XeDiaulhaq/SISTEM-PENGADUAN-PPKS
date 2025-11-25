import 'dart:convert';
import 'package:http/http.dart' as http;

import 'api_exceptions.dart';
import 'backend_config.dart';

class AuthService {
  AuthService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  Future<LoginResponse> login(String username, String password) async {
    final response = await _client.post(
      Uri.parse('$fastApiBaseUrl/auth/login'),
      headers: {
        'Content-Type': 'application/x-www-form-urlencoded',
        'accept': 'application/json',
      },
      body: {
        'grant_type': 'password',
        'username': username,
        'password': password,
        'scope': '',
        'client_id': 'flutter-admin',
        'client_secret': '',
      },
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body) as Map<String, dynamic>;
      return LoginResponse(
        accessToken: data['access_token'] as String,
        expiresIn: (data['expires_in'] as num?)?.toInt() ?? 3600,
      );
    }

    final detail = _readError(response.body);
    if (response.statusCode == 401) {
      throw AuthException(detail, response.statusCode);
    }
    throw AuthException(detail, response.statusCode);
  }

  String _readError(String body) {
    try {
      final data = json.decode(body) as Map<String, dynamic>;
      final detail = data['detail'];
      if (detail is String) {
        return detail;
      }
      if (detail is Map<String, dynamic> && detail['msg'] is String) {
        return detail['msg'] as String;
      }
    } catch (_) {
      // ignore
    }
    return 'Login gagal. Periksa koneksi dan kredensial Anda.';
  }
}

class LoginResponse {
  final String accessToken;
  final int expiresIn;

  LoginResponse({required this.accessToken, required this.expiresIn});
}
