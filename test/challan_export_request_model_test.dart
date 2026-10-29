import 'package:flutter_test/flutter_test.dart';
import 'package:rta_app/features/anpr/challan_export_request_model.dart';

void main() {
  group('ChallanExportRequestModel', () {
    test('serializes the challan Excel API payload', () {
      const request = ChallanExportRequestModel(
        startDate: '2026-10-01T14:45',
        endDate: '2026-10-08T14:45',
        categoryTitle: 'e-Challan',
        challanTypes: ['RAISE', 'ECHALLAN', 'E_CHALLAN'],
      );

      expect(request.toJson(), {
        'startDate': '2026-10-01T14:45',
        'endDate': '2026-10-08T14:45',
        'categoryTitle': 'e-Challan',
        'challanTypes': ['RAISE', 'ECHALLAN', 'E_CHALLAN'],
      });
      expect(request.validationError, isNull);
    });

    test('requires a valid ordered time range', () {
      const missingRange = ChallanExportRequestModel(
        startDate: '',
        endDate: '',
        categoryTitle: 'All Challan Data',
        challanTypes: ['RAISE'],
      );
      const reversedRange = ChallanExportRequestModel(
        startDate: '2026-09-30T16:43',
        endDate: '2026-03-30T16:43',
        categoryTitle: 'All Challan Data',
        challanTypes: ['RAISE'],
      );

      expect(missingRange.validationError, isNotNull);
      expect(reversedRange.validationError, isNotNull);
    });

    test('rejects dates outside the browser request format', () {
      const request = ChallanExportRequestModel(
        startDate: '2026-03-30T16:43:00',
        endDate: '2026-09-30T16:43',
        categoryTitle: 'e-Challan',
        challanTypes: ['RAISE', 'ECHALLAN', 'E_CHALLAN'],
      );

      expect(request.validationError, contains('yyyy-MM-ddTHH:mm'));
    });

    test('rejects invalid calendar dates', () {
      const request = ChallanExportRequestModel(
        startDate: '2026-02-30T16:43',
        endDate: '2026-03-30T16:43',
        categoryTitle: 'e-Challan',
        challanTypes: ['RAISE'],
      );

      expect(request.validationError, contains('valid Time Range'));
    });

    test('serializes only the selected count filters', () {
      const request = ChallanCountRequestModel(
        startDate: '2026-10-01T14:45:00',
        endDate: '2026-10-08T23:59:59',
        districtName: 'Kamareddy',
        zoneName: 'Kamareddy',
        cameraId: 29,
        vehicleCategory: 'N',
        violationType: 'NO_HELMET_CERTIFICATE',
        categoryTitle: 'e-Challan',
        challanTypes: ['RAISE', 'ECHALLAN', 'E_CHALLAN'],
      );

      expect(request.toJson(), {
        'startDate': '2026-10-01T14:45:00',
        'endDate': '2026-10-08T23:59:59',
        'districtName': 'Kamareddy',
        'officeName': 'Kamareddy',
        'zone': 'Kamareddy',
        'cameraId': 29,
        'vehicleCategory': 'N',
        'violationType': 'NO_HELMET_CERTIFICATE',
        'categoryTitle': 'e-Challan',
        'challanTypes': ['RAISE', 'ECHALLAN', 'E_CHALLAN'],
      });
      expect(request.validationError, isNull);
    });

    test('omits count filters that are not selected', () {
      const request = ChallanCountRequestModel(
        categoryTitle: 'All Challan Data',
        challanTypes: ['RAISE', 'COLLECT'],
      );

      expect(request.toJson(), {
        'categoryTitle': 'All Challan Data',
        'challanTypes': ['RAISE', 'COLLECT'],
      });
      expect(request.validationError, isNull);
    });
  });
}
