import 'dart:math';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:find_phone/services/app_blocking/app_blocking_service.dart';
import 'package:find_phone/services/app_blocking/i_app_blocking_service.dart';
import 'package:find_phone/services/storage/i_storage_service.dart';

/// Mock storage service for testing
class MockStorageService implements IStorageService {
  final Map<String, dynamic> _storage = {};
  final Map<String, String> _secureStorage = {};

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
  Future<void> clearAll() async {
    _storage.clear();
    _secureStorage.clear();
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
  Future<bool> containsKey(String key) async {
    return _storage.containsKey(key);
  }

  @override
  Future<bool> containsSecureKey(String key) async {
    return _secureStorage.containsKey(key);
  }

  @override
  Future<Set<String>> getAllKeys() async {
    return _storage.keys.toSet();
  }

  @override
  Future<Set<String>> getAllSecureKeys() async {
    return _secureStorage.keys.toSet();
  }

  void clear() {
    _storage.clear();
    _secureStorage.clear();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  
  group('AppBlockingService', () {
    late MockStorageService mockStorage;
    late AppBlockingService service;
    final random = Random();

    setUp(() {
      mockStorage = MockStorageService();
      service = AppBlockingService(
        storageService: mockStorage,
        accessibilityService: null, // Skip native calls in tests
      );
      
      // Mock the method channel to prevent native calls
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel('com.example.find_phone/app_blocking'),
        (MethodCall methodCall) async {
          // Return success for all method calls
          return true;
        },
      );
    });

    tearDown(() {
      mockStorage.clear();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel('com.example.find_phone/app_blocking'),
        null,
      );
    });

    group('USB Data Transfer Blocking', () {
      /// **Feature: anti-theft-protection, Property 16: USB Data Transfer Blocking**
      /// **Validates: Requirements 28.3**
      ///
      /// For any USB connection from an untrusted computer when Protected Mode
      /// is active, the system SHALL block USB data transfer and show only
      /// charging mode.
      test('property: USB data transfer blocking state persists correctly', () async {
        // Run 100 iterations with random states
        for (int i = 0; i < 100; i++) {
          mockStorage.clear();
          
          final shouldEnable = random.nextBool();
          
          if (shouldEnable) {
            await service.enableUsbDataTransferBlocking();
          } else {
            await service.disableUsbDataTransferBlocking();
          }
          
          final isEnabled = await service.isUsbDataTransferBlockingEnabled();
          
          expect(isEnabled, equals(shouldEnable),
              reason: 'USB blocking state should match: expected $shouldEnable, got $isEnabled');
        }
      });

      test('property: USB blocking state survives service recreation', () async {
        for (int i = 0; i < 100; i++) {
          mockStorage.clear();
          
          final shouldEnable = random.nextBool();
          
          // Set state with first service instance
          if (shouldEnable) {
            await service.enableUsbDataTransferBlocking();
          } else {
            await service.disableUsbDataTransferBlocking();
          }
          
          // Create new service instance with same storage
          final newService = AppBlockingService(
            storageService: mockStorage,
            accessibilityService: null,
          );
          
          final isEnabled = await newService.isUsbDataTransferBlockingEnabled();
          
          expect(isEnabled, equals(shouldEnable),
              reason: 'USB blocking state should persist across service instances');
        }
      });
    });

    group('Screen Lock Change Blocking', () {
      /// **Feature: anti-theft-protection, Property 18: Screen Lock Change Blocking**
      /// **Validates: Requirements 30.2**
      ///
      /// For any attempt to change screen lock password/PIN/pattern when
      /// Protected Mode is active, the system SHALL block the change and
      /// display warning.
      test('property: screen lock change blocking state persists correctly', () async {
        for (int i = 0; i < 100; i++) {
          mockStorage.clear();
          
          final shouldEnable = random.nextBool();
          
          if (shouldEnable) {
            await service.enableScreenLockChangeBlocking();
          } else {
            await service.disableScreenLockChangeBlocking();
          }
          
          final isEnabled = await service.isScreenLockChangeBlockingEnabled();
          
          expect(isEnabled, equals(shouldEnable),
              reason: 'Screen lock blocking state should match: expected $shouldEnable');
        }
      });

      test('property: screen lock blocking state survives service recreation', () async {
        for (int i = 0; i < 100; i++) {
          mockStorage.clear();
          
          final shouldEnable = random.nextBool();
          
          if (shouldEnable) {
            await service.enableScreenLockChangeBlocking();
          } else {
            await service.disableScreenLockChangeBlocking();
          }
          
          final newService = AppBlockingService(
            storageService: mockStorage,
            accessibilityService: null,
          );
          
          final isEnabled = await newService.isScreenLockChangeBlockingEnabled();
          
          expect(isEnabled, equals(shouldEnable),
              reason: 'Screen lock blocking state should persist');
        }
      });
    });

    group('Account Addition Blocking', () {
      /// **Feature: anti-theft-protection, Property 19: Account Addition Blocking**
      /// **Validates: Requirements 31.2**
      ///
      /// For any attempt to add a new Google or other account when Protected
      /// Mode is active, the system SHALL block the addition and close the
      /// account setup.
      test('property: account addition blocking state persists correctly', () async {
        for (int i = 0; i < 100; i++) {
          mockStorage.clear();
          
          final shouldEnable = random.nextBool();
          
          if (shouldEnable) {
            await service.enableAccountAdditionBlocking();
          } else {
            await service.disableAccountAdditionBlocking();
          }
          
          final isEnabled = await service.isAccountAdditionBlockingEnabled();
          
          expect(isEnabled, equals(shouldEnable),
              reason: 'Account addition blocking state should match');
        }
      });

      test('property: account addition blocking state survives service recreation', () async {
        for (int i = 0; i < 100; i++) {
          mockStorage.clear();
          
          final shouldEnable = random.nextBool();
          
          if (shouldEnable) {
            await service.enableAccountAdditionBlocking();
          } else {
            await service.disableAccountAdditionBlocking();
          }
          
          final newService = AppBlockingService(
            storageService: mockStorage,
            accessibilityService: null,
          );
          
          final isEnabled = await newService.isAccountAdditionBlockingEnabled();
          
          expect(isEnabled, equals(shouldEnable),
              reason: 'Account addition blocking state should persist');
        }
      });
    });

    group('App Installation Blocking', () {
      /// **Feature: anti-theft-protection, Property 20: App Installation/Uninstallation Blocking**
      /// **Validates: Requirements 32.2, 32.3**
      ///
      /// For any app installation or uninstallation attempt when Protected Mode
      /// is active, the system SHALL block the operation and close the installer.
      test('property: app installation blocking state persists correctly', () async {
        for (int i = 0; i < 100; i++) {
          mockStorage.clear();
          
          final shouldEnable = random.nextBool();
          
          if (shouldEnable) {
            await service.enableAppInstallationBlocking();
          } else {
            await service.disableAppInstallationBlocking();
          }
          
          final isEnabled = await service.isAppInstallationBlockingEnabled();
          
          expect(isEnabled, equals(shouldEnable),
              reason: 'App installation blocking state should match');
        }
      });

      test('property: app installation blocking state survives service recreation', () async {
        for (int i = 0; i < 100; i++) {
          mockStorage.clear();
          
          final shouldEnable = random.nextBool();
          
          if (shouldEnable) {
            await service.enableAppInstallationBlocking();
          } else {
            await service.disableAppInstallationBlocking();
          }
          
          final newService = AppBlockingService(
            storageService: mockStorage,
            accessibilityService: null,
          );
          
          final isEnabled = await newService.isAppInstallationBlockingEnabled();
          
          expect(isEnabled, equals(shouldEnable),
              reason: 'App installation blocking state should persist');
        }
      });
    });

    group('File Manager Access Timeout', () {
      /// Tests for file manager access timeout functionality
      /// Requirement 23.3, 23.4: 1-minute file manager access timeout
      test('property: file manager access timeout is correctly tracked', () async {
        for (int i = 0; i < 50; i++) {
          mockStorage.clear();
          
          // Initially should have no access
          var hasAccess = await service.hasTemporaryFileManagerAccess();
          expect(hasAccess, isFalse,
              reason: 'Should not have access initially');
          
          // Grant access
          await service.grantTemporaryFileManagerAccess();
          
          hasAccess = await service.hasTemporaryFileManagerAccess();
          expect(hasAccess, isTrue,
              reason: 'Should have access after granting');
          
          final remaining = await service.getFileManagerAccessRemainingSeconds();
          expect(remaining, greaterThan(0),
              reason: 'Should have remaining time');
          expect(remaining, lessThanOrEqualTo(60),
              reason: 'Should not exceed 60 seconds');
          
          // Revoke access
          await service.revokeFileManagerAccess();
          
          hasAccess = await service.hasTemporaryFileManagerAccess();
          expect(hasAccess, isFalse,
              reason: 'Should not have access after revoking');
        }
      });
    });

    group('Blocking Status', () {
      test('property: getBlockingStatus returns consistent state', () async {
        for (int i = 0; i < 100; i++) {
          mockStorage.clear();
          
          // Set random states
          final settingsBlocking = random.nextBool();
          final fileManagerBlocking = random.nextBool();
          final screenLockBlocking = random.nextBool();
          final accountBlocking = random.nextBool();
          final appInstallBlocking = random.nextBool();
          final factoryResetBlocking = random.nextBool();
          final usbBlocking = random.nextBool();
          
          if (settingsBlocking) {
            await service.enableSettingsBlocking();
          } else {
            await service.disableSettingsBlocking();
          }
          
          if (fileManagerBlocking) {
            await service.enableFileManagerBlocking();
          } else {
            await service.disableFileManagerBlocking();
          }
          
          if (screenLockBlocking) {
            await service.enableScreenLockChangeBlocking();
          } else {
            await service.disableScreenLockChangeBlocking();
          }
          
          if (accountBlocking) {
            await service.enableAccountAdditionBlocking();
          } else {
            await service.disableAccountAdditionBlocking();
          }
          
          if (appInstallBlocking) {
            await service.enableAppInstallationBlocking();
          } else {
            await service.disableAppInstallationBlocking();
          }
          
          if (factoryResetBlocking) {
            await service.enableFactoryResetBlocking();
          } else {
            await service.disableFactoryResetBlocking();
          }
          
          if (usbBlocking) {
            await service.enableUsbDataTransferBlocking();
          } else {
            await service.disableUsbDataTransferBlocking();
          }
          
          final status = await service.getBlockingStatus();
          
          expect(status.settingsBlocking, equals(settingsBlocking));
          expect(status.fileManagerBlocking, equals(fileManagerBlocking));
          expect(status.screenLockChangeBlocking, equals(screenLockBlocking));
          expect(status.accountAdditionBlocking, equals(accountBlocking));
          expect(status.appInstallationBlocking, equals(appInstallBlocking));
          expect(status.factoryResetBlocking, equals(factoryResetBlocking));
          expect(status.usbDataTransferBlocking, equals(usbBlocking));
        }
      });

      test('property: enableAllBlocking enables all blocking features', () async {
        for (int i = 0; i < 50; i++) {
          mockStorage.clear();
          
          // First disable all
          await service.disableAllBlocking();
          
          var status = await service.getBlockingStatus();
          expect(status.settingsBlocking, isFalse);
          expect(status.fileManagerBlocking, isFalse);
          expect(status.screenLockChangeBlocking, isFalse);
          expect(status.accountAdditionBlocking, isFalse);
          expect(status.appInstallationBlocking, isFalse);
          expect(status.factoryResetBlocking, isFalse);
          expect(status.usbDataTransferBlocking, isFalse);
          
          // Enable all
          await service.enableAllBlocking();
          
          status = await service.getBlockingStatus();
          expect(status.settingsBlocking, isTrue);
          expect(status.fileManagerBlocking, isTrue);
          expect(status.screenLockChangeBlocking, isTrue);
          expect(status.accountAdditionBlocking, isTrue);
          expect(status.appInstallationBlocking, isTrue);
          expect(status.factoryResetBlocking, isTrue);
          expect(status.usbDataTransferBlocking, isTrue);
        }
      });
    });

    group('AppBlockingStatus', () {
      test('property: JSON round-trip preserves all fields', () async {
        for (int i = 0; i < 100; i++) {
          final original = AppBlockingStatus(
            settingsBlocking: random.nextBool(),
            fileManagerBlocking: random.nextBool(),
            screenLockChangeBlocking: random.nextBool(),
            accountAdditionBlocking: random.nextBool(),
            appInstallationBlocking: random.nextBool(),
            factoryResetBlocking: random.nextBool(),
            usbDataTransferBlocking: random.nextBool(),
            hasTemporaryFileManagerAccess: random.nextBool(),
            fileManagerAccessRemainingSeconds: random.nextInt(60),
          );
          
          final json = original.toJson();
          final restored = AppBlockingStatus.fromJson(json);
          
          expect(restored.settingsBlocking, equals(original.settingsBlocking));
          expect(restored.fileManagerBlocking, equals(original.fileManagerBlocking));
          expect(restored.screenLockChangeBlocking, equals(original.screenLockChangeBlocking));
          expect(restored.accountAdditionBlocking, equals(original.accountAdditionBlocking));
          expect(restored.appInstallationBlocking, equals(original.appInstallationBlocking));
          expect(restored.factoryResetBlocking, equals(original.factoryResetBlocking));
          expect(restored.usbDataTransferBlocking, equals(original.usbDataTransferBlocking));
          expect(restored.hasTemporaryFileManagerAccess, equals(original.hasTemporaryFileManagerAccess));
          expect(restored.fileManagerAccessRemainingSeconds, equals(original.fileManagerAccessRemainingSeconds));
        }
      });

      test('property: copyWith preserves unmodified fields', () async {
        for (int i = 0; i < 100; i++) {
          final original = AppBlockingStatus(
            settingsBlocking: random.nextBool(),
            fileManagerBlocking: random.nextBool(),
            screenLockChangeBlocking: random.nextBool(),
            accountAdditionBlocking: random.nextBool(),
            appInstallationBlocking: random.nextBool(),
            factoryResetBlocking: random.nextBool(),
            usbDataTransferBlocking: random.nextBool(),
            hasTemporaryFileManagerAccess: random.nextBool(),
            fileManagerAccessRemainingSeconds: random.nextInt(60),
          );
          
          // Modify only one field
          final newSettingsBlocking = !original.settingsBlocking;
          final copied = original.copyWith(settingsBlocking: newSettingsBlocking);
          
          expect(copied.settingsBlocking, equals(newSettingsBlocking));
          expect(copied.fileManagerBlocking, equals(original.fileManagerBlocking));
          expect(copied.screenLockChangeBlocking, equals(original.screenLockChangeBlocking));
          expect(copied.accountAdditionBlocking, equals(original.accountAdditionBlocking));
          expect(copied.appInstallationBlocking, equals(original.appInstallationBlocking));
          expect(copied.factoryResetBlocking, equals(original.factoryResetBlocking));
          expect(copied.usbDataTransferBlocking, equals(original.usbDataTransferBlocking));
        }
      });
    });

    group('AppBlockingEvent', () {
      test('property: event map round-trip preserves all fields', () async {
        final eventTypes = AppBlockingEventType.values;
        
        for (int i = 0; i < 100; i++) {
          final original = AppBlockingEvent(
            type: eventTypes[random.nextInt(eventTypes.length)],
            timestamp: DateTime.now().subtract(Duration(
              days: random.nextInt(30),
              hours: random.nextInt(24),
              minutes: random.nextInt(60),
            )),
            packageName: random.nextBool() ? 'com.example.app${random.nextInt(100)}' : null,
            appName: random.nextBool() ? 'App ${random.nextInt(100)}' : null,
            metadata: random.nextBool() ? {'key': 'value${random.nextInt(100)}'} : null,
          );
          
          final map = original.toMap();
          final restored = AppBlockingEvent.fromMap(map);
          
          expect(restored.type, equals(original.type));
          expect(restored.timestamp.millisecondsSinceEpoch, 
              equals(original.timestamp.millisecondsSinceEpoch));
          expect(restored.packageName, equals(original.packageName));
          expect(restored.appName, equals(original.appName));
        }
      });
    });
  });
}
