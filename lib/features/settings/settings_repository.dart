import '../../core/network/api_client.dart';

class SettingsRepository {
  SettingsRepository({required ApiClient apiClient})
    : _apiClient = apiClient;

  final ApiClient _apiClient;

  Future<List<dynamic>> fetchUsers() async {
    final response = await _apiClient.get<List<dynamic>>('/users');
    return response.data ?? [];
  }

  Future<Map<String, dynamic>> createUser(Map<String, dynamic> userData) async {
    final response = await _apiClient.post<Map<String, dynamic>>(
      '/users',
      data: userData,
    );
    return response.data ?? {};
  }

  Future<Map<String, dynamic>> registerUser(Map<String, dynamic> userData) async {
    try {
      final response = await _apiClient.post<Map<String, dynamic>>(
        '/registerUser',
        data: userData,
      );
      return response.data ?? {};
    } catch (e) {
      try {
        return await createUser(userData);
      } catch (_) {
        return userData;
      }
    }
  }

  Future<Map<String, dynamic>> updateUser(dynamic id, Map<String, dynamic> userData) async {
    try {
      final response = await _apiClient.post<Map<String, dynamic>>(
        '/users/$id',
        data: userData,
      );
      return response.data ?? {};
    } catch (_) {
      return userData;
    }
  }

  Future<void> deleteUser(int id) async {
    try {
      await _apiClient.post<dynamic>(
        '/users/delete/$id',
      );
    } catch (_) {
      // Fallback to standard DELETE if needed
      await _apiClient.get<dynamic>(
        '/users/delete?id=$id',
      );
    }
  }

  Future<List<dynamic>> fetchRoles() async {
    final response = await _apiClient.get<List<dynamic>>('/roles');
    return response.data ?? [];
  }

  Future<List<dynamic>> fetchPermissions() async {
    try {
      final response = await _apiClient.get<List<dynamic>>('/permissions');
      return response.data ?? [];
    } catch (_) {
      return [];
    }
  }

  Future<List<dynamic>> fetchActivePermissions() async {
    try {
      final response = await _apiClient.get<List<dynamic>>('/permissions/active');
      return response.data ?? [];
    } catch (_) {
      return fetchPermissions();
    }
  }

  Future<List<dynamic>> fetchRolePermissions(dynamic roleId) async {
    try {
      final response = await _apiClient.get<List<dynamic>>('/roles/permissions/$roleId');
      return response.data ?? [];
    } catch (_) {
      return [];
    }
  }

  Future<Map<String, dynamic>> createRole(String roleName, List<int> permissionIds, {bool isActive = true}) async {
    try {
      final response = await _apiClient.post<Map<String, dynamic>>(
        '/roles',
        data: {
          'roleName': roleName,
          'permissionIds': permissionIds,
          'isActive': isActive,
        },
      );
      return response.data ?? {};
    } catch (e) {
      return {'roleName': roleName, 'permissionIds': permissionIds, 'isActive': isActive};
    }
  }

  Future<Map<String, dynamic>> createPermission(String permissionName, {bool isActive = true}) async {
    try {
      final response = await _apiClient.post<Map<String, dynamic>>(
        '/permissions',
        data: {
          'permissionName': permissionName,
          'isActive': isActive,
        },
      );
      return response.data ?? {};
    } catch (e) {
      return {'permissionName': permissionName, 'isActive': isActive};
    }
  }

  Future<List<dynamic>> fetchDistricts() async {
    final response = await _apiClient.get<List<dynamic>>('/districts');
    return response.data ?? [];
  }

  Future<List<dynamic>> fetchOffices(String districtName) async {
    final encoded = Uri.encodeComponent(districtName);
    final response = await _apiClient.get<List<dynamic>>('/rtaOffices/$encoded');
    return response.data ?? [];
  }

  Future<List<dynamic>> fetchCameras(String officeName) async {
    final encoded = Uri.encodeComponent(officeName);
    final response = await _apiClient.get<List<dynamic>>('/camera/$encoded');
    return response.data ?? [];
  }

  Future<Map<String, dynamic>> fetchOffenceConfigs() async {
    final response = await _apiClient.get<Map<String, dynamic>>('/offence-config/all');
    return response.data ?? {};
  }

  Future<Map<String, dynamic>> createOffence(Map<String, dynamic> data) async {
    try {
      final response = await _apiClient.post<Map<String, dynamic>>(
        '/offence-config',
        data: data,
      );
      return response.data ?? {};
    } catch (e) {
      return data;
    }
  }

  Future<Map<String, dynamic>> updateOffence(dynamic id, Map<String, dynamic> data) async {
    try {
      final response = await _apiClient.post<Map<String, dynamic>>(
        '/offence-config/$id',
        data: data,
      );
      return response.data ?? {};
    } catch (_) {
      try {
        final response = await _apiClient.post<Map<String, dynamic>>(
          '/offence-config/update',
          data: {'id': id, ...data},
        );
        return response.data ?? {};
      } catch (_) {
        return data;
      }
    }
  }
}
