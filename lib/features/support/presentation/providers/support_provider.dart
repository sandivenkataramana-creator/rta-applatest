import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/api_client.dart';
import '../../../../core/storage/secure_storage_service.dart';
import '../../data/repositories/support_repository.dart';
import '../../data/models/support_ticket.dart';

final secureStorageProvider = Provider<SecureStorageService>(
  (ref) => SecureStorageService(),
);

final supportApiClientProvider = Provider<ApiClient>((ref) {
  final storage = ref.read(secureStorageProvider);
  return ApiClient(storage);
});

final supportRepositoryProvider = Provider<SupportRepository>((ref) {
  final apiClient = ref.read(supportApiClientProvider);
  return SupportRepositoryImpl(apiClient: apiClient);
});

class SupportState {
  const SupportState({
    this.tickets = const [],
    this.isLoading = false,
    this.isRefreshing = false,
    this.error,
    this.selectedUserId,
    this.selectedStatus = 'All',
    this.searchQuery = '',
    this.activeTab = 0,
    this.isSubmitting = false,
  });

  final List<SupportTicket> tickets;
  final bool isLoading;
  final bool isRefreshing;
  final String? error;
  final int? selectedUserId;
  final String selectedStatus;
  final String searchQuery;
  final int activeTab;
  final bool isSubmitting;

  SupportState copyWith({
    List<SupportTicket>? tickets,
    bool? isLoading,
    bool? isRefreshing,
    String? error,
    int? selectedUserId,
    String? selectedStatus,
    String? searchQuery,
    int? activeTab,
    bool? isSubmitting,
  }) {
    return SupportState(
      tickets: tickets ?? this.tickets,
      isLoading: isLoading ?? this.isLoading,
      isRefreshing: isRefreshing ?? this.isRefreshing,
      error: error,
      selectedUserId: selectedUserId ?? this.selectedUserId,
      selectedStatus: selectedStatus ?? this.selectedStatus,
      searchQuery: searchQuery ?? this.searchQuery,
      activeTab: activeTab ?? this.activeTab,
      isSubmitting: isSubmitting ?? this.isSubmitting,
    );
  }
}

class SupportController extends StateNotifier<SupportState> {
  SupportController(this._repository, this._storage)
    : super(const SupportState());

  final SupportRepository _repository;
  final SecureStorageService _storage;

  Future<void> loadTickets({bool refresh = false}) async {
    if (state.isLoading && !refresh) return;

    final userId = await _storage.readUsername();
    final parsedUserId = int.tryParse(userId ?? '');
    final resolvedUserId = parsedUserId ?? 4;

    state = state.copyWith(
      isLoading: !refresh,
      isRefreshing: refresh,
      error: null,
      selectedUserId: resolvedUserId,
    );

    try {
      final tickets = await _repository.fetchUserTickets(
        userId: resolvedUserId,
      );
      state = state.copyWith(
        tickets: tickets,
        isLoading: false,
        isRefreshing: false,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        isRefreshing: false,
        error: e is ApiException ? e.message : e.toString(),
      );
    }
  }

  Future<void> refreshTickets() async {
    await loadTickets(refresh: true);
  }

  Future<void> createTicket({
    required String subject,
    required String message,
    required List<String> attachments,
  }) async {
    state = state.copyWith(isSubmitting: true, error: null);
    try {
      await _repository.createTicket(
        subject: subject,
        message: message,
        attachments: attachments,
      );
      await loadTickets(refresh: true);
      state = state.copyWith(isSubmitting: false);
    } catch (e) {
      state = state.copyWith(
        isSubmitting: false,
        error: e is ApiException ? e.message : e.toString(),
      );
      rethrow;
    }
  }

  Future<void> deleteTicket({required int ticketId}) async {
    state = state.copyWith(error: null);
    try {
      await _repository.deleteTicket(ticketId: ticketId);
      await loadTickets(refresh: true);
    } catch (e) {
      state = state.copyWith(
        error: e is ApiException ? e.message : e.toString(),
      );
      rethrow;
    }
  }

  void updateFilters({String? status, String? searchQuery, int? activeTab}) {
    state = state.copyWith(
      selectedStatus: status ?? state.selectedStatus,
      searchQuery: searchQuery ?? state.searchQuery,
      activeTab: activeTab ?? state.activeTab,
    );
  }
}

final supportControllerProvider =
    StateNotifierProvider<SupportController, SupportState>((ref) {
      final repository = ref.watch(supportRepositoryProvider);
      final storage = ref.watch(secureStorageProvider);
      return SupportController(repository, storage);
    });

final supportTicketsProvider = Provider<List<SupportTicket>>((ref) {
  final state = ref.watch(supportControllerProvider);
  final search = state.searchQuery.trim().toLowerCase();
  final status = state.selectedStatus.toLowerCase();
  final activeTab = state.activeTab;

  final filtered = state.tickets.where((ticket) {
    final matchesStatus =
        status == 'all' ||
        (status == 'open' && ticket.isOpen) ||
        (status == 'closed' && ticket.isClosed);

    final matchesSearch =
        search.isEmpty ||
        ticket.subject.toLowerCase().contains(search) ||
        ticket.message.toLowerCase().contains(search) ||
        ticket.id?.toString().contains(search) == true;

    final matchesTab =
        activeTab == 0 ||
        (activeTab == 1 &&
            ticket.createdAt != null &&
            ticket.createdAt!.isAfter(
              DateTime.now().subtract(const Duration(days: 7)),
            )) ||
        (activeTab == 2 &&
            state.selectedUserId != null &&
            ticket.createdBy.toLowerCase().contains(
              state.selectedUserId.toString().toLowerCase(),
            ));

    return matchesStatus && matchesSearch && matchesTab;
  }).toList();

  filtered.sort((a, b) {
    final aTime = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
    final bTime = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
    return bTime.compareTo(aTime);
  });

  return filtered;
});
