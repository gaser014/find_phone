import 'package:flutter_test/flutter_test.dart';
import 'package:faker/faker.dart';
import 'package:find_phone/services/protection/protection_service.dart';
import 'package:find_phone/services/authentication/authentication_service.dart';
import 'package:find_phone/services/storage/i_storage_service.dart';
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

/// Helper function to create a new ProtectionService for testing
Future<({ProtectionService service, AuthenticationService auth, MockStorageService storage})> 
    createTestServices(MockStorageService? existingStorage) async {
  final storage = existingStorage ?? MockStorageService();
  storage.reset();
  final auth = AuthenticationService(storageService: storage);
  final service = ProtectionService(
    storageService: storage,
    authService: auth,
    skipNativeSetup: true,
  );
  await service.initialize();
  return (service: service, auth: auth, storage: storage);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ProtectionService', () {
    late ProtectionService protectionService;
    late AuthenticationService authService;
    late MockStorageService mockStorage;

    setUp(() async {
      mockStorage = MockStorageService();
      authService = AuthenticationService(storageService: mockStorage);
      protectionService = ProtectionService(
        storageService: mockStorage,
        authService: authService,
        skipNativeSetup: true,
      );
      await protectionService.initialize();
    });

    tearDown(() {
      mockStorage.reset();
    });

    group('Configuration Management', () {
      test('loads default configuration when none exists', () async {
        final config = await protectionService.getConfiguration();
        expect(config.protectedModeEnabled, isFalse);
        expect(config.kioskModeEnabled, isFalse);
        expect(config.stealthModeEnabled, isFalse);
        expect(config.panicModeEnabled, isFalse);
      });

      test('saves and loads configuration correctly', () async {
        await authService.setupMasterPassword('TestPassword1');

        final newConfig = ProtectionConfig(
          protectedModeEnabled: true,
          blockSettings: true,
          blockFileManagers: true,
          monitorCalls: true,
          emergencyContact: '+1234567890',
        );

        final result = await protectionService.updateConfiguration(
          newConfig,
          'TestPassword1',
        );
        expect(result, isTrue);

        final loadedConfig = await protectionService.loadConfiguration();
        expect(loadedConfig.protectedModeEnabled, isTrue);
        expect(loadedConfig.blockSettings, isTrue);
        expect(loadedConfig.emergencyContact, equals('+1234567890'));
      });
    });

    // ============================================================
    // Property-Based Tests
    // ============================================================

    /// **Feature: anti-theft-protection, Property 3: Configuration Change Protection**
    /// **Validates: Requirements 1.4, 9.3**
    ///
    /// *For any* configuration change attempt when Protected Mode is active,
    /// the system SHALL require Master Password authentication before allowing
    /// the change.
    group('Property 3: Configuration Change Protection', () {
      test(
          'configuration changes require correct password when protected mode is active',
          () async {
        final faker = Faker();

        for (int i = 0; i < 100; i++) {
          final services = await createTestServices(mockStorage);
          final testService = services.service;
          final testAuth = services.auth;

          // Generate a valid password
          final password = '${faker.internet.password(length: 10)}A1';
          await testAuth.setupMasterPassword(password);

          // Get initial configuration
          final initialConfig = await testService.getConfiguration();

          // Generate a random configuration change
          final newConfig = ProtectionConfig(
            protectedModeEnabled: faker.randomGenerator.boolean(),
            kioskModeEnabled: faker.randomGenerator.boolean(),
            stealthModeEnabled: faker.randomGenerator.boolean(),
            blockSettings: faker.randomGenerator.boolean(),
            blockFileManagers: faker.randomGenerator.boolean(),
            blockPowerMenu: faker.randomGenerator.boolean(),
            monitorCalls: faker.randomGenerator.boolean(),
            monitorAirplaneMode: faker.randomGenerator.boolean(),
            monitorSimCard: faker.randomGenerator.boolean(),
            emergencyContact: faker.phoneNumber.us(),
          );

          // Attempt to update with wrong password
          final wrongPassword = '${faker.internet.password(length: 10)}B2';
          final wrongResult = await testService.updateConfiguration(
            newConfig,
            wrongPassword,
          );

          expect(wrongResult, isFalse,
              reason:
                  'Configuration change should fail with incorrect password');

          // Verify configuration was NOT changed
          final configAfterWrongPassword =
              await testService.getConfiguration();
          expect(
              configAfterWrongPassword.protectedModeEnabled,
              equals(initialConfig.protectedModeEnabled),
              reason:
                  'Configuration should remain unchanged after failed password');

          // Attempt to update with correct password
          final correctResult = await testService.updateConfiguration(
            newConfig,
            password,
          );

          expect(correctResult, isTrue,
              reason:
                  'Configuration change should succeed with correct password');

          // Verify configuration WAS changed
          final configAfterCorrectPassword =
              await testService.getConfiguration();
          expect(
              configAfterCorrectPassword.protectedModeEnabled,
              equals(newConfig.protectedModeEnabled),
              reason:
                  'Configuration should be updated after correct password');
          expect(
              configAfterCorrectPassword.blockSettings,
              equals(newConfig.blockSettings),
              reason: 'All configuration fields should be updated');
        }
      });

      test('configuration changes always require password regardless of mode',
          () async {
        final faker = Faker();

        for (int i = 0; i < 100; i++) {
          final services = await createTestServices(mockStorage);
          final testService = services.service;
          final testAuth = services.auth;

          // Generate a valid password
          final password = '${faker.internet.password(length: 10)}A1';
          await testAuth.setupMasterPassword(password);

          // Generate random configuration
          final newConfig = ProtectionConfig(
            protectedModeEnabled: faker.randomGenerator.boolean(),
            blockSettings: faker.randomGenerator.boolean(),
            dailyReportEnabled: faker.randomGenerator.boolean(),
          );

          // Attempt without password (empty string)
          final emptyPasswordResult =
              await testService.updateConfiguration(
            newConfig,
            '',
          );
          expect(emptyPasswordResult, isFalse,
              reason: 'Empty password should be rejected');

          // Attempt with null-like password
          final nullLikeResult = await testService.updateConfiguration(
            newConfig,
            'null',
          );
          expect(nullLikeResult, isFalse,
              reason: 'Invalid password should be rejected');

          // Only correct password should work
          final correctResult = await testService.updateConfiguration(
            newConfig,
            password,
          );
          expect(correctResult, isTrue,
              reason: 'Only correct password should allow configuration change');
        }
      });

      test('password verification is case-sensitive for configuration changes',
          () async {
        final faker = Faker();

        for (int i = 0; i < 100; i++) {
          final services = await createTestServices(mockStorage);
          final testService = services.service;
          final testAuth = services.auth;

          // Generate a password with mixed case
          final password = 'TestPassword${faker.randomGenerator.integer(999)}';
          await testAuth.setupMasterPassword(password);

          final newConfig = ProtectionConfig(
            protectedModeEnabled: true,
            blockSettings: true,
          );

          // Try with lowercase version
          final lowercaseResult = await testService.updateConfiguration(
            newConfig,
            password.toLowerCase(),
          );
          expect(lowercaseResult, isFalse,
              reason: 'Lowercase password should fail');

          // Try with uppercase version
          final uppercaseResult = await testService.updateConfiguration(
            newConfig,
            password.toUpperCase(),
          );
          expect(uppercaseResult, isFalse,
              reason: 'Uppercase password should fail');

          // Correct case should work
          final correctResult = await testService.updateConfiguration(
            newConfig,
            password,
          );
          expect(correctResult, isTrue,
              reason: 'Exact password should succeed');
        }
      });

      test('failed configuration change attempts do not modify state',
          () async {
        final faker = Faker();

        for (int i = 0; i < 100; i++) {
          final services = await createTestServices(mockStorage);
          final testService = services.service;
          final testAuth = services.auth;

          // Generate a valid password
          final password = '${faker.internet.password(length: 10)}A1';
          await testAuth.setupMasterPassword(password);

          // Set initial configuration
          final initialConfig = ProtectionConfig(
            protectedModeEnabled: true,
            blockSettings: true,
            emergencyContact: '+1111111111',
          );
          await testService.updateConfiguration(initialConfig, password);

          // Capture state before failed attempts
          final configBefore = await testService.getConfiguration();

          // Attempt multiple failed configuration changes
          final numAttempts = faker.randomGenerator.integer(5, min: 1);
          for (int j = 0; j < numAttempts; j++) {
            final wrongPassword = '${faker.internet.password(length: 10)}B2';
            final newConfig = ProtectionConfig(
              protectedModeEnabled: false,
              blockSettings: false,
              emergencyContact: '+2222222222',
            );

            await testService.updateConfiguration(newConfig, wrongPassword);
          }

          // Verify state is unchanged
          final configAfter = await testService.getConfiguration();
          expect(
              configAfter.protectedModeEnabled,
              equals(configBefore.protectedModeEnabled),
              reason: 'Protected mode should be unchanged after failed attempts');
          expect(
              configAfter.blockSettings,
              equals(configBefore.blockSettings),
              reason: 'Block settings should be unchanged after failed attempts');
          expect(
              configAfter.emergencyContact,
              equals(configBefore.emergencyContact),
              reason:
                  'Emergency contact should be unchanged after failed attempts');
        }
      });
    });
  });
}
