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
    this.vehicleDetail,
    this.expiryDetails = const [],
    this.challanDetails,
  });

  final List<dynamic> searchResults;
  final List<dynamic> offenceConfigs;
  final bool isLoading;
  final bool isSearched;
  final String searchText;
  final String? error;
  final Map<String, dynamic>? vehicleDetail;
  final List<dynamic> expiryDetails;
  final Map<String, dynamic>? challanDetails;

  VehicleHistoryState copyWith({
    List<dynamic>? searchResults,
    List<dynamic>? offenceConfigs,
    bool? isLoading,
    bool? isSearched,
    String? searchText,
    String? error,
    Map<String, dynamic>? vehicleDetail,
    List<dynamic>? expiryDetails,
    Map<String, dynamic>? challanDetails,
  }) {
    return VehicleHistoryState(
      searchResults: searchResults ?? this.searchResults,
      offenceConfigs: offenceConfigs ?? this.offenceConfigs,
      isLoading: isLoading ?? this.isLoading,
      isSearched: isSearched ?? this.isSearched,
      searchText: searchText ?? this.searchText,
      error: error,
      vehicleDetail: vehicleDetail ?? this.vehicleDetail,
      expiryDetails: expiryDetails ?? this.expiryDetails,
      challanDetails: challanDetails ?? this.challanDetails,
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
    final query = vehicleNumber.trim();
    
    state = state.copyWith(
      isLoading: true,
      isSearched: true,
      searchText: query,
      vehicleDetail: null,
      expiryDetails: const [],
      challanDetails: null,
    );

    try {
      // 1. Search by vehicle number
      final searchRes = await classificationRepo.searchByVehicleNumber(query);
      final vehicleMap = searchRes?['vehicle'] as Map<String, dynamic>?;
      
      int? vehicleId = vehicleMap?['id'] as int?;
      
      // 2. Fetch expiry details if we have vehicle ID
      List<dynamic> expiry = const [];
      if (vehicleId != null) {
        try {
          expiry = await classificationRepo.getVehicleExpiryDate(vehicleId);
        } catch (e) {
          debugPrint('Error fetching expiry details: $e');
        }
      }

      // 3. Fetch active challans
      Map<String, dynamic>? challansMap;
      try {
        challansMap = await classificationRepo.getVehicleChallansByNumber(query);
      } catch (e) {
        debugPrint('Error fetching challan details: $e');
      }

      // 4. Fetch search notifications (detections history)
      List<dynamic> searchNotifications = const [];
      try {
        searchNotifications = await classificationRepo.searchNotificationsByVehicleNumber(query);
      } catch (e) {
        debugPrint('Error fetching notifications list: $e');
      }

      state = state.copyWith(
        vehicleDetail: vehicleMap,
        expiryDetails: expiry,
        challanDetails: challansMap,
        searchResults: searchNotifications,
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
      vehicleDetail: null,
      expiryDetails: const [],
      challanDetails: null,
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
