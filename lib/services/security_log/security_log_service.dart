import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:sqflite_sqlcipher/sqflite.dart';
import 'package:crypto/crypto.dart';

import '../../domain/entities/security_event.dart';
import 'i_security_log_service.dart';

/// Implementation of [ISecurityLogService] using SQLCipher for encrypted storage.
///
/// This service provides secure storage for security events using an encrypted
/// SQLite database. All events are stored with full metadata including
/// timestamp, location, and optional photo paths.
///
/// Requirements:
/// - 4.3: Record unauthorized access events in secure log storage
/// - 19.3: Store call logs in encrypted Security Log
/// - 10.5: Automatic log rotation (keep last 1000 events)
class SecurityLogService implements ISecurityLogService {
  static const String databaseName = 'security_logs.db';
  static const String tableName = 'security_events';
  static const int maxLogEntries = 1000;
  static const int databaseVersion = 1;

  Database? _database;
  bool _isInitialized = false;
  String? _dbPath;

  /// Password verification callback for clearing logs
  final Future<bool> Function(String password)? _passwordVerifier;
  
  /// Optional custom database path for testing
  final String? customDbPath;

  SecurityLogService({
    Future<bool> Function(String password)? passwordVerifier,
    this.customDbPath,
  }) : _passwordVerifier = passwordVerifier;

  @override
  bool get isInitialized => _isInitialized;

  @override
  Future<void> initialize(String encryptionKey) async {
    if (_isInitialized) return;

    if (customDbPath != null) {
      _dbPath = customDbPath;
    } else {
      final directory = await getApplicationDocumentsDirectory();
      _dbPath = '${directory.path}/$databaseName';
    }

    _database = await openDatabase(
      _dbPath!,
      version: databaseVersion,
      password: encryptionKey,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );

    _isInitialized = true;
  }
  
  /// Initialize with a pre-opened database (for testing)
  Future<void> initializeWithDatabase(Database database) async {
    if (_isInitialized) return;
    
    _database = database;
    _isInitialized = true;
  }
  
