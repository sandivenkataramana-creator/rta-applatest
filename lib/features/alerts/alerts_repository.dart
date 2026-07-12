import '../../core/network/api_client.dart';
import 'alerts_models.dart';

class AlertsRepository {
  AlertsRepository({required ApiClient apiClient}) : _apiClient = apiClient;

  final ApiClient _apiClient;

  Future<List<AlertItem>> fetchAlerts() async {
    final response = await _apiClient.get<List<dynamic>>('/alerts');
    return response.data!
        .map((item) => AlertItem.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<List<dynamic>> fetchDetailsNotFound({int limit = 100}) async {
    final response = await _apiClient.get<List<dynamic>>(
      '/notifications/details-not-found',
      queryParameters: {
        'limit': limit,
      },
    );
    return response.data ?? [];
  }

  Future<List<String>> fetchDistricts() async {
    final response = await _apiClient.get<List<dynamic>>('/districts');
    final districtList = response.data ?? [];
    final names = districtList
        .map((item) {
          if (item is Map) {
            return item['districtName']?.toString();
          }
          return null;
        })
        .whereType<String>()
        .toList();
    return ['Select All District', ...names];
  }

  Future<List<String>> fetchZones(String district) async {
    final encodedDistrict = Uri.encodeComponent(district);
    final response = await _apiClient.get<List<dynamic>>(
      '/rtaOffices/$encodedDistrict',
    );
    final officeList = response.data ?? [];
    final names = officeList
        .map((item) {
          if (item is Map) {
            return item['officeName']?.toString();
          }
          return null;
        })
        .whereType<String>()
        .toList();
    return ['Select All Zone', ...names];
  }

  Future<List<dynamic>> fetchCameras(String zone) async {
    final encodedZone = Uri.encodeComponent(zone);
    final response = await _apiClient.get<List<dynamic>>(
      '/camera/$encodedZone',
    );
    return response.data ?? [];
  }
}
