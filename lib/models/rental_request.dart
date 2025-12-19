class RentalRequest {
  final String id;
  final String itemId;
  final String ownerId; // item owner
  final String renterId; // user who requests to rent
  final DateTime start;
  final DateTime end;
  final String status; // 'pending' | 'accepted' | 'declined' | 'running' | 'completed'
  final String? message;
  // Express delivery (2h) option
  final bool expressRequested; // renter requested express delivery during booking
  final String? expressStatus; // 'pending' | 'accepted' | 'declined' (null if not requested)
  final double expressFee; // default 5.0
  // Timestamps
  final DateTime createdAt; // when the request was created
  final DateTime? expressRequestedAt; // when renter opted for express
  final DateTime? expressConfirmedAt; // when owner confirmed express

  RentalRequest({
    required this.id,
    required this.itemId,
    required this.ownerId,
    required this.renterId,
    required this.start,
    required this.end,
    this.status = 'pending',
    this.message,
    this.expressRequested = false,
    this.expressStatus,
    this.expressFee = 5.0,
    DateTime? createdAt,
    this.expressRequestedAt,
    this.expressConfirmedAt,
  }) : createdAt = createdAt ?? DateTime.now();

  RentalRequest copyWith({DateTime? start, DateTime? end, String? status, bool? expressRequested, String? expressStatus, double? expressFee, DateTime? expressConfirmedAt, DateTime? expressRequestedAt}) => RentalRequest(
        id: id,
        itemId: itemId,
        ownerId: ownerId,
        renterId: renterId,
        start: start ?? this.start,
        end: end ?? this.end,
        status: status ?? this.status,
        message: message,
        expressRequested: expressRequested ?? this.expressRequested,
        expressStatus: expressStatus ?? this.expressStatus,
        expressFee: expressFee ?? this.expressFee,
        createdAt: this.createdAt,
        expressRequestedAt: expressRequestedAt ?? this.expressRequestedAt,
        expressConfirmedAt: expressConfirmedAt ?? this.expressConfirmedAt,
      );

  factory RentalRequest.fromJson(Map<String, dynamic> json) => RentalRequest(
        id: json['id'] as String,
        itemId: json['itemId'] as String,
        ownerId: json['ownerId'] as String,
        renterId: json['renterId'] as String,
        start: DateTime.parse(json['start'] as String),
        end: DateTime.parse(json['end'] as String),
        status: (json['status'] as String?) ?? 'pending',
        message: json['message'] as String?,
        expressRequested: (json['expressRequested'] as bool?) ?? false,
        expressStatus: json['expressStatus'] as String?,
        expressFee: (json['expressFee'] as num?)?.toDouble() ?? 5.0,
        createdAt: _parseDt(json['createdAt']) ?? DateTime.now(),
        expressRequestedAt: _parseDt(json['expressRequestedAt']),
        expressConfirmedAt: _parseDt(json['expressConfirmedAt']),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'itemId': itemId,
        'ownerId': ownerId,
        'renterId': renterId,
        'start': start.toIso8601String(),
        'end': end.toIso8601String(),
        'status': status,
        'message': message,
        'expressRequested': expressRequested,
        'expressStatus': expressStatus,
        'expressFee': expressFee,
        'createdAt': createdAt.toIso8601String(),
        'expressRequestedAt': expressRequestedAt?.toIso8601String(),
        'expressConfirmedAt': expressConfirmedAt?.toIso8601String(),
      };
}

DateTime? _parseDt(Object? v) {
  if (v is String && v.isNotEmpty) {
    try { return DateTime.parse(v); } catch (_) { return null; }
  }
  return null;
}
