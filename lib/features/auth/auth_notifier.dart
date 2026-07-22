import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/api_client.dart';
import '../../core/storage/secure_storage_service.dart';
import '../auth/auth_models.dart';
// legacy notifier uses an internal compatibility repository; avoid importing the
// new `auth_repository.dart` interface here to prevent type conflicts.

final authNotifierProvider = StateNotifierProvider<AuthNotifier, AuthState>((
  ref,
) {
  final storage = SecureStorageService();
  final apiClient = ApiClient(storage);
  final repository = _LegacyAuthRepository(apiClient, storage);
  return AuthNotifier(repository: repository, storage: storage);
});

class AuthState {
  AuthState({
    this.user,
    this.token,
    this.isAuthenticated = false,
    this.isInitializing = true,
  });

  final AuthUser? user;
  final AuthToken? token;
  final bool isAuthenticated;
  final bool isInitializing;
}

class _LegacyAuthRepository {
  _LegacyAuthRepository(this._apiClient, this._storage);

  final ApiClient _apiClient;
  final SecureStorageService _storage;

  Future<Map<String, dynamic>> login(
    String username,
    String password,
    bool rememberMe,
  ) async {
    final response = await _apiClient.get<Map<String, dynamic>>(
      '/auth/login',
      queryParameters: {'username': username, 'password': password},
    );
    final data = response.data ?? <String, dynamic>{};
    final access = data['token']?.toString() ?? data['accessToken']?.toString() ?? '';
    final refresh = data['refreshToken']?.toString() ?? '';
    final role = data['role']?.toString() ?? '';
    await _storage.writeRememberMe(rememberMe);
    await _storage.writeToken(access);
    await _storage.writeRefreshToken(refresh);
    await _storage.writeUsername(username);
    return {
      'token': AuthToken(accessToken: access, refreshToken: refresh),
      'role': role,
    };
  }

  Future<void> logout() async {
    try {
      await _apiClient.post('/auth/logout');
    } catch (_) {}
    await _storage.deleteToken();
    await _storage.deleteRefreshToken();
    await _storage.deleteUsername();
    await _storage.writeRememberMe(false);
  }
}

class AuthNotifier extends StateNotifier<AuthState> {
  AuthNotifier({required this.repository, required this.storage})
    : super(AuthState(isInitializing: true)) {
    _initialize();
  }

  final dynamic repository;
  final SecureStorageService storage;
  final _authChanges = StreamController<void>.broadcast();

  Stream<void> get authChangeStream => _authChanges.stream;

  Future<void> _initialize() async {
    try {
      final remember = await storage.readRememberMe();
      final token = await storage.readToken();
      final username = await storage.readUsername() ?? 'admin';
      
      if (remember && token != null && token.trim().isNotEmpty) {
        final role = username.contains('super')
            ? 'Super Admin'
            : username.contains('admin')
            ? 'RTA Administrator'
            : 'Enforcement Officer';
        final user = AuthUser(
          username: username,
          name: username.toUpperCase(),
          role: role,
        );
        state = AuthState(
          user: user,
          token: AuthToken(accessToken: token, refreshToken: ''),
          isAuthenticated: true,
          isInitializing: false,
        );
      } else {
        state = AuthState(
          isAuthenticated: false,
          isInitializing: false,
        );
      }
    } catch (_) {
      state = AuthState(
        isAuthenticated: false,
        isInitializing: false,
      );
    } finally {
      _authChanges.add(null);
    }
  }

  Future<void> login(String username, String password, bool rememberMe) async {
    final result = await repository.login(username, password, rememberMe);
    final AuthToken token;
    final String serverRole;
    if (result is Map) {
      token = result['token'] as AuthToken;
      serverRole = result['role']?.toString() ?? '';
    } else if (result is AuthToken) {
      token = result;
      serverRole = '';
    } else {
      throw Exception('Invalid login result');
    }

    String role;
    if (serverRole.isNotEmpty) {
      if (serverRole.toLowerCase() == 'admin') {
        role = 'RTA Administrator';
      } else {
        role = serverRole[0].toUpperCase() + serverRole.substring(1);
      }
    } else {
      role = username.contains('super')
          ? 'Super Admin'
          : username.contains('admin')
          ? 'RTA Administrator'
          : username.contains('enforce')
          ? 'Enforcement Officer'
          : username.contains('check')
          ? 'Checkpost Officer'
          : 'Supervisor';
    }

    final user = AuthUser(
      username: username,
      name: username.toUpperCase(),
      role: role,
    );
    state = AuthState(
      user: user,
      token: token,
      isAuthenticated: true,
      isInitializing: false,
    );
    _authChanges.add(null);
  }

  Future<void> logout() async {
    await repository.logout();
    state = AuthState(
      isAuthenticated: false,
      isInitializing: false,
    );
    _authChanges.add(null);
  }
}
