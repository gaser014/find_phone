import 'dart:io';

import '../../domain/entities/protection_config.dart';
import '../../domain/entities/security_event.dart';

/// Result of a backup operation.
class BackupResult {
  /// Whether the backup was successful
  final bool success;
  
  /// The backup file if successful
  final File? file;
  
  /// Error message if failed
  final String? errorMessage;

  BackupResult({
    required this.success,
    this.file,
    this.errorMessage,
  });

  factory BackupResult.success(File file) => BackupResult(
    success: true,
    file: file,
  );

  factory BackupResult.failure(String message) => BackupResult(
    success: false,
    errorMessage: message,
  );
}

/// Result of a restore operation.
class RestoreResult {
  /// Whether the restore was successful
  final bool success;
  
  /// Error message if failed
  final String? errorMessage;
  
  /// Number of settings restored
  final int settingsCount;
  
  /// Number of security events restored
  final int eventsCount;

  RestoreResult({
    required this.success,
    this.errorMessage,
    this.settingsCount = 0,
    this.eventsCount = 0,
  });

  factory RestoreResult.success({
    required int settingsCount,
    required int eventsCount,
  }) => RestoreResult(
    success: true,
    settingsCount: settingsCount,
    eventsCount: eventsCount,
  );

  factory RestoreResult.failure(String message) => RestoreResult(
    success: false,
    errorMessage: message,
  );
}

/// Data structure for backup content.
class BackupData {
  /// Backup format version
  final int version;
  
  /// Timestamp when backup was created
  final DateTime createdAt;
  
  /// Protection configuration settings
  final ProtectionConfig? config;
  
  /// Security events/logs
  final List<SecurityEvent> events;
  
  /// Additional secure storage data (excluding password hash)
  final Map<String, String> secureData;
  
  /// Non-sensitive settings
  final Map<String, dynamic> settings;

  BackupData({
    required this.version,
    required this.createdAt,
    this.config,
    this.events = const [],
    this.secureData = const {},
    this.settings = const {},
  });

  Map<String, dynamic> toJson() {
    return {
      'version': version,
      'createdAt': createdAt.toIso8601String(),
      'config': config?.toJson(),
      'events': events.map((e) => e.toJson()).toList(),
      'secureData': secureData,
      'settings': settings,
    };
  }

  factory BackupData.fromJson(Map<String, dynamic> json) {
    return BackupData(
      version: json['version'] as int,
      createdAt: DateTime.parse(json['createdAt'] as String),
      config: json['config'] != null
          ? ProtectionConfig.fromJson(json['config'] as Map<String, dynamic>)
          : null,
      events: (json['events'] as List<dynamic>?)
          ?.map((e) => SecurityEvent.fromJson(e as Map<String, dynamic>))
          .toList() ?? [],
      secureData: Map<String, String>.from(json['secureData'] as Map? ?? {}),
      settings: Map<String, dynamic>.from(json['settings'] as Map? ?? {}),
    );
  }
}

/// Interface for backup and restore operations in the Anti-Theft Protection app.
///
/// This interface defines the contract for creating encrypted backups of
/// settings and security logs, and restoring them from backup files.
///
/// Requirements:
/// - 15.1: Export all settings and logs as encrypted file
/// - 15.2: Encrypt backup using Master Password
/// - 15.3: Require Master Password to decrypt backup
/// - 15.4: Import all settings and security logs
/// - 15.5: Refuse to decrypt after 3 failed attempts
abstract class IBackupService {
  /// Create an encrypted backup of all settings and logs.
  ///
  /// Exports all protection configuration, security events, and other
  /// settings to an encrypted file using the provided password.
  ///
  /// [password] - The password to use for encryption (typically Master Password)
  /// [outputPath] - Optional custom output path for the backup file
  ///
  /// Returns a [BackupResult] indicating success or failure.
  ///
  /// Requirements: 15.1, 15.2
  Future<BackupResult> createBackup(String password, {String? outputPath});

  /// Restore settings and logs from an encrypted backup file.
  ///
  /// Decrypts the backup file using the provided password and imports
  /// all settings and security events.
  ///
  /// [file] - The encrypted backup file to restore from
  /// [password] - The password to decrypt the backup
  ///
  /// Returns a [RestoreResult] indicating success or failure.
  ///
  /// Requirements: 15.3, 15.4
  Future<RestoreResult> restoreBackup(File file, String password);

  /// Verify if a backup file can be decrypted with the given password.
  ///
  /// Attempts to decrypt the backup without importing data.
  ///
  /// [file] - The encrypted backup file to verify
  /// [password] - The password to test
  ///
  /// Returns true if the password is correct, false otherwise.
  Future<bool> verifyBackupPassword(File file, String password);

  /// Get the number of failed restore attempts.
  ///
  /// Returns the count of consecutive failed password attempts.
  ///
  /// Requirements: 15.5
  Future<int> getFailedRestoreAttempts();

  /// Check if restore is locked due to too many failed attempts.
  ///
  /// Returns true if 3 or more failed attempts have occurred.
  ///
  /// Requirements: 15.5
  Future<bool> isRestoreLocked();

  /// Reset the failed restore attempts counter.
  ///
  /// Called after successful restore or by admin action.
  Future<void> resetFailedRestoreAttempts();

  /// Get backup metadata without decrypting the full content.
  ///
  /// Returns basic information about the backup file.
  ///
  /// [file] - The backup file to inspect
  Future<Map<String, dynamic>?> getBackupMetadata(File file);

  /// List all backup files in the default backup directory.
  ///
  /// Returns a list of backup files sorted by creation date (newest first).
  Future<List<File>> listBackups();

  /// Delete a backup file.
  ///
  /// [file] - The backup file to delete
  ///
  /// Returns true if deletion was successful.
  Future<bool> deleteBackup(File file);
}