  /// Static method to create the database schema (for testing)
  static Future<void> createSchema(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $tableName (
        id TEXT PRIMARY KEY,
        type TEXT NOT NULL,
        timestamp TEXT NOT NULL,
        description TEXT NOT NULL,
        metadata TEXT NOT NULL,
        location TEXT,
        photo_path TEXT,
        created_at INTEGER NOT NULL
      )
    ''');

    // Create indexes for efficient querying
    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_type ON $tableName (type)
    ''');
    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_timestamp ON $tableName (timestamp)
    ''');
    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_created_at ON $tableName (created_at)
    ''');
  }

  Future<void> _onCreate(Database db, int version) async {
    await createSchema(db);
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    // Handle future database migrations here
  }

  void _ensureInitialized() {
    if (!_isInitialized || _database == null) {
      throw StateError(
        'SecurityLogService not initialized. Call initialize() first.',
      );
    }
  }

  @override
  Future<void> logEvent(SecurityEvent event) async {
    _ensureInitialized();

    await _database!.insert(
      tableName,
      _eventToMap(event),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );

    // Perform automatic log rotation
    await _performLogRotation();
  }


  /// Performs automatic log rotation to keep only the last [maxLogEntries] events.
  ///
  /// Requirements: 10.5 - Automatic log rotation (keep last 1000 events)
  Future<void> _performLogRotation() async {
    final count = await getEventCount();
    if (count > maxLogEntries) {
      final deleteCount = count - maxLogEntries;
      await _database!.execute('''
        DELETE FROM $tableName 
        WHERE id IN (
          SELECT id FROM $tableName 
          ORDER BY created_at ASC 
          LIMIT ?
        )
      ''', [deleteCount]);
    }
  }

  Map<String, dynamic> _eventToMap(SecurityEvent event) {
    return {
      'id': event.id,
      'type': event.type.name,
      'timestamp': event.timestamp.toIso8601String(),
      'description': event.description,
      'metadata': jsonEncode(event.metadata),
      'location': event.location != null ? jsonEncode(event.location) : null,
      'photo_path': event.photoPath,
      'created_at': event.timestamp.millisecondsSinceEpoch,
    };
  }

  SecurityEvent _mapToEvent(Map<String, dynamic> map) {
    return SecurityEvent(
      id: map['id'] as String,
      type: SecurityEventType.values.firstWhere(
        (e) => e.name == map['type'],
        orElse: () => SecurityEventType.failedLogin,
      ),
      timestamp: DateTime.parse(map['timestamp'] as String),
      description: map['description'] as String,
      metadata: jsonDecode(map['metadata'] as String) as Map<String, dynamic>,
      location: map['location'] != null
          ? jsonDecode(map['location'] as String) as Map<String, dynamic>
          : null,
      photoPath: map['photo_path'] as String?,
    );
  }

  @override
  Future<List<SecurityEvent>> getAllEvents() async {
    _ensureInitialized();

    final results = await _database!.query(
      tableName,
      orderBy: 'timestamp DESC',
    );

    return results.map(_mapToEvent).toList();
  }

  @override
  Future<List<SecurityEvent>> getEventsByType(SecurityEventType type) async {
    _ensureInitialized();

    final results = await _database!.query(
      tableName,
      where: 'type = ?',
      whereArgs: [type.name],
      orderBy: 'timestamp DESC',
    );

    return results.map(_mapToEvent).toList();
  }

  @override
  Future<List<SecurityEvent>> getEventsByDateRange(
    DateTime start,
    DateTime end,
  ) async {
    _ensureInitialized();

    final results = await _database!.query(
      tableName,
      where: 'timestamp >= ? AND timestamp <= ?',
      whereArgs: [start.toIso8601String(), end.toIso8601String()],
      orderBy: 'timestamp DESC',
    );

    return results.map(_mapToEvent).toList();
  }

  @override
  Future<List<SecurityEvent>> getEventsByTypeAndDateRange(
    SecurityEventType type,
    DateTime start,
    DateTime end,
  ) async {
    _ensureInitialized();

    final results = await _database!.query(
      tableName,
      where: 'type = ? AND timestamp >= ? AND timestamp <= ?',
      whereArgs: [type.name, start.toIso8601String(), end.toIso8601String()],
      orderBy: 'timestamp DESC',
    );

    return results.map(_mapToEvent).toList();
  }

  @override
  Future<SecurityEvent?> getEventById(String id) async {
    _ensureInitialized();

    final results = await _database!.query(
      tableName,
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );

    if (results.isEmpty) return null;
    return _mapToEvent(results.first);
  }

  @override
  Future<int> getEventCount() async {
    _ensureInitialized();

    final result = await _database!.rawQuery(
      'SELECT COUNT(*) as count FROM $tableName',
    );

    return Sqflite.firstIntValue(result) ?? 0;
  }

  @override
  Future<int> getEventCountByType(SecurityEventType type) async {
    _ensureInitialized();

    final result = await _database!.rawQuery(
      'SELECT COUNT(*) as count FROM $tableName WHERE type = ?',
      [type.name],
    );

    return Sqflite.firstIntValue(result) ?? 0;
  }

  @override
  Future<bool> clearLogs(String password) async {
    _ensureInitialized();

    // Verify password if verifier is provided
    if (_passwordVerifier != null) {
      final isValid = await _passwordVerifier(password);
      if (!isValid) return false;
    }

    await _database!.delete(tableName);
    return true;
  }

  @override
  Future<List<SecurityEvent>> getRecentEvents(int limit) async {
    _ensureInitialized();

    final results = await _database!.query(
      tableName,
      orderBy: 'timestamp DESC',
      limit: limit,
    );

    return results.map(_mapToEvent).toList();
  }

  @override
  Future<bool> deleteEvent(String id) async {
    _ensureInitialized();

    final count = await _database!.delete(
      tableName,
      where: 'id = ?',
      whereArgs: [id],
    );

    return count > 0;
  }


  @override
  Future<File> exportLogs(String password) async {
    _ensureInitialized();

    // Get all events
    final events = await getAllEvents();

    // Convert to JSON
    final jsonData = {
      'version': databaseVersion,
      'exported_at': DateTime.now().toIso8601String(),
      'event_count': events.length,
      'events': events.map((e) => e.toJson()).toList(),
    };

    final jsonString = jsonEncode(jsonData);

    // Encrypt the JSON data
    final encryptedData = _encryptData(jsonString, password);

    // Write to file
    String filePath;
    if (customDbPath != null) {
      final dbDir = File(customDbPath!).parent.path;
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      filePath = '$dbDir/security_logs_$timestamp.enc';
    } else {
      final directory = await getApplicationDocumentsDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      filePath = '${directory.path}/security_logs_$timestamp.enc';
    }
    final file = File(filePath);

    await file.writeAsString(encryptedData);

    return file;
  }

  @override
  Future<bool> importLogs(File file, String password) async {
    _ensureInitialized();

    try {
      // Read encrypted data
      final encryptedData = await file.readAsString();

      // Decrypt the data
      final jsonString = _decryptData(encryptedData, password);
      if (jsonString == null) return false;

      // Parse JSON
      final jsonData = jsonDecode(jsonString) as Map<String, dynamic>;
      final eventsList = jsonData['events'] as List<dynamic>;

      // Import events
      for (final eventJson in eventsList) {
        final event = SecurityEvent.fromJson(eventJson as Map<String, dynamic>);
        await _database!.insert(
          tableName,
          _eventToMap(event),
          conflictAlgorithm: ConflictAlgorithm.ignore,
        );
      }

      // Perform log rotation after import
      await _performLogRotation();

      return true;
    } catch (e) {
      return false;
    }
  }

  /// Encrypts data using AES-like encryption with the provided password.
  ///
  /// Note: This is a simplified encryption for demonstration.
  /// In production, use a proper AES encryption library.
  String _encryptData(String data, String password) {
    // Generate key from password using SHA-256
    final keyBytes = sha256.convert(utf8.encode(password)).bytes;
    final dataBytes = utf8.encode(data);

    // XOR encryption (simplified - use proper AES in production)
    final encryptedBytes = <int>[];
    for (int i = 0; i < dataBytes.length; i++) {
      encryptedBytes.add(dataBytes[i] ^ keyBytes[i % keyBytes.length]);
    }

    return base64Encode(encryptedBytes);
  }

  /// Decrypts data using the provided password.
  String? _decryptData(String encryptedData, String password) {
    try {
      // Generate key from password using SHA-256
      final keyBytes = sha256.convert(utf8.encode(password)).bytes;
      final encryptedBytes = base64Decode(encryptedData);

      // XOR decryption
      final decryptedBytes = <int>[];
      for (int i = 0; i < encryptedBytes.length; i++) {
        decryptedBytes.add(encryptedBytes[i] ^ keyBytes[i % keyBytes.length]);
      }

      return utf8.decode(decryptedBytes);
    } catch (e) {
      return null;
    }
  }

  @override
  Future<void> close() async {
    if (_database != null && _database!.isOpen) {
      await _database!.close();
      _database = null;
    }
    _isInitialized = false;
  }
}
