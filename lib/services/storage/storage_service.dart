import 'i_storage_service.dart';
import 'secure_storage_service.dart';
import 'shared_preferences_storage.dart';

/// Combined storage service implementing IStorageService.
///
/// This service provides a unified interface for both secure and non-sensitive
/// storage operations, delegating to the appropriate underlying service.
///
/// Requirements:
/// - 1.2: Store password securely using SHA-256 hashing with salt
/// - 2.5: Restore Protected Mode state from storage on boot
/// - 15.1: Export all settings and logs as encrypted file
/// - 22.2: Exclude all sensitive data from device backup
class StorageService implements IStorageService {
  final SecureStorageService _secureStorage;
  final SharedPreferencesStorage _prefsStorage;

  StorageService({
    SecureStorageService? secureStorage,
    SharedPreferencesStorage? prefsStorage,
  })  : _secureStorage = secureStorage ?? SecureStorageService(),
        _prefsStorage = prefsStorage ?? SharedPreferencesStorage();

  /// Initialize the storage service.
  ///
  /// Must be called before using any storage operations.
  Future<void> init() async {
    await _prefsStorage.init();
  }

  // ============ Secure Storage Operations ============

  @override
  Future<void> storeSecure(String key, String value) async {
    await _secureStorage.storeSecure(key, value);
  }

  @override
  Future<String?> retrieveSecure(String key) async {
    return await _secureStorage.retrieveSecure(key);
  }

  @override
  Future<void> deleteSecure(String key) async {
    await _secureStorage.deleteSecure(key);
  }

  @override
  Future<bool> containsSecureKey(String key) async {
    return await _secureStorage.containsSecureKey(key);
  }

  @override
  Future<Set<String>> getAllSecureKeys() async {
    return await _secureStorage.getAllKeys();
  }

  @override
  Future<void> clearSecure() async {
    await _secureStorage.clearAll();
  }

  // ============ Non-Sensitive Storage Operations ============

  @override
  Future<void> store(String key, dynamic value) async {
    await _prefsStorage.store(key, value);
  }

  @override
  Future<dynamic> retrieve(String key) async {
    return await _prefsStorage.retrieve(key);
  }

  @override
  Future<void> delete(String key) async {
    await _prefsStorage.delete(key);
  }

  @override
  Future<bool> containsKey(String key) async {
    return await _prefsStorage.containsKey(key);
  }

  @override
  Future<Set<String>> getAllKeys() async {
    return await _prefsStorage.getAllKeys();
  }

  @override
  Future<void> clearNonSecure() async {
    await _prefsStorage.clearAll();
  }

  // ============ Combined Operations ============

  @override
  Future<void> clearAll() async {
    await _secureStorage.clearAll();
    await _prefsStorage.clearAll();
  }

  /// Get all data for backup purposes.
  ///
  /// Returns a map containing both secure and non-sensitive data.
  /// Note: Secure data should be encrypted before export.
  Future<Map<String, dynamic>> getAllDataForBackup() async {
    final secureData = await _secureStorage.readAll();
    final prefsData = await _prefsStorage.readAll();

    return {
      'secure': secureData,
      'preferences': prefsData,
    };
  }

  /// Restore data from backup.
  ///
  /// [data] - Map containing 'secure' and 'preferences' keys
  Future<void> restoreFromBackup(Map<String, dynamic> data) async {
    // Restore secure data
    if (data['secure'] is Map) {
      final secureData = data['secure'] as Map<String, dynamic>;
      for (final entry in secureData.entries) {
        await _secureStorage.storeSecure(entry.key, entry.value.toString());
      }
    }

    // Restore preferences data
    if (data['preferences'] is Map) {
      final prefsData = data['preferences'] as Map<String, dynamic>;
      for (final entry in prefsData.entries) {
        await _prefsStorage.store(entry.key, entry.value);
      }
    }
  }

  // ============ Typed Accessors for Common Operations ============

  /// Store a boolean value in non-sensitive storage.
  Future<void> storeBool(String key, bool value) async {
    await _prefsStorage.store(key, value);
  }

  /// Retrieve a boolean value from non-sensitive storage.
  Future<bool> getBool(String key, {bool defaultValue = false}) async {
    return await _prefsStorage.getBool(key, defaultValue: defaultValue) ??
        defaultValue;
  }

  /// Store an integer value in non-sensitive storage.
  Future<void> storeInt(String key, int value) async {
    await _prefsStorage.store(key, value);
  }

  /// Retrieve an integer value from non-sensitive storage.
  Future<int?> getInt(String key, {int? defaultValue}) async {
    return await _prefsStorage.getInt(key, defaultValue: defaultValue);
  }

  /// Store a string value in non-sensitive storage.
  Future<void> storeString(String key, String value) async {
    await _prefsStorage.store(key, value);
  }

  /// Retrieve a string value from non-sensitive storage.
  Future<String?> getString(String key, {String? defaultValue}) async {
    return await _prefsStorage.getString(key, defaultValue: defaultValue);
  }

  /// Store a map value in non-sensitive storage (as JSON).
  Future<void> storeMap(String key, Map<String, dynamic> value) async {
    await _prefsStorage.store(key, value);
  }

  /// Retrieve a map value from non-sensitive storage.
  Future<Map<String, dynamic>?> getMap(String key) async {
    return await _prefsStorage.getMap(key);
  }
}
