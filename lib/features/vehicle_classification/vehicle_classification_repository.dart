import '../../core/network/api_client.dart';
import 'vehicle_classification_models.dart';

class VehicleClassificationRepository {
  VehicleClassificationRepository({required ApiClient apiClient})
    : _apiClient = apiClient;

  final ApiClient _apiClient;

  Future<List<VehicleCategory>> fetchVehicleCategories() async {
    final response = await _apiClient.get<List<dynamic>>(
      '/vehicle-classification',
    );
    return response.data!
        .map((item) => VehicleCategory.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<List<dynamic>> fetchActiveOffenceConfig() async {
    final response = await _apiClient.get<Map<String, dynamic>>(
      '/offence-config/active',
    );
    return response.data?['data'] ?? [];
  }

  Future<Map<String, dynamic>?> searchByVehicleNumber(String vehicleNumber) async {
    final response = await _apiClient.get<Map<String, dynamic>>(
      '/rta/searchByVehicleNumber/$vehicleNumber',
    );
    return response.data;
  }

  Future<List<dynamic>> getVehicleExpiryDate(int vehicleId) async {
    final response = await _apiClient.get<Map<String, dynamic>>(
      '/rta/getVehicleExpiryDate/$vehicleId',
    );
    return response.data?['data'] ?? [];
  }

  Future<Map<String, dynamic>?> getVehicleChallansByNumber(String vehicleNumber) async {
    final response = await _apiClient.get<Map<String, dynamic>>(
      '/rta/getVehicleChallansByNumber/$vehicleNumber',
    );
    return response.data;
  }

  Future<List<dynamic>> searchNotificationsByVehicleNumber(String vehicleNumber) async {
    final response = await _apiClient.get<List<dynamic>>(
      '/notifications/vehicle-search',
      queryParameters: {'vehicleNumber': vehicleNumber},
    );
    return response.data ?? [];
  }
}
