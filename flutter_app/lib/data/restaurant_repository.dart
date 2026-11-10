import 'dart:convert';
import 'dart:math';

import 'package:http/http.dart' as http;

import '../models/restaurant.dart';
import '../services/app_capabilities.dart';
import '../services/catalogue_client.dart';

String newRestaurantRequestId() =>
    '${DateTime.now().microsecondsSinceEpoch}_'
    '${List.generate(16, (_) => Random.secure().nextInt(256).toRadixString(16).padLeft(2, '0')).join()}';

class RestaurantAddResult {
  const RestaurantAddResult(
    this.restaurants,
    this.addedCount,
    this.existingCount,
  );
  final List<Restaurant> restaurants;
  final int addedCount;
  final int existingCount;
}

class RestaurantLookupResult {
  const RestaurantLookupResult(this.id, this.venues, this.issues);
  final String id;
  final List<Map<String, Object?>> venues;
  final List<String> issues;
}

class CitySuggestion {
  const CitySuggestion({
    required this.id,
    required this.name,
    required this.country,
    required this.region,
  });
  final int id;
  final String name;
  final String country;
  final String region;

  factory CitySuggestion.fromJson(Map<String, dynamic> json) => CitySuggestion(
    id: json['id'] as int,
    name: json['name'] as String,
    country: json['country'] as String,
    region: json['region'] as String,
  );
}

class RestaurantRepository {
  RestaurantRepository({http.Client? client})
    : _client = catalogueClient(client);

  final http.Client _client;
  bool _closed = false;
  static const baseUrl = catalogueBaseUrl;

  Future<List<CitySuggestion>> cities(String query, String country) async {
    if (_closed || query.trim().length < 2) return const [];
    final base = baseUrl.replaceAll(RegExp(r'/+$'), '');
    final uri = Uri.parse(
      '$base/api/cities',
    ).replace(queryParameters: {'q': query.trim(), 'country': country.trim()});
    final response = await _client.get(uri).timeout(const Duration(seconds: 5));
    if (response.statusCode != 200) {
      throw const FormatException('City suggestions are unavailable');
    }
    final payload =
        jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
    return (payload['cities'] as List)
        .map((item) => CitySuggestion.fromJson(item as Map<String, dynamic>))
        .toList(growable: false);
  }

  Future<Map<String, dynamic>> reviewDetails(int id) async {
    final base = baseUrl.replaceAll(RegExp(r'/+$'), '');
    final response = await _client
        .get(Uri.parse('$base/api/restaurants/$id/review'))
        .timeout(const Duration(seconds: 10));
    if ([404, 405, 501].contains(response.statusCode)) {
      throw const FormatException(
        'Restart the Python service and refresh to enable reviews.',
      );
    }
    final payload =
        jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
    if (response.statusCode != 200) {
      throw FormatException(
        payload['error'] ?? 'Could not load review details.',
      );
    }
    return payload;
  }

  Future<Restaurant> saveReview(
    Restaurant restaurant,
    String decision,
    String note,
  ) async {
    if (restaurant.revision == null) {
      throw const FormatException('Reload the review before deciding.');
    }
    final base = baseUrl.replaceAll(RegExp(r'/+$'), '');
    final response = await _client
        .post(
          Uri.parse('$base/api/restaurants/${restaurant.id}/review'),
          headers: {'Content-Type': 'application/json', 'X-BeneEde-Edit': '1'},
          body: jsonEncode({
            'revision': restaurant.revision,
            'decision': decision,
            'note': note,
          }),
        )
        .timeout(const Duration(seconds: 10));
    final payload =
        jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
    if (response.statusCode != 200) {
      throw FormatException(payload['error'] ?? 'Could not save the review.');
    }
    return Restaurant.fromJson(payload['restaurant'] as Map<String, dynamic>);
  }

