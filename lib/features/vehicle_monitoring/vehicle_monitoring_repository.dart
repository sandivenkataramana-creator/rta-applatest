import '../../core/network/api_client.dart';
import 'vehicle_monitoring_models.dart';

class VehicleMonitoringRepository {
  VehicleMonitoringRepository({required ApiClient apiClient})
    : _apiClient = apiClient;

  final ApiClient _apiClient;

  Future<List<VehicleDetection>> fetchDetections() async {
    final response = await _apiClient.get<List<dynamic>>('/vehicles');
    return response.data!
        .map((item) => VehicleDetection.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<List<dynamic>> fetchViolations() async {
    final response = await _apiClient.get<List<dynamic>>(
      '/notifications/violations',
      queryParameters: {
        'pageNumber': 1,
        'limit': 100,
      },
    );
    return response.data ?? [];
  }

  Future<List<dynamic>> fetchNotifications({int pageNumber = 1, int limit = 100}) async {
    final response = await _apiClient.get<List<dynamic>>(
      '/notifications',
      queryParameters: {
        'pageNumber': pageNumber,
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

  Future<List<String>> fetchOffenceTypes() async {
    final response = await _apiClient.get<Map<String, dynamic>>(
      '/rta/getOffencesList',
    );
    final data = response.data?['data'];
    if (data is List) {
      return data.whereType<String>().toList();
    }
    return [];
  }
}
