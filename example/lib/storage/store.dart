import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:sqflite/sqflite.dart';
import 'dart:math';

/// Generates unique IDs for documents
class IdGenerator {
  static String generateId() {
    final timestamp =
        DateTime.now().millisecondsSinceEpoch.toRadixString(16).padLeft(8, '0');
    final randomPart = _getRandomPart();
    final counter = _getCounter();
    return '$timestamp$randomPart$counter';
  }

  static String _getRandomPart() {
    final rand = Random();
    List<int> randomBytes = List.generate(5, (index) => rand.nextInt(256));
    return base64Url.encode(randomBytes);
  }

  static String _getCounter() {
    return Random().nextInt(256).toString().padLeft(3, '0');
  }
}

/// Main database class that manages collections
class FlutterDB {
  static final FlutterDB _instance = FlutterDB._internal();
  static Database? _database;
  static const int _version = 1;

  factory FlutterDB() {
    return _instance;
  }

  FlutterDB._internal();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    Directory directory = await getApplicationDocumentsDirectory();
    String dbPath = path.join(directory.path, 'flutterdb.db');
    return await openDatabase(
      dbPath,
      version: _version,
      onCreate: _createDb,
    );
  }

  Future<void> _createDb(Database db, int version) async {
    await db.execute('''
      CREATE TABLE collections (
        name TEXT PRIMARY KEY
      )
    ''');

    await db.execute('''
      CREATE TABLE documents (
        id TEXT PRIMARY KEY,
        collection_name TEXT,
        data TEXT,
        created_at INTEGER,
        updated_at INTEGER,
        FOREIGN KEY (collection_name) REFERENCES collections (name) ON DELETE CASCADE
      )
    ''');

    // Create indexes for faster querying
    await db
        .execute('CREATE INDEX idx_collection ON documents (collection_name)');
    await db.execute('PRAGMA journal_mode=WAL;');
  }

  /// Creates a collection if it doesn't exist
  Future<Collection> collection(String name) async {
    final db = await database;

    // Check if collection exists
    final collections = await db.query(
      'collections',
      where: 'name = ?',
      whereArgs: [name],
    );

    // If collection doesn't exist, create it
    if (collections.isEmpty) {
      await db.insert('collections', {'name': name});
    }

    return Collection(name, db);
  }

  /// Drops a collection
  Future<bool> dropCollection(String name) async {
    final db = await database;
    try {
      await db.delete(
        'collections',
        where: 'name = ?',
        whereArgs: [name],
      );
      await db.delete(
        'documents',
        where: 'collection_name = ?',
        whereArgs: [name],
      );
      return true;
    } catch (e) {
      print('Error dropping collection: $e');
      return false;
    }
  }

  /// Lists all collections
  Future<List<String>> listCollections() async {
    final db = await database;
    final collections = await db.query('collections');
    return collections.map((c) => c['name'] as String).toList();
  }
}

/// Represents a collection in the database
class Collection {
  final String name;
  final Database _db;

  Collection(this.name, this._db);

  /// Inserts a document into the collection
  Future<String> insert(Map<String, dynamic> document) async {
    final id = document['_id'] ?? IdGenerator.generateId();
    document['_id'] = id;

    final now = DateTime.now().millisecondsSinceEpoch;

    await _db.insert('documents', {
      'id': id,
      'collection_name': name,
      'data': jsonEncode(document),
      'created_at': now,
      'updated_at': now,
    });

    return id;
  }

  /// Inserts multiple documents into the collection
  Future<List<String>> insertMany(List<Map<String, dynamic>> documents) async {
    final ids = <String>[];
    final now = DateTime.now().millisecondsSinceEpoch;

    await _db.transaction((txn) async {
      final batch = txn.batch();
      for (var document in documents) {
        final id = document['_id'] ?? IdGenerator.generateId();
        document['_id'] = id;
        ids.add(id);

        batch.insert('documents', {
          'id': id,
          'collection_name': name,
          'data': jsonEncode(document),
          'created_at': now,
          'updated_at': now,
        });
      }
      await batch.commit(noResult: true);
    });

    return ids;
  }

