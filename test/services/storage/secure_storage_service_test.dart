import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:find_phone/services/storage/secure_storage_service.dart';

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

  // Required interface methods that we don't use in tests
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
  group('SecureStorageService', () {
    late SecureStorageService service;
    late MockFlutterSecureStorage mockStorage;

    setUp(() {
      mockStorage = MockFlutterSecureStorage();
      service = SecureStorageService(secureStorage: mockStorage);
    });

    group('storeSecure and retrieveSecure', () {
      test('stores and retrieves a value', () async {
        await service.storeSecure('password', 'secret123');
        final result = await service.retrieveSecure('password');
        expect(result, equals('secret123'));
      });

      test('returns null for non-existent key', () async {
        final result = await service.retrieveSecure('nonExistent');
        expect(result, isNull);
      });

      test('overwrites existing value', () async {
        await service.storeSecure('key', 'value1');
        await service.storeSecure('key', 'value2');
        final result = await service.retrieveSecure('key');
        expect(result, equals('value2'));
      });
    });

    group('deleteSecure', () {
      test('deletes existing key', () async {
        await service.storeSecure('toDelete', 'value');
        expect(await service.containsSecureKey('toDelete'), isTrue);

        await service.deleteSecure('toDelete');
        expect(await service.containsSecureKey('toDelete'), isFalse);
      });

      test('does not throw for non-existent key', () async {
        await expectLater(
          service.deleteSecure('nonExistent'),
          completes,
        );
      });
    });

    group('containsSecureKey', () {
      test('returns true for existing key', () async {
        await service.storeSecure('exists', 'value');
        expect(await service.containsSecureKey('exists'), isTrue);
      });

      test('returns false for non-existent key', () async {
        expect(await service.containsSecureKey('notExists'), isFalse);
      });
    });

    group('clearAll', () {
      test('removes all stored values', () async {
        await service.storeSecure('key1', 'value1');
        await service.storeSecure('key2', 'value2');

        await service.clearAll();

        expect(await service.containsSecureKey('key1'), isFalse);
        expect(await service.containsSecureKey('key2'), isFalse);
      });
    });

    group('getAllKeys', () {
      test('returns all stored keys', () async {
        await service.storeSecure('a', '1');
        await service.storeSecure('b', '2');
        await service.storeSecure('c', '3');

        final keys = await service.getAllKeys();
        expect(keys, containsAll(['a', 'b', 'c']));
      });

      test('returns empty set when no keys stored', () async {
        final keys = await service.getAllKeys();
        expect(keys, isEmpty);
      });
    });

    group('readAll', () {
      test('returns all stored data', () async {
        await service.storeSecure('key1', 'value1');
        await service.storeSecure('key2', 'value2');

        final all = await service.readAll();
        expect(all['key1'], equals('value1'));
        expect(all['key2'], equals('value2'));
      });
    });

    group('sensitive data handling', () {
      test('stores password hash securely', () async {
        const passwordHash = 'sha256:abc123def456';
        await service.storeSecure('master_password_hash', passwordHash);
        final result = await service.retrieveSecure('master_password_hash');
        expect(result, equals(passwordHash));
      });

      test('stores salt securely', () async {
        const salt = 'random_salt_value_12345';
        await service.storeSecure('password_salt', salt);
        final result = await service.retrieveSecure('password_salt');
        expect(result, equals(salt));
      });

      test('stores emergency contact securely', () async {
        const contact = '+201027888372';
        await service.storeSecure('emergency_contact', contact);
        final result = await service.retrieveSecure('emergency_contact');
        expect(result, equals(contact));
      });
    });
  });
}
