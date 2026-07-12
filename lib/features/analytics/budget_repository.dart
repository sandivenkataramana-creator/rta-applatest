import '../../core/network/api_client.dart';

class BudgetRepository {
  BudgetRepository({required ApiClient apiClient})
    : _apiClient = apiClient;

  final ApiClient _apiClient;

  Future<Map<String, dynamic>> fetchBudgetSummary(Map<String, dynamic> payload) async {
    final response = await _apiClient.post<Map<String, dynamic>>(
      '/budget/summary',
      data: payload,
    );
    return response.data ?? {};
  }

  Future<Map<String, dynamic>> fetchBudgetViolations(Map<String, dynamic> payload) async {
    final response = await _apiClient.post<Map<String, dynamic>>(
      '/budget/violations',
      data: payload,
    );
    return response.data ?? {};
  }

  Future<Map<String, dynamic>> fetchMonthlyRevenue(int year) async {
    final response = await _apiClient.get<Map<String, dynamic>>(
      '/budget/revenue/monthly/$year',
    );
    return response.data ?? {};
  }
}
