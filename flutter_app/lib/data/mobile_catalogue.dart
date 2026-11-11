import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'mobile_catalogue_store.dart';
import '../models/restaurant.dart';

Map<String, dynamic> _copy(Map value) =>
    jsonDecode(jsonEncode(value)) as Map<String, dynamic>;

/// Shared by every mobile repository, including modal editors. No pairing token
/// is written to the database. Server snapshots and queued changes stay separate.
class MobileCatalogue extends ChangeNotifier {
  MobileCatalogue({
    required this.remote,
    required this.baseUrl,
    required this.store,
    this.loadSeed,
    this.localNetworkChanges,
    this.checkLocalNetwork,
    this.pairWithServer,
  });
  static MobileCatalogue? active;
  final http.Client remote;
  final String baseUrl;
  final CatalogueStore store;
  final Future<Map<String, dynamic>?> Function()? loadSeed;
  final Stream<bool>? localNetworkChanges;
  final Future<bool> Function()? checkLocalNetwork;
  final Future<void> Function(String)? pairWithServer;
  StreamSubscription<bool>? _networkSubscription;
  Timer? _reconnectTimer;
  bool _localNetworkEligible = false;
  bool _networkRefreshPending = false;
  int _networkGeneration = 0;

  Map<String, dynamic>? _state;
  Future<void> _serial = Future<void>.value();
  Future<void>? _sync;
  Timer? _timer;
  DateTime _lastActivity = DateTime.now();
  bool _disposed = false;
  bool foreground = true;
  bool syncing = false;
  bool online = false;
  String? lastError;
  int generation = 0;

  int get pendingCount => (_state?['outbox'] as List?)?.length ?? 0;
  bool get hasChanges => _state?['has_changes'] == true;
  List<Map<String, dynamic>> get conflicts =>
      _ops.where((op) => op['error'] != null).map(_copy).toList();
  String? get lastSynced => _state?['last_synced'] as String?;
  List<Map<String, dynamic>> get _ops =>
      ((_state?['outbox'] as List?) ?? []).cast<Map<String, dynamic>>();
  bool get _hasLocal => _state?['has_snapshot'] == true || _ops.isNotEmpty;
  bool get hasLocalData => _hasLocal;

  Future<T> _locked<T>(Future<T> Function() action) {
    final result = _serial.then((_) => action());
    _serial = result.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return result;
  }

  Future<void> _ready() async {
    _state ??=
        await store.read() ??
        {
          'server': <String, dynamic>{},
          'outbox': <dynamic>[],
          'reviews': <String, dynamic>{},
          'resolved': <dynamic>[],
          'has_snapshot': false,
          'last_synced': null,
          'has_changes': false,
          'needs_download': false,
        };
    if (_state!['has_snapshot'] != true &&
        (_state!['server'] as Map).isEmpty &&
        loadSeed != null) {
      final seed = await loadSeed!();
      if (seed != null) {
        _validateSnapshot(seed);
        final next = _copy(_state!);
        next['server'] = {
          for (final row in seed['restaurants'] as List)
            row['id'].toString(): row,
        };
        next['reviews'] = seed['reviews'];
        next['version'] = seed['version'];
        next['has_snapshot'] = true;
        next['seed_packaged_at'] = seed['packaged_at'];
        await _commit(next);
      }
    }
    // Upgrade existing local catalogues without losing queued work. The durable
    // queue and an unfinished download are authoritative if an older flag differs.
    _state!['has_changes'] =
        _ops.isNotEmpty || _state!['needs_download'] == true;
  }

  void _validateSnapshot(Map<String, dynamic> data) {
    if (data['restaurants'] is! List ||
        data['reviews'] is! Map ||
        data['version'] is! String) {
      throw const FormatException(
        'Incomplete catalogue snapshot; local copy retained.',
      );
    }
    final ids = <int>{};
    for (final value in data['restaurants'] as List) {
      final row = value as Map<String, dynamic>;
      final record = Restaurant.fromJson(row);
      if (record.revision == null || !ids.add(record.id)) {
        throw const FormatException(
          'Invalid catalogue snapshot; local copy retained.',
        );
      }
    }
  }

  void networkChanged(bool eligible) {
    if (_disposed) {
      return;
    }
    _networkGeneration++;
    _localNetworkEligible = eligible;
    _reconnectTimer?.cancel();
    if (!eligible) {
      online = false;
      notifyListeners();
      return;
    }
    _networkRefreshPending = true;
    if (foreground) {
      _reconnectTimer = Timer(
        const Duration(seconds: 2),
        () => unawaited(_syncOnNetworkReturn()),
      );
    }
  }

