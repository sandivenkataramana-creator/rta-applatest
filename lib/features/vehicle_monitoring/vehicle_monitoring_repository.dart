import 'package:flutter/foundation.dart';
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

  Future<List<dynamic>> fetchViolations({
    String? violationType,
    String? districtName,
    String? zoneName,
    String? cameraId,
    String? vehicleType,
    int pageNumber = 1,
    int limit = 100,
  }) async {
    try {
      final queryParams = <String, dynamic>{
        'pageNumber': pageNumber,
        'limit': limit,
      };

      if (violationType != null &&
          violationType.isNotEmpty &&
          violationType != 'Select All Violation Type') {
        queryParams['violationType'] = violationType;
      }
      if (districtName != null &&
          districtName.isNotEmpty &&
          districtName != 'Select All District') {
        queryParams['districtName'] = districtName;
      }
      if (zoneName != null &&
          zoneName.isNotEmpty &&
          zoneName != 'Select All Zone') {
        queryParams['officeName'] = zoneName;
        queryParams['zone'] = zoneName;
      }
      if (cameraId != null &&
          cameraId.isNotEmpty &&
          cameraId != 'Select All Camera') {
        queryParams['cameraId'] = cameraId;
      }
      if (vehicleType != null &&
          vehicleType.isNotEmpty &&
          vehicleType != 'Select All Vehicle Type') {
        queryParams['vehicleType'] = vehicleType;
      }

      debugPrint('Fetching /notifications/violations with params: $queryParams');

      final response = await _apiClient.get<dynamic>(
        '/notifications/violations',
        queryParameters: queryParams,
      );

      final raw = response.data;
      if (raw is List) {
        return raw;
      } else if (raw is Map) {
        if (raw['data'] is List) return raw['data'] as List<dynamic>;
        if (raw['content'] is List) return raw['content'] as List<dynamic>;
        if (raw['violations'] is List) return raw['violations'] as List<dynamic>;
        if (raw['result'] is List) return raw['result'] as List<dynamic>;
      }
    } catch (e) {
      debugPrint('Error in fetchViolations: $e');
    }
    return [];
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

  Future<List<Map<String, dynamic>>> fetchOffenceConfigs() async {
    try {
      final response = await _apiClient.get<Map<String, dynamic>>(
        '/offence-config/active',
      );
      final data = response.data?['data'];
      if (data is List) {
        return data.map((item) {
          if (item is Map) return Map<String, dynamic>.from(item);
          return <String, dynamic>{'offence': item.toString(), 'challanAmount': 250.0};
        }).toList();
      }
    } catch (_) {}

    try {
      final response = await _apiClient.get<Map<String, dynamic>>(
        '/rta/getOffencesList',
      );
      final data = response.data?['data'];
      if (data is List) {
        return data.map((item) {
          if (item is Map) return Map<String, dynamic>.from(item);
          return <String, dynamic>{'offence': item.toString(), 'challanAmount': 250.0};
        }).toList();
      }
    } catch (_) {}

    return [];
  }

  Future<List<String>> fetchOffenceTypes() async {
    final configs = await fetchOffenceConfigs();
    return configs
        .map((item) => item['offence']?.toString())
        .whereType<String>()
        .toList();
  }
}