  /// Finds documents matching the query
  Future<List<Map<String, dynamic>>> find(Map<String, dynamic> query) async {
    // First get all documents in the collection
    final results = await _db.query(
      'documents',
      where: 'collection_name = ?',
      whereArgs: [name],
    );

    if (query.isEmpty) {
      // If no query, return all documents
      return results
          .map((doc) =>
              jsonDecode(doc['data'] as String) as Map<String, dynamic>)
          .toList();
    }

    // Filter documents based on query
    final filteredResults = results.where((doc) {
      final document =
          jsonDecode(doc['data'] as String) as Map<String, dynamic>;
      return _matchesQuery(document, query);
    }).toList();

    return filteredResults
        .map((doc) => jsonDecode(doc['data'] as String) as Map<String, dynamic>)
        .toList();
  }

  /// Finds a single document by ID
  Future<Map<String, dynamic>?> findById(String id) async {
    final results = await _db.query(
      'documents',
      where: 'id = ? AND collection_name = ?',
      whereArgs: [id, name],
    );

    if (results.isEmpty) return null;
    return jsonDecode(results.first['data'] as String) as Map<String, dynamic>;
  }

  /// Updates a document by ID
  Future<bool> updateById(String id, Map<String, dynamic> update) async {
    // First get the document
    final doc = await findById(id);
    if (doc == null) return false;

    // Merge the update with the existing document
    doc.addAll(update);
    doc['_id'] = id; // Ensure ID is preserved

    // Update the document
    final now = DateTime.now().millisecondsSinceEpoch;
    final count = await _db.update(
      'documents',
      {
        'data': jsonEncode(doc),
        'updated_at': now,
      },
      where: 'id = ? AND collection_name = ?',
      whereArgs: [id, name],
    );

    return count > 0;
  }

  /// Updates documents matching the query
  Future<int> updateMany(
      Map<String, dynamic> query, Map<String, dynamic> update) async {
    // First find all matching documents
    final docs = await find(query);
    if (docs.isEmpty) return 0;

    final batch = _db.batch();
    final now = DateTime.now().millisecondsSinceEpoch;

    for (var doc in docs) {
      final id = doc['_id'] as String;
      doc.addAll(update);
      doc['_id'] = id; // Ensure ID is preserved

      batch.update(
        'documents',
        {
          'data': jsonEncode(doc),
          'updated_at': now,
        },
        where: 'id = ? AND collection_name = ?',
        whereArgs: [id, name],
      );
    }

    await batch.commit(noResult: true);
    return docs.length;
  }

  /// Deletes a document by ID
  Future<bool> deleteById(String id) async {
    final count = await _db.delete(
      'documents',
      where: 'id = ? AND collection_name = ?',
      whereArgs: [id, name],
    );

    return count > 0;
  }

  /// Deletes documents matching the query
  Future<int> deleteMany(Map<String, dynamic> query) async {
    // First find all matching documents
    final docs = await find(query);
    if (docs.isEmpty) return 0;

    final batch = _db.batch();

    for (var doc in docs) {
      final id = doc['_id'] as String;
      batch.delete(
        'documents',
        where: 'id = ? AND collection_name = ?',
        whereArgs: [id, name],
      );
    }

    await batch.commit(noResult: true);
    return docs.length;
  }

  /// Counts documents matching the query
  Future<int> count([Map<String, dynamic>? query]) async {
    if (query == null || query.isEmpty) {
      final result = await _db.rawQuery(
        'SELECT COUNT(*) as count FROM documents WHERE collection_name = ?',
        [name],
      );
      return Sqflite.firstIntValue(result) ?? 0;
    }

    // If there's a query, we need to find matching documents first
    final docs = await find(query);
    return docs.length;
  }

