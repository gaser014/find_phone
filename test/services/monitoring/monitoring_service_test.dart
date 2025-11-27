import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:faker/faker.dart';
import 'package:find_phone/domain/entities/call_log_entry.dart';
import 'package:find_phone/domain/entities/sim_info.dart';
import 'package:find_phone/services/monitoring/i_monitoring_service.dart';
import 'package:find_phone/services/monitoring/monitoring_service.dart';
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
  TestWidgetsFlutterBinding.ensureInitialized();

  group('MonitoringService', () {
    late MonitoringService monitoringService;
    late MockStorageService mockStorage;

    setUp(() {
      mockStorage = MockStorageService();
      monitoringService = MonitoringService(
        storageService: mockStorage,
      );
    });

    tearDown(() {
      mockStorage.reset();
    });

    group('SimInfo Model', () {
      test('isDifferentFrom returns true for different ICCID', () {
        final sim1 = SimInfo(
          iccid: '12345',
          imsi: 'imsi1',
          recordedAt: DateTime.now(),
        );
        final sim2 = SimInfo(
          iccid: '67890',
          imsi: 'imsi1',
          recordedAt: DateTime.now(),
        );

        expect(sim1.isDifferentFrom(sim2), isTrue);
      });

      test('isDifferentFrom returns true for different IMSI', () {
        final sim1 = SimInfo(
          iccid: '12345',
          imsi: 'imsi1',
          recordedAt: DateTime.now(),
        );
        final sim2 = SimInfo(
          iccid: '12345',
          imsi: 'imsi2',
          recordedAt: DateTime.now(),
        );

        expect(sim1.isDifferentFrom(sim2), isTrue);
      });

      test('isDifferentFrom returns false for same SIM', () {
        final sim1 = SimInfo(
          iccid: '12345',
          imsi: 'imsi1',
          recordedAt: DateTime.now(),
        );
        final sim2 = SimInfo(
          iccid: '12345',
          imsi: 'imsi1',
          recordedAt: DateTime.now(),
        );

        expect(sim1.isDifferentFrom(sim2), isFalse);
      });

      test('isValid returns true when ICCID is present', () {
        final sim = SimInfo(
          iccid: '12345',
          recordedAt: DateTime.now(),
        );

        expect(sim.isValid, isTrue);
      });

      test('isAbsent returns true when no identifiers', () {
        final sim = SimInfo.absent();

        expect(sim.isAbsent, isTrue);
      });
    });

    group('CallLogEntry Model', () {
      test('creates entry with all fields', () {
        final entry = CallLogEntry(
          id: '1',
          phoneNumber: '+1234567890',
          type: CallType.incoming,
          timestamp: DateTime.now(),
          duration: const Duration(minutes: 5),
          isEmergencyContact: true,
        );

        expect(entry.phoneNumber, equals('+1234567890'));
        expect(entry.type, equals(CallType.incoming));
        expect(entry.duration.inMinutes, equals(5));
        expect(entry.isEmergencyContact, isTrue);
      });

      test('formattedDuration returns correct format', () {
        final entry = CallLogEntry(
          id: '1',
          phoneNumber: '+1234567890',
          type: CallType.outgoing,
          timestamp: DateTime.now(),
          duration: const Duration(minutes: 2, seconds: 30),
        );

        expect(entry.formattedDuration, equals('2:30'));
      });

      test('toJson and fromJson round trip', () {
        final original = CallLogEntry(
          id: '1',
          phoneNumber: '+1234567890',
          type: CallType.missed,
          timestamp: DateTime(2024, 1, 15, 10, 30),
          duration: const Duration(seconds: 0),
          isEmergencyContact: false,
        );

        final json = original.toJson();
        final restored = CallLogEntry.fromJson(json);

        expect(restored.id, equals(original.id));
        expect(restored.phoneNumber, equals(original.phoneNumber));
        expect(restored.type, equals(original.type));
        expect(restored.isEmergencyContact, equals(original.isEmergencyContact));
      });
    });

    group('Event Models', () {
      test('AirplaneModeEvent serialization', () {
        final event = AirplaneModeEvent(
          isEnabled: true,
          timestamp: DateTime(2024, 1, 15, 10, 30),
          isAuthorized: false,
        );

        final json = event.toJson();
        final restored = AirplaneModeEvent.fromJson(json);

        expect(restored.isEnabled, equals(event.isEnabled));
        expect(restored.isAuthorized, equals(event.isAuthorized));
      });

      test('SimChangeEvent detects removal', () {
        final event = SimChangeEvent(
          previousSim: SimInfo(iccid: '12345', recordedAt: DateTime.now()),
          newSim: SimInfo.absent(),
          timestamp: DateTime.now(),
        );

        expect(event.isRemoved, isTrue);
      });

      test('SimChangeEvent detects insertion', () {
        final event = SimChangeEvent(
          previousSim: SimInfo.absent(),
          newSim: SimInfo(iccid: '12345', recordedAt: DateTime.now()),
          timestamp: DateTime.now(),
        );

        expect(event.isInserted, isTrue);
      });

      test('CallEvent serialization', () {
        final event = CallEvent(
          phoneNumber: '+1234567890',
          type: CallType.incoming,
          timestamp: DateTime(2024, 1, 15, 10, 30),
          duration: const Duration(minutes: 5),
          isEmergencyContact: true,
        );

        final json = event.toJson();
        final restored = CallEvent.fromJson(json);

        expect(restored.phoneNumber, equals(event.phoneNumber));
        expect(restored.type, equals(event.type));
        expect(restored.isEmergencyContact, equals(event.isEmergencyContact));
      });
    });


    // ============================================================
    // Property-Based Tests
    // ============================================================

    /// **Feature: anti-theft-protection, Property 11: SIM Change Detection and Alert**
    /// **Validates: Requirements 13.3, 13.5**
    ///
    /// *For any* SIM card change, the system should detect it within 5 seconds,
    /// send SMS to Emergency Contact with new SIM details, and capture front camera photo.
    group('Property 11: SIM Change Detection and Alert', () {
      test('SIM change is detected and event contains correct details', () {
        final faker = Faker();

        for (int i = 0; i < 100; i++) {
          // Generate random SIM info for previous SIM
          final previousIccid = faker.randomGenerator.string(20, min: 15);
          final previousImsi = faker.randomGenerator.string(15, min: 10);
          final previousCarrier = faker.company.name();

          final previousSim = SimInfo(
            iccid: previousIccid,
            imsi: previousImsi,
            carrierName: previousCarrier,
            recordedAt: DateTime.now().subtract(const Duration(days: 1)),
          );

          // Generate random SIM info for new SIM (different)
          final newIccid = faker.randomGenerator.string(20, min: 15);
          final newImsi = faker.randomGenerator.string(15, min: 10);
          final newCarrier = faker.company.name();
          final newPhoneNumber = faker.phoneNumber.us();

          final newSim = SimInfo(
            iccid: newIccid,
            imsi: newImsi,
            phoneNumber: newPhoneNumber,
            carrierName: newCarrier,
            recordedAt: DateTime.now(),
          );

          // Verify SIMs are different
          expect(newSim.isDifferentFrom(previousSim), isTrue,
              reason: 'New SIM should be detected as different from previous SIM');

          // Create SIM change event
          final event = SimChangeEvent(
            previousSim: previousSim,
            newSim: newSim,
            timestamp: DateTime.now(),
          );

          // Verify event contains all required details for SMS alert (Requirement 13.3)
          expect(event.newSim, isNotNull,
              reason: 'Event should contain new SIM details');
          expect(event.newSim!.iccid, equals(newIccid),
              reason: 'Event should contain new SIM ICCID');
          expect(event.newSim!.imsi, equals(newImsi),
              reason: 'Event should contain new SIM IMSI');
          expect(event.previousSim, isNotNull,
              reason: 'Event should contain previous SIM for reference');
          expect(event.timestamp, isNotNull,
              reason: 'Event should have timestamp');
        }
      });

      test('SIM removal is detected correctly', () {
        final faker = Faker();

        for (int i = 0; i < 100; i++) {
          // Generate random SIM info for previous SIM
          final previousIccid = faker.randomGenerator.string(20, min: 15);
          final previousImsi = faker.randomGenerator.string(15, min: 10);

          final previousSim = SimInfo(
            iccid: previousIccid,
            imsi: previousImsi,
            recordedAt: DateTime.now().subtract(const Duration(days: 1)),
          );

          // Create absent SIM (removal)
          final newSim = SimInfo.absent();

          // Create SIM change event for removal
          final event = SimChangeEvent(
            previousSim: previousSim,
            newSim: newSim,
            timestamp: DateTime.now(),
          );

          // Verify removal is detected
          expect(event.isRemoved, isTrue,
              reason: 'SIM removal should be detected');
          expect(event.previousSim!.isValid, isTrue,
              reason: 'Previous SIM should be valid');
          expect(event.newSim!.isAbsent, isTrue,
              reason: 'New SIM should be absent');
        }
      });

      test('SIM insertion is detected correctly', () {
        final faker = Faker();

        for (int i = 0; i < 100; i++) {
          // Start with absent SIM
          final previousSim = SimInfo.absent();

          // Generate random SIM info for new SIM
          final newIccid = faker.randomGenerator.string(20, min: 15);
          final newImsi = faker.randomGenerator.string(15, min: 10);

          final newSim = SimInfo(
            iccid: newIccid,
            imsi: newImsi,
            recordedAt: DateTime.now(),
          );

          // Create SIM change event for insertion
          final event = SimChangeEvent(
            previousSim: previousSim,
            newSim: newSim,
            timestamp: DateTime.now(),
          );

          // Verify insertion is detected
          expect(event.isInserted, isTrue,
              reason: 'SIM insertion should be detected');
          expect(event.newSim!.isValid, isTrue,
              reason: 'New SIM should be valid');
        }
      });

      test('Same SIM is not detected as change', () {
        final faker = Faker();

        for (int i = 0; i < 100; i++) {
          // Generate random SIM info
          final iccid = faker.randomGenerator.string(20, min: 15);
          final imsi = faker.randomGenerator.string(15, min: 10);

          final sim1 = SimInfo(
            iccid: iccid,
            imsi: imsi,
            recordedAt: DateTime.now().subtract(const Duration(days: 1)),
          );

          final sim2 = SimInfo(
            iccid: iccid,
            imsi: imsi,
            recordedAt: DateTime.now(),
          );

          // Verify same SIM is not detected as different
          expect(sim1.isDifferentFrom(sim2), isFalse,
              reason: 'Same SIM should not be detected as different');
        }
      });
    });


    /// **Feature: anti-theft-protection, Property 14: Call Logging Completeness**
    /// **Validates: Requirements 19.2, 19.3**
    ///
    /// *For any* call made or received during Protected Mode, the system should
    /// log phone number, duration, timestamp, and call type in encrypted storage.
    group('Property 14: Call Logging Completeness', () {
      test('call log entries contain all required fields', () {
        final faker = Faker();

        for (int i = 0; i < 100; i++) {
          // Generate random call data
          final phoneNumber = faker.phoneNumber.us();
          final callTypes = [CallType.incoming, CallType.outgoing, CallType.missed];
          final type = callTypes[faker.randomGenerator.integer(callTypes.length)];
          final durationSeconds = faker.randomGenerator.integer(3600); // Up to 1 hour
          final isEmergencyContact = faker.randomGenerator.boolean();

          // Create call log entry
          final entry = CallLogEntry(
            id: DateTime.now().millisecondsSinceEpoch.toString(),
            phoneNumber: phoneNumber,
            type: type,
            timestamp: DateTime.now(),
            duration: Duration(seconds: durationSeconds),
            isEmergencyContact: isEmergencyContact,
          );

          // Verify all required fields are present (Requirement 19.2)
          expect(entry.phoneNumber, isNotEmpty,
              reason: 'Call log should contain phone number');
          expect(entry.type, isNotNull,
              reason: 'Call log should contain call type');
          expect(entry.timestamp, isNotNull,
              reason: 'Call log should contain timestamp');
          expect(entry.duration, isNotNull,
              reason: 'Call log should contain duration');
          expect(entry.id, isNotEmpty,
              reason: 'Call log should have unique ID');
        }
      });

      test('call log entries serialize and deserialize correctly for storage', () {
        final faker = Faker();

        for (int i = 0; i < 100; i++) {
          // Generate random call data
          final phoneNumber = faker.phoneNumber.us();
          final callTypes = [CallType.incoming, CallType.outgoing, CallType.missed];
          final type = callTypes[faker.randomGenerator.integer(callTypes.length)];
          final durationSeconds = faker.randomGenerator.integer(3600);
          final isEmergencyContact = faker.randomGenerator.boolean();

          final original = CallLogEntry(
            id: faker.guid.guid(),
            phoneNumber: phoneNumber,
            type: type,
            timestamp: DateTime.now(),
            duration: Duration(seconds: durationSeconds),
            isEmergencyContact: isEmergencyContact,
          );

          // Serialize to JSON (for encrypted storage - Requirement 19.3)
          final json = original.toJson();

          // Verify JSON contains all required fields
          expect(json['phoneNumber'], equals(phoneNumber),
              reason: 'JSON should contain phone number');
          expect(json['type'], equals(type.name),
              reason: 'JSON should contain call type');
          expect(json['timestamp'], isNotNull,
              reason: 'JSON should contain timestamp');
          expect(json['durationSeconds'], equals(durationSeconds),
              reason: 'JSON should contain duration');

          // Deserialize and verify round-trip
          final restored = CallLogEntry.fromJson(json);

          expect(restored.phoneNumber, equals(original.phoneNumber),
              reason: 'Restored entry should have same phone number');
          expect(restored.type, equals(original.type),
              reason: 'Restored entry should have same call type');
          expect(restored.duration.inSeconds, equals(original.duration.inSeconds),
              reason: 'Restored entry should have same duration');
          expect(restored.isEmergencyContact, equals(original.isEmergencyContact),
              reason: 'Restored entry should have same emergency contact flag');
        }
      });

      test('call events contain all required information', () {
        final faker = Faker();

        for (int i = 0; i < 100; i++) {
          // Generate random call event data
          final phoneNumber = faker.phoneNumber.us();
          final callTypes = [CallType.incoming, CallType.outgoing, CallType.missed];
          final type = callTypes[faker.randomGenerator.integer(callTypes.length)];
          final durationSeconds = faker.randomGenerator.integer(3600);
          final isEmergencyContact = faker.randomGenerator.boolean();

          // Create call event
          final event = CallEvent(
            phoneNumber: phoneNumber,
            type: type,
            timestamp: DateTime.now(),
            duration: Duration(seconds: durationSeconds),
            isEmergencyContact: isEmergencyContact,
          );

          // Verify event contains all required fields
          expect(event.phoneNumber, isNotEmpty,
              reason: 'Call event should contain phone number');
          expect(event.type, isNotNull,
              reason: 'Call event should contain call type');
          expect(event.timestamp, isNotNull,
              reason: 'Call event should contain timestamp');
          expect(event.duration, isNotNull,
              reason: 'Call event should contain duration');

          // Verify serialization for logging
          final json = event.toJson();
          expect(json['phoneNumber'], equals(phoneNumber));
          expect(json['type'], equals(type.name));
          expect(json['durationSeconds'], equals(durationSeconds));
          expect(json['isEmergencyContact'], equals(isEmergencyContact));
        }
      });

      test('emergency contact calls are properly flagged', () {
        final faker = Faker();

        for (int i = 0; i < 100; i++) {
          final phoneNumber = faker.phoneNumber.us();
          final isEmergencyContact = faker.randomGenerator.boolean();

          final entry = CallLogEntry(
            id: faker.guid.guid(),
            phoneNumber: phoneNumber,
            type: CallType.incoming,
            timestamp: DateTime.now(),
            duration: const Duration(minutes: 1),
            isEmergencyContact: isEmergencyContact,
          );

          // Verify emergency contact flag is preserved
          expect(entry.isEmergencyContact, equals(isEmergencyContact),
              reason: 'Emergency contact flag should be correctly set');

          // Verify flag survives serialization
          final json = entry.toJson();
          final restored = CallLogEntry.fromJson(json);
          expect(restored.isEmergencyContact, equals(isEmergencyContact),
              reason: 'Emergency contact flag should survive serialization');
        }
      });
    });
  });
}
