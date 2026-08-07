class CameraHealthModel {
  const CameraHealthModel({
    required this.checkInterval,
    required this.lastScanTime,
    required this.totalCameras,
    required this.activeCameras,
    required this.inactiveCameras,
    required this.inactiveLocations,
    this.id,
    this.updatedAt,
  });

  factory CameraHealthModel.fromJson(Map<String, dynamic> json) {
    final rawInactiveLocations = json['inactiveLocations'];
    return CameraHealthModel(
      checkInterval: _parseString(json['checkInterval']),
      lastScanTime: _parseString(json['lastScanTime']),
      totalCameras: _parseInt(json['totalCameras']),
      activeCameras: _parseInt(json['activeCameras']),
      inactiveCameras: _parseInt(json['inactiveCameras']),
      inactiveLocations: rawInactiveLocations is List
          ? rawInactiveLocations
                .whereType<Map>()
                .map(
                  (item) => CameraHealthLocation.fromJson(
                    Map<String, dynamic>.from(item),
                  ),
                )
                .toList()
          : const <CameraHealthLocation>[],
      id: _parseInt(json['id']),
      updatedAt: _parseString(json['updatedAt']),
    );
  }

  final String? checkInterval;
  final String? lastScanTime;
  final int totalCameras;
  final int activeCameras;
  final int inactiveCameras;
  final List<CameraHealthLocation> inactiveLocations;
  final int? id;
  final String? updatedAt;

  Map<String, dynamic> toJson() => {
    'checkInterval': checkInterval,
    'lastScanTime': lastScanTime,
    'totalCameras': totalCameras,
    'activeCameras': activeCameras,
    'inactiveCameras': inactiveCameras,
    'inactiveLocations': inactiveLocations
        .map((item) => item.toJson())
        .toList(),
    'id': id,
    'updatedAt': updatedAt,
  };

  static String? _parseString(dynamic value) {
    if (value == null) return null;
    return value.toString();
  }

  static int _parseInt(dynamic value) {
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }
}

class CameraHealthLocation {
  const CameraHealthLocation({
    required this.id,
    required this.district,
    required this.zone,
    required this.camera,
    required this.lastDataTime,
    required this.status,
  });

  factory CameraHealthLocation.fromJson(Map<String, dynamic> json) {
    return CameraHealthLocation(
      id: CameraHealthModel._parseInt(json['id']),
      district: CameraHealthModel._parseString(json['district']) ?? '',
      zone: CameraHealthModel._parseString(json['zone']) ?? '',
      camera: CameraHealthModel._parseString(json['camera']) ?? '',
      lastDataTime: CameraHealthModel._parseString(json['lastDataTime']) ?? '',
      status: CameraHealthModel._parseString(json['status']) ?? '',
    );
  }

  final int id;
  final String district;
  final String zone;
  final String camera;
  final String lastDataTime;
  final String status;

  Map<String, dynamic> toJson() => {
    'id': id,
    'district': district,
    'zone': zone,
    'camera': camera,
    'lastDataTime': lastDataTime,
    'status': status,
  };
}
