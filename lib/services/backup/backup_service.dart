import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:path_provider/path_provider.dart';

import '../../domain/entities/protection_config.dart';
import '../../domain/entities/security_event.dart';
import '../security_log/i_security_log_service.dart';
import '../storage/i_storage_service.dart';
import 'i_backup_service.dart';

/// Storage keys for backup service.
class BackupStorageKeys {
  static const String failedRestoreAttempts = 'backup_failed_restore_attempts';
  static const String lastFailedRestoreTime = 'backup_last_failed_restore_time';
  static const String protectionConfig = 'protection_config';
}

/// Implementation of [IBackupService] for creating and restoring encrypted backups.
///
/// This service provides functionality to:
/// - Export all settings and security logs to an encrypted file
/// - Import settings and logs from an encrypted backup
/// - Track failed restore attempts with lockout after 3 failures
///
/// Requirements:
/// - 15.1: Export all settings and logs as encrypted file
/// - 15.2: Encrypt backup using Master Password
/// - 15.3: Require Master Password to decrypt backup
/// - 15.4: Import all settings and security logs
/// - 15.5: Refuse to decrypt after 3 failed attempts
class BackupService implements IBackupService {
  /// Current backup format version
  static const int backupVersion = 1;
  
  /// Maximum failed restore attempts before lockout
  static const int maxFailedAttempts = 3;
  
  /// File extension for backup files
  static const String backupExtension = '.atbackup';
  
  /// Magic bytes to identify backup files
  static const String backupMagic = 'ATBK';

  final IStorageService _storageService;
  final ISecurityLogService _securityLogService;
  
  /// Optional custom backup directory for testing
  final String? customBackupDir;

  BackupService({
    required IStorageService storageService,
    required ISecurityLogService securityLogService,
    this.customBackupDir,
  }) : _storageService = storageService,
       _securityLogService = securityLogService;

  /// Get the backup directory path.
  Future<String> _getBackupDirectory() async {
    if (customBackupDir != null) {
      return customBackupDir!;
    }
    final directory = await getApplicationDocumentsDirectory();
    final backupDir = Directory('${directory.path}/backups');
    if (!await backupDir.exists()) {
      await backupDir.create(recursive: true);
    }
    return backupDir.path;
  }

  @override
  Future<BackupResult> createBackup(String password, {String? outputPath}) async {
    try {
      // Collect all data to backup
      final backupData = await _collectBackupData();
      
      // Convert to JSON
      final jsonString = jsonEncode(backupData.toJson());
      
      // Encrypt the data
      final encryptedData = _encryptData(jsonString, password);
      
      // Create backup file with metadata header
      final backupContent = _createBackupFile(encryptedData, backupData);
      
      // Determine output path
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final filePath = outputPath ?? 
          '${await _getBackupDirectory()}/backup_$timestamp$backupExtension';
      
      // Write to file
      final file = File(filePath);
      await file.writeAsString(backupContent);
      
      return BackupResult.success(file);
    } catch (e) {
      return BackupResult.failure('Failed to create backup: $e');
    }
  }

  /// Collect all data that needs to be backed up.
  Future<BackupData> _collectBackupData() async {
    // Get protection config
    ProtectionConfig? config;
    final configJson = await _storageService.retrieve(BackupStorageKeys.protectionConfig);
    if (configJson != null) {
      if (configJson is String) {
        config = ProtectionConfig.fromJson(jsonDecode(configJson) as Map<String, dynamic>);
      } else if (configJson is Map) {
        config = ProtectionConfig.fromJson(Map<String, dynamic>.from(configJson));
      }
    }
    
    // Get security events
    List<SecurityEvent> events = [];
    if (_securityLogService.isInitialized) {
      events = await _securityLogService.getAllEvents();
    }
    
    // Get secure data (excluding password hash and salt for security)
    final secureData = <String, String>{};
    final secureKeys = await _storageService.getAllSecureKeys();
    for (final key in secureKeys) {
      // Skip password-related keys for security
      if (key.contains('password') || key.contains('salt')) {
        continue;
      }
      final value = await _storageService.retrieveSecure(key);
      if (value != null) {
        secureData[key] = value;
      }
    }
    
    // Get non-sensitive settings
    final settings = <String, dynamic>{};
    final allKeys = await _storageService.getAllKeys();
    for (final key in allKeys) {
      // Skip backup-related keys
      if (key.startsWith('backup_')) {
        continue;
      }
      final value = await _storageService.retrieve(key);
      if (value != null) {
        settings[key] = value;
      }
    }
    
    return BackupData(
      version: backupVersion,
      createdAt: DateTime.now(),
      config: config,
      events: events,
      secureData: secureData,
      settings: settings,
    );
  }

