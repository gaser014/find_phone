import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:find_phone/services/storage/storage_service.dart';
import 'package:find_phone/services/storage/secure_storage_service.dart';
import 'package:find_phone/services/storage/shared_preferences_storage.dart';

/// Mock implementation of FlutterSecureStorage for testing.
class MockFlutterSecureStorage implements FlutterSecureStorage {
  final Map<String, String> _storage = {};

  @override
  Future<void> write({
    required String key,
    required String? value,
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    if (value == null) {
      _storage.remove(key);
    } else {
      _storage[key] = value;
    }
  }

  @override
  Future<String?> read({
    required String key,
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    return _storage[key];
  }

  @override
  Future<void> delete({
    required String key,
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    _storage.remove(key);
  }

  @override
  Future<bool> containsKey({
    required String key,
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    return _storage.containsKey(key);
  }

  @override
  Future<void> deleteAll({
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    _storage.clear();
  }

  @override
  Future<Map<String, String>> readAll({
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    return Map.from(_storage);
  }

  @override
  IOSOptions get iOptions => const IOSOptions();
  @override
  AndroidOptions get aOptions => const AndroidOptions();
  @override
  LinuxOptions get lOptions => const LinuxOptions();
  @override
  WebOptions get webOptions => const WebOptions();
  @override
  MacOsOptions get mOptions => const MacOsOptions();
  @override
  WindowsOptions get wOptions => const WindowsOptions();
  @override
  Future<bool> isCupertinoProtectedDataAvailable() async => true;
  @override
  Stream<bool> get onCupertinoProtectedDataAvailabilityChanged =>
      Stream.value(true);
  @override
  void registerListener({
    required String key,
    required ValueChanged<String?> listener,
  }) {}
  @override
  void unregisterListener({
    required String key,
    required ValueChanged<String?> listener,
  }) {}
  @override
  void unregisterAllListeners() {}
  @override
  void unregisterAllListenersForKey({required String key}) {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('StorageService', () {
    late StorageService storageService;
    late MockFlutterSecureStorage mockSecureStorage;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      mockSecureStorage = MockFlutterSecureStorage();

      final secureStorage =
          SecureStorageService(secureStorage: mockSecureStorage);
      final prefsStorage = SharedPreferencesStorage(keyPrefix: 'test_');

      storageService = StorageService(
        secureStorage: secureStorage,
        prefsStorage: prefsStorage,
      );
      await storageService.init();
    });

    group('secure storage operations', () {
      test('storeSecure and retrieveSecure work correctly', () async {
        await storageService.storeSecure('secret', 'mySecret');
        final result = await storageService.retrieveSecure('secret');
        expect(result, equals('mySecret'));
      });

      test('deleteSecure removes the key', () async {
        await storageService.storeSecure('toDelete', 'value');
        await storageService.deleteSecure('toDelete');
        final result = await storageService.retrieveSecure('toDelete');
        expect(result, isNull);
      });

      test('containsSecureKey returns correct value', () async {
        await storageService.storeSecure('exists', 'value');
        expect(await storageService.containsSecureKey('exists'), isTrue);
        expect(await storageService.containsSecureKey('notExists'), isFalse);
      });

      test('getAllSecureKeys returns all secure keys', () async {
        await storageService.storeSecure('a', '1');
        await storageService.storeSecure('b', '2');
        final keys = await storageService.getAllSecureKeys();
        expect(keys, containsAll(['a', 'b']));
      });

      test('clearSecure removes all secure data', () async {
        await storageService.storeSecure('key1', 'value1');
        await storageService.storeSecure('key2', 'value2');
        await storageService.clearSecure();
        expect(await storageService.containsSecureKey('key1'), isFalse);
        expect(await storageService.containsSecureKey('key2'), isFalse);
      });
    });

    group('non-sensitive storage operations', () {
      test('store and retrieve work correctly', () async {
        await storageService.store('config', 'value');
        final result = await storageService.retrieve('config');
        expect(result, equals('value'));
      });

      test('delete removes the key', () async {
        await storageService.store('toDelete', 'value');
        await storageService.delete('toDelete');
        final result = await storageService.retrieve('toDelete');
        expect(result, isNull);
      });

      test('containsKey returns correct value', () async {
        await storageService.store('exists', 'value');
        expect(await storageService.containsKey('exists'), isTrue);
        expect(await storageService.containsKey('notExists'), isFalse);
      });

      test('getAllKeys returns all non-secure keys', () async {
        await storageService.store('x', 1);
        await storageService.store('y', 2);
        final keys = await storageService.getAllKeys();
        expect(keys, containsAll(['x', 'y']));
      });

      test('clearNonSecure removes all non-sensitive data', () async {
        await storageService.store('key1', 'value1');
        await storageService.store('key2', 'value2');
        await storageService.clearNonSecure();
        expect(await storageService.containsKey('key1'), isFalse);
        expect(await storageService.containsKey('key2'), isFalse);
      });
    });

    group('typed accessors', () {
      test('storeBool and getBool work correctly', () async {
        await storageService.storeBool('flag', true);
        final result = await storageService.getBool('flag');
        expect(result, isTrue);
      });

      test('getBool returns default for missing key', () async {
        final result =
            await storageService.getBool('missing', defaultValue: false);
        expect(result, isFalse);
      });

      test('storeInt and getInt work correctly', () async {
        await storageService.storeInt('count', 42);
        final result = await storageService.getInt('count');
        expect(result, equals(42));
      });

      test('storeString and getString work correctly', () async {
        await storageService.storeString('name', 'test');
        final result = await storageService.getString('name');
        expect(result, equals('test'));
      });

      test('storeMap and getMap work correctly', () async {
        final map = {'key': 'value', 'num': 123};
        await storageService.storeMap('config', map);
        final result = await storageService.getMap('config');
        expect(result, equals(map));
      });
    });

    group('clearAll', () {
      test('removes both secure and non-sensitive data', () async {
        await storageService.storeSecure('secure', 'secret');
        await storageService.store('config', 'value');

        await storageService.clearAll();

        expect(await storageService.containsSecureKey('secure'), isFalse);
        expect(await storageService.containsKey('config'), isFalse);
      });
    });

    group('backup and restore', () {
      test('getAllDataForBackup returns all data', () async {
        await storageService.storeSecure('password', 'hash123');
        await storageService.store('setting', 'value');

        final backup = await storageService.getAllDataForBackup();

        expect(backup['secure'], isA<Map>());
        expect(backup['preferences'], isA<Map>());
        expect((backup['secure'] as Map)['password'], equals('hash123'));
        expect((backup['preferences'] as Map)['setting'], equals('value'));
      });

      test('restoreFromBackup restores all data', () async {
        final backupData = {
          'secure': {'restored_key': 'restored_value'},
          'preferences': {'restored_setting': 'restored_config'},
        };

        await storageService.restoreFromBackup(backupData);

        expect(
          await storageService.retrieveSecure('restored_key'),
          equals('restored_value'),
        );
        expect(
          await storageService.retrieve('restored_setting'),
          equals('restored_config'),
        );
      });
    });

    group('IStorageService interface compliance', () {
      test('implements all required methods', () async {
        // Secure operations
        await storageService.storeSecure('key', 'value');
        expect(await storageService.retrieveSecure('key'), isNotNull);
        await storageService.deleteSecure('key');
        expect(await storageService.containsSecureKey('key'), isFalse);

        // Non-secure operations
        await storageService.store('key', 'value');
        expect(await storageService.retrieve('key'), isNotNull);
        await storageService.delete('key');
        expect(await storageService.containsKey('key'), isFalse);

        // Clear operations
        await storageService.clearSecure();
        await storageService.clearNonSecure();
        await storageService.clearAll();

        // Key listing
        expect(await storageService.getAllSecureKeys(), isA<Set<String>>());
        expect(await storageService.getAllKeys(), isA<Set<String>>());
      });
    });
  });
}
