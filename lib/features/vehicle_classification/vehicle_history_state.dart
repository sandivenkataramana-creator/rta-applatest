import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/api_client.dart';
import '../../core/storage/secure_storage_service.dart';
import '../vehicle_monitoring/vehicle_monitoring_repository.dart';
import 'vehicle_classification_repository.dart';

class VehicleHistoryState {
  VehicleHistoryState({
    this.searchResults = const [],
    this.offenceConfigs = const [],
    this.isLoading = false,
    this.isSearched = false,
    this.searchText = '',
    this.error,
  });

  final List<dynamic> searchResults;
  final List<dynamic> offenceConfigs;
  final bool isLoading;
  final bool isSearched;
  final String searchText;
  final String? error;

  VehicleHistoryState copyWith({
    List<dynamic>? searchResults,
    List<dynamic>? offenceConfigs,
    bool? isLoading,
    bool? isSearched,
    String? searchText,
    String? error,
  }) {
    return VehicleHistoryState(
      searchResults: searchResults ?? this.searchResults,
      offenceConfigs: offenceConfigs ?? this.offenceConfigs,
      isLoading: isLoading ?? this.isLoading,
      isSearched: isSearched ?? this.isSearched,
      searchText: searchText ?? this.searchText,
      error: error,
    );
  }
}

class VehicleHistoryNotifier extends StateNotifier<VehicleHistoryState> {
  VehicleHistoryNotifier({
    required this.classificationRepo,
    required this.monitoringRepo,
  }) : super(VehicleHistoryState()) {
    fetchOffenceConfigs();
  }

  final VehicleClassificationRepository classificationRepo;
  final VehicleMonitoringRepository monitoringRepo;

  Future<void> fetchOffenceConfigs() async {
    try {
      final configs = await classificationRepo.fetchActiveOffenceConfig();
      state = state.copyWith(offenceConfigs: configs);
    } catch (e) {
      debugPrint('Error fetching offence configs: $e');
    }
  }

  Future<void> searchVehicle(String vehicleNumber) async {
    if (vehicleNumber.trim().isEmpty) return;
    
    state = state.copyWith(
      isLoading: true,
      isSearched: true,
      searchText: vehicleNumber,
    );

    try {
      // Fetch notifications list and filter by vehicleNumber locally
      // We can fetch a reasonably large batch (e.g. limit: 200) to find the vehicle's history
      final notifications = await monitoringRepo.fetchNotifications(pageNumber: 1, limit: 200);
      
      final query = vehicleNumber.trim().toLowerCase();
      final filtered = notifications.where((item) {
        final vehicle = item['vehicle'] as Map<String, dynamic>? ?? {};
        final vNo = vehicle['vehicleNumber']?.toString().toLowerCase() ?? '';
        return vNo.contains(query);
      }).toList();

      state = state.copyWith(
        searchResults: filtered,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(
        error: e.toString(),
        isLoading: false,
      );
    }
  }

  void resetSearch() {
    state = state.copyWith(
      searchResults: const [],
      isSearched: false,
      searchText: '',
    );
  }
}

final vehicleHistoryNotifierProvider =
    StateNotifierProvider.autoDispose<VehicleHistoryNotifier, VehicleHistoryState>((ref) {
  final storage = SecureStorageService();
  final apiClient = ApiClient(storage);
  
  return VehicleHistoryNotifier(
    classificationRepo: VehicleClassificationRepository(apiClient: apiClient),
    monitoringRepo: VehicleMonitoringRepository(apiClient: apiClient),
  );
});
