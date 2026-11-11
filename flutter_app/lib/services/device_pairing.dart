import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

abstract interface class PairingKeyStore {
  Future<String?> read();
  Future<void> write(String key);
}

class SecurePairingKeyStore implements PairingKeyStore {
  SecurePairingKeyStore(String serverUrl) : _key = 'beneede.pairing.$serverUrl';
  final String _key;
  static const _storage = FlutterSecureStorage(
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.unlocked_this_device,
    ),
    mOptions: MacOsOptions(usesDataProtectionKeychain: false),
  );
  @override
  Future<String?> read() => _storage.read(key: _key);
  @override
  Future<void> write(String key) => _storage.write(key: _key, value: key);
  Future<void> clear() => _storage.delete(key: _key);
}

class DevicePairing {
  DevicePairing({
    required this.serverUrl,
    required this.store,
    this.clientFactory,
  });
  final String serverUrl;
  final PairingKeyStore store;
  final http.Client Function()? clientFactory;

  Future<void> pair(String value) async {
    final key = value.trim();
    if (key.length < 32 || key.length > 256 || RegExp(r'\s').hasMatch(key)) {
      throw const FormatException(
        'Paste the complete pairing key from the Mac.',
      );
    }
    final client = clientFactory?.call() ?? http.Client();
    try {
      await verifyPairedServer(client, serverUrl, key);
      final response = await client
          .get(
            Uri.parse('$serverUrl/api/health'),
            headers: {'Authorization': 'Bearer $key'},
          )
          .timeout(const Duration(seconds: 6));
      if (response.statusCode != 200) {
        throw const FormatException(
          'Pairing failed. Check the key and connect to the Mac’s network.',
        );
      }
      final payload = jsonDecode(response.body) as Map<String, dynamic>;
      if (payload['service'] != 'BeneEde' || payload['mobile_access'] != true) {
        throw const FormatException('This is not the paired BeneEde service.');
      }
      await store.write(key);
    } finally {
      client.close();
    }
  }
}

/// Credential stays on the device and is never sent to an external website.
class AuthenticatedCatalogueClient extends http.BaseClient {
  AuthenticatedCatalogueClient(
    this.inner, {
    required this.serverUrl,
    required this.token,
    this.verifyServer = false,
  });
  final http.Client inner;
  final String serverUrl;
  final Future<String?> Function() token;
  final bool verifyServer;
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    if (request.url.origin == Uri.parse(serverUrl).origin) {
      final key = await token();
      if (verifyServer && (key == null || key.isEmpty)) {
        throw const FormatException(
          'Pair with Mac in sync details before synchronizing. Your local data is available.',
        );
      }
      if (key != null && key.isNotEmpty) {
        if (verifyServer) {
          await verifyPairedServer(inner, serverUrl, key);
        }
        request.headers['Authorization'] = 'Bearer $key';
      }
    }
    return inner.send(request);
  }

  @override
  void close() => inner.close();
}

/// Prove knowledge of the shared pairing key before disclosing it to a host.
/// A fresh challenge prevents a same-named Mac on another Wi-Fi replaying proof.
Future<void> verifyPairedServer(
  http.Client client,
  String serverUrl,
  String key,
) async {
  final random = Random.secure();
  final challenge = List.generate(
    16,
    (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'),
  ).join();
  final response = await client
      .get(Uri.parse('$serverUrl/api/server-proof?challenge=$challenge'))
      .timeout(const Duration(seconds: 6));
  if (response.statusCode != 200) {
    throw const FormatException(
      'Could not verify your Mac. Start the updated BeneEde service on its network.',
    );
  }
  final payload = jsonDecode(response.body) as Map<String, dynamic>;
  final expected = Hmac(
    sha256,
    utf8.encode(key),
  ).convert(utf8.encode('beneede-server:$challenge')).toString();
  if (payload['service'] != 'BeneEde' || payload['proof'] != expected) {
    throw const FormatException(
      'This server does not match the Mac pairing key. No changes were sent.',
    );
  }
}
