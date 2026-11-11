import 'dart:convert';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

import '../data/mobile_catalogue.dart';
import '../data/mobile_catalogue_store.dart';
import 'app_capabilities.dart';
import 'device_pairing.dart';

const catalogueBaseUrl = String.fromEnvironment(
  'RESTAURANT_API_URL',
  defaultValue: 'http://127.0.0.1:8765',
);
const _catalogueToken = String.fromEnvironment('RESTAURANT_API_TOKEN');

bool _localNetwork(List<ConnectivityResult> values) => values.any(
  (value) =>
      value == ConnectivityResult.wifi || value == ConnectivityResult.ethernet,
);

http.Client catalogueClient([http.Client? client]) {
  if (client != null || kIsWeb || !isMobilePlatform) {
    return AuthenticatedCatalogueClient(
      client ?? http.Client(),
      serverUrl: catalogueBaseUrl,
      token: () async => _catalogueToken,
    );
  }
  if (MobileCatalogue.active == null) {
    final url = catalogueBaseUrl.replaceAll(RegExp(r'/+$'), '');
    final keys = SecurePairingKeyStore(url);
    final pairing = DevicePairing(serverUrl: url, store: keys);
    final connectivity = Connectivity();
    MobileCatalogue.active = MobileCatalogue(
      remote: AuthenticatedCatalogueClient(
        http.Client(),
        serverUrl: url,
        verifyServer: true,
        token: () async => await keys.read() ?? _catalogueToken,
      ),
      baseUrl: url,
      store: SqliteCatalogueStore(catalogueBaseUrl),
      loadSeed: () async {
        final text = await rootBundle.loadString(
          'assets/catalogue/initial_catalogue.json',
        );
        return jsonDecode(text) as Map<String, dynamic>;
      },
      checkLocalNetwork: () async =>
          _localNetwork(await connectivity.checkConnectivity()),
      localNetworkChanges: connectivity.onConnectivityChanged.map(
        _localNetwork,
      ),
      pairWithServer: pairing.pair,
    );
  }
  return MobileCatalogueClient(MobileCatalogue.active!);
}