  /// Performs aggregation operations
  Future<List<Map<String, dynamic>>> aggregate(
      List<Map<String, dynamic>> pipeline) async {
    // Basic implementation of aggregation - can be expanded
    List<Map<String, dynamic>> results = await find({});

    for (var stage in pipeline) {
      if (stage.containsKey('\$match')) {
        final matchQuery = stage['\$match'] as Map<String, dynamic>;
        results =
            results.where((doc) => _matchesQuery(doc, matchQuery)).toList();
      } else if (stage.containsKey('\$sort')) {
        final sortFields = stage['\$sort'] as Map<String, dynamic>;
        results.sort((a, b) {
          for (var field in sortFields.keys) {
            final direction = sortFields[field] as int;
            final valueA = _getNestedValue(a, field);
            final valueB = _getNestedValue(b, field);

            int comparison;
            if (valueA == null && valueB == null) {
              comparison = 0;
            } else if (valueA == null) {
              comparison = -1;
            } else if (valueB == null) {
              comparison = 1;
            } else if (valueA is Comparable && valueB is Comparable) {
              comparison = valueA.compareTo(valueB);
            } else {
              comparison = 0;
            }

            if (comparison != 0) {
              return direction * comparison;
            }
          }
          return 0;
        });
      } else if (stage.containsKey('\$limit')) {
        final limit = stage['\$limit'] as int;
        results = results.take(limit).toList();
      } else if (stage.containsKey('\$skip')) {
        final skip = stage['\$skip'] as int;
        if (skip < results.length) {
          results = results.sublist(skip);
        } else {
          results = [];
        }
      }
      // Add more aggregation stages as needed
    }

    return results;
  }

  /// Gets a nested value from a document using dot notation
  dynamic _getNestedValue(Map<String, dynamic> doc, String field) {
    final parts = field.split('.');
    dynamic value = doc;

    for (var part in parts) {
      if (value is Map<String, dynamic>) {
        value = value[part];
      } else {
        return null;
      }
    }

    return value;
  }

  /// Matches a document against a query
  bool _matchesQuery(
      Map<String, dynamic> document, Map<String, dynamic> query) {
    for (var key in query.keys) {
      var queryValue = query[key];

      if (key.startsWith('\$')) {
        // Handle top-level operators
        switch (key) {
          case '\$or':
            if (queryValue is! List) return false;
            bool orMatches = false;
            for (var subQuery in queryValue) {
              if (_matchesQuery(document, subQuery)) {
                orMatches = true;
                break;
              }
            }
            if (!orMatches) return false;
            break;
          case '\$and':
            if (queryValue is! List) return false;
            for (var subQuery in queryValue) {
              if (!_matchesQuery(document, subQuery)) {
                return false;
              }
            }
            break;
          case '\$nor':
            if (queryValue is! List) return false;
            for (var subQuery in queryValue) {
              if (_matchesQuery(document, subQuery)) {
                return false;
              }
            }
            break;
          default:
            return false;
        }
      } else if (queryValue is Map<String, dynamic>) {
        // Handle field operators
        var docValue = _getNestedValue(document, key);

        for (var op in queryValue.keys) {
          var expectedValue = queryValue[op];

          switch (op) {
            case '\$eq':
              if (docValue != expectedValue) return false;
              break;
            case '\$gt':
              if (!(docValue is num &&
                  expectedValue is num &&
                  docValue > expectedValue)) {
                return false;
              }
              break;
            case '\$gte':
              if (!(docValue is num &&
                  expectedValue is num &&
                  docValue >= expectedValue)) {
                return false;
              }
              break;
            case '\$lt':
              if (!(docValue is num &&
                  expectedValue is num &&
                  docValue < expectedValue)) {
                return false;
              }
              break;
            case '\$lte':
              if (!(docValue is num &&
                  expectedValue is num &&
                  docValue <= expectedValue)) {
                return false;
              }
              break;
            case '\$ne':
              if (docValue == expectedValue) return false;
              break;
            case '\$in':
              if (!(expectedValue is List && expectedValue.contains(docValue))) {
                return false;
              }
              break;
            case '\$nin':
              if (!(expectedValue is List && !expectedValue.contains(docValue))) {
                return false;
              }
              break;
            case '\$exists':
              final exists = document.containsKey(key) || docValue != null;
              if (expectedValue is bool && exists != expectedValue) {
                return false;
              }
              break;
            case '\$regex':
              if (!(docValue is String && expectedValue is String)) {
                return false;
              }
              try {
                final regex = RegExp(expectedValue);
                if (!regex.hasMatch(docValue)) return false;
              } catch (e) {
                return false;
              }
              break;
            case '\$like':
              if (!(docValue is String &&
                  expectedValue is String &&
                  docValue.contains(expectedValue))) {
                return false;
              }
              break;
            default:
              return false;
          }
        }
      } else {
        // Simple equality match
        final docValue = _getNestedValue(document, key);
        if (docValue != queryValue) return false;
      }
    }

    return true;
  }
}
