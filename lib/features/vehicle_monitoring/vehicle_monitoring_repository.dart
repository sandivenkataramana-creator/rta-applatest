import 'package:flutter/foundation.dart';
import '../../core/network/api_client.dart';
import '../../core/storage/secure_storage_service.dart';
import 'vehicle_monitoring_models.dart';

class VehicleMonitoringRepository {
  VehicleMonitoringRepository({required ApiClient apiClient})
    : _apiClient = apiClient;

  final ApiClient _apiClient;

  Future<List<VehicleDetection>> fetchDetections() async {
    try {
      final violations = await fetchViolations();
      if (violations.isNotEmpty) {
        return violations
            .map((item) => VehicleDetection.fromJson(item as Map<String, dynamic>))
            .toList();
      }
    } catch (e) {
      debugPrint('Error fetching detections: $e');
    }
    return [];
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
        queryParams['zoneName'] = zoneName;
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

  Future<List<dynamic>> fetchNotifications({
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
        queryParams['zoneName'] = zoneName;
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

      final response = await _apiClient.get<dynamic>(
        '/notifications',
        queryParameters: queryParams,
      );

      final raw = response.data;
      if (raw is List) {
        return raw;
      } else if (raw is Map) {
        if (raw['data'] is List) return raw['data'] as List<dynamic>;
        if (raw['content'] is List) return raw['content'] as List<dynamic>;
        if (raw['notifications'] is List) return raw['notifications'] as List<dynamic>;
        if (raw['result'] is List) return raw['result'] as List<dynamic>;
      }
    } catch (e) {
      debugPrint('Error in fetchNotifications: $e');
    }
    return [];
  }

  Future<List<String>> fetchDistricts() async {
    final response = await _apiClient.get<List<dynamic>>('/districts');
    final districtList = response.data ?? [];

    final storage = SecureStorageService();
    final assignedIds = await storage.readDistrictIds();

    final names = districtList
        .map((item) {
          if (item is Map) {
            final id = int.tryParse(item['id']?.toString() ?? '');
            if (assignedIds.isNotEmpty && (id == null || !assignedIds.contains(id))) {
              return null;
            }
            return item['districtName']?.toString();
          }
          return null;
        })
        .whereType<String>()
        .toList();

    if (assignedIds.isNotEmpty && names.isNotEmpty) {
      return names;
    }

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

  Future<Map<String, dynamic>> checkDuplicateVcr({
    required String registrationNumber,
    required String offences,
  }) async {
    try {
      final response = await _apiClient.post<dynamic>(
        '/vcr/check-duplicate',
        data: {
          'registrationNumber': registrationNumber,
          'offences': offences,
        },
      );
      if (response.data is Map) {
        return Map<String, dynamic>.from(response.data as Map);
      }
    } catch (e) {
      debugPrint('Error in checkDuplicateVcr: $e');
    }
    return {'isDuplicate': false};
  }

  Future<Map<String, dynamic>> saveVcr(Map<String, dynamic> vcrData) async {
    final response = await _apiClient.post<dynamic>(
      '/vcr/save',
      data: vcrData,
    );
    if (response.data is Map) {
      return Map<String, dynamic>.from(response.data as Map);
    }
    return {};
  }

  Future<Map<String, dynamic>> addChallan(Map<String, dynamic> challanData) async {
    final response = await _apiClient.post<dynamic>(
      '/rta/addChallan',
      data: challanData,
    );
    if (response.data is Map) {
      return Map<String, dynamic>.from(response.data as Map);
    }
    return {};
  }

  Future<Map<String, dynamic>> saveDriverSign({
    required String vcrNumber,
    required String driverSign,
  }) async {
    try {
      final response = await _apiClient.post<dynamic>(
        '/vcr/saveDriverSign',
        data: {
          'vcrNumber': vcrNumber,
          'driverSign': driverSign,
        },
      );
      if (response.data is Map) {
        return Map<String, dynamic>.from(response.data as Map);
      }
    } catch (e) {
      debugPrint('Warning: saveDriverSign API error: $e');
    }
    return {};
  }

  Future<List<Map<String, dynamic>>> fetchVcrHistory(String registrationNumber) async {
    final cleanReg = registrationNumber.replaceAll(RegExp(r'\s+'), '').trim();
    if (cleanReg.isEmpty) return [];

    List<Map<String, dynamic>> parseList(dynamic raw) {
      if (raw is List) {
        return raw.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
      } else if (raw is Map) {
        for (final key in ['data', 'content', 'result', 'vcrList', 'vcrs', 'vcrHistory', 'items', 'list', 'history']) {
          if (raw[key] is List) {
            return (raw[key] as List).whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
          }
        }
      }
      return [];
    }

    final endpoints = [
      '/vcr/history/$cleanReg',
      '/vcr/getVcrByVehicle/$cleanReg',
      '/vcr/getVcrListByVehicleNo/$cleanReg',
      '/vcr/byVehicle/$cleanReg',
      '/vcr/getVcrDetails/$cleanReg',
    ];

    for (final ep in endpoints) {
      try {
        final response = await _apiClient.get<dynamic>(ep);
        final list = parseList(response.data);
        if (list.isNotEmpty) {
          return list;
        }
      } catch (e) {
        debugPrint('Error fetching VCR history from $ep: $e');
      }
    }
    return [];
  }

  Future<dynamic> generatePdf(String vcrNumber) async {
    try {
      final response = await _apiClient.post<dynamic>(
        '/generatepdf',
        data: {'vcrNumber': vcrNumber},
      );
      return response.data;
    } catch (e) {
      debugPrint('Error generating PDF for $vcrNumber: $e');
      rethrow;
    }
  }
}
