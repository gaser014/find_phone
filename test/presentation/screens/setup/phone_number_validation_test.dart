import 'dart:math';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:find_phone/services/sms/sms_service.dart';
import 'package:find_phone/services/storage/i_storage_service.dart';
import 'package:find_phone/services/authentication/i_authentication_service.dart';

/// Mock implementation of IStorageService for testing.
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
  Future<bool> containsKey(String key) async {
    return _storage.containsKey(key);
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
  Future<bool> containsSecureKey(String key) async {
    return _secureStorage.containsKey(key);
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
  Future<Set<String>> getAllKeys() async {
    return _storage.keys.toSet();
  }

  @override
  Future<Set<String>> getAllSecureKeys() async {
    return _secureStorage.keys.toSet();
  }

  /// Check if a value is stored in secure storage
  bool isStoredSecurely(String key) {
    return _secureStorage.containsKey(key);
  }
}

/// Mock implementation of IAuthenticationService for testing.
class MockAuthenticationService implements IAuthenticationService {
  @override
  Future<bool> setupMasterPassword(String password) async => true;

  @override
  Future<bool> verifyPassword(String password) async => true;

  @override
  Future<bool> isPasswordSet() async => true;

  @override
  Future<bool> changeMasterPassword(String oldPassword, String newPassword) async => true;

  @override
  Future<void> recordFailedAttempt() async {}

  @override
  Future<int> getFailedAttemptsCount() async => 0;

  @override
  Future<void> resetFailedAttempts() async {}

  @override
  Future<bool> isLocked() async => false;

  @override
  bool validatePasswordStrength(String password) => true;

  @override
  Future<DateTime?> getLastFailedAttemptTime() async => null;

  @override
  Future<bool> shouldTriggerSecurityAlert() async => false;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Phone Number Validation and Storage', () {
    late MockStorageService storageService;
    late MockAuthenticationService authService;
    late SmsService smsService;
    final random = Random();

    /// Generates a random valid phone number (7-15 digits with optional + prefix)
    String generateValidPhoneNumber() {
      final hasPlus = random.nextBool();
      final length = random.nextInt(9) + 7; // 7-15 digits
      final digits = List.generate(length, (_) => random.nextInt(10)).join();
      return hasPlus ? '+$digits' : digits;
    }

    /// Generates a random invalid phone number
    String generateInvalidPhoneNumber() {
      final invalidTypes = [
        '', // Empty string
        '123', // Too short (less than 7 digits)
        '12345', // Still too short
        'abc${random.nextInt(1000000)}', // Contains letters at start
        '${random.nextInt(1000000)}abc', // Contains letters at end
        '++${random.nextInt(10000000)}', // Double plus
        '+', // Only plus sign
        '   ', // Only whitespace
        '123-456', // Too short even with separator
      ];
      return invalidTypes[random.nextInt(invalidTypes.length)];
    }

    setUp(() {
      storageService = MockStorageService();
      authService = MockAuthenticationService();
      smsService = SmsService(
        storageService: storageService,
        authenticationService: authService,
      );

      // Mock the SMS method channel
      const MethodChannel smsChannel = MethodChannel('com.example.find_phone/sms');
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(smsChannel, (MethodCall methodCall) async {
        return true;
      });
    });

    tearDown(() {
      const MethodChannel smsChannel = MethodChannel('com.example.find_phone/sms');
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(smsChannel, null);
    });

    /// **Feature: anti-theft-protection, Property 13: Phone Number Validation and Storage**
    /// **Validates: Requirements 16.2**
    ///
    /// For any phone number entered as Emergency Contact, the system SHALL validate
    /// the phone number format and store it in encrypted form.
    group('Property 13: Phone Number Validation and Storage', () {
      test('property: valid phone numbers pass validation', () {
        // Run 100 iterations with random valid phone numbers
        for (int i = 0; i < 100; i++) {
          final phoneNumber = generateValidPhoneNumber();
          final isValid = smsService.validatePhoneNumber(phoneNumber);
          
          expect(isValid, isTrue,
              reason: 'Valid phone number "$phoneNumber" should pass validation');
        }
      });

      test('property: invalid phone numbers fail validation', () {
        // Run 100 iterations with random invalid phone numbers
        for (int i = 0; i < 100; i++) {
          final phoneNumber = generateInvalidPhoneNumber();
          final isValid = smsService.validatePhoneNumber(phoneNumber);
          
          expect(isValid, isFalse,
              reason: 'Invalid phone number "$phoneNumber" should fail validation');
        }
      });

      test('property: valid phone numbers are stored in encrypted storage', () async {
        // Run 100 iterations with random valid phone numbers
        for (int i = 0; i < 100; i++) {
          final phoneNumber = generateValidPhoneNumber();
          
          // Store the emergency contact
          await smsService.setEmergencyContact(phoneNumber);
          
          // Verify it's stored in secure (encrypted) storage
          expect(storageService.isStoredSecurely('emergency_contact'), isTrue,
              reason: 'Emergency contact should be stored in secure storage');
          
          // Verify the stored value matches
          final storedValue = await smsService.getEmergencyContact();
          expect(storedValue, equals(phoneNumber),
              reason: 'Stored phone number should match the input');
        }
      });

      test('property: invalid phone numbers are rejected and not stored', () async {
        // Run 100 iterations with random invalid phone numbers
        for (int i = 0; i < 100; i++) {
          // Clear storage first
          await storageService.clearAll();
          
          final phoneNumber = generateInvalidPhoneNumber();
          
          // Attempt to store the invalid emergency contact
          bool threwError = false;
          try {
            await smsService.setEmergencyContact(phoneNumber);
          } catch (e) {
            threwError = true;
          }
          
          // Should throw an error for invalid phone numbers
          expect(threwError, isTrue,
              reason: 'Setting invalid phone number "$phoneNumber" should throw an error');
          
          // Verify nothing was stored
          final storedValue = await smsService.getEmergencyContact();
          expect(storedValue, isNull,
              reason: 'Invalid phone number should not be stored');
        }
      });

      test('property: phone number format variations are handled correctly', () {
        // Test various valid formats
        final validFormats = [
          '+1234567890',      // International with +
          '1234567890',       // Without +
          '+201234567890',    // Egyptian format
          '01234567890',      // Local format
          '+447911123456',    // UK format
          '00447911123456',   // Alternative international
        ];

        for (final number in validFormats) {
          expect(smsService.validatePhoneNumber(number), isTrue,
              reason: 'Valid format "$number" should be accepted');
        }
      });

      test('property: phone numbers with separators are validated correctly', () {
        // Phone numbers with common separators should be validated
        // after removing separators
        final numbersWithSeparators = [
          '+1 234 567 8901',    // With spaces
          '+1-234-567-8901',    // With dashes
          '+1 (234) 567-8901',  // Mixed format
          '(234) 567-8901',     // US local format
        ];

        for (final number in numbersWithSeparators) {
          // The validation should handle these formats
          final isValid = smsService.validatePhoneNumber(number);
          // These should be valid after separator removal
          expect(isValid, isTrue,
              reason: 'Number with separators "$number" should be valid');
        }
      });

      test('property: stored phone number can be retrieved correctly', () async {
        // Run 100 iterations to verify round-trip storage
        for (int i = 0; i < 100; i++) {
          final phoneNumber = generateValidPhoneNumber();
          
          // Store the phone number
          await smsService.setEmergencyContact(phoneNumber);
          
          // Retrieve and verify
          final retrieved = await smsService.getEmergencyContact();
          
          expect(retrieved, equals(phoneNumber),
              reason: 'Retrieved phone number should match stored value');
        }
      });

      test('property: phone number length boundaries are enforced', () {
        // Test boundary conditions
        
        // Exactly 7 digits (minimum valid)
        expect(smsService.validatePhoneNumber('1234567'), isTrue,
            reason: '7 digit number should be valid (minimum)');
        
        // Exactly 15 digits (maximum valid)
        expect(smsService.validatePhoneNumber('123456789012345'), isTrue,
            reason: '15 digit number should be valid (maximum)');
        
        // 6 digits (too short)
        expect(smsService.validatePhoneNumber('123456'), isFalse,
            reason: '6 digit number should be invalid (too short)');
        
        // 16 digits (too long)
        expect(smsService.validatePhoneNumber('1234567890123456'), isFalse,
            reason: '16 digit number should be invalid (too long)');
      });
    });
  });
}
