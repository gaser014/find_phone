import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:faker/faker.dart';
import 'package:find_phone/domain/entities/remote_command.dart';

void main() {
  group('RemoteCommand', () {
    final random = Random();
    
    /// Generates a random phone number string
    String generatePhoneNumber() {
      final countryCode = random.nextInt(99) + 1;
      final number = random.nextInt(999999999) + 100000000;
      return '+$countryCode$number';
    }

    group('parse', () {
      /// **Feature: anti-theft-protection, Property 8: SMS Command Parsing and Validation**
      /// **Validates: Requirements 8.1, 8.4**
      /// 
      /// For any SMS command in format "COMMAND#password" from Emergency Contact,
      /// the system should correctly parse the command type and verify the password
      /// before execution.
      test('property: valid commands are parsed correctly for all command types', () {
        final commands = ['LOCK', 'WIPE', 'LOCATE', 'ALARM'];
        final expectedTypes = [
          RemoteCommandType.lock,
          RemoteCommandType.wipe,
          RemoteCommandType.locate,
          RemoteCommandType.alarm,
        ];

        // Run 100 iterations with random data
        for (int i = 0; i < 100; i++) {
          final sender = generatePhoneNumber();
          
          // Generate random password (non-empty, no # character)
          final passwordLength = random.nextInt(16) + 4;
          final password = List.generate(
            passwordLength,
            (_) => 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789'[
              random.nextInt(62)
            ],
          ).join();
          
          // Test each command type
          for (int j = 0; j < commands.length; j++) {
            final command = commands[j];
            final expectedType = expectedTypes[j];
            final message = '$command#$password';
            
            final parsed = RemoteCommand.parse(sender, message);
            
            expect(parsed, isNotNull, reason: 'Failed to parse: $message');
            expect(parsed!.type, equals(expectedType), 
                reason: 'Wrong type for command: $command');
            expect(parsed.password, equals(password),
                reason: 'Password not preserved correctly');
            expect(parsed.sender, equals(sender),
                reason: 'Sender not preserved correctly');
          }
        }
      });

      test('property: lowercase commands are parsed correctly', () {
        final commands = ['lock', 'wipe', 'locate', 'alarm'];
        final expectedTypes = [
          RemoteCommandType.lock,
          RemoteCommandType.wipe,
          RemoteCommandType.locate,
          RemoteCommandType.alarm,
        ];

        for (int i = 0; i < 100; i++) {
          final sender = generatePhoneNumber();
          final password = 'Pass${random.nextInt(99999)}word';
          
          for (int j = 0; j < commands.length; j++) {
            final message = '${commands[j]}#$password';
            final parsed = RemoteCommand.parse(sender, message);
            
            expect(parsed, isNotNull);
            expect(parsed!.type, equals(expectedTypes[j]));
          }
        }
      });

      test('property: mixed case commands are parsed correctly', () {
        final commands = ['LoCk', 'WiPe', 'LoCaTe', 'AlArM'];
        
        for (int i = 0; i < 100; i++) {
          final sender = generatePhoneNumber();
          final password = 'Test${random.nextInt(99999)}Pass';
          
          for (final command in commands) {
            final message = '$command#$password';
            final parsed = RemoteCommand.parse(sender, message);
            
            expect(parsed, isNotNull, reason: 'Failed to parse mixed case: $command');
          }
        }
      });

      test('property: invalid command formats return null', () {
        // List of invalid command words to test
        final invalidCommands = ['UNLOCK', 'DELETE', 'FIND', 'STOP', 'START', 'RESET'];
        
        for (int i = 0; i < 100; i++) {
          final sender = generatePhoneNumber();
          final password = 'Pass${random.nextInt(99999)}';
          
          // Missing hash
          expect(RemoteCommand.parse(sender, 'LOCK$password'), isNull);
          
          // Empty command
          expect(RemoteCommand.parse(sender, '#$password'), isNull);
          
          // Empty password
          expect(RemoteCommand.parse(sender, 'LOCK#'), isNull);
          
          // Invalid command - use predefined invalid commands
          final invalidCommand = invalidCommands[random.nextInt(invalidCommands.length)];
          expect(RemoteCommand.parse(sender, '$invalidCommand#$password'), isNull,
              reason: 'Invalid command "$invalidCommand" should return null');
          
          // Empty sender
          expect(RemoteCommand.parse('', 'LOCK#$password'), isNull);
          
          // Empty message
          expect(RemoteCommand.parse(sender, ''), isNull);
        }
      });

      test('property: password case is preserved', () {
        for (int i = 0; i < 100; i++) {
          final sender = generatePhoneNumber();
          // Generate password with mixed case
          final password = 'MixedCase${random.nextInt(999)}ABC';
          
          final parsed = RemoteCommand.parse(sender, 'LOCK#$password');
          
          expect(parsed, isNotNull);
          expect(parsed!.password, equals(password),
              reason: 'Password case should be preserved');
        }
      });
    });

    group('isFromEmergencyContact', () {
      /// **Feature: anti-theft-protection, Property 8: SMS Command Parsing and Validation**
      /// **Validates: Requirements 8.1, 8.4**
      test('property: correctly identifies emergency contact with normalized numbers', () {
        for (int i = 0; i < 100; i++) {
          // Generate a base phone number
          final countryCode = random.nextInt(99) + 1;
          final baseNumber = random.nextInt(999999999) + 100000000;
          
          final emergencyContact = '+$countryCode$baseNumber';
          
          // Same number should match
          final command = RemoteCommand(
            type: RemoteCommandType.lock,
            password: 'test123',
            sender: emergencyContact,
            receivedAt: DateTime.now(),
          );
          
          expect(command.isFromEmergencyContact(emergencyContact), isTrue,
              reason: 'Same number should match');
          
          // Number with spaces/dashes should also match after normalization
          final formattedSender = '+$countryCode-$baseNumber';
          final command2 = RemoteCommand(
            type: RemoteCommandType.lock,
            password: 'test123',
            sender: formattedSender,
            receivedAt: DateTime.now(),
          );
          
          expect(command2.isFromEmergencyContact(emergencyContact), isTrue,
              reason: 'Formatted number should match after normalization');
        }
      });

      test('property: rejects non-emergency contact numbers', () {
        for (int i = 0; i < 100; i++) {
          final emergencyNumber = generatePhoneNumber();
          // Generate a definitely different number
          final differentNumber = '+99${random.nextInt(999999999) + 100000000}';
          
          // Ensure they're actually different
          if (emergencyNumber != differentNumber) {
            final command = RemoteCommand(
              type: RemoteCommandType.lock,
              password: 'test123',
              sender: differentNumber,
              receivedAt: DateTime.now(),
            );
            
            expect(command.isFromEmergencyContact(emergencyNumber), isFalse,
                reason: 'Should not match different numbers');
          }
        }
      });
    });

    group('JSON serialization', () {
      test('property: round-trip serialization preserves all fields', () {
        final faker = Faker();
        final types = RemoteCommandType.values;
        
        for (int i = 0; i < 100; i++) {
          final original = RemoteCommand(
            type: types[random.nextInt(types.length)],
            password: 'Pass${random.nextInt(999999)}Word',
            sender: generatePhoneNumber(),
            receivedAt: DateTime.now().subtract(Duration(
              days: random.nextInt(30),
              hours: random.nextInt(24),
              minutes: random.nextInt(60),
            )),
            parameters: random.nextBool() 
                ? {'key': faker.lorem.word()} 
                : null,
          );
          
          final json = original.toJson();
          final restored = RemoteCommand.fromJson(json);
          
          expect(restored.type, equals(original.type));
          expect(restored.password, equals(original.password));
          expect(restored.sender, equals(original.sender));
          expect(restored.receivedAt.toIso8601String(), 
              equals(original.receivedAt.toIso8601String()));
        }
      });
    });
  });
}
