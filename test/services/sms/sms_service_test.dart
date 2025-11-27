import 'dart:io';
import 'dart:math';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:find_phone/domain/entities/remote_command.dart';
import 'package:find_phone/domain/entities/security_event.dart';
import 'package:find_phone/services/authentication/i_authentication_service.dart';
import 'package:find_phone/services/security_log/i_security_log_service.dart';
import 'package:find_phone/services/sms/sms_service.dart';
import 'package:find_phone/services/storage/i_storage_service.dart';

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
}

/// Mock implementation of IAuthenticationService for testing.
class MockAuthenticationService implements IAuthenticationService {
  String? _masterPassword;
  int _failedAttempts = 0;
  DateTime? _lastFailedAttempt;

  void setMasterPassword(String password) {
    _masterPassword = password;
  }

  @override
  Future<bool> setupMasterPassword(String password) async {
    if (_masterPassword != null) return false;
    _masterPassword = password;
    return true;
  }

  @override
  Future<bool> verifyPassword(String password) async {
    if (_masterPassword == null) return false;
    if (password == _masterPassword) {
      await resetFailedAttempts();
      return true;
    }
    await recordFailedAttempt();
    return false;
  }

  @override
  Future<bool> isPasswordSet() async {
    return _masterPassword != null;
  }

  @override
  Future<bool> changeMasterPassword(String oldPassword, String newPassword) async {
    if (await verifyPassword(oldPassword)) {
      _masterPassword = newPassword;
      return true;
    }
    return false;
  }

  @override
  Future<void> recordFailedAttempt() async {
    _failedAttempts++;
    _lastFailedAttempt = DateTime.now();
  }

  @override
  Future<int> getFailedAttemptsCount() async {
    return _failedAttempts;
  }

  @override
  Future<void> resetFailedAttempts() async {
    _failedAttempts = 0;
    _lastFailedAttempt = null;
  }

  @override
  Future<bool> isLocked() async {
    return _failedAttempts >= 3;
  }

  @override
  bool validatePasswordStrength(String password) {
    if (password.length < 8) return false;
    if (!RegExp(r'[a-zA-Z]').hasMatch(password)) return false;
    if (!RegExp(r'[0-9]').hasMatch(password)) return false;
    return true;
  }

  @override
  Future<DateTime?> getLastFailedAttemptTime() async {
    return _lastFailedAttempt;
  }

  @override
  Future<bool> shouldTriggerSecurityAlert() async {
    return await isLocked();
  }
}

/// Mock implementation of ISecurityLogService for testing.
class MockSecurityLogService implements ISecurityLogService {
  final List<SecurityEvent> _events = [];
  bool _isInitialized = false;

  List<SecurityEvent> get events => List.unmodifiable(_events);

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
  Future<File> exportLogs(String password) async {
    throw UnimplementedError();
  }

