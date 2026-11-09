import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/restaurant.dart';

class RestaurantRepository {
  RestaurantRepository({http.Client? client})
    : _client = client ?? http.Client();

  final http.Client _client;
  static const _baseUrl = String.fromEnvironment(
    'RESTAURANT_API_URL',
    defaultValue: 'http://127.0.0.1:8765',
  );

  Future<List<Restaurant>> load() async {
    final base = _baseUrl.replaceAll(RegExp(r'/+$'), '');
    final response = await _client
        .get(Uri.parse('$base/api/restaurants'))
        .timeout(const Duration(seconds: 15));
    if (response.statusCode != 200) {
      throw const FormatException('Restaurant data is unavailable');
    }
    final payload = jsonDecode(utf8.decode(response.bodyBytes));
    if (payload is! Map<String, dynamic> || payload['restaurants'] is! List) {
      throw const FormatException('Unexpected restaurant data');
    }
    return (payload['restaurants'] as List)
        .map((item) {
          if (item is! Map<String, dynamic>) {
            throw const FormatException('Unexpected restaurant record');
          }
          return Restaurant.fromJson(item);
        })
        .toList(growable: false);
  }

  void close() => _client.close();
}
