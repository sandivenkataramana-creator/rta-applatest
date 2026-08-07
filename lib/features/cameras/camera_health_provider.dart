import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/api_client.dart';
import '../auth/auth_provider.dart';
import 'camera_health_model.dart';
import 'camera_health_repository.dart';

final cameraHealthRepositoryProvider = Provider<CameraHealthRepository>((ref) {
  final apiClient = ref.read(apiClientProvider);
  return CameraHealthRepositoryImpl(apiClient: apiClient);
});

class CameraHealthState {
  const CameraHealthState({
    this.data,
    this.isLoading = false,
    this.isRefreshing = false,
    this.isScanning = false,
    this.isSaving = false,
    this.error,
    this.searchQuery = '',
  });

  final CameraHealthModel? data;
  final bool isLoading;
  final bool isRefreshing;
  final bool isScanning;
  final bool isSaving;
  final String? error;
  final String searchQuery;

  CameraHealthState copyWith({
    CameraHealthModel? data,
    bool? isLoading,
    bool? isRefreshing,
    bool? isScanning,
    bool? isSaving,
    String? error,
    String? searchQuery,
  }) {
    return CameraHealthState(
      data: data ?? this.data,
      isLoading: isLoading ?? this.isLoading,
      isRefreshing: isRefreshing ?? this.isRefreshing,
      isScanning: isScanning ?? this.isScanning,
      isSaving: isSaving ?? this.isSaving,
      error: error,
      searchQuery: searchQuery ?? this.searchQuery,
    );
  }
}

class CameraHealthNotifier extends StateNotifier<CameraHealthState> {
  CameraHealthNotifier(this._repository) : super(const CameraHealthState());

  final CameraHealthRepository _repository;

  Future<void> load({bool refresh = false}) async {
    if (state.isLoading && !refresh) return;

    state = state.copyWith(
      isLoading: !refresh,
      isRefreshing: refresh,
      error: null,
    );

    try {
      final data = await _repository.getCameraHealth();
      state = state.copyWith(data: data, isLoading: false, isRefreshing: false);
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        isRefreshing: false,
        error: e is ApiException ? e.message : e.toString(),
      );
    }
  }

  Future<void> refresh() async {
    await load(refresh: true);
  }

  Future<bool> scanNow() async {
    if (state.isScanning) return false;

    state = state.copyWith(isScanning: true, error: null);

    try {
      final data = await _repository.scanNow();
      state = state.copyWith(
        data: data,
        isScanning: false,
        isLoading: false,
        isRefreshing: false,
      );
      return true;
    } catch (e) {
      state = state.copyWith(
        isScanning: false,
        error: e is ApiException ? e.message : e.toString(),
      );
      return false;
    }
  }

  Future<bool> saveSettings(int interval) async {
    if (state.isSaving) return false;

    state = state.copyWith(isSaving: true, error: null);

    try {
      final data = await _repository.saveSettings(interval);
      state = state.copyWith(
        data: data,
        isSaving: false,
        isLoading: false,
        isRefreshing: false,
      );
      return true;
    } catch (e) {
      state = state.copyWith(
        isSaving: false,
        error: e is ApiException ? e.message : e.toString(),
      );
      return false;
    }
  }

  void updateSearch(String query) {
    state = state.copyWith(searchQuery: query);
  }
}

final cameraHealthNotifierProvider =
    StateNotifierProvider<CameraHealthNotifier, CameraHealthState>((ref) {
      final repository = ref.watch(cameraHealthRepositoryProvider);
      return CameraHealthNotifier(repository);
    });

final cameraHealthFilteredLocationsProvider =
    Provider<List<CameraHealthLocation>>((ref) {
      final state = ref.watch(cameraHealthNotifierProvider);
      final searchQuery = state.searchQuery.trim().toLowerCase();

      if (state.data == null) {
        return const <CameraHealthLocation>[];
      }

      final allLocations = state.data!.inactiveLocations.toList();

      if (searchQuery.isEmpty) {
        return allLocations;
      }

      return allLocations.where((location) {
        final district = location.district.toLowerCase();
        final zone = location.zone.toLowerCase();
        final camera = location.camera.toLowerCase();

        return district.contains(searchQuery) ||
            zone.contains(searchQuery) ||
            camera.contains(searchQuery);
      }).toList();
    });
