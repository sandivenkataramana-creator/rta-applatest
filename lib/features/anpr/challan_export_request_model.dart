class ChallanExportRequestModel {
  const ChallanExportRequestModel({
    required this.startDate,
    required this.endDate,
    required this.categoryTitle,
    required this.challanTypes,
  });

  final String startDate;
  final String endDate;
  final String categoryTitle;
  final List<String> challanTypes;

  String? get validationError {
    final start = _parseBrowserDateTime(startDate);
    final end = _parseBrowserDateTime(endDate);
    if (start == null || end == null) {
      return 'Please select a valid Time Range before exporting '
          '(yyyy-MM-ddTHH:mm).';
    }
    if (end.isBefore(start)) {
      return 'The end of the Time Range must be after its start.';
    }
    if (categoryTitle.trim().isEmpty ||
        challanTypes.isEmpty ||
        challanTypes.any((type) => type.trim().isEmpty)) {
      return 'Please select a Challan Type before exporting.';
    }
    return null;
  }

  Map<String, dynamic> toJson() => {
    'startDate': startDate,
    'endDate': endDate,
    'categoryTitle': categoryTitle,
    'challanTypes': challanTypes,
  };

  static DateTime? _parseBrowserDateTime(String value) {
    if (!RegExp(r'^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}$').hasMatch(value)) {
      return null;
    }
    final parsed = DateTime.tryParse(value);
    if (parsed == null) return null;

    final normalized =
        '${parsed.year.toString().padLeft(4, '0')}-'
        '${parsed.month.toString().padLeft(2, '0')}-'
        '${parsed.day.toString().padLeft(2, '0')}T'
        '${parsed.hour.toString().padLeft(2, '0')}:'
        '${parsed.minute.toString().padLeft(2, '0')}';
    return normalized == value ? parsed : null;
  }
}

class ChallanCountRequestModel {
  const ChallanCountRequestModel({
    this.startDate,
    this.endDate,
    this.districtName,
    this.zoneName,
    this.cameraId,
    this.vehicleCategory,
    this.violationType,
    required this.categoryTitle,
    required this.challanTypes,
  });

  final String? startDate;
  final String? endDate;
  final String? districtName;
  final String? zoneName;
  final int? cameraId;
  final String? vehicleCategory;
  final String? violationType;
  final String categoryTitle;
  final List<String> challanTypes;

  String? get validationError {
    if ((startDate == null) != (endDate == null)) {
      return 'Please select both the start and end of the Time Range.';
    }
    if (startDate != null && endDate != null) {
      final start = _parseDateTimeWithSeconds(startDate!);
      final end = _parseDateTimeWithSeconds(endDate!);
      if (start == null || end == null) {
        return 'Please select a valid Time Range.';
      }
      if (end.isBefore(start)) {
        return 'The end of the Time Range must be after its start.';
      }
    }
    if (categoryTitle.trim().isEmpty ||
        challanTypes.isEmpty ||
        challanTypes.any((type) => type.trim().isEmpty)) {
      return 'Please select a Challan Type before applying filters.';
    }
    return null;
  }

  Map<String, dynamic> toJson() => {
    if (startDate != null) 'startDate': startDate,
    if (endDate != null) 'endDate': endDate,
    if (districtName != null) 'districtName': districtName,
    if (zoneName != null) ...{'officeName': zoneName, 'zone': zoneName},
    if (cameraId != null) 'cameraId': cameraId,
    if (vehicleCategory != null) 'vehicleCategory': vehicleCategory,
    if (violationType != null) 'violationType': violationType,
    'categoryTitle': categoryTitle,
    'challanTypes': challanTypes,
  };

  static DateTime? _parseDateTimeWithSeconds(String value) {
    if (!RegExp(r'^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}$')
        .hasMatch(value)) {
      return null;
    }
    final parsed = DateTime.tryParse(value);
    if (parsed == null) return null;
    final normalized =
        '${parsed.year.toString().padLeft(4, '0')}-'
        '${parsed.month.toString().padLeft(2, '0')}-'
        '${parsed.day.toString().padLeft(2, '0')}T'
        '${parsed.hour.toString().padLeft(2, '0')}:'
        '${parsed.minute.toString().padLeft(2, '0')}:'
        '${parsed.second.toString().padLeft(2, '0')}';
    return normalized == value ? parsed : null;
  }
}
