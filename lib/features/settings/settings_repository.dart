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
    final response = await _apiClient.get<List<dynamic>>('/rtaOffices/$districtName');
    return response.data ?? [];
  }

  Future<List<dynamic>> fetchCameras(String officeName) async {
    final response = await _apiClient.get<List<dynamic>>('/camera/$officeName');
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
}
