import 'dart:convert';

import 'package:sqflite/sqflite.dart' as sql;

/// A single transaction commits the snapshot and its durable mutation outbox.
abstract interface class CatalogueStore {
  Future<Map<String, dynamic>?> read();
  Future<void> write(Map<String, dynamic> state);
}

class SqliteCatalogueStore implements CatalogueStore {
  SqliteCatalogueStore(this.scope, {this.factory, this.path});
  final String scope;
  final sql.DatabaseFactory? factory;
  final String? path;
  Future<sql.Database>? _database;

  Future<sql.Database> get _db => _database ??= _open();

  Future<sql.Database> _open() async {
    final databaseFactory = factory ?? sql.databaseFactory;
    final databasePath =
        path ??
        '${await databaseFactory.getDatabasesPath()}/beneede_catalogue.sqlite3';
    return databaseFactory.openDatabase(
      databasePath,
      options: sql.OpenDatabaseOptions(
        version: 1,
        onCreate: (db, version) => db.execute(
          'CREATE TABLE catalogues (scope TEXT PRIMARY KEY, document TEXT NOT NULL)',
        ),
      ),
    );
  }

  @override
  Future<Map<String, dynamic>?> read() async {
    final rows = await (await _db).query(
      'catalogues',
      columns: ['document'],
      where: 'scope = ?',
      whereArgs: [scope],
    );
    return rows.isEmpty
        ? null
        : jsonDecode(rows.single['document'] as String) as Map<String, dynamic>;
  }

  @override
  Future<void> write(Map<String, dynamic> state) async {
    await (await _db).transaction(
      (txn) => txn.insert('catalogues', {
        'scope': scope,
        'document': jsonEncode(state),
      }, conflictAlgorithm: sql.ConflictAlgorithm.replace),
    );
  }

  /// Used by isolated persistence/device checks to genuinely reopen the file.
  Future<void> close() async {
    final database = _database;
    _database = null;
    if (database != null) {
      await (await database).close();
    }
  }
}
