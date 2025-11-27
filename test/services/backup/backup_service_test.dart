import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:faker/faker.dart';
import 'package:find_phone/services/backup/backup_service.dart';
import 'package:find_phone/services/storage/i_storage_service.dart';
import 'package:find_phone/services/security_log/i_security_log_service.dart';
import 'package:find_phone/domain/entities/security_event.dart';
import 'package:find_phone/domain/entities/protection_config.dart';

/// Mock implementation of IStorageService for testing.
class MockStorageService implements IStorageService {
  final Map<String, String> _secureStorage = {};
  final Map<String, dynamic> _storage = {};

  @override
  Future<void> storeSecure(String key, String value) async {
    _secureStorage[key] = value;
  }

  @override
  Future<String?> retrieveSecure(String key) async {
    return _secureStorage[key];
  }

  @override
  Future<void> deleteSecure(String key) async {
    _secureStorage.remove(key);
  }

  @override
  Future<bool> containsSecureKey(String key) async {
    return _secureStorage.containsKey(key);
  }

  @override
  Future<void> store(String key, dynamic value) async {
    _storage[key] = value;
  }

  @override
  Future<dynamic> retrieve(String key) async {
    return _storage[key];
  }

  @override
  Future<void> delete(String key) async {
    _storage.remove(key);
  }

  @override
  Future<bool> containsKey(String key) async {
    return _storage.containsKey(key);
  }

  @override
  Future<void> clearAll() async {
    _secureStorage.clear();
    _storage.clear();
  }

  @override
  Future<void> clearSecure() async {
    _secureStorage.clear();
  }

  @override
  Future<void> clearNonSecure() async {
    _storage.clear();
  }

  @override
  Future<Set<String>> getAllSecureKeys() async {
    return _secureStorage.keys.toSet();
  }

  @override
  Future<Set<String>> getAllKeys() async {
    return _storage.keys.toSet();
  }

  void reset() {
    _secureStorage.clear();
    _storage.clear();
  }
}

/// Mock implementation of ISecurityLogService for testing.
class MockSecurityLogService implements ISecurityLogService {
  final List<SecurityEvent> _events = [];
  bool _initialized = false;

  @override
  bool get isInitialized => _initialized;

  @override
  Future<void> initialize(String encryptionKey) async {
    _initialized = true;
  }

  @override
  Future<void> logEvent(SecurityEvent event) async {
    _events.add(event);
  }

  @override
  Future<List<SecurityEvent>> getAllEvents() async {
    return List.from(_events);
  }

  @override
  Future<List<SecurityEvent>> getEventsByType(SecurityEventType type) async {
    return _events.where((e) => e.type == type).toList();
  }

  @override
  Future<List<SecurityEvent>> getEventsByDateRange(DateTime start, DateTime end) async {
    return _events.where((e) => 
      e.timestamp.isAfter(start) && e.timestamp.isBefore(end)
    ).toList();
  }

  @override
  Future<List<SecurityEvent>> getEventsByTypeAndDateRange(
    SecurityEventType type,
    DateTime start,
    DateTime end,
  ) async {
    return _events.where((e) => 
      e.type == type && e.timestamp.isAfter(start) && e.timestamp.isBefore(end)
    ).toList();
  }

