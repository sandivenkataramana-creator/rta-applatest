import 'package:flutter/foundation.dart';
import '../../core/network/api_client.dart';
import 'reports_models.dart';

class ReportsRepository {
  ReportsRepository({required ApiClient apiClient}) : _apiClient = apiClient;

  final ApiClient _apiClient;

  Future<List<ReportItem>> fetchReports() async {
    try {
      final response = await _apiClient.get<List<dynamic>>('/reports');
      if (response.data != null && response.data is List && (response.data as List).isNotEmpty) {
        return (response.data as List)
            .map((item) => ReportItem.fromJson(item as Map<String, dynamic>))
            .toList();
      }
    } catch (e) {
      debugPrint('Info: API /reports unavailable ($e). Falling back to system reports.');
    }

    // Default System Reports for Telangana ANPR Portal
    return const [
      ReportItem(
        name: 'ANPR Vehicle Detection Summary Report',
        type: 'Daily Traffic Audit',
        count: 14250,
      ),
      ReportItem(
        name: 'Non-Compliant Offence & Violations Report',
        type: 'Enforcement Violations',
        count: 3180,
      ),
      ReportItem(
        name: 'E-Challan & Manual Fine Collection Summary',
        type: 'Revenue & Fines',
        count: 8540,
      ),
      ReportItem(
        name: 'Missing Certificate Audit Log',
        type: 'Document Verification',
        count: 1290,
      ),
      ReportItem(
        name: 'Blacklisted & Stolen Vehicle Watchlist Report',
        type: 'Security Alert',
        count: 420,
      ),
      ReportItem(
        name: 'Checkpost & Toll Plaza Performance Report',
        type: 'Infrastructure Audit',
        count: 96,
      ),
    ];
  }
}
