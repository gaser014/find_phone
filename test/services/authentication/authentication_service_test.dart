import 'package:flutter_test/flutter_test.dart';
import 'package:faker/faker.dart';
import 'package:find_phone/services/authentication/authentication_service.dart';
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

  void reset() {
    _secureStorage.clear();
    _storage.clear();
  }
}

void main() {
  group('AuthenticationService', () {
    late AuthenticationService authService;
    late MockStorageService mockStorage;

    setUp(() {
      mockStorage = MockStorageService();
      authService = AuthenticationService(storageService: mockStorage);
    });

    tearDown(() {
      mockStorage.reset();
    });

    group('Password Strength Validation', () {
      test('rejects password shorter than 8 characters', () {
        expect(authService.validatePasswordStrength('Pass1'), isFalse);
        expect(authService.validatePasswordStrength('Ab1'), isFalse);
        expect(authService.validatePasswordStrength('1234567'), isFalse);
      });

      test('rejects password without letters', () {
        expect(authService.validatePasswordStrength('12345678'), isFalse);
        expect(authService.validatePasswordStrength('123456789'), isFalse);
      });

      test('rejects password without numbers', () {
        expect(authService.validatePasswordStrength('abcdefgh'), isFalse);
        expect(authService.validatePasswordStrength('Password'), isFalse);
      });

      test('accepts valid password with letters and numbers', () {
        expect(authService.validatePasswordStrength('Password1'), isTrue);
        expect(authService.validatePasswordStrength('abc12345'), isTrue);
        expect(authService.validatePasswordStrength('12345abc'), isTrue);
        expect(authService.validatePasswordStrength('a1b2c3d4'), isTrue);
      });
    });

    group('Password Setup', () {
      test('successfully sets up valid password', () async {
        final result = await authService.setupMasterPassword('Password123');
        expect(result, isTrue);
        expect(await authService.isPasswordSet(), isTrue);
      });

      test('fails to set up weak password', () async {
        final result = await authService.setupMasterPassword('weak');
        expect(result, isFalse);
        expect(await authService.isPasswordSet(), isFalse);
      });

      test('fails to set up password twice', () async {
        await authService.setupMasterPassword('Password123');
        final result = await authService.setupMasterPassword('AnotherPass1');
        expect(result, isFalse);
      });
    });

    group('Password Verification', () {
      test('verifies correct password', () async {
        await authService.setupMasterPassword('Password123');
        final result = await authService.verifyPassword('Password123');
        expect(result, isTrue);
      });

      test('rejects incorrect password', () async {
        await authService.setupMasterPassword('Password123');
        final result = await authService.verifyPassword('WrongPassword1');
        expect(result, isFalse);
      });

      test('returns false when no password is set', () async {
        final result = await authService.verifyPassword('Password123');
        expect(result, isFalse);
      });
    });

    group('Password Change', () {
      test('successfully changes password with correct old password', () async {
        await authService.setupMasterPassword('OldPassword1');
        final result = await authService.changeMasterPassword(
          'OldPassword1',
          'NewPassword2',
        );
        expect(result, isTrue);
        expect(await authService.verifyPassword('NewPassword2'), isTrue);
        expect(await authService.verifyPassword('OldPassword1'), isFalse);
      });

      test('fails to change password with incorrect old password', () async {
        await authService.setupMasterPassword('OldPassword1');
        final result = await authService.changeMasterPassword(
          'WrongPassword1',
          'NewPassword2',
        );
        expect(result, isFalse);
        expect(await authService.verifyPassword('OldPassword1'), isTrue);
      });

      test('fails to change to weak new password', () async {
        await authService.setupMasterPassword('OldPassword1');
        final result = await authService.changeMasterPassword(
          'OldPassword1',
          'weak',
        );
        expect(result, isFalse);
        expect(await authService.verifyPassword('OldPassword1'), isTrue);
      });
    });


    group('Failed Attempts Tracking', () {
      test('starts with zero failed attempts', () async {
        final count = await authService.getFailedAttemptsCount();
        expect(count, equals(0));
      });

      test('increments failed attempts on wrong password', () async {
        await authService.setupMasterPassword('Password123');
        await authService.verifyPassword('WrongPass1');
        expect(await authService.getFailedAttemptsCount(), equals(1));
        await authService.verifyPassword('WrongPass2');
        expect(await authService.getFailedAttemptsCount(), equals(2));
      });

      test('resets failed attempts on successful login', () async {
        await authService.setupMasterPassword('Password123');
        await authService.verifyPassword('WrongPass1');
        await authService.verifyPassword('WrongPass2');
        expect(await authService.getFailedAttemptsCount(), equals(2));

        await authService.verifyPassword('Password123');
        expect(await authService.getFailedAttemptsCount(), equals(0));
      });

      test('is locked after 3 failed attempts', () async {
        await authService.setupMasterPassword('Password123');
        expect(await authService.isLocked(), isFalse);

        await authService.verifyPassword('Wrong1');
        await authService.verifyPassword('Wrong2');
        await authService.verifyPassword('Wrong3');

        expect(await authService.isLocked(), isTrue);
        expect(await authService.shouldTriggerSecurityAlert(), isTrue);
      });

      test('records last failed attempt time', () async {
        await authService.setupMasterPassword('Password123');
        expect(await authService.getLastFailedAttemptTime(), isNull);

        await authService.verifyPassword('WrongPass1');
        final lastTime = await authService.getLastFailedAttemptTime();
        expect(lastTime, isNotNull);
        expect(
          lastTime!.difference(DateTime.now()).inSeconds.abs(),
          lessThan(2),
        );
      });
    });

    // ============================================================
    // Property-Based Tests
    // ============================================================

    /// **Feature: anti-theft-protection, Property 1: Password Hashing Consistency**
    /// **Validates: Requirements 1.2**
    ///
    /// *For any* valid Master Password, hashing it with SHA-256 and salt should
    /// produce a consistent hash that can be verified later with the same password.
    group('Property 1: Password Hashing Consistency', () {
      test('password hashing produces consistent verifiable hashes', () async {
        final faker = Faker();

        for (int i = 0; i < 100; i++) {
          // Reset storage for each iteration
          mockStorage.reset();
          authService = AuthenticationService(storageService: mockStorage);

          // Generate a valid password (8+ chars with letters and numbers)
          final basePassword = faker.internet.password(length: 10);
          // Ensure it has both letters and numbers
          final password = '${basePassword}A1';

          // Setup the password
          final setupResult = await authService.setupMasterPassword(password);
          expect(setupResult, isTrue,
              reason: 'Password setup should succeed for: $password');

          // Verify the same password works
          final verifyResult = await authService.verifyPassword(password);
          expect(verifyResult, isTrue,
              reason: 'Same password should verify successfully');

          // Verify a different password fails
          final wrongPassword = '${password}wrong';
          final wrongResult = await authService.verifyPassword(wrongPassword);
          expect(wrongResult, isFalse,
              reason: 'Different password should fail verification');
        }
      });

      test('same password with same salt produces same hash', () {
        final faker = Faker();

        for (int i = 0; i < 100; i++) {
          final password = '${faker.internet.password(length: 10)}A1';
          final salt = authService.generateSalt();

          final hash1 = authService.hashPassword(password, salt);
          final hash2 = authService.hashPassword(password, salt);

          expect(hash1, equals(hash2),
              reason: 'Same password and salt should produce same hash');
        }
      });

      test('same password with different salt produces different hash', () {
        final faker = Faker();

        for (int i = 0; i < 100; i++) {
          final password = '${faker.internet.password(length: 10)}A1';
          final salt1 = authService.generateSalt();
          final salt2 = authService.generateSalt();

          final hash1 = authService.hashPassword(password, salt1);
          final hash2 = authService.hashPassword(password, salt2);

          expect(hash1, isNot(equals(hash2)),
              reason: 'Same password with different salt should produce different hash');
        }
      });
    });


    /// **Feature: anti-theft-protection, Property 2: Failed Attempt Counter Reset**
    /// **Validates: Requirements 1.6**
    ///
    /// *For any* number of failed password attempts followed by a successful login,
    /// the failed attempt counter should be reset to zero.
    group('Property 2: Failed Attempt Counter Reset', () {
      test('failed attempt counter resets to zero after successful login', () async {
        final faker = Faker();

        for (int i = 0; i < 100; i++) {
          // Reset storage for each iteration
          mockStorage.reset();
          authService = AuthenticationService(storageService: mockStorage);

          // Generate a valid password
          final password = '${faker.internet.password(length: 10)}A1';
          await authService.setupMasterPassword(password);

          // Generate random number of failed attempts (1-10)
          final numFailedAttempts = faker.randomGenerator.integer(10, min: 1);

          // Perform failed attempts
          for (int j = 0; j < numFailedAttempts; j++) {
            final wrongPassword = '${faker.internet.password(length: 10)}B2';
            await authService.verifyPassword(wrongPassword);
          }

          // Verify failed attempts were recorded
          final countBeforeSuccess = await authService.getFailedAttemptsCount();
          expect(countBeforeSuccess, equals(numFailedAttempts),
              reason: 'Failed attempts should be recorded');

          // Successful login
          final verifyResult = await authService.verifyPassword(password);
          expect(verifyResult, isTrue,
              reason: 'Correct password should verify successfully');

          // Verify counter is reset to zero
          final countAfterSuccess = await authService.getFailedAttemptsCount();
          expect(countAfterSuccess, equals(0),
              reason: 'Failed attempt counter should be reset to zero after successful login');
        }
      });

      test('counter resets even when at threshold', () async {
        final faker = Faker();

        for (int i = 0; i < 100; i++) {
          // Reset storage for each iteration
          mockStorage.reset();
          authService = AuthenticationService(storageService: mockStorage);

          // Generate a valid password
          final password = '${faker.internet.password(length: 10)}A1';
          await authService.setupMasterPassword(password);

          // Reach the threshold (3 failed attempts)
          for (int j = 0; j < AuthenticationService.failedAttemptThreshold; j++) {
            final wrongPassword = '${faker.internet.password(length: 10)}B2';
            await authService.verifyPassword(wrongPassword);
          }

          // Verify we're at threshold
          expect(await authService.isLocked(), isTrue,
              reason: 'Account should be locked after threshold');
          expect(await authService.shouldTriggerSecurityAlert(), isTrue,
              reason: 'Security alert should be triggered');

          // Successful login should still work and reset counter
          final verifyResult = await authService.verifyPassword(password);
          expect(verifyResult, isTrue,
              reason: 'Correct password should still verify even when locked');

          // Counter should be reset
          expect(await authService.getFailedAttemptsCount(), equals(0),
              reason: 'Counter should reset after successful login');
          expect(await authService.isLocked(), isFalse,
              reason: 'Account should no longer be locked');
        }
      });
    });
  });
}
