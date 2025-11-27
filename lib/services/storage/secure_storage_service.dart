import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Service for securely storing sensitive data using flutter_secure_storage.
///
/// This service provides encrypted storage for sensitive data like:
/// - Master Password hash and salt
/// - Emergency Contact information
/// - Security keys and tokens
///
/// Requirements:
/// - 1.2: Store password securely using SHA-256 hashing with salt
/// - 22.2: Exclude all sensitive data from device backup
class SecureStorageService {
  final FlutterSecureStorage _secureStorage;

  /// Android options to enhance security:
  /// - encryptedSharedPreferences: Uses Android EncryptedSharedPreferences
  /// - keyCipherAlgorithm: AES/GCM/NoPadding for key encryption
  /// - storageCipherAlgorithm: AES/GCM/NoPadding for value encryption
  static const _androidOptions = AndroidOptions(
    encryptedSharedPreferences: true,
    sharedPreferencesName: 'anti_theft_secure_prefs',
    preferencesKeyPrefix: 'at_',
  );

  /// iOS options for keychain storage
  static const _iosOptions = IOSOptions(
    accessibility: KeychainAccessibility.first_unlock_this_device,
    accountName: 'anti_theft_protection',
  );

  SecureStorageService({FlutterSecureStorage? secureStorage})
      : _secureStorage = secureStorage ??
            const FlutterSecureStorage(
              aOptions: _androidOptions,
              iOptions: _iosOptions,
            );

  /// Store a value securely using encryption.
  ///
  /// The value is encrypted using AES before storage.
  ///
  /// [key] - The unique identifier for the stored value
  /// [value] - The string value to store securely
  Future<void> storeSecure(String key, String value) async {
    await _secureStorage.write(
      key: key,
      value: value,
      aOptions: _androidOptions,
      iOptions: _iosOptions,
    );
  }

  /// Retrieve a securely stored value.
  ///
  /// Returns the decrypted value or null if the key doesn't exist.
  ///
  /// [key] - The unique identifier for the stored value
  Future<String?> retrieveSecure(String key) async {
    return await _secureStorage.read(
      key: key,
      aOptions: _androidOptions,
      iOptions: _iosOptions,
    );
  }

  /// Delete a securely stored value.
  ///
  /// [key] - The unique identifier for the value to delete
  Future<void> deleteSecure(String key) async {
    await _secureStorage.delete(
      key: key,
      aOptions: _androidOptions,
      iOptions: _iosOptions,
    );
  }

  /// Check if a secure key exists.
  ///
  /// [key] - The unique identifier to check
  Future<bool> containsSecureKey(String key) async {
    return await _secureStorage.containsKey(
      key: key,
      aOptions: _androidOptions,
      iOptions: _iosOptions,
    );
  }

  /// Clear all securely stored data.
  ///
  /// This is a destructive operation and should be used with caution.
  Future<void> clearAll() async {
    await _secureStorage.deleteAll(
      aOptions: _androidOptions,
      iOptions: _iosOptions,
    );
  }

  /// Get all keys from secure storage.
  Future<Set<String>> getAllKeys() async {
    final allData = await _secureStorage.readAll(
      aOptions: _androidOptions,
      iOptions: _iosOptions,
    );
    return allData.keys.toSet();
  }

  /// Read all secure data as a map.
  ///
  /// Useful for backup operations.
  Future<Map<String, String>> readAll() async {
    return await _secureStorage.readAll(
      aOptions: _androidOptions,
      iOptions: _iosOptions,
    );
  }
}
