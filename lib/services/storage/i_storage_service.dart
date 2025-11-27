/// Interface for storage operations in the Anti-Theft Protection app.
///
/// This interface defines the contract for storing and retrieving data,
/// supporting both secure (encrypted) storage for sensitive data and
/// regular storage for non-sensitive configuration.
///
/// Requirements: 15.1 - Export all settings and logs as encrypted file
abstract class IStorageService {
  /// Store a value securely using encryption.
  ///
  /// Use this for sensitive data like passwords, keys, and security logs.
  /// The value will be encrypted before storage.
  ///
  /// [key] - The unique identifier for the stored value
  /// [value] - The string value to store securely
  Future<void> storeSecure(String key, String value);

  /// Retrieve a securely stored value.
  ///
  /// Returns the decrypted value or null if the key doesn't exist.
  ///
  /// [key] - The unique identifier for the stored value
  Future<String?> retrieveSecure(String key);

  /// Delete a securely stored value.
  ///
  /// [key] - The unique identifier for the value to delete
  Future<void> deleteSecure(String key);

  /// Check if a secure key exists.
  ///
  /// [key] - The unique identifier to check
  Future<bool> containsSecureKey(String key);

  /// Store a non-sensitive value.
  ///
  /// Use this for configuration settings that don't require encryption.
  ///
  /// [key] - The unique identifier for the stored value
  /// [value] - The value to store (supports String, int, double, bool, List<String>)
  Future<void> store(String key, dynamic value);

  /// Retrieve a non-sensitive stored value.
  ///
  /// Returns the value or null if the key doesn't exist.
  ///
  /// [key] - The unique identifier for the stored value
  Future<dynamic> retrieve(String key);

  /// Delete a non-sensitive stored value.
  ///
  /// [key] - The unique identifier for the value to delete
  Future<void> delete(String key);

  /// Check if a non-sensitive key exists.
  ///
  /// [key] - The unique identifier to check
  Future<bool> containsKey(String key);

  /// Clear all stored data (both secure and non-sensitive).
  ///
  /// This is a destructive operation and should be used with caution.
  Future<void> clearAll();

  /// Clear only secure storage.
  Future<void> clearSecure();

  /// Clear only non-sensitive storage.
  Future<void> clearNonSecure();

  /// Get all keys from secure storage.
  Future<Set<String>> getAllSecureKeys();

  /// Get all keys from non-sensitive storage.
  Future<Set<String>> getAllKeys();
}
