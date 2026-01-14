class User {
  final String id;
  final String displayName;
  final String email;
  final String? phone;
  final String? photoURL;
  final String? bio; // Short about me
  final String? city;
  final String? country;
  final String preferredLanguage;
  final bool isVerified;
  final bool isBanned;
  final String role;
  final String? payoutAccountId;
  final double avgRating;
  final int reviewCount;
  final DateTime createdAt;
  final List<String> languages;
  final List<String> interests;

  // Public profile optional fields
  final String? workTitle;
  final String? hobbies; // comma-separated simple string for demo
  final String? homeLocation; // optional override of city/country
  final String? favoriteSong;
  // New: structured address extras and personal data
  final double? homeLat;
  final double? homeLng;
  final DateTime? birthDate;

  // Visibility toggles for public profile
  final bool showWork;
  final bool showHobbies;
  final bool showHomeLocation;
  final bool showBioPublic;
  final bool showFavoriteSong;

  const User({
    required this.id,
    required this.displayName,
    required this.email,
    this.phone,
    this.photoURL,
    this.bio,
    this.city,
    this.country,
    required this.preferredLanguage,
    required this.isVerified,
    required this.isBanned,
    required this.role,
    this.payoutAccountId,
    required this.avgRating,
    required this.reviewCount,
    required this.createdAt,
    this.languages = const [],
    this.interests = const [],
    this.workTitle,
    this.hobbies,
    this.homeLocation,
    this.favoriteSong,
    this.showWork = false,
    this.showHobbies = false,
    this.showHomeLocation = false,
    this.showBioPublic = true,
    this.showFavoriteSong = false,
    this.homeLat,
    this.homeLng,
    this.birthDate,
  });

  factory User.fromJson(Map<String, dynamic> json) => User(
    id: json['id'],
    displayName: json['displayName'],
    email: json['email'],
    phone: json['phone'],
    photoURL: json['photoURL'],
    bio: json['bio'],
    city: json['city'],
    country: json['country'],
    preferredLanguage: json['preferredLanguage'] ?? 'de-DE',
    isVerified: json['isVerified'] ?? false,
    isBanned: json['isBanned'] ?? false,
    role: json['role'] ?? 'user',
    payoutAccountId: json['payoutAccountId'],
    avgRating: (json['avgRating'] as num?)?.toDouble() ?? 0.0,
    reviewCount: (json['reviewCount'] as num?)?.toInt() ?? 0,
    createdAt: _parseDateOrNow(json['createdAt']),
    languages: (json['languages'] as List?)?.map((e) => e.toString()).toList() ?? const [],
    interests: (json['interests'] as List?)?.map((e) => e.toString()).toList() ?? const [],
    workTitle: json['workTitle'],
    hobbies: json['hobbies'],
    homeLocation: json['homeLocation'],
    favoriteSong: json['favoriteSong'],
    showWork: json['showWork'] ?? false,
    showHobbies: json['showHobbies'] ?? false,
    showHomeLocation: json['showHomeLocation'] ?? false,
    showBioPublic: json['showBioPublic'] ?? true,
    showFavoriteSong: json['showFavoriteSong'] ?? false,
    homeLat: (json['homeLat'] as num?)?.toDouble(),
    homeLng: (json['homeLng'] as num?)?.toDouble(),
    birthDate: _parseNullableDate(json['birthDate']),
  );

  static DateTime _parseDateOrNow(dynamic value) {
    if (value is String && value.isNotEmpty) {
      return DateTime.tryParse(value) ?? DateTime.now();
    }
    return DateTime.now();
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'displayName': displayName,
    'email': email,
    'phone': phone,
    'photoURL': photoURL,
    'bio': bio,
    'city': city,
    'country': country,
    'preferredLanguage': preferredLanguage,
    'isVerified': isVerified,
    'isBanned': isBanned,
    'role': role,
    'payoutAccountId': payoutAccountId,
    'avgRating': avgRating,
    'reviewCount': reviewCount,
    'createdAt': createdAt.toIso8601String(),
    'languages': languages,
    'interests': interests,
    'workTitle': workTitle,
    'hobbies': hobbies,
    'homeLocation': homeLocation,
    'favoriteSong': favoriteSong,
    'showWork': showWork,
    'showHobbies': showHobbies,
    'showHomeLocation': showHomeLocation,
    'showBioPublic': showBioPublic,
    'showFavoriteSong': showFavoriteSong,
    'homeLat': homeLat,
    'homeLng': homeLng,
    'birthDate': birthDate?.toIso8601String(),
  };

  User copyWith({
    String? id,
    String? displayName,
    String? email,
    String? phone,
    String? photoURL,
    String? bio,
    String? city,
    String? country,
    String? preferredLanguage,
    bool? isVerified,
    bool? isBanned,
    String? role,
    String? payoutAccountId,
    double? avgRating,
    int? reviewCount,
    DateTime? createdAt,
    List<String>? languages,
    List<String>? interests,
    String? workTitle,
    String? hobbies,
    String? homeLocation,
    String? favoriteSong,
    bool? showWork,
    bool? showHobbies,
    bool? showHomeLocation,
    bool? showBioPublic,
    bool? showFavoriteSong,
    double? homeLat,
    double? homeLng,
    DateTime? birthDate,
  }) => User(
        id: id ?? this.id,
        displayName: displayName ?? this.displayName,
        email: email ?? this.email,
        phone: phone ?? this.phone,
        photoURL: photoURL ?? this.photoURL,
        bio: bio ?? this.bio,
        city: city ?? this.city,
        country: country ?? this.country,
        preferredLanguage: preferredLanguage ?? this.preferredLanguage,
        isVerified: isVerified ?? this.isVerified,
        isBanned: isBanned ?? this.isBanned,
        role: role ?? this.role,
        payoutAccountId: payoutAccountId ?? this.payoutAccountId,
        avgRating: avgRating ?? this.avgRating,
        reviewCount: reviewCount ?? this.reviewCount,
        createdAt: createdAt ?? this.createdAt,
        languages: languages ?? this.languages,
        interests: interests ?? this.interests,
        workTitle: workTitle ?? this.workTitle,
        hobbies: hobbies ?? this.hobbies,
        homeLocation: homeLocation ?? this.homeLocation,
        favoriteSong: favoriteSong ?? this.favoriteSong,
        showWork: showWork ?? this.showWork,
        showHobbies: showHobbies ?? this.showHobbies,
        showHomeLocation: showHomeLocation ?? this.showHomeLocation,
        showBioPublic: showBioPublic ?? this.showBioPublic,
        showFavoriteSong: showFavoriteSong ?? this.showFavoriteSong,
        homeLat: homeLat ?? this.homeLat,
        homeLng: homeLng ?? this.homeLng,
        birthDate: birthDate ?? this.birthDate,
      );

  static DateTime? _parseNullableDate(dynamic v) {
    if (v is String && v.isNotEmpty) {
      return DateTime.tryParse(v);
    }
    return null;
  }
}