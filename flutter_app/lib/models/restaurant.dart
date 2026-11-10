class Restaurant {
  const Restaurant({
    required this.id,
    required this.name,
    this.city,
    this.address,
    this.country,
    this.cuisine,
    this.specialDish,
    this.notes,
    this.telephone,
    this.internetLink,
    this.needsReview = false,
  });

  final int id;
  final String name;
  final String? city;
  final String? address;
  final String? country;
  final String? cuisine;
  final String? specialDish;
  final String? notes;
  final String? telephone;
  final String? internetLink;
  final bool needsReview;

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
    return Restaurant(
      id: id,
      name: text('restaurant_name') ?? 'Unnamed restaurant',
      city: text('city'),
      address: text('address'),
      country: text('country'),
      cuisine: text('cuisine'),
      specialDish: text('special_dish'),
      notes: text('notes'),
      telephone: text('telephone'),
      internetLink: text('internet_link'),
      needsReview: review == true || review == 1,
    );
  }

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
