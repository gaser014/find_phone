import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// Service for storing non-sensitive configuration using SharedPreferences.
///
/// This service provides storage for configuration settings that don't
/// require encryption, such as:
/// - Protected Mode state
/// - Auto-protection schedule
/// - UI preferences
/// - Feature toggles
///
/// Requirements:
/// - 2.5: Restore Protected Mode state from storage on boot
class SharedPreferencesStorage {
  SharedPreferences? _prefs;
  final String _keyPrefix;

  /// Creates a SharedPreferencesStorage with an optional key prefix.
  ///
  /// [keyPrefix] - Optional prefix for all keys to avoid collisions
  SharedPreferencesStorage({String keyPrefix = 'at_config_'})
      : _keyPrefix = keyPrefix;

  /// Initialize SharedPreferences instance.
  ///
  /// Must be called before using any storage operations.
  Future<void> init() async {
    _prefs ??= await SharedPreferences.getInstance();
  }

  /// Ensure preferences are initialized.
  Future<SharedPreferences> _ensureInitialized() async {
    if (_prefs == null) {
      await init();
    }
    return _prefs!;
  }

  /// Get the prefixed key.
  String _prefixedKey(String key) => '$_keyPrefix$key';

  /// Store a value.
  ///
  /// Supports String, int, double, bool, List<String>, and Map (as JSON).
  ///
  /// [key] - The unique identifier for the stored value
  /// [value] - The value to store
  Future<void> store(String key, dynamic value) async {
    final prefs = await _ensureInitialized();
    final prefixedKey = _prefixedKey(key);

    if (value == null) {
      await prefs.remove(prefixedKey);
      return;
    }

    if (value is String) {
      await prefs.setString(prefixedKey, value);
    } else if (value is int) {
      await prefs.setInt(prefixedKey, value);
    } else if (value is double) {
      await prefs.setDouble(prefixedKey, value);
    } else if (value is bool) {
      await prefs.setBool(prefixedKey, value);
    } else if (value is List<String>) {
      await prefs.setStringList(prefixedKey, value);
    } else if (value is Map || value is List) {
      // Store complex objects as JSON
      await prefs.setString(prefixedKey, jsonEncode(value));
    } else {
      throw ArgumentError(
        'Unsupported type: ${value.runtimeType}. '
        'Supported types: String, int, double, bool, List<String>, Map, List',
      );
    }
  }

  /// Retrieve a stored value.
  ///
  /// Returns the value or null if the key doesn't exist.
  ///
  /// [key] - The unique identifier for the stored value
  Future<dynamic> retrieve(String key) async {
    final prefs = await _ensureInitialized();
    final prefixedKey = _prefixedKey(key);
    return prefs.get(prefixedKey);
  }

  /// Retrieve a stored value as a specific type.
  ///
  /// [key] - The unique identifier for the stored value
  /// [defaultValue] - Value to return if key doesn't exist
  Future<T?> retrieveTyped<T>(String key, {T? defaultValue}) async {
    final prefs = await _ensureInitialized();
    final prefixedKey = _prefixedKey(key);

    final Object? value = prefs.get(prefixedKey);
    if (value == null) return defaultValue;

    // Direct type check and cast
    try {
      if (value is T) {
        // ignore: unnecessary_cast
        return value as T;
      }

      // Try to decode JSON for complex types
      if (value is String) {
        final decoded = jsonDecode(value);
        if (decoded is T) {
          // ignore: unnecessary_cast
          return decoded as T;
        }
      }
    } catch (_) {
      // Fall through to return default
    }

    return defaultValue;
  }

  /// Retrieve a string value.
  Future<String?> getString(String key, {String? defaultValue}) async {
    final prefs = await _ensureInitialized();
    return prefs.getString(_prefixedKey(key)) ?? defaultValue;
  }

  /// Retrieve an integer value.
  Future<int?> getInt(String key, {int? defaultValue}) async {
    final prefs = await _ensureInitialized();
    return prefs.getInt(_prefixedKey(key)) ?? defaultValue;
  }

  /// Retrieve a double value.
  Future<double?> getDouble(String key, {double? defaultValue}) async {
    final prefs = await _ensureInitialized();
    return prefs.getDouble(_prefixedKey(key)) ?? defaultValue;
  }

  /// Retrieve a boolean value.
  Future<bool?> getBool(String key, {bool? defaultValue}) async {
    final prefs = await _ensureInitialized();
    return prefs.getBool(_prefixedKey(key)) ?? defaultValue;
  }

  /// Retrieve a string list value.
  Future<List<String>?> getStringList(String key,
      {List<String>? defaultValue}) async {
    final prefs = await _ensureInitialized();
    return prefs.getStringList(_prefixedKey(key)) ?? defaultValue;
  }

  /// Retrieve a JSON-encoded map.
  Future<Map<String, dynamic>?> getMap(String key) async {
    final prefs = await _ensureInitialized();
    final jsonString = prefs.getString(_prefixedKey(key));
    if (jsonString == null) return null;

    try {
      return jsonDecode(jsonString) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  /// Delete a stored value.
  ///
  /// [key] - The unique identifier for the value to delete
  Future<void> delete(String key) async {
    final prefs = await _ensureInitialized();
    await prefs.remove(_prefixedKey(key));
  }

  /// Check if a key exists.
  ///
  /// [key] - The unique identifier to check
  Future<bool> containsKey(String key) async {
    final prefs = await _ensureInitialized();
    return prefs.containsKey(_prefixedKey(key));
  }

  /// Clear all stored data with the configured prefix.
  Future<void> clearAll() async {
    final prefs = await _ensureInitialized();
    final keys = prefs.getKeys().where((k) => k.startsWith(_keyPrefix));
    for (final key in keys) {
      await prefs.remove(key);
    }
  }

  /// Get all keys with the configured prefix.
  Future<Set<String>> getAllKeys() async {
    final prefs = await _ensureInitialized();
    return prefs
        .getKeys()
        .where((k) => k.startsWith(_keyPrefix))
        .map((k) => k.substring(_keyPrefix.length))
        .toSet();
  }

  /// Read all data as a map.
  ///
  /// Useful for backup operations.
  Future<Map<String, dynamic>> readAll() async {
    final prefs = await _ensureInitialized();
    final result = <String, dynamic>{};

    for (final key in prefs.getKeys()) {
      if (key.startsWith(_keyPrefix)) {
        final shortKey = key.substring(_keyPrefix.length);
        result[shortKey] = prefs.get(key);
      }
    }

    return result;
  }

  /// Reload preferences from disk.
  ///
  /// Useful when preferences might have been modified externally.
  Future<void> reload() async {
    final prefs = await _ensureInitialized();
    await prefs.reload();
  }
}