  Future<void> _syncOnNetworkReturn() async {
    if (_disposed || !foreground || !_localNetworkEligible) {
      return;
    }
    await syncAll();
  }

  Future<void> _checkNetworkOnResume() async {
    try {
      networkChanged(await checkLocalNetwork!());
    } catch (_) {
      networkChanged(false);
    }
  }

  Future<void> _commit(
    Map<String, dynamic> next, {
    bool dataChanged = true,
  }) async {
    await store.write(
      next,
    ); // Only publish after the durable transaction commits.
    _state = next;
    if (dataChanged) {
      generation++;
    }
    notifyListeners();
  }

  void activity() => _lastActivity = DateTime.now();

  void resume() {
    foreground = true;
    activity();
    if (localNetworkChanges != null) {
      _networkSubscription ??= localNetworkChanges!.listen(
        networkChanged,
        onError: (Object _) => networkChanged(false),
      );
    }
    if (checkLocalNetwork != null) {
      unawaited(_checkNetworkOnResume());
    }
    _timer ??= Timer.periodic(const Duration(seconds: 15), (_) {
      if (foreground &&
          DateTime.now().difference(_lastActivity).inSeconds >= 5) {
        unawaited(synchronizeIfChanged());
      }
    });
  }

  void pause() {
    foreground = false;
    _timer?.cancel();
    _timer = null;
    _reconnectTimer?.cancel();
  }

  @override
  void dispose() {
    _disposed = true;
    pause();
    unawaited(_networkSubscription?.cancel());
    remote.close();
    super.dispose();
  }

  Map<String, dynamic> _project() {
    final rows = _copy(_state!['server'] as Map);
    for (final op in _ops) {
      final body = op['body'] as Map;
      final method = op['method'];
      final id = op['record_id'].toString();
      if (method == 'ADD') {
        for (final row in op['rows'] as List) {
          rows[row['id'].toString()] = _copy(row as Map);
        }
      } else if (method == 'DELETE') {
        rows.remove(id);
      } else {
        final row = _copy((rows[id] ?? op['before']) as Map);
        if (method == 'PATCH') {
          row.addAll(Map<String, dynamic>.from(body['changes'] as Map));
          row['review_status'] = 'pending';
          row['needs_review'] = 1;
        } else {
          final decision = body['decision'];
          final status = decision == 'restore' ? 'pending' : decision;
          row.addAll({
            'review_status': status,
            'needs_review': status == 'pending' ? 1 : 0,
            'review_note': body['note'],
            'reviewed_at': op['created_at'],
            'archived_at': status == 'failed' ? op['created_at'] : null,
          });
        }
        row['revision'] = 'local:${op['key']}';
        rows[id] = row;
      }
    }
    return rows;
  }

  http.Response _json(Object value, [int status = 200]) => http.Response(
    jsonEncode(value),
    status,
    headers: {'content-type': 'application/json; charset=utf-8'},
  );

  Future<http.Response> _request(
    String method,
    String path, [
    Map? body,
  ]) async {
    final request = http.Request(method, Uri.parse('$baseUrl$path'));
    if (body != null) {
      request.headers.addAll({
        'Content-Type': 'application/json',
        'X-BeneEde-Edit': '1',
      });
      request.body = jsonEncode(body);
    }
    return (() async => http.Response.fromStream(
      await remote.send(request),
    ))().timeout(const Duration(seconds: 6));
  }

  /// First launch needs one successful download; subsequent loads are local and
  /// never wait for Wi-Fi. Background synchronization updates listeners later.
  Future<http.Response> catalogue() async {
    activity();
    await _locked(_ready);
    if (!_hasLocal) {
      await synchronize();
    }
    return _locked(() async {
      if (!_hasLocal) {
        return _json({
          'error': 'Connect to your Mac once to download the catalogue.',
        }, 503);
      }
      return _json({'restaurants': _project().values.toList()});
    });
  }

