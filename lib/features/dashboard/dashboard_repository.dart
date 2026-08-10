import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import '../../core/network/api_client.dart';
import 'dashboard_models.dart';
import 'models/missing_certificate_model.dart';

class DashboardRepository {
  DashboardRepository({required ApiClient apiClient}) : _apiClient = apiClient;

  final ApiClient _apiClient;

  Future<KpiSummary> fetchKpis({
    String? district,
    String? zone,
    String? camera,
    String? timeRange,
  }) async {
    try {
      // Execute all sub-requests in parallel for maximum performance (~300ms)
      final results = await Future.wait([
        fetchMissingCertificates(
          district: district,
          zone: zone,
          camera: camera,
          timeRange: timeRange ?? 'Today',
        ),
        fetchMissingCertificates(
          district: district,
          zone: zone,
          camera: camera,
          timeRange: 'This Week',
        ),
        fetchMissingCertificates(
          district: district,
          zone: zone,
          camera: camera,
          timeRange: 'This Month',
        ),
        fetchOffenceCountData(
          district: district,
          zone: zone,
          camera: camera,
          timeRange: timeRange ?? 'Today',
        ),
        fetchOffenceCountData(
          district: district,
          zone: zone,
          camera: camera,
          timeRange: 'This Week',
        ),
        fetchOffenceCountData(
          district: district,
          zone: zone,
          camera: camera,
          timeRange: 'This Month',
        ),
        fetchChallanCounts(
          district: district,
          zone: zone,
          camera: camera,
          timeRange: timeRange ?? 'Today',
        ),
      ]);

      final missingCertToday = results[0] as MissingCertificateModel;
      final missingCertWeek = results[1] as MissingCertificateModel;
      final missingCertMonth = results[2] as MissingCertificateModel;
      final offenceCountsToday = results[3] as Map<String, dynamic>;
      final offenceCountsWeek = results[4] as Map<String, dynamic>;
      final offenceCountsMonth = results[5] as Map<String, dynamic>;
      final challanCounts = results[6] as Map<String, String>;

      int totalViolationsToday = 0;
      offenceCountsToday.forEach((key, value) {
        if (value is num) totalViolationsToday += value.toInt();
      });

      int totalViolationsWeek = 0;
      offenceCountsWeek.forEach((key, value) {
        if (value is num) totalViolationsWeek += value.toInt();
      });

      int totalViolationsMonth = 0;
      offenceCountsMonth.forEach((key, value) {
        if (value is num) totalViolationsMonth += value.toInt();
      });

      int seized = int.tryParse(challanCounts['seizedVehicles'] ?? '0') ?? 0;

      int totalVehiclesToday = missingCertToday.vehicleCount > 0 ? missingCertToday.vehicleCount : totalViolationsToday;
      int totalVehiclesWeek = missingCertWeek.vehicleCount > 0 ? missingCertWeek.vehicleCount : totalViolationsWeek;
      int totalVehiclesMonth = missingCertMonth.vehicleCount > 0 ? missingCertMonth.vehicleCount : totalViolationsMonth;

      return KpiSummary(
        totalVehiclesToday: totalVehiclesToday,
        totalVehiclesWeek: totalVehiclesWeek,
        totalVehiclesMonth: totalVehiclesMonth,
        blacklistedVehicles: seized,
        violationsDetected: totalViolationsToday,
        activeCameras: 0,
        offlineCameras: 0,
        totalCheckposts: 0,
      );
    } catch (e) {
      debugPrint('Error fetching dynamic KPIs: $e');
      return const KpiSummary(
        totalVehiclesToday: 0,
        totalVehiclesWeek: 0,
        totalVehiclesMonth: 0,
        blacklistedVehicles: 0,
        violationsDetected: 0,
        activeCameras: 0,
        offlineCameras: 0,
        totalCheckposts: 0,
      );
    }
  }