  Future<List<Restaurant>> load() async {
    final base = baseUrl.replaceAll(RegExp(r'/+$'), '');
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

  Future<Restaurant> save(
    Restaurant original,
    Map<String, Object?> changes,
  ) async {
    if (original.revision == null) {
      throw const FormatException(
        'Restart the Python service, refresh the list and reopen the editor.',
      );
    }
    final base = baseUrl.replaceAll(RegExp(r'/+$'), '');
    final response = await _client
        .patch(
          Uri.parse('$base/api/restaurants/${original.id}'),
          headers: {'Content-Type': 'application/json', 'X-BeneEde-Edit': '1'},
          body: jsonEncode({'revision': original.revision, 'changes': changes}),
        )
        .timeout(const Duration(seconds: 15));
    if ([404, 405, 501].contains(response.statusCode)) {
      throw const FormatException(
        'Restart the Python service and refresh the list. This record may no longer exist.',
      );
    }
    final payload = jsonDecode(utf8.decode(response.bodyBytes));
    if (response.statusCode != 200) {
      throw FormatException(
        payload['error'] ?? 'Could not save the restaurant.',
      );
    }
    return Restaurant.fromJson(payload['restaurant'] as Map<String, dynamic>);
  }

  Future<void> delete(Restaurant original) async {
    if (original.revision == null) {
      throw const FormatException(
        'Restart the Python service, refresh and reopen the editor.',
      );
    }
    final base = baseUrl.replaceAll(RegExp(r'/+$'), '');
    final response = await _client
        .delete(
          Uri.parse('$base/api/restaurants/${original.id}'),
          headers: {'Content-Type': 'application/json', 'X-BeneEde-Edit': '1'},
          body: jsonEncode({'revision': original.revision, 'confirmed': true}),
        )
        .timeout(const Duration(seconds: 15));
    if ([405, 501].contains(response.statusCode)) {
      throw const FormatException(
        'Restart the Python service to enable deletion.',
      );
    }
    final payload = jsonDecode(utf8.decode(response.bodyBytes));
    if (response.statusCode != 200 || payload['deleted_id'] != original.id) {
      throw FormatException(
        payload['error'] ??
            'Could not confirm deletion. Cancel and refresh the list.',
      );
    }
  }

  Map<String, dynamic> _addPayload(http.Response response) {
    if ([404, 405, 501].contains(response.statusCode)) {
      throw const FormatException(
        'Restart the Python service to enable adding and lookups. Refresh before retrying.',
      );
    }
    final payload =
        jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
    if (response.statusCode != 200 && response.statusCode != 202) {
      throw FormatException(
        payload['error'] ?? 'The request could not be completed.',
      );
    }
    return payload;
  }

  Future<RestaurantLookupResult> lookup(
    Map<String, Object?> fields,
    String mode, {
    required void Function(String) onProgress,
  }) async {
    if (!allowsRestaurantDiscovery) {
      throw const FormatException(
        'Automatic restaurant discovery is available on desktop only. Add the details manually.',
      );
    }
    final base = baseUrl.replaceAll(RegExp(r'/+$'), '');
    final id = newRestaurantRequestId();
    var payload = _addPayload(
      await _client
          .post(
            Uri.parse('$base/api/restaurant-lookups'),
            headers: {
              'Content-Type': 'application/json',
              'X-BeneEde-Edit': '1',
            },
            body: jsonEncode({
              'request_id': id,
              'fields': fields,
              'mode': mode,
            }),
          )
          .timeout(const Duration(seconds: 15)),
    );
    final deadline = DateTime.now().add(const Duration(minutes: 10));
    while (payload['status'] == 'running') {
      if (_closed) throw const FormatException('Lookup cancelled.');
      if (DateTime.now().isAfter(deadline)) {
        throw const FormatException(
          'Lookup took too long. Try again or add manually. No records were saved.',
        );
      }
      onProgress(
        payload['message'] as String? ?? 'Looking up restaurant details…',
      );
      await Future<void>.delayed(const Duration(seconds: 1));
      if (_closed) throw const FormatException('Lookup cancelled.');
      payload = _addPayload(
        await _client
            .get(Uri.parse('$base/api/restaurant-lookups/$id'))
            .timeout(const Duration(seconds: 15)),
      );
    }
    if (payload['status'] != 'ready') {
      throw FormatException(
        payload['message'] ?? 'Lookup failed. You can add manually.',
      );
    }
    final venues = (payload['venues'] as List)
        .map((venue) => Map<String, Object?>.from(venue['fields'] as Map))
        .toList();
    final issues = <String>{...(payload['issues'] as List).cast<String>()};
    for (final venue in payload['venues'] as List) {
      issues.addAll((venue['issues'] as List).cast<String>());
    }
    return RestaurantLookupResult(id, venues, issues.toList());
  }

  Future<RestaurantAddResult> add(
    String requestId,
    List<Map<String, Object?>> records,
    String? lookupId,
  ) async {
    final base = baseUrl.replaceAll(RegExp(r'/+$'), '');
    final payload = _addPayload(
      await _client
          .post(
            Uri.parse('$base/api/restaurants'),
            headers: {
              'Content-Type': 'application/json',
              'X-BeneEde-Edit': '1',
            },
            body: jsonEncode({
              'request_id': requestId,
              'records': records,
              'lookup_id': lookupId,
            }),
          )
          .timeout(const Duration(seconds: 20)),
    );
    return RestaurantAddResult(
      (payload['restaurants'] as List)
          .map((row) => Restaurant.fromJson(row as Map<String, dynamic>))
          .toList(),
      payload['added_count'] as int,
      payload['existing_count'] as int,
    );
  }

  void close() {
    _closed = true;
    _client.close();
  }
}
