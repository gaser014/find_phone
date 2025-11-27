import 'dart:convert';
import 'dart:math';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:faker/faker.dart';
import 'package:find_phone/services/usb/i_usb_service.dart';
import 'package:find_phone/services/usb/usb_service.dart';
import 'package:find_phone/services/storage/i_storage_service.dart';

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

  /// Get raw secure storage for verification
  Map<String, String> get rawSecureStorage => Map.from(_secureStorage);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('UsbService', () {
    late MockStorageService mockStorage;
    final random = Random();
    final faker = Faker();

    setUp(() {
      mockStorage = MockStorageService();

      // Mock the method channel to prevent platform exceptions
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel('com.example.find_phone/usb'),
        (MethodCall methodCall) async {
          switch (methodCall.method) {
            case 'isUsbConnected':
              return false;
            case 'getCurrentUsbMode':
              return 'charging';
            case 'getConnectedDeviceId':
              return null;
            case 'startUsbMonitoring':
              return true;
            case 'stopUsbMonitoring':
              return true;
            case 'blockUsbDataTransfer':
              return true;
            case 'allowUsbDataTransfer':
              return true;
            case 'isUsbDataTransferBlocked':
              return true;
            case 'isAdbEnabled':
              return false;
            case 'blockAdbConnection':
              return true;
            default:
              return null;
          }
        },
      );
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel('com.example.find_phone/usb'),
        null,
      );
    });

    /// Generates a random device ID (vendor:product:name format)
    String generateDeviceId() {
      final vendorId = random.nextInt(65535);
      final productId = random.nextInt(65535);
      final deviceName = '/dev/bus/usb/${random.nextInt(999)}/${random.nextInt(999)}';
      return '$vendorId:$productId:$deviceName';
    }

    /// Generates a random TrustedDevice
    TrustedDevice generateTrustedDevice() {
      return TrustedDevice(
        deviceId: generateDeviceId(),
        deviceName: faker.lorem.words(2).join(' '),
        addedAt: DateTime.now().subtract(Duration(
          days: random.nextInt(365),
          hours: random.nextInt(24),
          minutes: random.nextInt(60),
        )),
        description: random.nextBool() ? faker.lorem.sentence() : null,
      );
    }


    group('TrustedDevice', () {
      test('toJson and fromJson round-trip preserves all fields', () {
        for (int i = 0; i < 100; i++) {
          final original = generateTrustedDevice();
          final json = original.toJson();
          final restored = TrustedDevice.fromJson(json);

          expect(restored.deviceId, equals(original.deviceId));
          expect(restored.deviceName, equals(original.deviceName));
          expect(restored.addedAt.toIso8601String(),
              equals(original.addedAt.toIso8601String()));
          expect(restored.description, equals(original.description));
        }
      });

      test('equality is based on deviceId', () {
        for (int i = 0; i < 100; i++) {
          final deviceId = generateDeviceId();
          final device1 = TrustedDevice(
            deviceId: deviceId,
            deviceName: 'Device 1',
            addedAt: DateTime.now(),
          );
          final device2 = TrustedDevice(
            deviceId: deviceId,
            deviceName: 'Device 2',
            addedAt: DateTime.now().subtract(const Duration(days: 1)),
          );

          expect(device1, equals(device2),
              reason: 'Devices with same ID should be equal');
          expect(device1.hashCode, equals(device2.hashCode),
              reason: 'Hash codes should match for equal devices');
        }
      });
    });

    group('Trusted Devices Management', () {
      /// **Feature: anti-theft-protection, Property 17: Trusted Devices Persistence**
      /// **Validates: Requirements 29.1, 29.2**
      ///
      /// For any trusted device added to the system, when stored in encrypted
      /// persistent storage and then restored, the device information SHALL
      /// be preserved exactly.
      test('property: trusted devices persist across service restarts', () async {
        for (int i = 0; i < 50; i++) {
          // Clear storage for each iteration
          await mockStorage.clearAll();

          // Generate random number of devices (1-10)
          final deviceCount = random.nextInt(10) + 1;
          final originalDevices = <TrustedDevice>[];

          // Create first service instance and add devices
          final service1 = UsbService(storageService: mockStorage);
          await service1.initialize();

          for (int j = 0; j < deviceCount; j++) {
            final device = generateTrustedDevice();
            originalDevices.add(device);
            await service1.addTrustedDevice(device);
          }

          // Verify devices were added
          final devicesBeforeRestart = await service1.getTrustedDevices();
          expect(devicesBeforeRestart.length, equals(deviceCount),
              reason: 'All devices should be added');

          // Create new service instance (simulating restart)
          final service2 = UsbService(storageService: mockStorage);
          await service2.initialize();

          // Verify devices were restored
          final devicesAfterRestart = await service2.getTrustedDevices();
          expect(devicesAfterRestart.length, equals(deviceCount),
              reason: 'All devices should be restored after restart');

          // Verify each device was restored correctly
          for (final original in originalDevices) {
            final restored = devicesAfterRestart.firstWhere(
              (d) => d.deviceId == original.deviceId,
              orElse: () => throw StateError('Device not found: ${original.deviceId}'),
            );

            expect(restored.deviceId, equals(original.deviceId));
            expect(restored.deviceName, equals(original.deviceName));
            expect(restored.addedAt.toIso8601String(),
                equals(original.addedAt.toIso8601String()));
            expect(restored.description, equals(original.description));
          }
        }
      });

      /// **Feature: anti-theft-protection, Property 17: Trusted Devices Persistence**
      /// **Validates: Requirements 29.1, 29.2**
      test('property: trusted devices are stored in encrypted storage', () async {
        for (int i = 0; i < 50; i++) {
          await mockStorage.clearAll();

          final service = UsbService(storageService: mockStorage);
          await service.initialize();

          final device = generateTrustedDevice();
          await service.addTrustedDevice(device);

          // Verify data is stored in secure storage
          final secureKeys = await mockStorage.getAllSecureKeys();
          expect(secureKeys.contains('trusted_devices'), isTrue,
              reason: 'Trusted devices should be stored in secure storage');

          // Verify the stored data is valid JSON
          final storedData = await mockStorage.retrieveSecure('trusted_devices');
          expect(storedData, isNotNull);
          expect(() => json.decode(storedData!), returnsNormally,
              reason: 'Stored data should be valid JSON');
        }
      });

      test('property: isDeviceTrusted returns correct result', () async {
        for (int i = 0; i < 50; i++) {
          await mockStorage.clearAll();

          final service = UsbService(storageService: mockStorage);
          await service.initialize();

          final trustedDevice = generateTrustedDevice();
          final untrustedDeviceId = generateDeviceId();

          await service.addTrustedDevice(trustedDevice);

          expect(await service.isDeviceTrusted(trustedDevice.deviceId), isTrue,
              reason: 'Added device should be trusted');
          expect(await service.isDeviceTrusted(untrustedDeviceId), isFalse,
              reason: 'Non-added device should not be trusted');
        }
      });

      test('property: removing device updates persistence', () async {
        for (int i = 0; i < 50; i++) {
          await mockStorage.clearAll();

          final service = UsbService(storageService: mockStorage);
          await service.initialize();

          // Add multiple devices
          final devices = List.generate(5, (_) => generateTrustedDevice());
          for (final device in devices) {
            await service.addTrustedDevice(device);
          }

          // Remove one device
          final deviceToRemove = devices[random.nextInt(devices.length)];
          await service.removeTrustedDevice(deviceToRemove.deviceId);

          // Verify removal persists
          final service2 = UsbService(storageService: mockStorage);
          await service2.initialize();

          expect(await service2.isDeviceTrusted(deviceToRemove.deviceId), isFalse,
              reason: 'Removed device should not be trusted after restart');
          expect((await service2.getTrustedDevices()).length, equals(devices.length - 1),
              reason: 'Device count should be reduced by 1');
        }
      });

      test('property: clearAllTrustedDevices removes all devices', () async {
        for (int i = 0; i < 50; i++) {
          await mockStorage.clearAll();

          final service = UsbService(storageService: mockStorage);
          await service.initialize();

          // Add multiple devices
          final deviceCount = random.nextInt(10) + 1;
          for (int j = 0; j < deviceCount; j++) {
            await service.addTrustedDevice(generateTrustedDevice());
          }

          expect((await service.getTrustedDevices()).length, equals(deviceCount));

          // Clear all
          await service.clearAllTrustedDevices();

          expect((await service.getTrustedDevices()).length, equals(0),
              reason: 'All devices should be cleared');

          // Verify persistence
          final service2 = UsbService(storageService: mockStorage);
          await service2.initialize();

          expect((await service2.getTrustedDevices()).length, equals(0),
              reason: 'Clear should persist after restart');
        }
      });

      test('property: duplicate device IDs are not added twice', () async {
        for (int i = 0; i < 50; i++) {
          await mockStorage.clearAll();

          final service = UsbService(storageService: mockStorage);
          await service.initialize();

          final device = generateTrustedDevice();

          // Add same device twice
          await service.addTrustedDevice(device);
          await service.addTrustedDevice(device);

          final devices = await service.getTrustedDevices();
          expect(devices.length, equals(1),
              reason: 'Duplicate device should not be added');
        }
      });
    });

    group('UsbConnectionEvent', () {
      test('toJson and fromJson round-trip preserves all fields', () {
        for (int i = 0; i < 100; i++) {
          final modes = UsbMode.values;
          final original = UsbConnectionEvent(
            isConnected: random.nextBool(),
            deviceId: random.nextBool() ? generateDeviceId() : null,
            deviceName: random.nextBool() ? faker.lorem.words(2).join(' ') : null,
            timestamp: DateTime.now().subtract(Duration(
              days: random.nextInt(30),
              hours: random.nextInt(24),
            )),
            isTrusted: random.nextBool(),
            mode: modes[random.nextInt(modes.length)],
          );

          final json = original.toJson();
          final restored = UsbConnectionEvent.fromJson(json);

          expect(restored.isConnected, equals(original.isConnected));
          expect(restored.deviceId, equals(original.deviceId));
          expect(restored.deviceName, equals(original.deviceName));
          expect(restored.timestamp.toIso8601String(),
              equals(original.timestamp.toIso8601String()));
          expect(restored.isTrusted, equals(original.isTrusted));
          expect(restored.mode, equals(original.mode));
        }
      });
    });
  });
}
