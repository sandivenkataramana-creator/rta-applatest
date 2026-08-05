// lib/core/storage/secure_storage_service.dart
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SecureStorageService {
  SecureStorageService._internal();
  static final SecureStorageService _instance =
      SecureStorageService._internal();
  factory SecureStorageService() => _instance;

  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  static const _kToken = 'rta_access_token';
  static const _kRefresh = 'rta_refresh_token';
  static const _kUsername = 'rta_username';
  static const _kRemember = 'rta_remember';
  static const _kDistrictIds = 'rta_district_ids';

  Future<void> writeToken(String token) =>
      _storage.write(key: _kToken, value: token);
  Future<String?> readToken() => _storage.read(key: _kToken);
  Future<void> deleteToken() => _storage.delete(key: _kToken);

  Future<void> writeRefreshToken(String token) =>
      _storage.write(key: _kRefresh, value: token);
  Future<String?> readRefreshToken() => _storage.read(key: _kRefresh);
  Future<void> deleteRefreshToken() => _storage.delete(key: _kRefresh);

  Future<void> writeUsername(String username) =>
      _storage.write(key: _kUsername, value: username);
  Future<String?> readUsername() => _storage.read(key: _kUsername);
  Future<void> deleteUsername() => _storage.delete(key: _kUsername);

  Future<void> writeRememberMe(bool remember) =>
      _storage.write(key: _kRemember, value: remember ? '1' : '0');
  Future<bool> readRememberMe() async =>
      (await _storage.read(key: _kRemember)) == '1';

  Future<void> writeDistrictIds(List<int> ids) =>
      _storage.write(key: _kDistrictIds, value: ids.join(','));
  Future<List<int>> readDistrictIds() async {
    final str = await _storage.read(key: _kDistrictIds);
    if (str == null || str.trim().isEmpty) return [];
    return str
        .split(',')
        .map((e) => int.tryParse(e.trim()))
        .whereType<int>()
        .toList();
  }
  Future<void> deleteDistrictIds() => _storage.delete(key: _kDistrictIds);

  Future<void> clearAll() => _storage.deleteAll();
}