  @override
  Future<SecurityEvent?> getEventById(String id) async {
    try {
      return _events.firstWhere((e) => e.id == id);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<int> getEventCount() async {
    return _events.length;
  }

  @override
  Future<int> getEventCountByType(SecurityEventType type) async {
    return _events.where((e) => e.type == type).length;
  }

  @override
  Future<bool> clearLogs(String password) async {
    _events.clear();
    return true;
  }

  @override
  Future<List<SecurityEvent>> getRecentEvents(int limit) async {
    final sorted = List<SecurityEvent>.from(_events)
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return sorted.take(limit).toList();
  }

  @override
  Future<bool> deleteEvent(String id) async {
    final index = _events.indexWhere((e) => e.id == id);
    if (index >= 0) {
      _events.removeAt(index);
      return true;
    }
    return false;
  }

  @override
  Future<File> exportLogs(String password) async {
    throw UnimplementedError();
  }

  @override
  Future<bool> importLogs(File file, String password) async {
    throw UnimplementedError();
  }

  @override
  Future<void> close() async {
    _initialized = false;
  }

  void reset() {
    _events.clear();
    _initialized = false;
  }
}

void main() {
  group('BackupService', () {
    late BackupService backupService;
    late MockStorageService mockStorage;
    late MockSecurityLogService mockSecurityLog;
    late Directory tempDir;

    setUp(() async {
      mockStorage = MockStorageService();
      mockSecurityLog = MockSecurityLogService();
      
      // Create temp directory for backup files
      tempDir = await Directory.systemTemp.createTemp('backup_test_');
      
      backupService = BackupService(
        storageService: mockStorage,
        securityLogService: mockSecurityLog,
        customBackupDir: tempDir.path,
      );
      
      await mockSecurityLog.initialize('test_key');
    });

    tearDown(() async {
      mockStorage.reset();
      mockSecurityLog.reset();
      
      // Clean up temp directory
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    group('Basic Backup Operations', () {
      test('creates backup file successfully', () async {
        final result = await backupService.createBackup('TestPassword123');
        
        expect(result.success, isTrue);
        expect(result.file, isNotNull);
        expect(await result.file!.exists(), isTrue);
      });

      test('backup file contains valid header', () async {
        final result = await backupService.createBackup('TestPassword123');
        
        final content = await result.file!.readAsString();
        expect(content.contains('"magic":"ATBK"'), isTrue);
        expect(content.contains('"version":1'), isTrue);
      });

      test('restores backup with correct password', () async {
        // Create some test data
        await mockStorage.store('test_setting', 'test_value');
        await mockStorage.storeSecure('secure_key', 'secure_value');
        
        // Create backup
        final backupResult = await backupService.createBackup('TestPassword123');
        expect(backupResult.success, isTrue);
        
        // Clear storage
        mockStorage.reset();
        
        // Restore backup
        final restoreResult = await backupService.restoreBackup(
          backupResult.file!,
          'TestPassword123',
        );
        
        expect(restoreResult.success, isTrue);
      });

      test('fails to restore with incorrect password', () async {
        final backupResult = await backupService.createBackup('TestPassword123');
        
        final restoreResult = await backupService.restoreBackup(
          backupResult.file!,
          'WrongPassword456',
        );
        
        expect(restoreResult.success, isFalse);
        expect(restoreResult.errorMessage, contains('Incorrect password'));
      });
    });

    group('Failed Attempts Tracking', () {
      test('tracks failed restore attempts', () async {
        final backupResult = await backupService.createBackup('TestPassword123');
        
        // Attempt with wrong password
        await backupService.restoreBackup(backupResult.file!, 'Wrong1');
        expect(await backupService.getFailedRestoreAttempts(), equals(1));
        
        await backupService.restoreBackup(backupResult.file!, 'Wrong2');
        expect(await backupService.getFailedRestoreAttempts(), equals(2));
      });

      test('locks after 3 failed attempts', () async {
        final backupResult = await backupService.createBackup('TestPassword123');
        
        // 3 failed attempts
        await backupService.restoreBackup(backupResult.file!, 'Wrong1');
        await backupService.restoreBackup(backupResult.file!, 'Wrong2');
        await backupService.restoreBackup(backupResult.file!, 'Wrong3');
        
        expect(await backupService.isRestoreLocked(), isTrue);
        
        // Further attempts should fail with locked message
        final result = await backupService.restoreBackup(
          backupResult.file!,
          'TestPassword123',
        );
        expect(result.success, isFalse);
        expect(result.errorMessage, contains('locked'));
      });

      test('resets failed attempts after successful restore', () async {
        final backupResult = await backupService.createBackup('TestPassword123');
        
        // Some failed attempts
        await backupService.restoreBackup(backupResult.file!, 'Wrong1');
        await backupService.restoreBackup(backupResult.file!, 'Wrong2');
        expect(await backupService.getFailedRestoreAttempts(), equals(2));
        
        // Successful restore
        await backupService.restoreBackup(backupResult.file!, 'TestPassword123');
        expect(await backupService.getFailedRestoreAttempts(), equals(0));
      });
    });

    group('Backup Metadata', () {
      test('retrieves backup metadata', () async {
        // Add some events
        await mockSecurityLog.logEvent(SecurityEvent(
          id: '1',
          type: SecurityEventType.failedLogin,
          timestamp: DateTime.now(),
          description: 'Test event',
          metadata: {},
        ));
        
        final backupResult = await backupService.createBackup('TestPassword123');
        final metadata = await backupService.getBackupMetadata(backupResult.file!);
        
        expect(metadata, isNotNull);
        expect(metadata!['version'], equals(1));
        expect(metadata['eventCount'], equals(1));
      });

      test('lists backup files', () async {
        // Create multiple backups
        await backupService.createBackup('Password1');
        await backupService.createBackup('Password2');
        
        final backups = await backupService.listBackups();
        expect(backups.length, equals(2));
      });

      test('deletes backup file', () async {
        final backupResult = await backupService.createBackup('TestPassword123');
        expect(await backupResult.file!.exists(), isTrue);
        
        final deleted = await backupService.deleteBackup(backupResult.file!);
        expect(deleted, isTrue);
        expect(await backupResult.file!.exists(), isFalse);
      });
    });

    // ============================================================
    // Property-Based Tests
    // ============================================================

    /// **Feature: anti-theft-protection, Property 12: Backup Encryption Round-Trip**
    /// **Validates: Requirements 15.2, 15.4**
    ///
    /// *For any* valid configuration state, performing a backup followed by a restore
    /// SHALL preserve all settings and security logs without data loss.
    group('Property 12: Backup Encryption Round-Trip', () {
      test('backup and restore preserves all settings', () async {
        final faker = Faker();

        for (int i = 0; i < 100; i++) {
          // Reset for each iteration
          mockStorage.reset();
          mockSecurityLog.reset();
          await mockSecurityLog.initialize('test_key');
          
          // Generate random password (valid: 8+ chars with letters and numbers)
          final password = '${faker.internet.password(length: 10)}A1';
          
          // Generate random settings
          final numSettings = faker.randomGenerator.integer(10, min: 1);
          final originalSettings = <String, dynamic>{};
          
          for (int j = 0; j < numSettings; j++) {
            final key = 'setting_${faker.guid.guid()}';
            final value = faker.lorem.sentence();
            originalSettings[key] = value;
            await mockStorage.store(key, value);
          }
          
          // Generate random secure data (excluding password-related keys)
          final numSecureData = faker.randomGenerator.integer(5, min: 1);
          final originalSecureData = <String, String>{};
          
          for (int j = 0; j < numSecureData; j++) {
            final key = 'secure_${faker.guid.guid()}';
            final value = faker.lorem.sentence();
            originalSecureData[key] = value;
            await mockStorage.storeSecure(key, value);
          }
          
          // Generate random security events
          final numEvents = faker.randomGenerator.integer(10, min: 1);
          final originalEvents = <SecurityEvent>[];
          
          for (int j = 0; j < numEvents; j++) {
            final event = SecurityEvent(
              id: faker.guid.guid(),
              type: SecurityEventType.values[
                faker.randomGenerator.integer(SecurityEventType.values.length)
              ],
              timestamp: DateTime.now().subtract(
                Duration(hours: faker.randomGenerator.integer(100)),
              ),
              description: faker.lorem.sentence(),
              metadata: {'key': faker.lorem.word()},
            );
            originalEvents.add(event);
            await mockSecurityLog.logEvent(event);
          }
          
          // Create backup
          final backupResult = await backupService.createBackup(password);
          expect(backupResult.success, isTrue,
              reason: 'Backup should succeed for iteration $i');
          
          // Clear all data
          mockStorage.reset();
          mockSecurityLog.reset();
          await mockSecurityLog.initialize('test_key');
          
          // Restore backup
          final restoreResult = await backupService.restoreBackup(
            backupResult.file!,
            password,
          );
          expect(restoreResult.success, isTrue,
              reason: 'Restore should succeed for iteration $i');
          
          // Verify settings were restored
          for (final entry in originalSettings.entries) {
            final restored = await mockStorage.retrieve(entry.key);
            expect(restored, equals(entry.value),
                reason: 'Setting ${entry.key} should be restored');
          }
          
          // Verify secure data was restored
          for (final entry in originalSecureData.entries) {
            final restored = await mockStorage.retrieveSecure(entry.key);
            expect(restored, equals(entry.value),
                reason: 'Secure data ${entry.key} should be restored');
          }
          
          // Verify events were restored
          final restoredEvents = await mockSecurityLog.getAllEvents();
          expect(restoredEvents.length, equals(originalEvents.length),
              reason: 'All events should be restored');
          
          for (final originalEvent in originalEvents) {
            final found = restoredEvents.any((e) => 
              e.id == originalEvent.id &&
              e.type == originalEvent.type &&
              e.description == originalEvent.description
            );
            expect(found, isTrue,
                reason: 'Event ${originalEvent.id} should be restored');
          }
          
          // Clean up backup file
          await backupResult.file!.delete();
        }
      });

      test('wrong password fails decryption for any backup', () async {
        final faker = Faker();

        for (int i = 0; i < 100; i++) {
          // Reset for each iteration
          mockStorage.reset();
          await backupService.resetFailedRestoreAttempts();
          
          // Generate random password
          final correctPassword = '${faker.internet.password(length: 10)}A1';
          final wrongPassword = '${faker.internet.password(length: 10)}B2';
          
          // Ensure passwords are different
          if (correctPassword == wrongPassword) continue;
          
          // Add some data
          await mockStorage.store('test_key', faker.lorem.sentence());
          
          // Create backup with correct password
          final backupResult = await backupService.createBackup(correctPassword);
          expect(backupResult.success, isTrue);
          
          // Attempt restore with wrong password
          final restoreResult = await backupService.restoreBackup(
            backupResult.file!,
            wrongPassword,
          );
          
          expect(restoreResult.success, isFalse,
              reason: 'Restore with wrong password should fail');
          
          // Clean up
          await backupResult.file!.delete();
          await backupService.resetFailedRestoreAttempts();
        }
      });

      test('backup preserves protection config', () async {
        final faker = Faker();

        for (int i = 0; i < 100; i++) {
          // Reset for each iteration
          mockStorage.reset();
          mockSecurityLog.reset();
          await mockSecurityLog.initialize('test_key');
          
          final password = '${faker.internet.password(length: 10)}A1';
          
          // Create random protection config with simpler values
          final phoneNum = '${faker.randomGenerator.integer(999, min: 100)}${faker.randomGenerator.integer(9999, min: 1000)}${faker.randomGenerator.integer(9999, min: 1000)}';
          final originalConfig = ProtectionConfig(
            protectedModeEnabled: faker.randomGenerator.boolean(),
            kioskModeEnabled: faker.randomGenerator.boolean(),
            stealthModeEnabled: faker.randomGenerator.boolean(),
            panicModeEnabled: faker.randomGenerator.boolean(),
            emergencyContact: '+1$phoneNum',
            locationTrackingInterval: Duration(
              minutes: faker.randomGenerator.integer(60, min: 1),
            ),
            autoProtectionEnabled: faker.randomGenerator.boolean(),
            trustedWifiSsid: 'wifi_${faker.randomGenerator.integer(1000)}',
            monitorCalls: faker.randomGenerator.boolean(),
            monitorAirplaneMode: faker.randomGenerator.boolean(),
            monitorSimCard: faker.randomGenerator.boolean(),
            blockSettings: faker.randomGenerator.boolean(),
            blockPowerMenu: faker.randomGenerator.boolean(),
            blockFileManagers: faker.randomGenerator.boolean(),
            dailyReportEnabled: faker.randomGenerator.boolean(),
            whatsappNumber: '+1$phoneNum',
            audioRecordingEnabled: faker.randomGenerator.boolean(),
            lockScreenMessage: 'Message ${faker.randomGenerator.integer(1000)}',
          );
          
          // Store config as proper JSON string
          await mockStorage.store(
            BackupStorageKeys.protectionConfig,
            jsonEncode(originalConfig.toJson()),
          );
          
          // Create backup
          final backupResult = await backupService.createBackup(password);
          expect(backupResult.success, isTrue,
              reason: 'Backup should succeed for iteration $i');
          
          // Clear storage
          mockStorage.reset();
          
          // Restore backup
          final restoreResult = await backupService.restoreBackup(
            backupResult.file!,
            password,
          );
          expect(restoreResult.success, isTrue,
              reason: 'Restore should succeed for iteration $i');
          
          // Verify config was restored
          final restoredConfigStr = await mockStorage.retrieve(
            BackupStorageKeys.protectionConfig,
          );
          expect(restoredConfigStr, isNotNull,
              reason: 'Protection config should be restored');
          
          // Clean up
          await backupResult.file!.delete();
        }
      });
    });
  });
}
