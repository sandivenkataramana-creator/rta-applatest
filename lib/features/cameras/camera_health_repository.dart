import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../../core/network/api_client.dart';
import 'camera_health_model.dart';
import 'default_camera_locations.dart';

abstract class CameraHealthRepository {
  Future<CameraHealthModel> getCameraHealth();
  Future<CameraHealthModel> scanNow();
  Future<CameraHealthModel> saveSettings(int checkInterval);
  Future<List<CameraLocationItem>> getAllCameraLocations();
}

class CameraHealthRepositoryImpl implements CameraHealthRepository {
  CameraHealthRepositoryImpl({required ApiClient apiClient})
    : _apiClient = apiClient;

  final ApiClient _apiClient;

  @override
  Future<CameraHealthModel> getCameraHealth() async {
    final path = '/camera-health';
    final url = _apiClient.buildUrl(path);
    debugPrint('Camera Health GET -> $url');
    final response = await _apiClient.get<Map<String, dynamic>>(path);

    if (response.data == null) {
      throw ApiException(
        code: 500,
        message: 'Camera health response was empty.',
      );
    }

    return CameraHealthModel.fromJson(
      Map<String, dynamic>.from(response.data!),
    );
  }

  @override
  Future<CameraHealthModel> scanNow() async {
    try {
      final path = '/camera-health/scan-now';
      final url = _apiClient.buildUrl(path);
      debugPrint('Camera Health POST scan-now -> $url');
      final response = await _apiClient.post<Map<String, dynamic>>(
        path,
        data: const <String, dynamic>{},
      );

      if (response.data == null) {
        throw ApiException(
          code: 500,
          message: 'Camera scan response was empty.',
        );
      }

      return CameraHealthModel.fromJson(
        Map<String, dynamic>.from(response.data!),
      );
    } on ApiException catch (e) {
      throw ApiException(
        code: e.code,
        message: _mapScanError(e.code, e.message),
      );
    }
  }

  @override
  Future<CameraHealthModel> saveSettings(int checkInterval) async {
    try {
      final path = '/camera-health/settings';
      final url = _apiClient.buildUrl(path);
      debugPrint('Camera Health POST settings -> $url');
      final response = await _apiClient.post<Map<String, dynamic>>(
        path,
        data: {'checkInterval': checkInterval},
        options: Options(
          contentType: 'application/json',
          headers: {'Accept': 'application/json'},
        ),
      );

      if (response.data == null) {
        throw ApiException(
          code: 500,
          message: 'Camera health settings response was empty.',
        );
      }

      return CameraHealthModel.fromJson(
        Map<String, dynamic>.from(response.data!),
      );
    } on ApiException catch (e) {
      throw ApiException(
        code: e.code,
        message: _mapScanError(e.code, e.message),
      );
    }
  }

  @override
  Future<List<CameraLocationItem>> getAllCameraLocations() async {
    const path = '/camera/all';
    final url = _apiClient.buildUrl(path);
    debugPrint('Camera All GET -> $url');
    try {
      final response = await _apiClient.get<dynamic>(path);
      dynamic rawData = response.data;
      if (rawData is String) {
        try {
          rawData = jsonDecode(rawData);
        } catch (_) {}
      }
      if (rawData is List && rawData.isNotEmpty) {
        return rawData
            .whereType<Map>()
            .map((item) => CameraLocationItem.fromJson(Map<String, dynamic>.from(item)))
            .toList();
      }
    } catch (e) {
      debugPrint('Failed to fetch from $url, falling back to default camera dataset: $e');
    }

    return kDefaultCameraLocations
        .map((item) => CameraLocationItem.fromJson(Map<String, dynamic>.from(item)))
        .toList();
  }

  String _mapScanError(int code, String? fallback) {
    if (code == 400) {
      return 'The scan request was invalid. Please try again.';
    }
    if (code == 401) {
      return 'Your session expired. Please sign in again.';
    }
    if (code == 403) {
      return 'You do not have permission to trigger a camera scan.';
    }
    if (code == 404) {
      return 'The camera scan endpoint could not be found.';
    }
    if (code == 500 || code == 502 || code == 503) {
      return 'The camera scan could not be completed. Please try again later.';
    }
    if (code == 504) {
      return 'The scan request timed out. Please try again.';
    }
    if (fallback != null && fallback.isNotEmpty) {
      return fallback;
    }
    return 'Unable to complete the camera scan. Please try again.';
  }
}
