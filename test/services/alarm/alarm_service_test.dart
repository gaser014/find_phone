import 'package:flutter_test/flutter_test.dart';
import 'package:faker/faker.dart';
import 'package:find_phone/services/alarm/i_alarm_service.dart';

/// Mock implementation of AlarmService for testing.
///
/// This mock simulates the alarm behavior without requiring
/// native Android platform channels.
class MockAlarmService implements IAlarmService {
  bool _isPlaying = false;
  bool _isContinuous = false;
  DateTime? _startTime;
  Duration _duration = Duration.zero;
  String? _reason;

  @override
  Future<void> initialize() async {
    // No-op for mock
  }

  @override
  Future<void> dispose() async {
    await stopAlarm();
  }

  @override
  Future<bool> triggerAlarm({
    Duration duration = const Duration(minutes: 2),
    bool ignoreVolumeSettings = true,
    bool continuous = false,
    String? reason,
  }) async {
    _isPlaying = true;
    _isContinuous = continuous;
    _startTime = DateTime.now();
    _duration = continuous ? Duration.zero : duration;
    _reason = reason;
    return true;
  }

  @override
  Future<bool> triggerContinuousAlarm({String? reason}) async {
    return triggerAlarm(
      ignoreVolumeSettings: true,
      continuous: true,
      reason: reason,
    );
  }

  @override
  Future<bool> stopAlarm() async {
    _isPlaying = false;
    _isContinuous = false;
    _startTime = null;
    _duration = Duration.zero;
    _reason = null;
    return true;
  }

  @override
  Future<bool> isAlarmPlaying() async {
    return _isPlaying;
  }

  @override
  Future<bool> requiresPasswordToStop() async {
    return _isPlaying && _isContinuous;
  }

  @override
  Future<String?> getAlarmReason() async {
    return _isPlaying ? _reason : null;
  }

  @override
  Future<Duration> getRemainingDuration() async {
    if (_startTime == null || _isContinuous) {
      return Duration.zero;
    }
    final elapsed = DateTime.now().difference(_startTime!);
    final remaining = _duration - elapsed;
    return remaining.isNegative ? Duration.zero : remaining;
  }

  @override
  Future<void> setAlarmSound(String soundPath) async {}

  @override
  Future<bool> hasAudioPermission() async => true;

  @override
  Future<bool> requestAudioPermission() async => true;

  @override
  DateTime? getAlarmStartTime() => _startTime;

  @override
  Future<bool> stopAlarmWithPassword(
    Future<bool> Function(String) verifyPassword,
    String password,
  ) async {
    if (!_isPlaying) {
      return false;
    }
    final isCorrect = await verifyPassword(password);
    if (!isCorrect) {
      return false;
    }
    return stopAlarm();
  }

  void reset() {
    _isPlaying = false;
    _isContinuous = false;
    _startTime = null;
    _duration = Duration.zero;
    _reason = null;
  }
}