  Future<http.Response> review(int id) => _locked(() async {
    activity();
    await _ready();
    final row = _project()[id.toString()];
    if (row == null) {
      return _json({'error': 'Record not found locally.'}, 404);
    }
    final cached = (_state!['reviews'] as Map)[id.toString()];
    if (cached != null) {
      return _json({
        ..._copy(cached as Map),
        'restaurant': row,
        'offline_notice': 'Saved evidence from the last sync. Changes may still be waiting to sync.',
      });
    }
    if (id > 0 && online) {
      try {
        final response = await _request('GET', '/api/restaurants/$id/review');
        if (response.statusCode == 200) {
          final details = jsonDecode(response.body) as Map<String, dynamic>;
          final next = _copy(_state!);
          (next['reviews'] as Map)[id.toString()] = details;
          await _commit(next);
          return _json({...details, 'restaurant': row});
        }
      } catch (_) {
        /* The local review remains available without Wi-Fi. */
      }
    }
    return _json({
      'restaurant': row,
      'review_reasons': [
        'Full source evidence has not been downloaded. Reconnect before relying on it.',
      ],
      'evidence': [],
      'sources': [],
      'history': [],
      'alternatives': [],
      'duplicate_ids': [],
      'confidence': row['confidence'],
      'offline_notice':
          'Only the locally saved restaurant details are available.',
    });
  });

  Future<http.Response> cities(Uri uri) async {
    try {
      final response = await _request('GET', '${uri.path}?${uri.query}');
      if (response.statusCode == 200) {
        return response;
      }
    } catch (_) {
      /* Fall back to city names already in the local catalogue. */
    }
    return _locked(() async {
      await _ready();
      final query = (uri.queryParameters['q'] ?? '').toLowerCase();
      final country = uri.queryParameters['country'] ?? '';
      final seen = <String>{};
      final values = <Map<String, dynamic>>[];
      for (final value in _project().values) {
        final row = value as Map;
        final city = (row['city'] as String?) ?? '';
        final key = '$city|${row['country']}';
        if (city.toLowerCase().contains(query) &&
            city.isNotEmpty &&
            (country.isEmpty || row['country'] == country) &&
            seen.add(key)) {
          values.add({
            'id': values.length,
            'name': city,
            'country': row['country'] ?? '',
            'region': row['region'] ?? '',
          });
        }
      }
      return _json({'cities': values.take(12).toList()});
    });
  }

  Future<http.Response> mutate(
    String method,
    int? id,
    Map<String, dynamic> body,
  ) => _locked(() async {
    activity();
    await _ready();
    final rows = _project();
    final before = id == null ? null : rows[id.toString()];
    if (id != null && before == null) {
      return _json({'error': 'Record not found locally.'}, 404);
    }
    if (before != null && before['revision'] != body['revision']) {
      return _json({
        'error': 'This record changed locally. Reopen it before saving.',
      }, 409);
    }
    if (method == 'ADD' &&
        ((body['records'] as List).length != 1 || body['lookup_id'] != null)) {
      return _json({
        'error':
            'Mobile additions support one manually entered venue at a time.',
      }, 400);
    }
    final next = _copy(_state!);
    final key = '${DateTime.now().microsecondsSinceEpoch}_${(_ops.length + 1)}';
    final op = <String, dynamic>{
      'key': key,
      'method': method,
      'record_id': id,
      'body': body,
      'before': before,
      'created_at': DateTime.now().toUtc().toIso8601String(),
    };
    if (method == 'ADD') {
      final fields = Map<String, dynamic>.from(
        (body['records'] as List).single as Map,
      );
      final localId = -DateTime.now().microsecondsSinceEpoch;
      final website = fields['internet_link'] as String? ?? '';
      final name = (fields['restaurant_name'] as String?)?.trim();
      op['record_id'] = localId;
      op['rows'] = [
        {
          ...fields,
          'id': localId,
          'restaurant_name': name == null || name.isEmpty
              ? 'Website: ${Uri.tryParse(website.contains('://') ? website : 'https://$website')?.host ?? website}'
              : name,
          'needs_review': 1,
          'review_status': 'pending',
          'revision': 'local:$key',
        },
      ];
    }
    (next['outbox'] as List).add(op);
    next['has_changes'] = true;
    await _commit(next);
    if (method == 'DELETE') {
      return _json({'deleted_id': id});
    }
    if (method == 'ADD') {
      return _json({
        'restaurants': op['rows'],
        'added_count': 1,
        'existing_count': 0,
      });
    }
    return _json({'restaurant': _project()[id.toString()]});
  });

  Future<void> synchronize() =>
      _sync ??= _synchronize().whenComplete(() => _sync = null);

