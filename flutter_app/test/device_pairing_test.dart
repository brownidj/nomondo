import 'dart:convert';

import 'package:beneede_app/services/device_pairing.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

class Keys implements PairingKeyStore {
  String? value;
  @override
  Future<String?> read() async => value;
  @override
  Future<void> write(String key) async => value = key;
}

const key = 'fixture-pairing-key-12345678901234567890';
http.Response proof(http.Request request, {bool valid = true}) => http.Response(
  jsonEncode({
    'service': 'BeneEde',
    'proof': valid
        ? Hmac(sha256, utf8.encode(key))
              .convert(
                utf8.encode(
                  'beneede-server:${request.url.queryParameters['challenge']}',
                ),
              )
              .toString()
        : 'wrong-server',
  }),
  200,
);

void main() {
  test(
    'pairing verifies Mac identity before sending the key and storing it',
    () async {
      final keys = Keys();
      final requests = <http.Request>[];
      final pairing = DevicePairing(
        serverUrl: 'http://mac.local:8766',
        store: keys,
        clientFactory: () => MockClient((request) async {
          requests.add(request);
          if (request.url.path == '/api/server-proof') return proof(request);
          return http.Response(
            '{"service":"BeneEde","mobile_access":true}',
            200,
          );
        }),
      );
      await pairing.pair(key);
      expect(requests.first.headers['Authorization'], isNull);
      expect(requests.last.headers['Authorization'], 'Bearer $key');
      expect(keys.value, key);
    },
  );

  test(
    'a same-named wrong server never receives credentials or edits',
    () async {
      final requests = <http.Request>[];
      final client = AuthenticatedCatalogueClient(
        MockClient((request) async {
          requests.add(request);
          return proof(request, valid: false);
        }),
        serverUrl: 'http://mac.local:8766',
        token: () async => key,
        verifyServer: true,
      );
      await expectLater(
        client.patch(
          Uri.parse('http://mac.local:8766/api/restaurants/1'),
          body: '{}',
        ),
        throwsFormatException,
      );
      expect(requests, hasLength(1));
      expect(requests.single.url.path, '/api/server-proof');
      expect(requests.single.headers['Authorization'], isNull);
      client.close();
    },
  );

  test(
    'external websites never receive the pairing key or identity probe',
    () async {
      var reads = 0;
      final client = AuthenticatedCatalogueClient(
        MockClient((request) async {
          expect(request.headers['Authorization'], isNull);
          return http.Response('ok', 200);
        }),
        serverUrl: 'http://mac.local:8766',
        token: () async {
          reads++;
          return key;
        },
        verifyServer: true,
      );
      await client.get(Uri.parse('https://example.com'));
      expect(reads, 0);
      client.close();
    },
  );

  test('missing pairing key prevents any network mutation', () async {
    var requests = 0;
    final client = AuthenticatedCatalogueClient(
      MockClient((request) async {
        requests++;
        return http.Response('{}', 200);
      }),
      serverUrl: 'http://mac.local:8766',
      token: () async => null,
      verifyServer: true,
    );
    await expectLater(
      client.post(Uri.parse('http://mac.local:8766/api/restaurants')),
      throwsFormatException,
    );
    expect(requests, 0);
    client.close();
  });
}
