import 'package:flutter/foundation.dart';

/// Platform policy, independent of screen width (including mobile browsers).
bool get isMobilePlatform => switch (defaultTargetPlatform) {
  TargetPlatform.iOS || TargetPlatform.android => true,
  _ => false,
};

bool get allowsRestaurantDiscovery => !isMobilePlatform;