  /// Create the backup file content with header and encrypted data.
  String _createBackupFile(String encryptedData, BackupData backupData) {
    final header = {
      'magic': backupMagic,
      'version': backupVersion,
      'createdAt': backupData.createdAt.toIso8601String(),
      'eventCount': backupData.events.length,
      'settingsCount': backupData.settings.length + backupData.secureData.length,
    };
    
    return '${jsonEncode(header)}\n$encryptedData';
  }

  @override
  Future<RestoreResult> restoreBackup(File file, String password) async {
    // Check if locked
    if (await isRestoreLocked()) {
      return RestoreResult.failure(
        'Restore is locked due to too many failed attempts. Please wait or contact support.',
      );
    }
    
    try {
      // Read and parse backup file
      final content = await file.readAsString();
      final parts = content.split('\n');
      
      if (parts.length < 2) {
        await _recordFailedRestoreAttempt();
        return RestoreResult.failure('Invalid backup file format');
      }
      
      // Verify header
      final header = jsonDecode(parts[0]) as Map<String, dynamic>;
      if (header['magic'] != backupMagic) {
        await _recordFailedRestoreAttempt();
        return RestoreResult.failure('Invalid backup file');
      }
      
      // Decrypt data
      final encryptedData = parts.sublist(1).join('\n');
      final jsonString = _decryptData(encryptedData, password);
      
      if (jsonString == null) {
        await _recordFailedRestoreAttempt();
        return RestoreResult.failure('Incorrect password');
      }
      
      // Parse backup data
      final backupData = BackupData.fromJson(
        jsonDecode(jsonString) as Map<String, dynamic>,
      );
      
      // Import data
      final result = await _importBackupData(backupData);
      
      // Reset failed attempts on success
      await resetFailedRestoreAttempts();
      
      return result;
    } catch (e) {
      await _recordFailedRestoreAttempt();
      return RestoreResult.failure('Failed to restore backup: $e');
    }
  }

  /// Import backup data into the system.
  Future<RestoreResult> _importBackupData(BackupData backupData) async {
    int settingsCount = 0;
    int eventsCount = 0;
    
    try {
      // Import protection config
      if (backupData.config != null) {
        await _storageService.store(
          BackupStorageKeys.protectionConfig,
          jsonEncode(backupData.config!.toJson()),
        );
        settingsCount++;
      }
      
      // Import secure data
      for (final entry in backupData.secureData.entries) {
        await _storageService.storeSecure(entry.key, entry.value);
        settingsCount++;
      }
      
      // Import non-sensitive settings
      for (final entry in backupData.settings.entries) {
        await _storageService.store(entry.key, entry.value);
        settingsCount++;
      }
      
      // Import security events (if security log service is initialized)
      if (_securityLogService.isInitialized) {
        for (final event in backupData.events) {
          await _securityLogService.logEvent(event);
          eventsCount++;
        }
      }
      
      return RestoreResult.success(
        settingsCount: settingsCount,
        eventsCount: eventsCount,
      );
    } catch (e) {
      return RestoreResult.failure('Failed to import data: $e');
    }
  }

  @override
  Future<bool> verifyBackupPassword(File file, String password) async {
    try {
      final content = await file.readAsString();
      final parts = content.split('\n');
      
      if (parts.length < 2) return false;
      
      // Verify header
      final header = jsonDecode(parts[0]) as Map<String, dynamic>;
      if (header['magic'] != backupMagic) return false;
      
      // Try to decrypt
      final encryptedData = parts.sublist(1).join('\n');
      final jsonString = _decryptData(encryptedData, password);
      
      return jsonString != null;
    } catch (e) {
      return false;
    }
  }

  @override
  Future<int> getFailedRestoreAttempts() async {
    final count = await _storageService.retrieve(BackupStorageKeys.failedRestoreAttempts);
    if (count == null) return 0;
    return count is int ? count : int.tryParse(count.toString()) ?? 0;
  }

