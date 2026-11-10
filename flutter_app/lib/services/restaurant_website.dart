import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';

import '../data/restaurant_repository.dart';
import 'catalogue_client.dart';
import 'browser_maps_stub.dart'
    if (dart.library.js_interop) 'browser_maps_web.dart';

Uri? websiteUri(String value) {
  final text = value.trim();
  if (text.isEmpty || text.toLowerCase() == 'not listed') return null;
  final uri = Uri.tryParse(text.contains('://') ? text : 'https://$text');
  if (uri == null ||
      !['http', 'https'].contains(uri.scheme) ||
      uri.host.isEmpty ||
      uri.userInfo.isNotEmpty) {
    return null;
  }
  return uri;
}

Future<bool> openRestaurantWebsite(Uri uri) {
  // Browser opening must happen synchronously, before the reachability request.
  if (kIsWeb) return Future.value(openBrowserMap(uri));
  return launchUrl(uri, mode: LaunchMode.externalApplication);
}

Future<bool?> checkRestaurantWebsite(int id) async {
  final client = catalogueClient();
  try {
    final base = RestaurantRepository.baseUrl.replaceAll(RegExp(r'/+$'), '');
    final response = await client
        .get(Uri.parse('$base/api/restaurants/$id/website-status'))
        .timeout(const Duration(seconds: 20));
    if (response.statusCode != 200) return null;
    final payload = jsonDecode(response.body);
    return switch (payload['status']) {
      'available' => true,
      'unavailable' => false,
      _ => null,
    };
  } catch (_) {
    return null; // An unavailable local checker is not a failed restaurant site.
  } finally {
    client.close();
  }
}
