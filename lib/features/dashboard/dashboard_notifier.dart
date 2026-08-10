import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/api_client.dart';
import '../auth/auth_notifier.dart';
import 'dashboard_models.dart';
import 'dashboard_repository.dart';

final dashboardNotifierProvider =
    StateNotifierProvider.autoDispose<DashboardNotifier, DashboardState>((ref) {
      final authState = ref.watch(authNotifierProvider);
      final storage = ref.watch(authNotifierProvider.notifier).storage;
      final apiClient = ApiClient(storage);
      return DashboardNotifier(
        repository: DashboardRepository(apiClient: apiClient),
        isAuthenticated: authState.isAuthenticated,
      );
    });

class DashboardState {
  DashboardState({
    this.kpis,
    this.analyticsSeries = const [],
    this.districts = const ['Select All District'],
    this.zones = const ['Select All Zone'],
    this.cameras = const ['Select All Camera'],
    this.cameraLocationToId = const {},
    this.offenceData,
    this.offenceTypes = const [],
    this.isLoading = false,
    this.error,
    this.eChallan = '0',
    this.manualChallan = '0',
    this.seizedVehicles = '0',
    this.monthlyRevenue = const {},
  });

  final KpiSummary? kpis;
  final List<AnalyticsSeries> analyticsSeries;
  final List<String> districts;
  final List<String> zones;
  final List<String> cameras;
  final Map<String, String> cameraLocationToId;
  final Map<String, dynamic>? offenceData;
  final List<String> offenceTypes;
  final bool isLoading;
  final String? error;
  final String eChallan;
  final String manualChallan;
  final String seizedVehicles;
  final Map<String, double> monthlyRevenue;

  DashboardState copyWith({
    KpiSummary? kpis,
    List<AnalyticsSeries>? analyticsSeries,
    List<String>? districts,
    List<String>? zones,
    List<String>? cameras,
    Map<String, String>? cameraLocationToId,
    Map<String, dynamic>? offenceData,
    List<String>? offenceTypes,
    bool? isLoading,
    String? error,
    String? eChallan,
    String? manualChallan,
    String? seizedVehicles,
    Map<String, double>? monthlyRevenue,
  }) {
    return DashboardState(
      kpis: kpis ?? this.kpis,
      analyticsSeries: analyticsSeries ?? this.analyticsSeries,
      districts: districts ?? this.districts,
      zones: zones ?? this.zones,
      cameras: cameras ?? this.cameras,
      cameraLocationToId: cameraLocationToId ?? this.cameraLocationToId,
      offenceData: offenceData ?? this.offenceData,
      offenceTypes: offenceTypes ?? this.offenceTypes,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      eChallan: eChallan ?? this.eChallan,
      manualChallan: manualChallan ?? this.manualChallan,
      seizedVehicles: seizedVehicles ?? this.seizedVehicles,
      monthlyRevenue: monthlyRevenue ?? this.monthlyRevenue,
    );
  }
}

class DashboardNotifier extends StateNotifier<DashboardState> {
  DashboardNotifier({
    required this.repository,
    required bool isAuthenticated,
  }) : super(DashboardState()) {
    if (isAuthenticated) {
      fetchDashboard(timeRange: 'Today', isInitial: true);
    }
  }

  final DashboardRepository repository;