  @override
  Future<bool> importLogs(File file, String password) async {
    throw UnimplementedError();
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
  Future<void> initialize(String encryptionKey) async {
    _isInitialized = true;
  }

  @override
  Future<void> close() async {
    _isInitialized = false;
  }

  @override
  bool get isInitialized => _isInitialized;

  void clear() {
    _events.clear();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SmsService', () {
    late MockStorageService storageService;
    late MockAuthenticationService authService;
    late MockSecurityLogService securityLogService;
    late SmsService smsService;
    final random = Random();

    /// Generates a random phone number string
    String generatePhoneNumber() {
      final countryCode = random.nextInt(99) + 1;
      final number = random.nextInt(999999999) + 100000000;
      return '+$countryCode$number';
    }

    /// Generates a random password that meets strength requirements
    String generateValidPassword() {
      final length = random.nextInt(8) + 8; // 8-15 characters
      final chars = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
      final password = List.generate(length, (_) => chars[random.nextInt(chars.length)]).join();
      // Ensure it has at least one letter and one number
      return 'A1$password';
    }

    setUp(() {
      storageService = MockStorageService();
      authService = MockAuthenticationService();
      securityLogService = MockSecurityLogService();
      smsService = SmsService(
        storageService: storageService,
        authenticationService: authService,
        securityLogService: securityLogService,
      );

      // Mock the SMS method channel to avoid platform errors
      const MethodChannel smsChannel = MethodChannel('com.example.find_phone/sms');
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(smsChannel, (MethodCall methodCall) async {
        switch (methodCall.method) {
          case 'sendSms':
            return true;
          case 'sendSmsWithDeliveryConfirmation':
            return true;
          case 'hasSmsPermission':
            return true;
          case 'requestSmsPermission':
            return true;
          default:
            return null;
        }
      });
    });

    tearDown(() {
      const MethodChannel smsChannel = MethodChannel('com.example.find_phone/sms');
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(smsChannel, null);
    });

    group('Emergency Contact Validation', () {
      /// **Feature: anti-theft-protection, Property 9: Non-Emergency Contact Command Rejection**
      /// **Validates: Requirements 8.6**
      ///
      /// For any remote command received from a number that is not the Emergency Contact,
      /// the command should be ignored and logged as suspicious activity.
      test('property: commands from non-emergency contacts are rejected and logged', () async {
        const masterPassword = 'SecurePass123';
        authService.setMasterPassword(masterPassword);

        // Run 100 iterations with random data
        for (int i = 0; i < 100; i++) {
          securityLogService.clear();
          
          // Set up emergency contact
          final emergencyContact = generatePhoneNumber();
          await smsService.setEmergencyContact(emergencyContact);

          // Generate a different sender (non-emergency contact)
          String nonEmergencySender;
          do {
            nonEmergencySender = generatePhoneNumber();
          } while (nonEmergencySender == emergencyContact);

          // Create a valid command from non-emergency contact
          final commands = ['LOCK', 'WIPE', 'LOCATE', 'ALARM'];
          final command = commands[random.nextInt(commands.length)];
          final message = '$command#$masterPassword';

          // Handle the incoming SMS
          final result = await smsService.handleIncomingSms(nonEmergencySender, message);

          // Command should be rejected (return null)
          expect(result, isNull,
              reason: 'Command from non-emergency contact should be rejected');

          // Check that the event was logged
          final events = await securityLogService.getEventsByType(
            SecurityEventType.remoteCommandReceived,
          );
          
          expect(events.isNotEmpty, isTrue,
              reason: 'Rejected command should be logged');
          
          // Verify the log contains rejection reason
          final lastEvent = events.last;
          expect(lastEvent.metadata['rejected_reason'], equals('not_emergency_contact'),
              reason: 'Log should indicate rejection due to non-emergency contact');
          expect(lastEvent.metadata['sender'], equals(nonEmergencySender),
              reason: 'Log should contain the sender number');
        }
      });

      test('property: commands from emergency contact are accepted', () async {
        const masterPassword = 'SecurePass123';
        authService.setMasterPassword(masterPassword);

        // Run 100 iterations with random data
        for (int i = 0; i < 100; i++) {
          securityLogService.clear();
          
          // Set up emergency contact
          final emergencyContact = generatePhoneNumber();
          await smsService.setEmergencyContact(emergencyContact);

          // Create a valid command from emergency contact
          final commands = ['LOCK', 'WIPE', 'LOCATE', 'ALARM'];
          final expectedTypes = [
            RemoteCommandType.lock,
            RemoteCommandType.wipe,
            RemoteCommandType.locate,
            RemoteCommandType.alarm,
          ];
          final commandIndex = random.nextInt(commands.length);
          final command = commands[commandIndex];
          final message = '$command#$masterPassword';

          // Handle the incoming SMS
          final result = await smsService.handleIncomingSms(emergencyContact, message);

          // Command should be accepted
          expect(result, isNotNull,
              reason: 'Command from emergency contact with correct password should be accepted');
          expect(result!.type, equals(expectedTypes[commandIndex]),
              reason: 'Command type should match');
          expect(result.sender, equals(emergencyContact),
              reason: 'Sender should be preserved');
        }
      });

      test('property: phone number normalization works correctly', () async {
        // Run 100 iterations with random data
        for (int i = 0; i < 100; i++) {
          // Generate a base phone number
          final countryCode = random.nextInt(99) + 1;
          final baseNumber = random.nextInt(999999999) + 100000000;
          
          // Store with one format
          final storedFormat = '+$countryCode$baseNumber';
          await smsService.setEmergencyContact(storedFormat);

          // Check with different formats
          final formats = [
            '+$countryCode$baseNumber',           // Same format
            '+$countryCode-$baseNumber',          // With dash
            '+$countryCode $baseNumber',          // With space
            '+$countryCode ($baseNumber)',        // With parentheses
          ];

          for (final format in formats) {
            final isEmergency = await smsService.isEmergencyContact(format);
            expect(isEmergency, isTrue,
                reason: 'Format "$format" should match stored "$storedFormat"');
          }

          // Different number should not match
          final differentNumber = '+${countryCode + 1}$baseNumber';
          final isDifferent = await smsService.isEmergencyContact(differentNumber);
          expect(isDifferent, isFalse,
              reason: 'Different number should not match');
        }
      });
    });

    group('Password Verification', () {
      /// **Feature: anti-theft-protection, Property 10: Incorrect Password Command Rejection**
      /// **Validates: Requirements 8.7**
      ///
      /// For any remote command with incorrect password, the command should not execute
      /// and an authentication failure SMS should be sent.
      test('property: commands with incorrect password are rejected and logged', () async {
        const masterPassword = 'SecurePass123';
        authService.setMasterPassword(masterPassword);

        // Run 100 iterations with random data
        for (int i = 0; i < 100; i++) {
          securityLogService.clear();
          
          // Set up emergency contact
          final emergencyContact = generatePhoneNumber();
          await smsService.setEmergencyContact(emergencyContact);

          // Generate an incorrect password (different from master password)
          String incorrectPassword;
          do {
            incorrectPassword = generateValidPassword();
          } while (incorrectPassword == masterPassword);

          // Create a command with incorrect password
          final commands = ['LOCK', 'WIPE', 'LOCATE', 'ALARM'];
          final command = commands[random.nextInt(commands.length)];
          final message = '$command#$incorrectPassword';

          // Handle the incoming SMS
          final result = await smsService.handleIncomingSms(emergencyContact, message);

          // Command should be rejected (return null)
          expect(result, isNull,
              reason: 'Command with incorrect password should be rejected');

          // Check that the event was logged
          final events = await securityLogService.getEventsByType(
            SecurityEventType.remoteCommandReceived,
          );
          
          expect(events.isNotEmpty, isTrue,
              reason: 'Rejected command should be logged');
          
          // Verify the log contains rejection reason
          final rejectedEvents = events.where(
            (e) => e.metadata['rejected_reason'] == 'invalid_password'
          ).toList();
          
          expect(rejectedEvents.isNotEmpty, isTrue,
              reason: 'Log should indicate rejection due to invalid password');
        }
      });

      test('property: commands with correct password are executed', () async {
        const masterPassword = 'SecurePass123';
        authService.setMasterPassword(masterPassword);

        // Run 100 iterations with random data
        for (int i = 0; i < 100; i++) {
          securityLogService.clear();
          
          // Set up emergency contact
          final emergencyContact = generatePhoneNumber();
          await smsService.setEmergencyContact(emergencyContact);

          // Create a command with correct password
          final commands = ['LOCK', 'WIPE', 'LOCATE', 'ALARM'];
          final command = commands[random.nextInt(commands.length)];
          final message = '$command#$masterPassword';

          // Handle the incoming SMS
          final result = await smsService.handleIncomingSms(emergencyContact, message);

          // Command should be accepted
          expect(result, isNotNull,
              reason: 'Command with correct password should be accepted');

          // Check that execution was logged
          final executedEvents = await securityLogService.getEventsByType(
            SecurityEventType.remoteCommandExecuted,
          );
          
          expect(executedEvents.isNotEmpty, isTrue,
              reason: 'Executed command should be logged');
        }
      });
    });

    group('Phone Number Validation', () {
      test('property: valid phone numbers are accepted', () {
        // Run 100 iterations with random valid phone numbers
        for (int i = 0; i < 100; i++) {
          final phoneNumber = generatePhoneNumber();
          expect(smsService.validatePhoneNumber(phoneNumber), isTrue,
              reason: 'Valid phone number "$phoneNumber" should be accepted');
        }
      });

      test('property: invalid phone numbers are rejected', () {
        final invalidNumbers = [
          '',                    // Empty
          '123',                 // Too short
          'abc123456789',        // Contains letters
          '+',                   // Only plus sign
          '++1234567890',        // Double plus
        ];

        for (final number in invalidNumbers) {
          expect(smsService.validatePhoneNumber(number), isFalse,
              reason: 'Invalid phone number "$number" should be rejected');
        }
      });
    });
  });
}
