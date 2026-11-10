import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/restaurant.dart';
import 'browser_maps_stub.dart'
    if (dart.library.js_interop) 'browser_maps_web.dart';

/// Open a map search using the venue identity and its listed address.
Future<bool> openRestaurantMap(Restaurant restaurant) async {
  final address = restaurant.address?.trim();
  if (address == null ||
      address.isEmpty ||
      address.toLowerCase() == 'not listed') {
    return false;
  }
  final query =
      <String?>[restaurant.name, address, restaurant.city, restaurant.country]
          .whereType<String>()
          .map((value) => value.trim())
          .where(
            (value) => value.isNotEmpty && value.toLowerCase() != 'not listed',
          )
          .toSet()
          .join(', ');

  final googleMap = Uri.https('www.google.com', '/maps/search/', {
    'api': '1',
    'query': query,
  });
  // Execute before any await so the new tab retains browser user activation.
  if (kIsWeb) return openBrowserMap(googleMap);

  final applePlatform =
      defaultTargetPlatform == TargetPlatform.macOS ||
      defaultTargetPlatform == TargetPlatform.iOS;
  if (applePlatform) {
    // The Maps scheme opens the native app, including on older macOS versions.
    final native = Uri(
      scheme: 'maps',
      host: 'maps.apple.com',
      path: '/',
      query: 'q=${Uri.encodeComponent(query)}',
    );
    if (await _launch(native)) return true;
    return _launch(Uri.https('maps.apple.com', '/', {'q': query}));
  }
  return _launch(googleMap);
}

Future<bool> _launch(Uri uri) async {
  try {
    return await launchUrl(
      uri,
      mode: LaunchMode.externalApplication,
      webOnlyWindowName: '_blank',
    );
  } on MissingPluginException {
    rethrow;
  } catch (error) {
    debugPrint('Map launch failed (${error.runtimeType}).');
    return false;
  }
}