  Future<void> fetchDashboard({
    String? district,
    String? zone,
    String? camera,
    String? timeRange,
    DateTime? customStartDate,
    DateTime? customEndDate,
    bool isInitial = false,
  }) async {
    if (!isInitial) {
      state = state.copyWith(isLoading: true);
    }

    try {
      // 1. Immediate Fast Fetch: Districts, Offence Types, & Offence Counts (~200ms)
      final fastResults = await Future.wait([
        repository.fetchDistricts().catchError((_) => state.districts),
        repository.fetchOffenceTypes().catchError((_) => state.offenceTypes),
        repository.fetchOffenceCountData(
          district: district,
          zone: zone,
          camera: camera,
          timeRange: timeRange,
          customStartDate: customStartDate,
          customEndDate: customEndDate,
        ).catchError((_) => const <String, dynamic>{}),
      ]);

      if (!mounted) return;

      final dynamic distsRes = fastResults[0];
      final dynamic offTypesRes = fastResults[1];
      final dynamic offDataRes = fastResults[2];

      final districtsList = distsRes is List<String> ? distsRes : state.districts;
      final offenceTypesList = offTypesRes is List<String> ? offTypesRes : state.offenceTypes;
      final offenceDataMap = offDataRes is Map<String, dynamic> ? offDataRes : state.offenceData;

      // Update state immediately so UI opens instantly on mobile!
      state = state.copyWith(
        districts: districtsList,
        offenceTypes: offenceTypesList,
        offenceData: offenceDataMap,
        isLoading: false,
      );

      // 2. Stream secondary metrics in background (KPIs, Traffic, Challan Counts, Revenue)
      repository.fetchKpis(
        district: district,
        zone: zone,
        camera: camera,
        timeRange: timeRange,
      ).then((kpis) {
        if (mounted) {
          state = state.copyWith(kpis: kpis);
        }
      }).catchError((_) {});

      repository.fetchHourlyTraffic(
        district: district,
        zone: zone,
        camera: camera,
        timeRange: timeRange,
      ).then((analytics) {
        if (mounted) {
          state = state.copyWith(analyticsSeries: analytics);
        }
      }).catchError((_) {});

      repository.fetchChallanCounts(
        district: district,
        zone: zone,
        camera: camera,
        timeRange: timeRange,
        customStartDate: customStartDate,
        customEndDate: customEndDate,
      ).then((challans) {
        if (mounted) {
          state = state.copyWith(
            eChallan: challans['eChallan'],
            manualChallan: challans['manualChallan'],
            seizedVehicles: challans['seizedVehicles'],
          );
        }
      }).catchError((_) {});

      repository.fetchMonthlyRevenue(
        DateTime.now().year,
        district: district,
        zone: zone,
        camera: camera,
        timeRange: timeRange,
        customStartDate: customStartDate,
        customEndDate: customEndDate,
      ).then((revenue) {
        if (mounted) {
          state = state.copyWith(monthlyRevenue: revenue);
        }
      }).catchError((_) {});

    } catch (e) {
      debugPrint('Unhandled error in fetchDashboard: $e');
      if (!mounted) return;
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  /// Returns the auto-selected zone name if only one zone exists, else null.
  Future<String?> fetchZonesForDistrict(String district) async {
    debugPrint('Notifier fetchZonesForDistrict called for: $district');
    if (!mounted) return null;
    state = state.copyWith(isLoading: true);
    try {
      final zonesList = await repository.fetchZones(district);
      if (!mounted) return null;
      debugPrint('Notifier fetchZonesForDistrict success: $zonesList');
      state = state.copyWith(
        zones: zonesList,
        isLoading: false,
      );
      // Auto-select if only one real zone (besides 'Select All Zone')
      final realZones = zonesList.where((z) => z != 'Select All Zone').toList();
      if (realZones.length == 1) {
        return realZones.first;
      }
      return null;
    } catch (e, stack) {
      debugPrint('Notifier fetchZonesForDistrict error: $e');
      debugPrint(stack.toString());
      if (!mounted) return null;
      state = state.copyWith(
        zones: const ['Select All Zone'],
        isLoading: false,
        error: e.toString(),
      );
      return null;
    }
  }

  void resetZones() {
    state = state.copyWith(
      zones: const ['Select All Zone'],
    );
  }

  Future<void> fetchCamerasForZone(String zone) async {
    debugPrint('Notifier fetchCamerasForZone called for: $zone');
    if (!mounted) return;
    state = state.copyWith(isLoading: true);
    try {
      final cameraData = await repository.fetchCameras(zone);
      if (!mounted) return;
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
      debugPrint('Notifier fetchCamerasForZone success: $camerasList');
      state = state.copyWith(
        cameras: camerasList,
        cameraLocationToId: lookup,
        isLoading: false,
      );
    } catch (e, stack) {
      debugPrint('Notifier fetchCamerasForZone error: $e');
      debugPrint(stack.toString());
      if (!mounted) return;
      state = state.copyWith(
        cameras: const ['Select All Camera'],
        cameraLocationToId: const {},
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  void resetCameras() {
    state = state.copyWith(
      cameras: const ['Select All Camera'],
      cameraLocationToId: const {},
    );
  }
}
