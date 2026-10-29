import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/services/file_download_service.dart';
import '../auth/auth_provider.dart';
import 'challan_export_repository.dart';
import 'challan_export_request_model.dart';

class ChallanExportState {
  const ChallanExportState({
    this.isLoading = false,
    this.isDownloading = false,
    this.totalRecords = 0,
    this.hasCountResult = false,
    this.error,
    this.selectedChallanType = 'All Challan Data',
  });

  final bool isLoading;
  final bool isDownloading;
  final int totalRecords;
  final bool hasCountResult;
  final String? error;
  final String selectedChallanType;

  bool get canDownload => totalRecords > 0 && hasCountResult && !isLoading;

  ChallanExportState copyWith({
    bool? isLoading,
    bool? isDownloading,
    int? totalRecords,
    bool? hasCountResult,
    Object? error = _unset,
    String? selectedChallanType,
  }) {
    return ChallanExportState(
      isLoading: isLoading ?? this.isLoading,
      isDownloading: isDownloading ?? this.isDownloading,
      totalRecords: totalRecords ?? this.totalRecords,
      hasCountResult: hasCountResult ?? this.hasCountResult,
      error: identical(error, _unset) ? this.error : error as String?,
      selectedChallanType: selectedChallanType ?? this.selectedChallanType,
    );
  }
}

const _unset = Object();

class ChallanExportNotifier extends StateNotifier<ChallanExportState> {
  ChallanExportNotifier(this._repository) : super(const ChallanExportState());

  final ChallanExportRepository _repository;
  int _countRequestGeneration = 0;

  void setChallanType(String value) {
    _countRequestGeneration++;
    state = state.copyWith(
      isLoading: false,
      selectedChallanType: value,
      totalRecords: 0,
      hasCountResult: false,
      error: null,
    );
  }

  void invalidateCount() {
    _countRequestGeneration++;
    state = state.copyWith(
      isLoading: false,
      totalRecords: 0,
      hasCountResult: false,
      error: null,
    );
  }

  Future<bool> applyFilters(ChallanCountRequestModel request) async {
    final generation = ++_countRequestGeneration;
    final validationError = request.validationError;
    if (validationError != null) {
      state = state.copyWith(
        isLoading: false,
        totalRecords: 0,
        hasCountResult: false,
        error: validationError,
      );
      return false;
    }

    state = state.copyWith(
      isLoading: true,
      totalRecords: 0,
      hasCountResult: false,
      error: null,
    );
    try {
      final count = await _repository.fetchMatchingRecordCount(request);
      if (generation != _countRequestGeneration) return false;
      state = state.copyWith(
        isLoading: false,
        totalRecords: count,
        hasCountResult: true,
        error: null,
      );
      return true;
    } catch (error) {
      if (generation != _countRequestGeneration) return false;
      state = state.copyWith(
        isLoading: false,
        totalRecords: 0,
        hasCountResult: false,
        error: error.toString(),
      );
      return false;
    }
  }

  Future<bool> downloadExcel(ChallanExportRequestModel request) async {
    if (!state.canDownload) return false;
    final validationError = request.validationError;
    if (validationError != null) {
      state = state.copyWith(error: validationError);
      return false;
    }

    state = state.copyWith(isDownloading: true, error: null);
    try {
      final bytes = await _repository.downloadExcel(request);
      await FileDownloadService.saveBytes(
        bytes,
        'challan_export.xlsx',
        mimeType:
            'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
      );
      state = state.copyWith(isDownloading: false, error: null);
      return true;
    } catch (error) {
      state = state.copyWith(isDownloading: false, error: error.toString());
      return false;
    }
  }
}

final challanExportRepositoryProvider = Provider<ChallanExportRepository>((
  ref,
) {
  return ChallanExportRepository(apiClient: ref.read(apiClientProvider));
});

final challanExportProvider =
    StateNotifierProvider<ChallanExportNotifier, ChallanExportState>((ref) {
      return ChallanExportNotifier(ref.read(challanExportRepositoryProvider));
    });
