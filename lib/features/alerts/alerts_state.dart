import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/api_client.dart';
import '../../core/storage/secure_storage_service.dart';
import 'alerts_repository.dart';

class AlertsState {
  AlertsState({
    this.items = const [],
    this.isLoading = false,
    this.error,
    this.searchText = '',
    this.selectedDistrict = 'Select All District',
    this.selectedZone = 'Select All Zone',
    this.selectedCamera = 'Select All Camera',
    this.districts = const ['Select All District'],
    this.zones = const ['Select All Zone'],
    this.cameras = const ['Select All Camera'],
    this.cameraLocationToId = const {},
  });

  final List<dynamic> items;
  final bool isLoading;
  final String? error;
  final String searchText;

  final String selectedDistrict;
  final String selectedZone;
  final String selectedCamera;

  final List<String> districts;
  final List<String> zones;
  final List<String> cameras;
  final Map<String, String> cameraLocationToId;

  AlertsState copyWith({
    List<dynamic>? items,
    bool? isLoading,
    String? error,
    String? searchText,
    String? selectedDistrict,
    String? selectedZone,
    String? selectedCamera,
    List<String>? districts,
    List<String>? zones,
    List<String>? cameras,
    Map<String, String>? cameraLocationToId,
  }) {
    return AlertsState(
      items: items ?? this.items,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      searchText: searchText ?? this.searchText,
      selectedDistrict: selectedDistrict ?? this.selectedDistrict,
      selectedZone: selectedZone ?? this.selectedZone,
      selectedCamera: selectedCamera ?? this.selectedCamera,
      districts: districts ?? this.districts,
      zones: zones ?? this.zones,
      cameras: cameras ?? this.cameras,
      cameraLocationToId: cameraLocationToId ?? this.cameraLocationToId,
    );
  }
}

class AlertsNotifier extends StateNotifier<AlertsState> {
  AlertsNotifier({required this.repository}) : super(AlertsState()) {
    fetchDetailsNotFound();
    loadInitialFilters();
  }

  final AlertsRepository repository;

  Future<void> fetchDetailsNotFound() async {
    state = state.copyWith(isLoading: true);
    try {
      final results = await repository.fetchDetailsNotFound(limit: 100);
      state = state.copyWith(items: results, isLoading: false);
    } catch (e) {
      state = state.copyWith(error: e.toString(), isLoading: false);
    }
  }

  Future<void> loadInitialFilters() async {
    try {
      final distList = await repository.fetchDistricts();
      state = state.copyWith(districts: distList);
    } catch (e) {
      debugPrint('Error loading initial filters: $e');
    }
  }

  Future<void> fetchZonesForDistrict(String district) async {
    state = state.copyWith(isLoading: true);
    try {
      final zonesList = await repository.fetchZones(district);
      state = state.copyWith(
        zones: zonesList,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(
        zones: const ['Select All Zone'],
        isLoading: false,
      );
    }
  }

  Future<void> fetchCamerasForZone(String zone) async {
    state = state.copyWith(isLoading: true);
    try {
      final cameraData = await repository.fetchCameras(zone);
      final List<String> camerasList = ['Select All Camera'];
      final Map<String, String> lookup = {};
      for (final item in cameraData) {
        if (item is Map) {
          final id = item['cameraID']?.toString();
          final loc = item['cameraLocation']?.toString();
          if (id != null && loc != null) {
            camerasList.add(loc);
            lookup[loc] = id;
          }
        }
      }
      state = state.copyWith(
        cameras: camerasList,
        cameraLocationToId: lookup,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(
        cameras: const ['Select All Camera'],
        cameraLocationToId: const {},
        isLoading: false,
      );
    }
  }

  void resetZones() {
    state = state.copyWith(zones: const ['Select All Zone']);
  }

  void resetCameras() {
    state = state.copyWith(
      cameras: const ['Select All Camera'],
      cameraLocationToId: const {},
    );
  }

  void updateSelectedFilters({
    String? district,
    String? zone,
    String? camera,
  }) {
    state = state.copyWith(
      selectedDistrict: district,
      selectedZone: zone,
      selectedCamera: camera,
    );
  }

  void updateSearch(String value) {
    state = state.copyWith(searchText: value);
  }
}

final alertsNotifierProvider =
    StateNotifierProvider.autoDispose<AlertsNotifier, AlertsState>((ref) {
  final storage = SecureStorageService();
  final apiClient = ApiClient(storage);
  return AlertsNotifier(
    repository: AlertsRepository(apiClient: apiClient),
  );
});
