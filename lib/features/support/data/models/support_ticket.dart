class SupportTicket {
  const SupportTicket({
    this.id,
    required this.subject,
    required this.message,
    this.attachmentName,
    this.attachmentType,
    this.attachmentData,
    this.fromUserId,
    this.toRole,
    this.status = 'Open',
    this.date,
    this.ticketId,
    this.ticketType,
    this.read = false,
    this.createdBy = 'Unknown',
    this.createdAt,
    this.attachments = const [],
    this.replies = const [],
    this.timeline = const [],
  });

  final int? id;
  final String subject;
  final String message;
  final String? attachmentName;
  final String? attachmentType;
  final dynamic attachmentData;
  final int? fromUserId;
  final String? toRole;
  final String status;
  final DateTime? date;
  final String? ticketId;
  final String? ticketType;
  final bool read;
  final String createdBy;
  final DateTime? createdAt;
  final List<String> attachments;
  final List<SupportReply> replies;
  final List<SupportTimelineEntry> timeline;

  bool get isOpen {
    final value = status.trim().toLowerCase();
    return value == 'open' ||
        value == 'pending' ||
        value == 'new' ||
        value.isEmpty;
  }

  bool get isClosed {
    final value = status.trim().toLowerCase();
    return value == 'closed' || value == 'resolved' || value == 'done';
  }

  String get displayStatus => isClosed ? 'Closed' : 'Open';

  static String _coerceString(Object? value) => value?.toString() ?? '';

  static int? _coerceInt(Object? value) {
    if (value is int) return value;
    if (value is String) return int.tryParse(value);
    return null;
  }

  static bool _coerceBool(Object? value) {
    if (value is bool) return value;
    if (value is int) return value != 0;
    if (value is String) {
      final lowered = value.trim().toLowerCase();
      return lowered == 'true' || lowered == '1' || lowered == 'yes';
    }
    return false;
  }

  static DateTime? _coerceDateTime(Object? value) {
    if (value is DateTime) return value;
    if (value is String && value.trim().isNotEmpty) {
      return DateTime.tryParse(value);
    }
    return null;
  }

  static List<String> _coerceStringList(Object? value) {
    if (value is List) {
      return value.map((e) => e.toString()).toList();
    }
    return const [];
  }

  factory SupportTicket.fromJson(Map<String, dynamic> json) {
    final createdBy = _coerceString(
      json['createdBy'] ??
          json['created_by'] ??
          json['fromUserId'] ??
          json['userName'] ??
          json['user']?['name'] ??
          json['user']?['fullName'] ??
          json['submittedBy'],
    );

    final dateValue = json['date'] ?? json['createdAt'] ?? json['created_at'];

    return SupportTicket(
      id: _coerceInt(json['id'] ?? json['complaintId'] ?? json['complaint_id']),
      subject: _coerceString(json['subject'] ?? json['title'] ?? json['heading']),
      message: _coerceString(json['message'] ?? json['description'] ?? json['details'] ?? json['body']),
      attachmentName: _coerceString(json['attachmentName']).isNotEmpty ? _coerceString(json['attachmentName']) : null,
      attachmentType: _coerceString(json['attachmentType']).isNotEmpty ? _coerceString(json['attachmentType']) : null,
      attachmentData: json['attachmentData'],
      fromUserId: _coerceInt(json['fromUserId']),
      toRole: _coerceString(json['toRole']).isNotEmpty ? _coerceString(json['toRole']) : null,
      status: _coerceString(json['status'] ?? 'Open'),
      date: _coerceDateTime(dateValue),
      ticketId: _coerceString(json['ticketId']).isNotEmpty ? _coerceString(json['ticketId']) : null,
      ticketType: _coerceString(json['ticketType']).isNotEmpty ? _coerceString(json['ticketType']) : null,
      read: _coerceBool(json['read']),
      createdBy: createdBy.isNotEmpty ? createdBy : 'Unknown',
      createdAt: _coerceDateTime(dateValue),
      attachments: _coerceStringList(json['attachments'] ?? json['files'] ?? json['documents']),
      replies: const [],
      timeline: const [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'subject': subject,
      'message': message,
      'fromUserId': fromUserId,
      'status': status,
      'attachmentData': attachmentData,
      'attachmentName': attachmentName,
      'attachmentType': attachmentType,
      'date': date?.toUtc().toIso8601String() ?? DateTime.now().toUtc().toIso8601String(),
    };
  }
}

class SupportReply {
  const SupportReply({
    required this.message,
    this.author = 'Support',
    this.createdAt,
  });

  final String message;
  final String author;
  final DateTime? createdAt;
}

class SupportTimelineEntry {
  const SupportTimelineEntry({
    required this.title,
    this.details,
    this.createdAt,
  });

  final String title;
  final String? details;
  final DateTime? createdAt;
}
