class RentalRequest {
  final String id;
  final String itemId;
  final String ownerId; // item owner
  final String renterId; // user who requests to rent
  final DateTime start;
  final DateTime end;
  final String status; // 'pending' | 'accepted' | 'declined' | 'running' | 'completed'
  final String? message;
  // Who cancelled the request when status == 'cancelled'.
  // Values: 'renter' | 'owner'. Null when not cancelled or legacy data.
  final String? cancelledBy;
  // Express delivery (2h) option
  final bool expressRequested; // renter requested express delivery during booking
  final String? expressStatus; // 'pending' | 'accepted' | 'declined' (null if not requested)
  final double expressFee; // default 5.0
  // Persist the chosen transport responsibilities at booking time so UI remains correct
  // even after transient UI selections are cleared.
  // When true => Owner brings item to renter at start (delivery on dropoff). When false => renter picks up.
  final bool ownerDeliversAtDropoffChosen;
  // When true => Owner picks item up from renter at return. When false => renter returns himself.
  final bool ownerPicksUpAtReturnChosen;
  // Optional delivery address snapshot (lightweight, used for demo display only)
  final String? deliveryAddressLine;
  final String? deliveryCity;
  final double? deliveryLat;
  final double? deliveryLng;
  // Timestamps
  final DateTime createdAt; // when the request was created
  final DateTime? expressRequestedAt; // when renter opted for express
  final DateTime? expressConfirmedAt; // when owner confirmed express
  // Snapshot of renter-facing total and subtitle at booking time to keep UI constant
  final double? quotedTotalRenter; // what the renter saw as Gesamtbetrag at request time
  final String? quotedSubtitle;    // the small info line under Gesamtbetrag at request time

  RentalRequest({
    required this.id,
    required this.itemId,
    required this.ownerId,
    required this.renterId,
    required this.start,
    required this.end,
    this.status = 'pending',
    this.message,
    this.cancelledBy,
    this.expressRequested = false,
    this.expressStatus,
    this.expressFee = 5.0,
    this.ownerDeliversAtDropoffChosen = false,
    this.ownerPicksUpAtReturnChosen = false,
    this.deliveryAddressLine,
    this.deliveryCity,
    this.deliveryLat,
    this.deliveryLng,
    DateTime? createdAt,
    this.expressRequestedAt,
    this.expressConfirmedAt,
    this.quotedTotalRenter,
    this.quotedSubtitle,
  }) : createdAt = createdAt ?? DateTime.now();

  RentalRequest copyWith({
    DateTime? start,
    DateTime? end,
    String? status,
    String? cancelledBy,
    bool? expressRequested,
    String? expressStatus,
    double? expressFee,
    DateTime? expressConfirmedAt,
    DateTime? expressRequestedAt,
    bool? ownerDeliversAtDropoffChosen,
    bool? ownerPicksUpAtReturnChosen,
    String? deliveryAddressLine,
    String? deliveryCity,
    double? deliveryLat,
    double? deliveryLng,
    double? quotedTotalRenter,
    String? quotedSubtitle,
  }) => RentalRequest(
        id: id,
        itemId: itemId,
        ownerId: ownerId,
        renterId: renterId,
        start: start ?? this.start,
        end: end ?? this.end,
        status: status ?? this.status,
        message: message,
        cancelledBy: cancelledBy ?? this.cancelledBy,
        expressRequested: expressRequested ?? this.expressRequested,
        expressStatus: expressStatus ?? this.expressStatus,
        expressFee: expressFee ?? this.expressFee,
        createdAt: this.createdAt,
        expressRequestedAt: expressRequestedAt ?? this.expressRequestedAt,
        expressConfirmedAt: expressConfirmedAt ?? this.expressConfirmedAt,
        ownerDeliversAtDropoffChosen: ownerDeliversAtDropoffChosen ?? this.ownerDeliversAtDropoffChosen,
        ownerPicksUpAtReturnChosen: ownerPicksUpAtReturnChosen ?? this.ownerPicksUpAtReturnChosen,
        deliveryAddressLine: deliveryAddressLine ?? this.deliveryAddressLine,
        deliveryCity: deliveryCity ?? this.deliveryCity,
        deliveryLat: deliveryLat ?? this.deliveryLat,
        deliveryLng: deliveryLng ?? this.deliveryLng,
        quotedTotalRenter: quotedTotalRenter ?? this.quotedTotalRenter,
        quotedSubtitle: quotedSubtitle ?? this.quotedSubtitle,
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
        cancelledBy: json['cancelledBy'] as String?,
        expressRequested: (json['expressRequested'] as bool?) ?? false,
        expressStatus: json['expressStatus'] as String?,
        expressFee: (json['expressFee'] as num?)?.toDouble() ?? 5.0,
        ownerDeliversAtDropoffChosen: (json['ownerDeliversAtDropoffChosen'] as bool?) ?? false,
        ownerPicksUpAtReturnChosen: (json['ownerPicksUpAtReturnChosen'] as bool?) ?? false,
        deliveryAddressLine: json['deliveryAddressLine'] as String?,
        deliveryCity: json['deliveryCity'] as String?,
        deliveryLat: (json['deliveryLat'] as num?)?.toDouble(),
        deliveryLng: (json['deliveryLng'] as num?)?.toDouble(),
        createdAt: _parseDt(json['createdAt']) ?? DateTime.now(),
        expressRequestedAt: _parseDt(json['expressRequestedAt']),
        expressConfirmedAt: _parseDt(json['expressConfirmedAt']),
        quotedTotalRenter: (json['quotedTotalRenter'] as num?)?.toDouble(),
        quotedSubtitle: json['quotedSubtitle'] as String?,
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
        'cancelledBy': cancelledBy,
        'expressRequested': expressRequested,
        'expressStatus': expressStatus,
        'expressFee': expressFee,
        'ownerDeliversAtDropoffChosen': ownerDeliversAtDropoffChosen,
        'ownerPicksUpAtReturnChosen': ownerPicksUpAtReturnChosen,
        'deliveryAddressLine': deliveryAddressLine,
        'deliveryCity': deliveryCity,
        'deliveryLat': deliveryLat,
        'deliveryLng': deliveryLng,
        'createdAt': createdAt.toIso8601String(),
        'expressRequestedAt': expressRequestedAt?.toIso8601String(),
        'expressConfirmedAt': expressConfirmedAt?.toIso8601String(),
        'quotedTotalRenter': quotedTotalRenter,
        'quotedSubtitle': quotedSubtitle,
      };
}

DateTime? _parseDt(Object? v) {
  if (v is String && v.isNotEmpty) {
    try { return DateTime.parse(v); } catch (_) { return null; }
  }
  return null;
}
