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
}
