import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'i_alarm_service.dart';

/// Implementation of [IAlarmService] using native Android audio.
///
/// Provides loud alarm functionality for anti-theft protection:
/// - Maximum volume alarm that ignores device volume settings
/// - Continuous playback until password is entered
/// - 2-minute duration for remote ALARM command
///
/// Requirements: 7.1, 7.2, 7.4, 7.5, 8.5
class AlarmService implements IAlarmService {
  static const String _channelName = 'com.example.find_phone/alarm';
  final MethodChannel _methodChannel = const MethodChannel(_channelName);

  Timer? _alarmTimer;
  DateTime? _alarmStartTime;
  Duration _alarmDuration = Duration.zero;
  bool _isInitialized = false;
  bool _isContinuous = false;
  String? _alarmReason;

  /// Singleton instance
  static AlarmService? _instance;

  /// Get singleton instance
  static AlarmService get instance {
    _instance ??= AlarmService._();
    return _instance!;
  }

  AlarmService._();

  /// Factory constructor for testing
  factory AlarmService.forTesting() {
    return AlarmService._();
  }

  @override
  Future<void> initialize() async {
    if (_isInitialized) return;
    _isInitialized = true;
  }

  @override
  Future<void> dispose() async {
    _alarmTimer?.cancel();
    _alarmTimer = null;
    await stopAlarm();
    _isInitialized = false;
  }

  @override
  Future<bool> triggerAlarm({
    Duration duration = const Duration(minutes: 2),
    bool ignoreVolumeSettings = true,
    bool continuous = false,
    String? reason,
  }) async {
    try {
      // For continuous alarms, use a very long duration (24 hours)
      // The alarm will be stopped manually via stopAlarm()
      final effectiveDuration = continuous 
          ? const Duration(hours: 24).inMilliseconds 
          : duration.inMilliseconds;

      final result = await _methodChannel.invokeMethod<bool>('triggerAlarm', {
        'duration': effectiveDuration,
        'maxVolume': ignoreVolumeSettings,
        'ignoreVolumeSettings': ignoreVolumeSettings,
      });

      if (result == true) {
        _alarmStartTime = DateTime.now();
        _alarmDuration = continuous ? Duration.zero : duration;
        _isContinuous = continuous;
        _alarmReason = reason;

        // Only set auto-stop timer for non-continuous alarms
        if (!continuous) {
          _alarmTimer?.cancel();
          _alarmTimer = Timer(duration, () async {
            await stopAlarm();
          });
        }
      }

      return result ?? false;
    } on PlatformException catch (e) {
      debugPrint('Error triggering alarm: ${e.message}');
      return false;
    }
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
    try {
      _alarmTimer?.cancel();
      _alarmTimer = null;
      _alarmStartTime = null;
      _alarmDuration = Duration.zero;
      _isContinuous = false;
      _alarmReason = null;

      final result = await _methodChannel.invokeMethod<bool>('stopAlarm');
      return result ?? false;
    } on PlatformException catch (e) {
      debugPrint('Error stopping alarm: ${e.message}');
      return false;
    }
  }

  @override
  Future<bool> isAlarmPlaying() async {
    try {
      final result = await _methodChannel.invokeMethod<bool>('isAlarmPlaying');
      return result ?? false;
    } on PlatformException catch (e) {
      debugPrint('Error checking alarm status: ${e.message}');
      return false;
    }
  }

  @override
  Future<bool> requiresPasswordToStop() async {
    final isPlaying = await isAlarmPlaying();
    return isPlaying && _isContinuous;
  }

  @override
  Future<String?> getAlarmReason() async {
    final isPlaying = await isAlarmPlaying();
    return isPlaying ? _alarmReason : null;
  }

  @override
  Future<Duration> getRemainingDuration() async {
    if (_alarmStartTime == null || _isContinuous) {
      return Duration.zero;
    }

    final elapsed = DateTime.now().difference(_alarmStartTime!);
    final remaining = _alarmDuration - elapsed;

    return remaining.isNegative ? Duration.zero : remaining;
  }

  @override
  Future<void> setAlarmSound(String soundPath) async {
    try {
      await _methodChannel.invokeMethod('setAlarmSound', {
        'soundPath': soundPath,
      });
    } on PlatformException catch (e) {
      debugPrint('Error setting alarm sound: ${e.message}');
    }
  }

  @override
  Future<bool> hasAudioPermission() async {
    // Audio playback doesn't require special permissions on Android
    // but we check if the service is available
    try {
      final result = await _methodChannel.invokeMethod<bool>('hasAudioPermission');
      return result ?? true;
    } on PlatformException {
      return true;
    }
  }

  @override
  Future<bool> requestAudioPermission() async {
    // Audio playback doesn't require special permissions on Android
    return true;
  }

  @override
  DateTime? getAlarmStartTime() {
    return _alarmStartTime;
  }

  /// Check if the alarm is in continuous mode.
  bool get isContinuousMode => _isContinuous;

  @override
  Future<bool> stopAlarmWithPassword(
    Future<bool> Function(String) verifyPassword,
    String password,
  ) async {
    // Check if alarm is playing
    final isPlaying = await isAlarmPlaying();
    if (!isPlaying) {
      return false;
    }

    // Verify the password
    final isPasswordCorrect = await verifyPassword(password);
    if (!isPasswordCorrect) {
      return false;
    }

    // Password is correct, stop the alarm
    return stopAlarm();
  }
}