  /// No HTTP requests or disk writes for a clean catalogue. Conflicts wait for
  /// a user decision instead of repeatedly contacting the Mac.
  Future<void> synchronizeIfChanged() async {
    if (checkLocalNetwork != null && !_localNetworkEligible) {
      return;
    }
    final needed = await _locked(() async {
      await _ready();
      if (_networkRefreshPending ||
          _state!['has_snapshot'] != true ||
          _state!['needs_download'] == true) {
        return true;
      }
      if (!hasChanges) {
        return false;
      }
      final blocked = <int>{};
      for (final op in _ops) {
        final id = op['record_id'] as int;
        if (op['error'] != null) {
          blocked.add(id);
        } else if (!blocked.contains(id)) {
          return true;
        }
      }
      return false;
    });
    if (needed) {
      await synchronize();
    }
  }

  /// An explicit refresh drains independent queued changes. Automatic idle work
  /// sends a single change per interval so it yields quickly to foreground use.
  Future<void> syncAll() async {
    do {
      final count = pendingCount;
      final issues = conflicts.length;
      await synchronize();
      if (!online || (pendingCount >= count && conflicts.length <= issues)) {
        break;
      }
    } while (foreground && pendingCount > 0);
  }

  Future<void> _synchronize() async {
    final networkGeneration = _networkGeneration;
    syncing = true;
    notifyListeners();
    try {
      if (checkLocalNetwork != null && !await checkLocalNetwork!()) {
        online = false;
        lastError = 'Offline — changes stay on this device until you reconnect to the Mac’s network.';
        return;
      }
      await _locked(() async {
        await _ready();
        final blocked = <int>{};
        // A short batch allows foreground editing between sync attempts.
        for (final key in _ops.map((op) => op['key']).toList()) {
          final op = _copy(_ops.firstWhere((op) => op['key'] == key));
          final id = op['record_id'] as int;
          if (op['error'] != null || blocked.contains(id)) {
            blocked.add(id);
            continue;
          }
          final method = op['method'] as String;
          final path = method == 'ADD'
              ? '/api/restaurants'
              : '/api/restaurants/$id${method == 'REVIEW' ? '/review' : ''}';
          final response = await _request(
            method == 'ADD' || method == 'REVIEW' ? 'POST' : method,
            path,
            op['body'] as Map,
          );
          if (response.statusCode == 401 ||
              response.statusCode == 403 ||
              response.statusCode >= 500) {
            throw const FormatException(
              'Mac unavailable or not paired. Open sync details to pair with the Mac. Local changes are safe.',
            );
          }
          final payload = jsonDecode(response.body) as Map<String, dynamic>;
          final next = _copy(_state!);
          final queue = next['outbox'] as List;
          final index = queue.indexWhere((item) => item['key'] == op['key']);
          if (response.statusCode != 200) {
            queue[index]['error'] =
                payload['error'] ?? 'Sync needs your attention.';
            blocked.add(id);
            await _commit(next);
            break;
          }
          if (method == 'ADD' && (payload['restaurants'] as List).length != 1) {
            queue[index]['error'] = 'The saved venue is no longer on the Mac. Your local addition is preserved.';
            await _commit(next);
            break;
          }
          if (method != 'DELETE') {
            final row = method == 'ADD'
                ? (payload['restaurants'] as List).single
                : payload['restaurant'];
            final serverId = row['id'] as int;
            (next['server'] as Map)[serverId.toString()] = row;
            // Rebase ONLY dependent local operations after our own confirmed save.
            // A Mac revision change never gets automatically overwritten.
            for (final pending in queue) {
              if (pending['key'] == op['key'] || pending['record_id'] != id) {
                continue;
              }
              pending['record_id'] = serverId;
              if (pending['before'] != null) {
                pending['before']['id'] = serverId;
              }
              if (pending['body']['revision'] == 'local:${op['key']}') {
                pending['body']['revision'] = row['revision'];
              }
            }
          } else {
            (next['server'] as Map).remove(id.toString());
          }
          queue.removeAt(index);
          next['needs_download'] = true;
          next['has_changes'] = true;
          await _commit(next);
          break;
        }
      });
      await _locked(() async {
        final version = _state!['version'] as String? ?? '';
        final response = await _request(
          'GET',
          '/api/offline-catalogue?version=$version',
        );
        if (response.statusCode != 200) {
          throw const FormatException('Could not sync with your Mac.');
        }
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        if (data['unchanged'] == true) {
          final next = _copy(_state!);
          next['last_synced'] = DateTime.now().toUtc().toIso8601String();
          next['needs_download'] = false;
          next['has_changes'] = (next['outbox'] as List).isNotEmpty;
          await _commit(next, dataChanged: false);
          online = true;
          lastError = null;
          return;
        }
        _validateSnapshot(data);
        final rows = (data['restaurants'] as List).cast<Map<String, dynamic>>();
        final next = _copy(_state!);
        next['server'] = {for (final row in rows) row['id'].toString(): row};
        next['reviews'] = data['reviews'];
        next['version'] = data['version'];
        next['has_snapshot'] = true;
        next['last_synced'] = DateTime.now().toUtc().toIso8601String();
        next['needs_download'] = false;
        next['has_changes'] = (next['outbox'] as List).isNotEmpty;
        await _commit(next);
        online = true;
        lastError = null;
      });
    } catch (error) {
      online = false;
      lastError = error is FormatException
          ? error.message.toString()
          : 'Offline — your local data is safe.';
    } finally {
      if (_networkGeneration == networkGeneration) {
        _networkRefreshPending = false;
      }
      syncing = false;
      if (!_disposed) {
        notifyListeners();
      }
    }
  }

