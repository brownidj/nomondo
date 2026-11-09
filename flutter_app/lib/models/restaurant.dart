class Restaurant {
  const Restaurant({
    required this.id,
    required this.name,
    this.city,
    this.country,
    this.cuisine,
    this.specialDish,
    this.notes,
  });

  final int id;
  final String name;
  final String? city;
  final String? country;
  final String? cuisine;
  final String? specialDish;
  final String? notes;

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
    return Restaurant(
      id: id,
      name: text('restaurant_name') ?? 'Unnamed restaurant',
      city: text('city'),
      country: text('country'),
      cuisine: text('cuisine'),
      specialDish: text('special_dish'),
      notes: text('notes'),
    );
  }

  bool matches(String query) =>
      [name, city, country, cuisine, specialDish, notes]
          .whereType<String>()
          .any((value) => value.toLowerCase().contains(query.toLowerCase()));
}
