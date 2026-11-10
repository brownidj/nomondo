class Restaurant {
  const Restaurant({
    required this.id,
    required this.name,
    this.revision,
    this.region,
    this.venueType,
    this.historicalRanking,
    this.rating = 0,
    this.venueStatus = 'unknown',
    this.city,
    this.address,
    this.country,
    this.cuisine,
    this.specialDish,
    this.notes,
    this.telephone,
    this.internetLink,
    this.needsReview = false,
    this.reviewStatus = 'pending',
    this.reviewedAt,
    this.reviewNote = '',
    this.archivedAt,
    this.confidence,
  });

  final int id;
  final String name;
  final String? revision;
  final String? region;
  final String? venueType;
  final String? historicalRanking;
  final double rating;
  final String venueStatus;
  final String? city;
  final String? address;
  final String? country;
  final String? cuisine;
  final String? specialDish;
  final String? notes;
  final String? telephone;
  final String? internetLink;
  final bool needsReview;
  final String reviewStatus;
  final String? reviewedAt;
  final String reviewNote;
  final String? archivedAt;
  final double? confidence;
  bool get isArchived => archivedAt != null;
  String get reviewLabel => isArchived
      ? 'Failed · archived'
      : reviewStatus == 'passed'
      ? 'Passed'
      : needsReview
      ? 'Needs review'
      : 'Not reviewed';

  factory Restaurant.fromJson(Map<String, dynamic> json) {
    String? text(String field) {
      final value = json[field];
      if (value == null) return null;
      if (value is! String) {
        throw FormatException('Unexpected restaurant field: $field');
      }
      return value.trim().isEmpty ? null : value.trim();
    }

    final id = json['id'];
    if (id is! int) throw const FormatException('Invalid restaurant ID');
    final review = json['needs_review'];
    if (review is! bool && review != 0 && review != 1) {
      throw const FormatException('Invalid restaurant review flag');
    }
    final confidence = json['confidence'];
    final validConfidence =
        confidence is num &&
        confidence.isFinite &&
        confidence >= 0 &&
        confidence <= 1;
    return Restaurant(
      id: id,
      name: text('restaurant_name') ?? 'Unnamed restaurant',
      revision: text('revision'),
      region: text('region'),
      venueType: text('venue_type'),
      historicalRanking: text('historical_ranking'),
      rating: (json['rating'] as num?)?.toDouble() ?? 0,
      venueStatus: text('venue_status') ?? 'unknown',
      city: text('city'),
      address: text('address'),
      country: text('country'),
      cuisine: text('cuisine'),
      specialDish: text('special_dish'),
      notes: text('notes'),
      telephone: text('telephone'),
      internetLink: text('internet_link'),
      needsReview: review == true || review == 1,
      reviewStatus: text('review_status') ?? 'pending',
      reviewedAt: text('reviewed_at'),
      reviewNote: text('review_note') ?? '',
      archivedAt: text('archived_at'),
      confidence: validConfidence ? confidence.toDouble() : null,
    );
  }

  Map<String, Object?> get editValues => {
    'restaurant_name': name,
    'city': city,
    'country': country,
    'address': address,
    'telephone': telephone,
    'internet_link': internetLink,
    'cuisine': cuisine,
    'special_dish': specialDish,
    'notes': notes,
    'region': region,
    'venue_type': venueType,
    'historical_ranking': historicalRanking,
    'rating': rating,
    'venue_status': venueStatus,
  };

  bool matches(String query) =>
      [
        name,
        city,
        address,
        country,
        cuisine,
        specialDish,
        notes,
        telephone,
        internetLink,
      ].whereType<String>().any(
        (value) => value.toLowerCase().contains(query.toLowerCase()),
      );
}