  @override
  Future<bool> isRestoreLocked() async {
    final attempts = await getFailedRestoreAttempts();
    return attempts >= maxFailedAttempts;
  }

  @override
  Future<void> resetFailedRestoreAttempts() async {
    await _storageService.store(BackupStorageKeys.failedRestoreAttempts, 0);
    await _storageService.delete(BackupStorageKeys.lastFailedRestoreTime);
  }

  /// Record a failed restore attempt.
  Future<void> _recordFailedRestoreAttempt() async {
    final currentCount = await getFailedRestoreAttempts();
    await _storageService.store(
      BackupStorageKeys.failedRestoreAttempts,
      currentCount + 1,
    );
    await _storageService.store(
      BackupStorageKeys.lastFailedRestoreTime,
      DateTime.now().toIso8601String(),
    );
  }

  @override
  Future<Map<String, dynamic>?> getBackupMetadata(File file) async {
    try {
      final content = await file.readAsString();
      final parts = content.split('\n');
      
      if (parts.isEmpty) return null;
      
      final header = jsonDecode(parts[0]) as Map<String, dynamic>;
      if (header['magic'] != backupMagic) return null;
      
      return {
        'version': header['version'],
        'createdAt': header['createdAt'],
        'eventCount': header['eventCount'],
        'settingsCount': header['settingsCount'],
        'fileSize': await file.length(),
        'fileName': file.path.split('/').last,
      };
    } catch (e) {
      return null;
    }
  }

  @override
  Future<List<File>> listBackups() async {
    try {
      final backupDir = Directory(await _getBackupDirectory());
      if (!await backupDir.exists()) {
        return [];
      }
      
      final files = await backupDir
          .list()
          .where((entity) => entity is File && entity.path.endsWith(backupExtension))
          .cast<File>()
          .toList();
      
      // Sort by modification time (newest first)
      files.sort((a, b) {
        final aStat = a.statSync();
        final bStat = b.statSync();
        return bStat.modified.compareTo(aStat.modified);
      });
      
      return files;
    } catch (e) {
      return [];
    }
  }

  @override
  Future<bool> deleteBackup(File file) async {
    try {
      if (await file.exists()) {
        await file.delete();
        return true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  /// Encrypt data using AES-like encryption with the provided password.
  ///
  /// Uses SHA-256 to derive a key from the password and XOR encryption.
  /// Note: For production, consider using a proper AES library like encrypt.
  ///
  /// Requirements: 15.2 - Encrypt backup using Master Password
  String _encryptData(String data, String password) {
    // Generate key from password using SHA-256
    final keyBytes = sha256.convert(utf8.encode(password)).bytes;
    final dataBytes = utf8.encode(data);
    
    // Generate IV from password hash (first 16 bytes)
    final iv = Uint8List.fromList(keyBytes.sublist(0, 16));
    
    // XOR encryption with key rotation
    final encryptedBytes = <int>[];
    for (int i = 0; i < dataBytes.length; i++) {
      final keyByte = keyBytes[i % keyBytes.length];
      final ivByte = iv[i % iv.length];
      encryptedBytes.add(dataBytes[i] ^ keyByte ^ ivByte);
    }
    
    return base64Encode(encryptedBytes);
  }

  /// Decrypt data using the provided password.
  ///
  /// Requirements: 15.3 - Require Master Password to decrypt backup
  String? _decryptData(String encryptedData, String password) {
    try {
      // Generate key from password using SHA-256
      final keyBytes = sha256.convert(utf8.encode(password)).bytes;
      final encryptedBytes = base64Decode(encryptedData);
      
      // Generate IV from password hash (first 16 bytes)
      final iv = Uint8List.fromList(keyBytes.sublist(0, 16));
      
      // XOR decryption
      final decryptedBytes = <int>[];
      for (int i = 0; i < encryptedBytes.length; i++) {
        final keyByte = keyBytes[i % keyBytes.length];
        final ivByte = iv[i % iv.length];
        decryptedBytes.add(encryptedBytes[i] ^ keyByte ^ ivByte);
      }
      
      final result = utf8.decode(decryptedBytes);
      
      // Verify it's valid JSON
      jsonDecode(result);
      
      return result;
    } catch (e) {
      return null;
    }
  }
}
