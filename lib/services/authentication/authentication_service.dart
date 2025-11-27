import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

import '../storage/storage.dart';
import 'i_authentication_service.dart';

/// Storage keys for authentication data.
class AuthStorageKeys {
  static const String passwordHash = 'master_password_hash';
  static const String passwordSalt = 'password_salt';
  static const String failedAttempts = 'failed_attempts_count';
  static const String lastFailedAttempt = 'last_failed_attempt_time';
}

/// Implementation of IAuthenticationService.
///
/// Provides secure password management using SHA-256 hashing with random salt.
/// Tracks failed authentication attempts and triggers security alerts.
///
/// Requirements:
/// - 1.1: Create Master Password with minimum 8 characters including letters and numbers
/// - 1.2: Validate password strength and store securely using SHA-256 hashing with salt
/// - 1.4: Require Master Password for configuration changes or app exit
/// - 1.5: Trigger security alert after 3 consecutive incorrect password attempts
/// - 1.6: Reset failed attempt counter on successful login
class AuthenticationService implements IAuthenticationService {
  final IStorageService _storageService;

  /// The threshold for failed attempts before triggering security alert.
  static const int failedAttemptThreshold = 3;

  /// Minimum password length requirement.
  static const int minPasswordLength = 8;

  AuthenticationService({required IStorageService storageService})
      : _storageService = storageService;

  /// Generate a cryptographically secure random salt.
  ///
  /// Returns a 32-byte random salt encoded as base64 string.
  String generateSalt() {
    final random = Random.secure();
    final saltBytes = Uint8List(32);
    for (int i = 0; i < 32; i++) {
      saltBytes[i] = random.nextInt(256);
    }
    return base64Encode(saltBytes);
  }

  /// Hash a password using SHA-256 with the provided salt.
  ///
  /// The password and salt are combined and hashed using SHA-256.
  ///
  /// [password] - The password to hash
  /// [salt] - The salt to use for hashing
  ///
  /// Returns the hash as a hex string.
  String hashPassword(String password, String salt) {
    final combined = utf8.encode(password + salt);
    final digest = sha256.convert(combined);
    return digest.toString();
  }


  @override
  bool validatePasswordStrength(String password) {
    // Check minimum length
    if (password.length < minPasswordLength) {
      return false;
    }

    // Check for at least one letter
    final hasLetter = RegExp(r'[a-zA-Z]').hasMatch(password);
    if (!hasLetter) {
      return false;
    }

    // Check for at least one number
    final hasNumber = RegExp(r'[0-9]').hasMatch(password);
    if (!hasNumber) {
      return false;
    }

    return true;
  }

  @override
  Future<bool> setupMasterPassword(String password) async {
    // Validate password strength
    if (!validatePasswordStrength(password)) {
      return false;
    }

    // Check if password is already set
    if (await isPasswordSet()) {
      return false;
    }

    // Generate salt and hash password
    final salt = generateSalt();
    final hash = hashPassword(password, salt);

    // Store hash and salt securely
    await _storageService.storeSecure(AuthStorageKeys.passwordHash, hash);
    await _storageService.storeSecure(AuthStorageKeys.passwordSalt, salt);

    // Reset failed attempts
    await resetFailedAttempts();

    return true;
  }

  @override
  Future<bool> verifyPassword(String password) async {
    // Get stored hash and salt
    final storedHash =
        await _storageService.retrieveSecure(AuthStorageKeys.passwordHash);
    final storedSalt =
        await _storageService.retrieveSecure(AuthStorageKeys.passwordSalt);

    if (storedHash == null || storedSalt == null) {
      return false;
    }

    // Hash the provided password with the stored salt
    final computedHash = hashPassword(password, storedSalt);

    // Compare hashes
    if (computedHash == storedHash) {
      // Reset failed attempts on successful login
      await resetFailedAttempts();
      return true;
    } else {
      // Record failed attempt
      await recordFailedAttempt();
      return false;
    }
  }

  @override
  Future<bool> isPasswordSet() async {
    return await _storageService.containsSecureKey(AuthStorageKeys.passwordHash);
  }

  @override
  Future<bool> changeMasterPassword(
      String oldPassword, String newPassword) async {
    // Verify old password first
    // Note: We need to verify without recording failed attempt
    final storedHash =
        await _storageService.retrieveSecure(AuthStorageKeys.passwordHash);
    final storedSalt =
        await _storageService.retrieveSecure(AuthStorageKeys.passwordSalt);

    if (storedHash == null || storedSalt == null) {
      return false;
    }

    final computedHash = hashPassword(oldPassword, storedSalt);
    if (computedHash != storedHash) {
      await recordFailedAttempt();
      return false;
    }

    // Validate new password strength
    if (!validatePasswordStrength(newPassword)) {
      return false;
    }

    // Generate new salt and hash for new password
    final newSalt = generateSalt();
    final newHash = hashPassword(newPassword, newSalt);

    // Store new hash and salt
    await _storageService.storeSecure(AuthStorageKeys.passwordHash, newHash);
    await _storageService.storeSecure(AuthStorageKeys.passwordSalt, newSalt);

    // Reset failed attempts after successful password change
    await resetFailedAttempts();

    return true;
  }


  @override
  Future<void> recordFailedAttempt() async {
    final currentCount = await getFailedAttemptsCount();
    final newCount = currentCount + 1;

    await _storageService.store(AuthStorageKeys.failedAttempts, newCount);
    await _storageService.store(
      AuthStorageKeys.lastFailedAttempt,
      DateTime.now().toIso8601String(),
    );
  }

  @override
  Future<int> getFailedAttemptsCount() async {
    final count = await _storageService.retrieve(AuthStorageKeys.failedAttempts);
    if (count == null) {
      return 0;
    }
    return count is int ? count : int.tryParse(count.toString()) ?? 0;
  }

  @override
  Future<void> resetFailedAttempts() async {
    await _storageService.store(AuthStorageKeys.failedAttempts, 0);
    await _storageService.delete(AuthStorageKeys.lastFailedAttempt);
  }

  @override
  Future<bool> isLocked() async {
    final count = await getFailedAttemptsCount();
    return count >= failedAttemptThreshold;
  }

  @override
  Future<DateTime?> getLastFailedAttemptTime() async {
    final timeStr =
        await _storageService.retrieve(AuthStorageKeys.lastFailedAttempt);
    if (timeStr == null) {
      return null;
    }
    return DateTime.tryParse(timeStr.toString());
  }

  @override
  Future<bool> shouldTriggerSecurityAlert() async {
    return await isLocked();
  }

  /// Get the stored password hash (for testing/backup purposes).
  ///
  /// Returns null if no password is set.
  Future<String?> getStoredHash() async {
    return await _storageService.retrieveSecure(AuthStorageKeys.passwordHash);
  }

  /// Get the stored salt (for testing/backup purposes).
  ///
  /// Returns null if no password is set.
  Future<String?> getStoredSalt() async {
    return await _storageService.retrieveSecure(AuthStorageKeys.passwordSalt);
  }
}