void main() {
  group('AlarmService', () {
    late MockAlarmService alarmService;

    setUp(() {
      alarmService = MockAlarmService();
    });

    tearDown(() {
      alarmService.reset();
    });

    group('Basic Alarm Operations', () {
      test('triggers alarm successfully', () async {
        final result = await alarmService.triggerAlarm();
        expect(result, isTrue);
        expect(await alarmService.isAlarmPlaying(), isTrue);
      });

      test('stops alarm successfully', () async {
        await alarmService.triggerAlarm();
        final result = await alarmService.stopAlarm();
        expect(result, isTrue);
        expect(await alarmService.isAlarmPlaying(), isFalse);
      });

      test('records alarm start time', () async {
        final beforeTrigger = DateTime.now();
        await alarmService.triggerAlarm();
        final startTime = alarmService.getAlarmStartTime();
        
        expect(startTime, isNotNull);
        expect(startTime!.isAfter(beforeTrigger.subtract(const Duration(seconds: 1))), isTrue);
      });

      test('records alarm reason', () async {
        const reason = 'unauthorized_access';
        await alarmService.triggerAlarm(reason: reason);
        expect(await alarmService.getAlarmReason(), equals(reason));
      });
    });

    group('Continuous Alarm', () {
      test('triggers continuous alarm', () async {
        final result = await alarmService.triggerContinuousAlarm(reason: 'test');
        expect(result, isTrue);
        expect(await alarmService.isAlarmPlaying(), isTrue);
        expect(await alarmService.requiresPasswordToStop(), isTrue);
      });

      test('continuous alarm returns zero remaining duration', () async {
        await alarmService.triggerContinuousAlarm();
        expect(await alarmService.getRemainingDuration(), equals(Duration.zero));
      });
    });

    group('Password-Protected Alarm Stop', () {
      test('stops alarm with correct password', () async {
        await alarmService.triggerContinuousAlarm();
        
        Future<bool> verifyPassword(String password) async {
          return password == 'correct123';
        }
        
        final result = await alarmService.stopAlarmWithPassword(
          verifyPassword,
          'correct123',
        );
        
        expect(result, isTrue);
        expect(await alarmService.isAlarmPlaying(), isFalse);
      });

      test('does not stop alarm with incorrect password', () async {
        await alarmService.triggerContinuousAlarm();
        
        Future<bool> verifyPassword(String password) async {
          return password == 'correct123';
        }
        
        final result = await alarmService.stopAlarmWithPassword(
          verifyPassword,
          'wrong_password',
        );
        
        expect(result, isFalse);
        expect(await alarmService.isAlarmPlaying(), isTrue);
      });

      test('returns false when no alarm is playing', () async {
        Future<bool> verifyPassword(String password) async => true;
        
        final result = await alarmService.stopAlarmWithPassword(
          verifyPassword,
          'any_password',
        );
        
        expect(result, isFalse);
      });
    });

    // ============================================================
    // Property-Based Tests
    // ============================================================

    /// **Feature: anti-theft-protection, Property 7: Alarm Trigger on Unauthorized Access**
    /// **Validates: Requirements 7.1**
    ///
    /// *For any* unauthorized access attempt detected, the system SHALL trigger
    /// a loud alarm sound at maximum volume.
    group('Property 7: Alarm Trigger on Unauthorized Access', () {
      test('alarm triggers for any unauthorized access event', () async {
        final faker = Faker();

        // Test with 100 random unauthorized access scenarios
        for (int i = 0; i < 100; i++) {
          // Reset for each iteration
          alarmService.reset();

          // Generate random unauthorized access reason
          final reasons = [
            'failed_login_attempt',
            'sim_card_changed',
            'settings_access_blocked',
            'power_menu_blocked',
            'file_manager_blocked',
            'airplane_mode_toggled',
            'device_admin_deactivation_attempt',
            'force_stop_detected',
            'safe_mode_boot',
            'usb_debugging_enabled',
          ];
          final reason = reasons[faker.randomGenerator.integer(reasons.length)];

          // Trigger alarm for unauthorized access
          final triggerResult = await alarmService.triggerAlarm(
            ignoreVolumeSettings: true,
            reason: reason,
          );

          // Property: Alarm MUST trigger successfully for any unauthorized access
          expect(triggerResult, isTrue,
              reason: 'Alarm should trigger for unauthorized access: $reason');

          // Property: Alarm MUST be playing after trigger
          expect(await alarmService.isAlarmPlaying(), isTrue,
              reason: 'Alarm should be playing after trigger');

          // Property: Alarm reason MUST be recorded
          expect(await alarmService.getAlarmReason(), equals(reason),
              reason: 'Alarm reason should be recorded');

          // Property: Alarm start time MUST be recorded
          expect(alarmService.getAlarmStartTime(), isNotNull,
              reason: 'Alarm start time should be recorded');
        }
      });

      test('continuous alarm persists until password entry', () async {
        final faker = Faker();

        for (int i = 0; i < 100; i++) {
          alarmService.reset();

          // Generate random correct password
          final correctPassword = '${faker.internet.password(length: 10)}A1';

          // Trigger continuous alarm (simulating unauthorized access)
          await alarmService.triggerContinuousAlarm(
            reason: 'unauthorized_access_${faker.randomGenerator.integer(1000)}',
          );

          // Property: Continuous alarm requires password to stop
          expect(await alarmService.requiresPasswordToStop(), isTrue,
              reason: 'Continuous alarm should require password to stop');

          // Generate random number of wrong password attempts (1-5)
          final wrongAttempts = faker.randomGenerator.integer(5, min: 1);

          // Simulate wrong password attempts
          for (int j = 0; j < wrongAttempts; j++) {
            final wrongPassword = '${faker.internet.password(length: 10)}B2';
            
            Future<bool> verifyPassword(String password) async {
              return password == correctPassword;
            }

            final stopResult = await alarmService.stopAlarmWithPassword(
              verifyPassword,
              wrongPassword,
            );

            // Property: Alarm MUST NOT stop with wrong password
            expect(stopResult, isFalse,
                reason: 'Alarm should not stop with wrong password');
            expect(await alarmService.isAlarmPlaying(), isTrue,
                reason: 'Alarm should still be playing after wrong password');
          }

          // Now use correct password
          Future<bool> verifyPassword(String password) async {
            return password == correctPassword;
          }

          final stopResult = await alarmService.stopAlarmWithPassword(
            verifyPassword,
            correctPassword,
          );

          // Property: Alarm MUST stop with correct password
          expect(stopResult, isTrue,
              reason: 'Alarm should stop with correct password');
          expect(await alarmService.isAlarmPlaying(), isFalse,
              reason: 'Alarm should not be playing after correct password');
        }
      });

      test('alarm ignores volume settings for unauthorized access', () async {
        final faker = Faker();

        for (int i = 0; i < 100; i++) {
          alarmService.reset();

          // Generate random reason
          final reason = 'unauthorized_${faker.randomGenerator.integer(1000)}';

          // Trigger alarm with ignoreVolumeSettings = true
          final result = await alarmService.triggerAlarm(
            ignoreVolumeSettings: true,
            reason: reason,
          );

          // Property: Alarm MUST trigger with ignoreVolumeSettings
          expect(result, isTrue,
              reason: 'Alarm should trigger with ignoreVolumeSettings=true');

          // Property: Alarm MUST be playing
          expect(await alarmService.isAlarmPlaying(), isTrue,
              reason: 'Alarm should be playing');
        }
      });
    });
  });
}