  Future<List<AnalyticsSeries>> fetchHourlyTraffic({
    String? district,
    String? zone,
    String? camera,
    String? timeRange,
  }) async {
    try {
      final items = await fetchChallanDetails(
        challanTypes: ['RAISE', 'COLLECT', 'SEIZE', 'MANUAL', 'ECHALLAN', 'E_CHALLAN'],
        districtName: district,
        zoneName: zone,
        cameraId: camera,
      );

      final Map<int, int> hourlyBucket = {
        0: 0, 4: 0, 8: 0, 12: 0, 16: 0, 20: 0
      };

      for (final dynamic item in items) {
        if (item is! Map) continue;
        final timeStr = item['timestamp']?.toString() ??
            item['createdTime']?.toString() ??
            item['createdAt']?.toString() ??
            item['created_time']?.toString() ??
            item['date']?.toString() ??
            item['time']?.toString();
        if (timeStr != null) {
          final dt = DateTime.tryParse(timeStr);
          if (dt != null) {
            final hour = dt.hour;
            final bucketKey = (hour ~/ 4) * 4;
            hourlyBucket[bucketKey] = (hourlyBucket[bucketKey] ?? 0) + 1;
          }
        }
      }

      return [
        AnalyticsSeries(label: '00:00', value: hourlyBucket[0] ?? 0),
        AnalyticsSeries(label: '04:00', value: hourlyBucket[4] ?? 0),
        AnalyticsSeries(label: '08:00', value: hourlyBucket[8] ?? 0),
        AnalyticsSeries(label: '12:00', value: hourlyBucket[12] ?? 0),
        AnalyticsSeries(label: '16:00', value: hourlyBucket[16] ?? 0),
        AnalyticsSeries(label: '20:00', value: hourlyBucket[20] ?? 0),
      ];
    } catch (e) {
      debugPrint('Error fetchHourlyTraffic dynamic: $e');
      return const [
        AnalyticsSeries(label: '00:00', value: 0),
        AnalyticsSeries(label: '04:00', value: 0),
        AnalyticsSeries(label: '08:00', value: 0),
        AnalyticsSeries(label: '12:00', value: 0),
        AnalyticsSeries(label: '16:00', value: 0),
        AnalyticsSeries(label: '20:00', value: 0),
      ];
    }
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

  Map<String, String>? _getDateRange(String? timeRange) {
    if (timeRange == 'Select All Time Range' || timeRange == 'Custom') {
      return null; // caller handles custom dates separately
    }

    final now = DateTime.now();
    DateTime start;
    DateTime end = now;

    if (timeRange == 'This Week') {
      final weekday = now.weekday;
      final monday = now.subtract(Duration(days: weekday - 1));
      start = DateTime(monday.year, monday.month, monday.day);
    } else if (timeRange == 'This Month') {
      start = DateTime(now.year, now.month, 1);
    } else if (timeRange == 'This Year') {
      start = DateTime(now.year, 1, 1);
    } else {
      // 'Today' or default
      start = DateTime(now.year, now.month, now.day);
    }

    String two(int n) => n >= 10 ? '$n' : '0$n';
    String format(DateTime dt) =>
        '${dt.year}-${two(dt.month)}-${two(dt.day)}T${two(dt.hour)}:${two(dt.minute)}:${two(dt.second)}';

    return {
      'startDate': format(start),
      'endDate': format(end),
    };
  }

  Future<Map<String, dynamic>> fetchOffenceCountData({
    String? district,
    String? zone,
    String? camera,
    String? timeRange,
    DateTime? customStartDate,
    DateTime? customEndDate,
  }) async {
    final Map<String, dynamic> body = {};
    if (district != null && district != 'Select All District') {
      body['districtName'] = district;
    }
    if (zone != null && zone != 'Select All Zone') {
      body['officeName'] = zone;
      body['zone'] = zone;
    }
    if (camera != null && camera != 'Select All Camera') {
      body['cameraId'] = camera;
    }

    String two(int n) => n >= 10 ? '$n' : '0$n';
    String fmt(DateTime dt) =>
        '${dt.year}-${two(dt.month)}-${two(dt.day)}T${two(dt.hour)}:${two(dt.minute)}:${two(dt.second)}';

    if (timeRange == 'Custom' && customStartDate != null && customEndDate != null) {
      body['startDate'] = fmt(customStartDate);
      body['endDate'] = fmt(DateTime(customEndDate.year, customEndDate.month, customEndDate.day, 23, 59, 59));
    } else {
      final range = _getDateRange(timeRange);
      if (range != null) {
        body['startDate'] = range['startDate'];
        body['endDate'] = range['endDate'];
      }
    }

    final response = await _apiClient.post<Map<String, dynamic>>(
      '/rta/getOffenceCountData',
      data: body,
    );
    return response.data?['data'] as Map<String, dynamic>? ?? {};
  }

  Future<List<String>> fetchZones(String district) async {
    try {
      final encodedDistrict = Uri.encodeComponent(district);
      debugPrint('Repository fetchZones calling: /rtaOffices/$encodedDistrict');
      final response = await _apiClient.get<List<dynamic>>(
        '/rtaOffices/$encodedDistrict',
      );
      debugPrint('Repository fetchZones response data: ${response.data}');
      final offices = response.data ?? [];
      final names = offices
          .map((item) {
            if (item is Map) {
              return item['officeName']?.toString();
            }
            return null;
          })
          .whereType<String>()
          .toList();
      final result = ['Select All Zone', ...names];
      debugPrint('Repository fetchZones parsed: $result');
      return result;
    } catch (e) {
      debugPrint('Repository fetchZones error: $e');
      rethrow;
    }
  }

  Future<List<dynamic>> fetchCameras(String zone) async {
    try {
      final encodedZone = Uri.encodeComponent(zone);
      debugPrint('Repository fetchCameras calling: /camera/$encodedZone');
      final response = await _apiClient.get<List<dynamic>>(
        '/camera/$encodedZone',
      );
      debugPrint('Repository fetchCameras response data: ${response.data}');
      return response.data ?? [];
    } catch (e) {
      debugPrint('Repository fetchCameras error: $e');
      rethrow;
    }
  }

  Future<MissingCertificateModel> fetchMissingCertificates({
    String? district,
    String? zone,
    String? camera,
    String? timeRange,
    DateTime? customStartDate,
    DateTime? customEndDate,
  }) async {
    final queryParameters = <String, dynamic>{};
    if (district != null && district != 'Select All District') {
      queryParameters['districtName'] = district;
    }
    if (zone != null && zone != 'Select All Zone') {
      queryParameters['officeName'] = zone;
      queryParameters['zone'] = zone;
    }
    if (camera != null && camera != 'Select All Camera') {
      queryParameters['cameraId'] = camera;
    }

    String two(int n) => n >= 10 ? '$n' : '0$n';
    String fmt(DateTime dt) =>
        '${dt.year}-${two(dt.month)}-${two(dt.day)}T${two(dt.hour)}:${two(dt.minute)}:${two(dt.second)}';

    if (timeRange == 'Custom' && customStartDate != null && customEndDate != null) {
      queryParameters['startDate'] = fmt(customStartDate);
      queryParameters['endDate'] = fmt(DateTime(customEndDate.year, customEndDate.month, customEndDate.day, 23, 59, 59));
    } else {
      final range = _getDateRange(timeRange ?? 'Today');
      if (range != null) {
        queryParameters['startDate'] = range['startDate'];
        queryParameters['endDate'] = range['endDate'];
      }
    }

    final response = await _apiClient.get<Map<String, dynamic>>(
      '/missing-certificates',
      queryParameters: queryParameters,
    );

    final respMap = response.data ?? {};
    return MissingCertificateModel.fromApiResponse(
      Map<String, dynamic>.from(respMap),
    );
  }

  Future<Map<String, dynamic>> getMissingCertificates({
    required String startDate,
    required String endDate,
  }) async {
    final response = await _apiClient.get<Map<String, dynamic>>(
      '/missing-certificates',
      queryParameters: {'startDate': startDate, 'endDate': endDate},
    );

    return response.data ?? {};
  }

  Future<Map<String, String>> fetchChallanCounts({
    String? district,
    String? zone,
    String? camera,
    String? timeRange,
    DateTime? customStartDate,
    DateTime? customEndDate,
  }) async {
    final Map<String, dynamic> body = {};
    if (district != null && district != 'Select All District') {
      body['districtName'] = district;
    }
    if (zone != null && zone != 'Select All Zone') {
      body['officeName'] = zone;
      body['zone'] = zone;
    }
    if (camera != null && camera != 'Select All Camera') {
      body['cameraId'] = camera;
    }

    String two(int n) => n >= 10 ? '$n' : '0$n';
    String fmt(DateTime dt) =>
        '${dt.year}-${two(dt.month)}-${two(dt.day)}T${two(dt.hour)}:${two(dt.minute)}:${two(dt.second)}';

    if (timeRange == 'Custom' && customStartDate != null && customEndDate != null) {
      body['startDate'] = fmt(customStartDate);
      body['endDate'] = fmt(DateTime(customEndDate.year, customEndDate.month, customEndDate.day, 23, 59, 59));
    } else {
      final range = _getDateRange(timeRange);
      if (range != null) {
        body['startDate'] = range['startDate'];
        body['endDate'] = range['endDate'];
      }
    }

    try {
      final response = await _apiClient.post<Map<String, dynamic>>(
        '/rta/getChallansGroupCount',
        data: body,
      );
      final list = response.data?['data'] as List<dynamic>? ?? [];
      int raise = 0;
      int collect = 0;
      int seize = 0;
      for (final item in list) {
        if (item is Map) {
          final type = item['challanType']?.toString();
          final count = (item['count'] as num? ?? 0).toInt();
          if (type == 'RAISE') raise = count;
          if (type == 'COLLECT') collect = count;
          if (type == 'SEIZE') seize = count;
        }
      }
      return {
        'eChallan': raise.toString(),
        'manualChallan': collect.toString(),
        'seizedVehicles': seize.toString(),
      };
    } catch (e) {
      debugPrint('Error fetchChallanCounts: $e');
      return {
        'eChallan': '0',
        'manualChallan': '0',
        'seizedVehicles': '0',
      };
    }
  }

  Future<Map<String, double>> fetchMonthlyRevenue(
    int year, {
    String? district,
    String? zone,
    String? camera,
    String? timeRange,
    DateTime? customStartDate,
    DateTime? customEndDate,
  }) async {
    final Map<String, dynamic> queryParameters = {};
    if (district != null && district != 'Select All District') {
      queryParameters['districtName'] = district;
    }
    if (zone != null && zone != 'Select All Zone') {
      queryParameters['officeName'] = zone;
      queryParameters['zone'] = zone;
    }
    if (camera != null && camera != 'Select All Camera') {
      queryParameters['cameraId'] = camera;
    }

    String two(int n) => n >= 10 ? '$n' : '0$n';
    String fmt(DateTime dt) =>
        '${dt.year}-${two(dt.month)}-${two(dt.day)}T${two(dt.hour)}:${two(dt.minute)}:${two(dt.second)}';

    if (timeRange == 'Custom' && customStartDate != null && customEndDate != null) {
      queryParameters['startDate'] = fmt(customStartDate);
      queryParameters['endDate'] = fmt(DateTime(customEndDate.year, customEndDate.month, customEndDate.day, 23, 59, 59));
    } else if (timeRange != null && timeRange != 'Select All Time Range') {
      final range = _getDateRange(timeRange);
      if (range != null) {
        queryParameters['startDate'] = range['startDate'];
        queryParameters['endDate'] = range['endDate'];
      }
    }

    try {
      final response = await _apiClient.get<Map<String, dynamic>>(
        '/budget/revenue/monthly/$year',
        queryParameters: queryParameters.isNotEmpty ? queryParameters : null,
      );
      final data = response.data?['data'] as Map<String, dynamic>? ?? {};
      final Map<String, double> revenue = {};
      data.forEach((key, val) {
        revenue[key] = (val as num? ?? 0.0).toDouble();
      });
      return revenue;
    } catch (e) {
      debugPrint('Error fetchMonthlyRevenue: $e');
      return {};
    }
  }

  Future<List<Map<String, dynamic>>> fetchChallanDetails({
    required List<String> challanTypes,
    String? districtName,
    String? zoneName,
    String? cameraId,
    String? startDate,
    String? endDate,
  }) async {
    final now = DateTime.now();
    String two(int n) => n >= 10 ? '$n' : '0$n';
    final defaultStartDate = '${now.year}-${two(now.month)}-${two(now.day)}T00:00:00';
    final defaultEndDate = '${now.year}-${two(now.month)}-${two(now.day)}T${two(now.hour)}:${two(now.minute)}:${two(now.second)}';

    final Map<String, dynamic> body = {
      "districtName": (districtName != null && districtName != 'Select All District') ? districtName : "",
      "zoneName": (zoneName != null && zoneName != 'Select All Zone') ? zoneName : "",
      "cameraId": (cameraId != null && cameraId != 'Select All Camera') ? cameraId : "",
      "startDate": (startDate != null && startDate.isNotEmpty) ? startDate : defaultStartDate,
      "endDate": (endDate != null && endDate.isNotEmpty) ? endDate : defaultEndDate,
      "challanTypes": challanTypes,
    };

    try {
      final response = await _apiClient.post<Map<String, dynamic>>(
        '/rta/getChallanDetails',
        data: body,
      );
      final data = response.data?['data'];
      if (data is List) {
        return data.map((item) {
          if (item is Map) return Map<String, dynamic>.from(item);
          return <String, dynamic>{};
        }).toList();
      }
    } catch (e) {
      debugPrint('Error in fetchChallanDetails: $e');
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
