import 'package:http/http.dart' as http;

const catalogueBaseUrl = String.fromEnvironment(
  'RESTAURANT_API_URL',
  defaultValue: 'http://127.0.0.1:8765',
);
const _catalogueToken = String.fromEnvironment('RESTAURANT_API_TOKEN');

http.Client catalogueClient([http.Client? client]) =>
    _CatalogueClient(client ?? http.Client());

class _CatalogueClient extends http.BaseClient {
  _CatalogueClient(this.inner);
  final http.Client inner;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    // Never send the pairing token to website/map or other external origins.
    if (_catalogueToken.isNotEmpty &&
        request.url.origin == Uri.parse(catalogueBaseUrl).origin) {
      request.headers['Authorization'] = 'Bearer $_catalogueToken';
    }
    return inner.send(request);
  }

  @override
  void close() => inner.close();
}
