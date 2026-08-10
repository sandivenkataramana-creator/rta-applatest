import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import '../../core/network/api_client.dart';
import 'vehicle_monitoring_models.dart';

class VehicleMonitoringRepository {
  VehicleMonitoringRepository({required ApiClient apiClient})
    : _apiClient = apiClient;

  final ApiClient _apiClient;

  Future<List<VehicleDetection>> fetchDetections() async {
    try {
      final violations = await fetchViolations();
      if (violations.isNotEmpty) {
        final List<VehicleDetection> list = [];
        for (final item in violations) {
          if (item is Map<String, dynamic>) {
            final vehicle = item['vehicle'] as Map<String, dynamic>? ?? {};
            final plate = (vehicle['vehicleNumber'] ?? vehicle['vehicleNo'] ?? vehicle['registrationNumber'] ?? item['vehicleNumber'] ?? item['vehicleNo'] ?? '').toString();
            final vType = (vehicle['vehicleType'] ?? vehicle['vehicleCategory'] ?? item['vehicleType'] ?? '').toString();
            final camera = (vehicle['cameraName'] ?? vehicle['cameraLocation'] ?? item['cameraName'] ?? '').toString();
            final checkpost = (vehicle['districtName'] ?? vehicle['zoneName'] ?? item['districtName'] ?? '').toString();
            final detectedAt = (vehicle['imageDetectionTime'] ?? item['createdTime'] ?? item['dateTime'] ?? item['timestamp'] ?? '').toString();
            final vImg = (vehicle['vehicleImage'] ?? vehicle['imageUrl'] ?? item['vehicleImage'] ?? '').toString();
            final pImg = (vehicle['plateImage'] ?? vehicle['licensePlateImage'] ?? item['plateImage'] ?? '').toString();

            list.add(VehicleDetection(
              plate: plate,
              vehicleType: vType,
              camera: camera,
              checkpost: checkpost,
              detectedAt: detectedAt,
              confidence: 0.95,
              direction: 'INBOUND',
              vehicleImage: vImg,
              plateImage: pImg,
            ));
          }
        }
        return list;
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
    List<dynamic>? parseResponse(dynamic raw) {
      if (raw is List) return raw;
      if (raw is Map) {
        for (final key in ['data', 'content', 'result', 'offences', 'items', 'list']) {
          if (raw[key] is List) return raw[key] as List;
        }
      }
      return null;
    }

    double extractAmount(Map map) {
      final rawAmt = map['challanAmount'] ?? map['amount'] ?? map['fineAmount'] ?? map['penalty'] ?? map['price'] ?? 0.0;
      if (rawAmt is num) return rawAmt.toDouble();
      return double.tryParse(rawAmt.toString()) ?? 0.0;
    }

    try {
      final response = await _apiClient.get<dynamic>('/offence-config/active');
      final list = parseResponse(response.data);
      if (list != null && list.isNotEmpty) {
        return list.map((item) {
          if (item is Map) {
            final map = Map<String, dynamic>.from(item);
            final name = (map['offence'] ?? map['offenceName'] ?? map['name'] ?? map['violationType'] ?? '').toString();
            final amt = extractAmount(map);
            return {
              ...map,
              'offence': name,
              'challanAmount': amt,
            };
          }
          return <String, dynamic>{'offence': item.toString(), 'challanAmount': 0.0};
        }).toList();
      }
    } catch (_) {}

    try {
      final response = await _apiClient.get<dynamic>('/rta/getOffencesList');
      final list = parseResponse(response.data);
      if (list != null && list.isNotEmpty) {
        return list.map((item) {
          if (item is Map) {
            final map = Map<String, dynamic>.from(item);
            final name = (map['offence'] ?? map['offenceName'] ?? map['name'] ?? map['violationType'] ?? '').toString();
            final amt = extractAmount(map);
            return {
              ...map,
              'offence': name,
              'challanAmount': amt,
            };
          }
          return <String, dynamic>{'offence': item.toString(), 'challanAmount': 0.0};
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
      final safeOptions = Options(
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        validateStatus: (status) => status != null && status < 500,
      );

      final response = await _apiClient.post<dynamic>(
        '/vcr/check-duplicate',
        data: {
          'registrationNumber': registrationNumber,
          'vehicleNo': registrationNumber,
          'offences': offences,
        },
        options: safeOptions,
      );
      debugPrint('checkDuplicateVcr response (${response.statusCode}): ${response.data}');
      if (response.data is Map) {
        final resMap = Map<String, dynamic>.from(response.data as Map);
        if (resMap.containsKey('isDuplicate') || resMap.containsKey('status') || resMap.containsKey('previousVcr')) {
          return resMap;
        }
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

  Future<List<Map<String, dynamic>>> getVcrByVehicle(String vehicleNumber) async {
    try {
      final cleanReg = vehicleNumber.replaceAll(RegExp(r'\s+'), '').trim().toUpperCase();
      if (cleanReg.isEmpty) return [];

      final response = await _apiClient.get<dynamic>(
        '/vcr/vehicle/$cleanReg',
        options: Options(validateStatus: (status) => true),
      );

      if (response.statusCode == 200 && response.data != null) {
        final raw = response.data;
        if (raw is List) {
          return raw.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
        } else if (raw is Map) {
          for (final key in ['data', 'content', 'result', 'list', 'vcrList', 'vcrs', 'items']) {
            if (raw[key] is List) {
              return (raw[key] as List).whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
            }
          }
        }
      }
    } catch (e) {
      debugPrint('Error in getVcrByVehicle: $e');
    }
    return [];
  }

  Future<List<Map<String, dynamic>>> fetchVcrHistory(String registrationNumber) async {
    final cleanReg = registrationNumber.replaceAll(RegExp(r'\s+'), '').trim().toUpperCase();
    if (cleanReg.isEmpty) return [];

    List<Map<String, dynamic>> parseList(dynamic raw) {
      List<Map<String, dynamic>> items = [];
      if (raw is List) {
        items = raw.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
      } else if (raw is Map) {
        for (final key in ['notifications', 'data', 'content', 'result', 'challanDetails', 'challans', 'vcrList', 'vcrs', 'vcrHistory', 'items', 'list', 'history']) {
          if (raw[key] is List) {
            items = (raw[key] as List).whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
            break;
          }
        }
        if (items.isEmpty) {
          for (final val in raw.values) {
            if (val is List) {
              items = val.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
              if (items.isNotEmpty) break;
            }
          }
        }
      }

      if (items.isEmpty) return [];

      // Filter by cleanReg if vehicleNumber is present
      return items.where((it) {
        final vObj = it['vehicle'];
        String vNo = '';
        if (vObj is Map) {
          vNo = (vObj['vehicleNumber'] ?? vObj['vehicleNo'] ?? vObj['registrationNumber'] ?? '').toString();
        }
        if (vNo.isEmpty) {
          vNo = (it['vehicleNumber'] ?? it['vehicleNo'] ?? it['registrationNumber'] ?? '').toString();
        }
        final cleanVNo = vNo.replaceAll(RegExp(r'\s+'), '').toUpperCase();
        if (cleanVNo.isNotEmpty && cleanVNo != cleanReg && !cleanVNo.contains(cleanReg) && !cleanReg.contains(cleanVNo)) return false;
        return true;
      }).toList();
    }

    final safeOptions = Options(validateStatus: (status) => true);

    // 0. Try GET /rta/getNotificationHistory/$cleanReg
    try {
      final response = await _apiClient.get<dynamic>(
        '/rta/getNotificationHistory/$cleanReg',
        options: safeOptions,
      );
      if (response.statusCode == 200) {
        final list = parseList(response.data);
        if (list.isNotEmpty) return list;
      }
    } catch (_) {}

    // 1. Try POST to /rta/getChallanDetails with vehicleNumber
    try {
      final response = await _apiClient.post<Map<String, dynamic>>(
        '/rta/getChallanDetails',
        data: {
          'vehicleNumber': cleanReg,
          'vehicleNo': cleanReg,
          'registrationNumber': cleanReg,
          'challanTypes': ['RAISE', 'COLLECT', 'SEIZE', 'MANUAL', 'ECHALLAN', 'E_CHALLAN'],
        },
        options: safeOptions,
      );
      if (response.statusCode == 200) {
        final list = parseList(response.data);
        if (list.isNotEmpty) return list;
      }
    } catch (_) {}

    // 2. Try POST to /vcr/history
    try {
      final response = await _apiClient.post<dynamic>(
        '/vcr/history',
        data: {'vehicleNumber': cleanReg},
        options: safeOptions,
      );
      if (response.statusCode == 200) {
        final list = parseList(response.data);
        if (list.isNotEmpty) return list;
      }
    } catch (_) {}

    // 3. Try GET endpoints silently
    final endpoints = [
      '/vcr/history/$cleanReg',
      '/vcr/getVcrByVehicle/$cleanReg',
      '/vcr/getVcrListByVehicleNo/$cleanReg',
      '/rta/getChallanDetails/$cleanReg',
      '/vcr/byVehicle/$cleanReg',
      '/vcr/getVcrDetails/$cleanReg',
    ];

    for (final ep in endpoints) {
      try {
        final response = await _apiClient.get<dynamic>(
          ep,
          options: safeOptions,
        );
        if (response.statusCode == 200) {
          final list = parseList(response.data);
          if (list.isNotEmpty) {
            return list;
          }
        }
      } catch (_) {}
    }
    return [];
  }

  Future<List<dynamic>> searchVehicle(String vehicleNumber) async {
    try {
      final cleanVNo = vehicleNumber.replaceAll(RegExp(r'\s+'), '').trim().toUpperCase();
      if (cleanVNo.isEmpty) return [];

      final response = await _apiClient.get<dynamic>(
        '/notifications/vehicle-search',
        queryParameters: {'vehicleNumber': cleanVNo},
      );

      final raw = response.data;
      if (raw is List) {
        return raw;
      } else if (raw is Map) {
        if (raw['data'] is List) return raw['data'] as List<dynamic>;
        if (raw['content'] is List) return raw['content'] as List<dynamic>;
        if (raw['results'] is List) return raw['results'] as List<dynamic>;
      }
    } catch (e) {
      debugPrint('Error searching vehicle: $e');
    }
    return [];
  }

  Future<dynamic> generatePdf(String vcrNumber) async {
    try {
      final response = await _apiClient.post<dynamic>(
        '/generatepdf',
        data: {'vcrNumber': vcrNumber},
        options: Options(responseType: ResponseType.bytes),
      );
      return response.data;
    } catch (e) {
      debugPrint('Bytes PDF request failed, retrying standard response: $e');
      try {
        final response = await _apiClient.post<dynamic>(
          '/generatepdf',
          data: {'vcrNumber': vcrNumber},
        );
        return response.data;
      } catch (err) {
        debugPrint('Error generating PDF for $vcrNumber: $err');
        rethrow;
      }
    }
  }
}
