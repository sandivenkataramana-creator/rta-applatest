import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../../core/network/api_client.dart';
import 'challan_export_request_model.dart';

const _browserRequestFields = {
  'startDate',
  'endDate',
  'categoryTitle',
  'challanTypes',
};

class ChallanExportRepository {
  ChallanExportRepository({required ApiClient apiClient})
    : _apiClient = apiClient;

  final ApiClient _apiClient;

  Future<int> fetchMatchingRecordCount(ChallanCountRequestModel request) async {
    final validationError = request.validationError;
    if (validationError != null) {
      throw FormatException(validationError);
    }

    final payload = request.toJson();
    if (kDebugMode) {
      debugPrint(
        'POST /api/rta/getChallansGroupCount payload: ${jsonEncode(payload)}',
      );
    }

    final response = await _apiClient.post<Map<String, dynamic>>(
      '/rta/getChallansGroupCount',
      data: payload,
    );
    final responseData = response.data;
    if (responseData == null || responseData['data'] is! List) {
      throw const FormatException(
        'The challan count response did not contain a data list.',
      );
    }

    var total = 0;
    for (final item in responseData['data'] as List<dynamic>) {
      if (item is! Map) {
        throw const FormatException(
          'The challan count response contained an invalid record.',
        );
      }
      final rawCount = item['count'];
      final count = rawCount is num
          ? rawCount.toInt()
          : int.tryParse(rawCount?.toString() ?? '');
      if (count == null || count < 0) {
        throw const FormatException(
          'The challan count response contained an invalid count.',
        );
      }
      total += count;
    }

    if (kDebugMode) {
      debugPrint('Challan count API returned $total matching records.');
    }
    return total;
  }

  Future<Uint8List> downloadExcel(ChallanExportRequestModel request) async {
    final validationError = request.validationError;
    if (validationError != null) {
      throw FormatException(validationError);
    }

    final payload = request.toJson();
    if (kDebugMode) {
      final payloadFields = payload.keys.toSet();
      final missingFields = _browserRequestFields.difference(payloadFields);
      final unexpectedFields = payloadFields.difference(_browserRequestFields);
      debugPrint(
        'Browser request contract POST /vehicle-export/challan-excel: '
        '{"startDate":"<yyyy-MM-ddTHH:mm>",'
        '"endDate":"<yyyy-MM-ddTHH:mm>",'
        '"categoryTitle":"<selected category>",'
        '"challanTypes":["<selected challan types>"]}',
      );
      debugPrint(
        'Flutter request payload POST /vehicle-export/challan-excel: '
        '${jsonEncode(payload)}',
      );
      debugPrint(
        'Browser/Flutter payload field comparison: '
        'missing=$missingFields, unexpected=$unexpectedFields, '
        'field sets match=${missingFields.isEmpty && unexpectedFields.isEmpty}',
      );
    }

    final response = await _apiClient.post<List<int>>(
      '/vehicle-export/challan-excel',
      data: payload,
      options: Options(
        responseType: ResponseType.bytes,
        headers: const {
          Headers.contentTypeHeader: Headers.jsonContentType,
          'Accept':
              'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet, application/octet-stream',
        },
      ),
    );
    final data = response.data;
    if (data == null || data.isEmpty) {
      throw Exception('The challan export response was empty.');
    }
    if (kDebugMode) {
      debugPrint(
        'Challan Excel export received ${data.length} bytes '
        '(${response.headers.value(Headers.contentTypeHeader) ?? 'unknown content type'}).',
      );
    }
    return Uint8List.fromList(data);
  }
}
