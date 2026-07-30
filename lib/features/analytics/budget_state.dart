import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/api_client.dart';
import '../../core/storage/secure_storage_service.dart';
import 'budget_repository.dart';

class BudgetState {
  BudgetState({
    this.selectedDistrict = 'Select All District',
    this.selectedZone = 'Select All Zone',
    this.selectedCamera = 'Select All Camera',
    this.selectedTimeRange = 'Select All Time Range',
    this.customStartDate,
    this.customEndDate,
    this.summary = const {},
    this.violations = const {},
    this.monthlyRevenue = const {},
    this.isLoading = false,
    this.error,
  });

  final String selectedDistrict;
  final String selectedZone;
  final String selectedCamera;
  final String selectedTimeRange;
  final DateTime? customStartDate;
  final DateTime? customEndDate;
  final Map<String, dynamic> summary;
  final Map<String, dynamic> violations;
  final Map<String, double> monthlyRevenue;
  final bool isLoading;
  final String? error;

  BudgetState copyWith({
    String? selectedDistrict,
    String? selectedZone,
    String? selectedCamera,
    String? selectedTimeRange,
    DateTime? customStartDate,
    DateTime? customEndDate,
    Map<String, dynamic>? summary,
    Map<String, dynamic>? violations,
    Map<String, double>? monthlyRevenue,
    bool? isLoading,
    String? error,
  }) {
    return BudgetState(
      selectedDistrict: selectedDistrict ?? this.selectedDistrict,
      selectedZone: selectedZone ?? this.selectedZone,
      selectedCamera: selectedCamera ?? this.selectedCamera,
      selectedTimeRange: selectedTimeRange ?? this.selectedTimeRange,
      customStartDate: customStartDate ?? this.customStartDate,
      customEndDate: customEndDate ?? this.customEndDate,
      summary: summary ?? this.summary,
      violations: violations ?? this.violations,
      monthlyRevenue: monthlyRevenue ?? this.monthlyRevenue,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

class BudgetNotifier extends StateNotifier<BudgetState> {
  BudgetNotifier({required this.repository}) : super(BudgetState()) {
    applyFilters();
  }

  final BudgetRepository repository;

  Future<void> updateFilters({
    String? district,
    String? zone,
    String? camera,
    String? timeRange,
    DateTime? customStartDate,
    DateTime? customEndDate,
  }) async {
    state = state.copyWith(
      selectedDistrict: district ?? state.selectedDistrict,
      selectedZone: zone ?? state.selectedZone,
      selectedCamera: camera ?? state.selectedCamera,
      selectedTimeRange: timeRange ?? state.selectedTimeRange,
      customStartDate: customStartDate,
      customEndDate: customEndDate,
    );
  }

  Map<String, String>? _getDateRange(String? timeRange) {
    if (timeRange == null || timeRange == 'Select All Time Range' || timeRange == 'Custom') {
      return null;
    }
    final now = DateTime.now();
    DateTime start;
    DateTime end = now;

    if (timeRange == 'Yesterday') {
      final y = now.subtract(const Duration(days: 1));
      start = DateTime(y.year, y.month, y.day, 0, 0, 0);
      end = DateTime(y.year, y.month, y.day, 23, 59, 59);
    } else if (timeRange == 'Last 7 Days' || timeRange == 'This Week') {
      start = now.subtract(const Duration(days: 7));
    } else if (timeRange == 'Monthly' || timeRange == 'This Month') {
      start = DateTime(now.year, now.month, 1);
    } else if (timeRange == 'This Year') {
      start = DateTime(now.year, 1, 1);
    } else {
      // 'Today' or default
      start = DateTime(now.year, now.month, now.day, 0, 0, 0);
    }

    String two(int n) => n >= 10 ? '$n' : '0$n';
    String format(DateTime dt) =>
        '${dt.year}-${two(dt.month)}-${two(dt.day)} ${two(dt.hour)}:${two(dt.minute)}:${two(dt.second)}';

    return {
      'startDate': format(start),
      'endDate': format(end),
    };
  }

  Future<void> applyFilters() async {
    state = state.copyWith(isLoading: true);
    try {
      String two(int n) => n >= 10 ? '$n' : '0$n';
      String fmt(DateTime dt) =>
          '${dt.year}-${two(dt.month)}-${two(dt.day)} ${two(dt.hour)}:${two(dt.minute)}:${two(dt.second)}';

      String startDateStr = '';
      String endDateStr = '';

      if (state.selectedTimeRange == 'Custom' && state.customStartDate != null && state.customEndDate != null) {
        startDateStr = fmt(state.customStartDate!);
        endDateStr = fmt(DateTime(state.customEndDate!.year, state.customEndDate!.month, state.customEndDate!.day, 23, 59, 59));
      } else {
        final range = _getDateRange(state.selectedTimeRange);
        if (range != null) {
          startDateStr = range['startDate']!;
          endDateStr = range['endDate']!;
        } else {
          final now = DateTime.now();
          startDateStr = '${now.year}-${two(now.month)}-${two(now.day)} 00:00:00';
          endDateStr = fmt(now);
        }
      }

      final dist = (state.selectedDistrict.startsWith('Select') || state.selectedDistrict.isEmpty)
          ? ''
          : state.selectedDistrict;
      final zone = (state.selectedZone.startsWith('Select') || state.selectedZone.isEmpty)
          ? ''
          : state.selectedZone;
      final cam = (state.selectedCamera.startsWith('Select') || state.selectedCamera.isEmpty)
          ? ''
          : state.selectedCamera;

      final payload = {
        'cameraId': cam,
        'districtName': dist,
        'endDate': endDateStr,
        'startDate': startDateStr,
        'zoneName': zone,
        'officeName': zone,
      };

      // 1. Summary API
      Map<String, dynamic> summaryData = {};
      try {
        summaryData = await repository.fetchBudgetSummary(payload);
        final dataMap = summaryData['data'];
        if (dataMap is Map<String, dynamic>) {
          summaryData = dataMap;
        }
      } catch (_) {}

      // 2. Violations API
      Map<String, dynamic> violationsData = {};
      try {
        violationsData = await repository.fetchBudgetViolations(payload);
        final dataMap = violationsData['data'];
        if (dataMap is Map<String, dynamic>) {
          violationsData = dataMap;
        }
      } catch (_) {}

      // 3. Monthly Revenue Chart API
      Map<String, double> monthlyData = {};
      try {
        final queryMap = <String, dynamic>{};
        if (dist.isNotEmpty) queryMap['districtName'] = dist;
        if (zone.isNotEmpty) {
          queryMap['officeName'] = zone;
          queryMap['zone'] = zone;
        }
        if (cam.isNotEmpty) queryMap['cameraId'] = cam;
        if (startDateStr.isNotEmpty) queryMap['startDate'] = startDateStr;
        if (endDateStr.isNotEmpty) queryMap['endDate'] = endDateStr;

        final rawMonthly = await repository.fetchMonthlyRevenue(
          DateTime.now().year,
          queryParameters: queryMap.isNotEmpty ? queryMap : null,
        );
        final rawData = rawMonthly['data'] as Map<String, dynamic>? ?? {};
        rawData.forEach((key, value) {
          monthlyData[key] = (value as num? ?? 0.0).toDouble();
        });
      } catch (_) {}

      state = state.copyWith(
        summary: summaryData,
        violations: violationsData,
        monthlyRevenue: monthlyData,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(
        error: e.toString(),
        isLoading: false,
      );
    }
  }
}

final budgetNotifierProvider =
    StateNotifierProvider.autoDispose<BudgetNotifier, BudgetState>((ref) {
  final storage = SecureStorageService();
  final apiClient = ApiClient(storage);
  return BudgetNotifier(
    repository: BudgetRepository(apiClient: apiClient),
  );
});
