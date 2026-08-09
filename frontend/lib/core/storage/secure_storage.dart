// MAYA — Secure Storage Wrapper
// Wraps flutter_secure_storage for JWT token management.

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class MayaSecureStorage {
  MayaSecureStorage._();

  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    wOptions: WindowsOptions(),
  );

  static const _tokenKey = 'maya_access_token';

  /// Save the JWT token securely.
  static Future<void> saveToken(String token) async {
    await _storage.write(key: _tokenKey, value: token);
  }

  /// Read the saved JWT token, or null if not found.
  static Future<String?> readToken() async {
    return _storage.read(key: _tokenKey);
  }

  /// Delete the JWT token (logout).
  static Future<void> deleteToken() async {
    await _storage.delete(key: _tokenKey);
  }

  /// Check if a token exists.
  static Future<bool> hasToken() async {
    final token = await readToken();
    return token != null && token.isNotEmpty;
  }
}