  Map<String, dynamic>? serverRecord(int id) =>
      (_state?['server'] as Map?)?[id.toString()] as Map<String, dynamic>?;

  Map<String, dynamic>? localRecord(int id) => _state == null
      ? null
      : _project()[id.toString()] as Map<String, dynamic>?;

  Future<void> resolve(String key, {required bool useLocal}) => _locked(
    () async {
      await _ready();
      final next = _copy(_state!);
      final queue = next['outbox'] as List;
      final op = queue.firstWhere((item) => item['key'] == key) as Map;
      final id = op['record_id'] as int;
      final server = (next['server'] as Map)[id.toString()] as Map?;
      if (useLocal && (server == null || op['method'] == 'ADD')) {
        throw const FormatException(
          'This change cannot be retried against a current Mac record. Your local copy is preserved below.',
        );
      }
      (next['resolved'] as List).add({
        'resolved_at': DateTime.now().toUtc().toIso8601String(),
        'choice': useLocal ? 'local' : 'mac',
        'changes': queue
            .where((item) => item['record_id'] == id)
            .map((item) => _copy(item as Map))
            .toList(),
        'server': server,
      });
      if (useLocal) {
        op['body']['revision'] = server!['revision'];
        for (final item in queue.where((item) => item['record_id'] == id)) {
          item.remove('error');
        }
      } else {
        queue.removeWhere((item) => item['record_id'] == id);
      }
      next['has_changes'] = queue.isNotEmpty || next['needs_download'] == true;
      await _commit(next);
    },
  );

  String exportLocalHistory() => const JsonEncoder.withIndent('  ').convert({
    'pending_changes': _state?['outbox'],
    'resolved_conflicts': _state?['resolved'],
  });
}

class MobileCatalogueClient extends http.BaseClient {
  MobileCatalogueClient(this.catalogue);
  final MobileCatalogue catalogue;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final uri = request.url;
    final match = RegExp(r'^/api/restaurants/(-?\d+)(/review)?$')
        .firstMatch(uri.path);
    final list = uri.path == '/api/restaurants';
    if (uri.origin != Uri.parse(catalogue.baseUrl).origin ||
        (!list && match == null && uri.path != '/api/cities')) {
      return catalogue.remote.send(request);
    }
    http.Response response;
    if (request.method == 'GET') {
      if (list) {
        response = await catalogue.catalogue();
      } else if (uri.path == '/api/cities') {
        response = await catalogue.cities(uri);
      } else if (match?.group(2) != null) {
        response = await catalogue.review(int.parse(match!.group(1)!));
      } else {
        return catalogue.remote.send(request);
      }
    } else {
      final bytes = await request.finalize().toBytes();
      final body = jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;
      response = await catalogue.mutate(
        list
            ? 'ADD'
            : match?.group(2) != null
            ? 'REVIEW'
            : request.method,
        match == null ? null : int.parse(match.group(1)!),
        body,
      );
    }
    return http.StreamedResponse(
      Stream.value(response.bodyBytes),
      response.statusCode,
      headers: response.headers,
      request: request,
    );
  }

  @override
  void close() {} // The shared catalogue outlives individual dialogs/repositories.
}
