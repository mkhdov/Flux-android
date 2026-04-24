import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../constants/api_constants.dart';

class TokenStorage {
  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  static Future<void> saveTokens({
    required String accessToken,
    String? tokenType,
  }) async {
    await _storage.write(key: kAccessTokenKey, value: accessToken);
    if (tokenType != null) {
      await _storage.write(key: kTokenTypeKey, value: tokenType);
    }
  }

  static Future<String?> getAccessToken() async {
    return await _storage.read(key: kAccessTokenKey);
  }

  static Future<String?> getTokenType() async {
    return await _storage.read(key: kTokenTypeKey);
  }

  static Future<bool> hasToken() async {
    final token = await _storage.read(key: kAccessTokenKey);
    return token != null && token.isNotEmpty;
  }

  static Future<void> clearTokens() async {
    await _storage.delete(key: kAccessTokenKey);
    await _storage.delete(key: kTokenTypeKey);
  }
}
