import '../../core/network/api_client.dart';
import 'cameras_models.dart';

class CamerasRepository {
  CamerasRepository({required ApiClient apiClient}) : _apiClient = apiClient;

  final ApiClient _apiClient;

  Future<List<CameraStatus>> fetchCameras() async {
    try {
      final response = await _apiClient.get<List<dynamic>>('/dashboard/filters/cameras');
      if (response.data is List) {
        return response.data!
            .map((item) => CameraStatus.fromJson(item as Map<String, dynamic>))
            .toList();
      }
    } catch (_) {
      try {
        final response = await _apiClient.get<List<dynamic>>('/cameras');
        if (response.data is List) {
          return response.data!
              .map((item) => CameraStatus.fromJson(item as Map<String, dynamic>))
              .toList();
        }
      } catch (_) {}
    }
    return [];
  }
}
