import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../../../../core/network/api_client.dart';
import '../../../../core/storage/secure_storage_service.dart';
import '../models/support_ticket.dart';

abstract class SupportRepository {
  Future<List<SupportTicket>> fetchUserTickets({required int userId});
  Future<SupportTicket?> fetchTicketDetails({required int ticketId});
  Future<SupportTicket> createTicket({
    required String subject,
    required String message,
    List<String>? attachments,
  });
  Future<bool> deleteTicket({required int ticketId});
}

class SupportRepositoryImpl implements SupportRepository {
  SupportRepositoryImpl({required ApiClient apiClient})
    : _apiClient = apiClient;

  final ApiClient _apiClient;

  @override
  Future<List<SupportTicket>> fetchUserTickets({required int userId}) async {
    final response = await _apiClient.get<List<dynamic>>(
      '/complaints/user/$userId',
    );

    final data = response.data ?? const <dynamic>[];
    return data
        .whereType<Map>()
        .map((item) => SupportTicket.fromJson(Map<String, dynamic>.from(item)))
        .toList();
  }

  @override
  Future<SupportTicket?> fetchTicketDetails({required int ticketId}) async {
    final userIdString = await SecureStorageService().readUsername();
    final userId = int.tryParse(userIdString ?? '');
    debugPrint('Fetching ticket details for ID: $ticketId');
    debugPrint('Stored user identifier: $userIdString (parsed: $userId)');

    try {
      final response = await _apiClient.get<Map<String, dynamic>>(
        '/complaints/$ticketId',
      );
      if (response.data == null) return null;
      return SupportTicket.fromJson(Map<String, dynamic>.from(response.data!));
    } on ApiException catch (e) {
      if (e.code == 403 && userId != null) {
        debugPrint(
          'Primary complaint detail endpoint returned 403, retrying with user-scoped endpoint.',
        );
        final response = await _apiClient.get<Map<String, dynamic>>(
          '/complaints/user/$userId/$ticketId',
        );
        if (response.data == null) return null;
        return SupportTicket.fromJson(
          Map<String, dynamic>.from(response.data!),
        );
      }
      rethrow;
    }
  }

  @override
  Future<SupportTicket> createTicket({
    required String subject,
    required String message,
    List<String>? attachments,
  }) async {
    final rawUserId = await SecureStorageService().readUsername();
    final parsedUserId = int.tryParse(rawUserId ?? '');
    final fromUserId = parsedUserId ?? 4;

    final payload = SupportTicket(
      subject: subject,
      message: message,
      fromUserId: fromUserId,
      status: 'Open',
      attachmentData: null,
      attachmentName: null,
      attachmentType: null,
      date: DateTime.now().toUtc(),
    ).toJson();

    final response = await _apiClient.post<Map<String, dynamic>>(
      '/complaints',
      data: payload,
      options: Options(contentType: 'application/json'),
    );

    if (response.data == null) {
      throw ApiException(
        code: 500,
        message: 'Ticket creation did not return a valid response.',
      );
    }

    return SupportTicket.fromJson(Map<String, dynamic>.from(response.data!));
  }

  @override
  Future<bool> deleteTicket({required int ticketId}) async {
    final userIdString = await SecureStorageService().readUsername();
    final userId = int.tryParse(userIdString ?? '');
    debugPrint('Deleting ticket ID: $ticketId');
    debugPrint('Stored user identifier: $userIdString (parsed: $userId)');

    try {
      final response = await _apiClient.post<dynamic>(
        '/complaints/$ticketId/delete',
        options: Options(headers: {'Accept': 'application/json'}),
      );
      debugPrint('Delete response: ${response.statusCode} ${response.data}');
      return response.statusCode == 200 || response.statusCode == 204;
    } on ApiException catch (e) {
      if (e.code == 403 && userId != null) {
        debugPrint(
          'Primary delete endpoint returned 403, retrying with user-scoped endpoint.',
        );
        final response = await _apiClient.post<dynamic>(
          '/complaints/user/$userId/$ticketId/delete',
          options: Options(headers: {'Accept': 'application/json'}),
        );
        debugPrint(
          'Fallback delete response: ${response.statusCode} ${response.data}',
        );
        return response.statusCode == 200 || response.statusCode == 204;
      }
      rethrow;
    }
  }
}
