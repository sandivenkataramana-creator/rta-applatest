import '../../core/network/api_client.dart';
import 'reports_models.dart';

class ReportsRepository {
  ReportsRepository({required ApiClient apiClient}) : _apiClient = apiClient;

  final ApiClient _apiClient;

  Future<List<ReportItem>> fetchReports() async {
    final response = await _apiClient.get<List<dynamic>>('/reports');

    final data = response.data;

    if (data == null) {
      return const [];
    }

    return data
        .map(
          (item) => ReportItem.fromJson(
            Map<String, dynamic>.from(item as Map),
          ),
        )
        .toList();
  }
}
