import 'dart:async';
import 'dart:developer';
import 'package:flutter/services.dart';
import 'i_boot_service.dart';

/// Implementation of Boot and Auto-Restart Service
///
/// This service manages boot events and auto-restart functionality
/// through native Android method channels.
///
/// Requirements: 2.4, 2.5, 2.6, 20.1
class BootService implements IBootService {
  static const String _channelName = 'com.example.find_phone/boot';
  static const String _eventsChannelName = 'com.example.find_phone/boot_events';

  final MethodChannel _channel = const MethodChannel(_channelName);
  final EventChannel _eventsChannel = const EventChannel(_eventsChannelName);

  // Stream controllers
  final StreamController<BootEvent> _bootEventsController =
      StreamController<BootEvent>.broadcast();
  final StreamController<AutoRestartEvent> _autoRestartEventsController =
      StreamController<AutoRestartEvent>.broadcast();

  StreamSubscription<dynamic>? _eventsSubscription;
  bool _isInitialized = false;

  /// Initialize the boot service
  Future<void> initialize() async {
    if (_isInitialized) return;

    // Listen to native events
    _eventsSubscription = _eventsChannel.receiveBroadcastStream().listen(
      _handleNativeEvent,
      onError: (error) {
        log('BootService: Error receiving events: $error');
      },
    );

    _isInitialized = true;
  }

  /// Dispose of resources
  void dispose() {
    _eventsSubscription?.cancel();
    _bootEventsController.close();
    _autoRestartEventsController.close();
  }

  /// Handle events from native side
  void _handleNativeEvent(dynamic event) {
    if (event is! Map) return;

    final Map<String, dynamic> eventMap = Map<String, dynamic>.from(event);
    final String? action = eventMap['action'] as String?;

    switch (action) {
      case 'BOOT_COMPLETED':
        _bootEventsController.add(BootEvent(
          type: BootEventType.bootCompleted,
          timestamp: DateTime.fromMillisecondsSinceEpoch(
            eventMap['timestamp'] as int? ?? DateTime.now().millisecondsSinceEpoch,
          ),
          protectedModeRestored: eventMap['protected_mode_restored'] as bool? ?? false,
          isSafeMode: eventMap['safe_mode'] as bool? ?? false,
        ));
        break;

      case 'SAFE_MODE_DETECTED':
        _bootEventsController.add(BootEvent(
          type: BootEventType.safeModeDetected,
          timestamp: DateTime.fromMillisecondsSinceEpoch(
            eventMap['timestamp'] as int? ?? DateTime.now().millisecondsSinceEpoch,
          ),
          isSafeMode: true,
        ));
        break;

      case 'APP_RESTARTED_AFTER_FORCE_STOP':
        _autoRestartEventsController.add(AutoRestartEvent(
          type: AutoRestartEventType.forceStopDetected,
          timestamp: DateTime.fromMillisecondsSinceEpoch(
            eventMap['timestamp'] as int? ?? DateTime.now().millisecondsSinceEpoch,
          ),
          restartCount: eventMap['restart_count'] as int? ?? 0,
          triggerAlarm: eventMap['trigger_alarm'] as bool? ?? true,
        ));
        break;

      case 'FORCE_STOP_DETECTED':
        _autoRestartEventsController.add(AutoRestartEvent(
          type: AutoRestartEventType.forceStopDetected,
          timestamp: DateTime.fromMillisecondsSinceEpoch(
            eventMap['timestamp'] as int? ?? DateTime.now().millisecondsSinceEpoch,
          ),
          triggerAlarm: eventMap['trigger_alarm'] as bool? ?? true,
        ));
        break;

      case 'ACCESSIBILITY_SERVICE_STOPPED':
        _autoRestartEventsController.add(AutoRestartEvent(
          type: AutoRestartEventType.accessibilityServiceStopped,
          timestamp: DateTime.fromMillisecondsSinceEpoch(
            eventMap['timestamp'] as int? ?? DateTime.now().millisecondsSinceEpoch,
          ),
        ));
        break;

      case 'PROTECTION_SERVICE_STARTED':
        _autoRestartEventsController.add(AutoRestartEvent(
          type: AutoRestartEventType.serviceRestarted,
          timestamp: DateTime.now(),
        ));
        break;
    }
  }

  @override
  Future<bool> wasStartedAfterBoot() async {
    try {
      final result = await _channel.invokeMethod<bool>('wasStartedAfterBoot');
      return result ?? false;
    } on PlatformException catch (e) {
      log('BootService: Error checking boot start: ${e.message}');
      return false;
    }
  }

  @override
  Future<bool> shouldRestoreProtectedMode() async {
    try {
      final result = await _channel.invokeMethod<bool>('shouldRestoreProtectedMode');
      return result ?? false;
    } on PlatformException catch (e) {
      log('BootService: Error checking protected mode restoration: ${e.message}');
      return false;
    }
  }

  @override
  Future<void> restoreProtectedModeState() async {
    try {
      await _channel.invokeMethod<void>('restoreProtectedModeState');
    } on PlatformException catch (e) {
      log('BootService: Error restoring protected mode: ${e.message}');
    }
  }

  @override
  Future<bool> isInSafeMode() async {
    try {
      final result = await _channel.invokeMethod<bool>('isInSafeMode');
      return result ?? false;
    } on PlatformException catch (e) {
      log('BootService: Error checking safe mode: ${e.message}');
      return false;
    }
  }

  @override
  Future<void> handleSafeModeBoot() async {
    try {
      await _channel.invokeMethod<void>('handleSafeModeBoot');
    } on PlatformException catch (e) {
      log('BootService: Error handling safe mode boot: ${e.message}');
    }
  }

  @override
  Future<void> scheduleAutoRestartJob() async {
    try {
      await _channel.invokeMethod<void>('scheduleAutoRestartJob');
    } on PlatformException catch (e) {
      log('BootService: Error scheduling auto-restart job: ${e.message}');
    }
  }

  @override
  Future<void> cancelAutoRestartJob() async {
    try {
      await _channel.invokeMethod<void>('cancelAutoRestartJob');
    } on PlatformException catch (e) {
      log('BootService: Error cancelling auto-restart job: ${e.message}');
    }
  }

  @override
  Future<bool> isAutoRestartJobScheduled() async {
    try {
      final result = await _channel.invokeMethod<bool>('isAutoRestartJobScheduled');
      return result ?? false;
    } on PlatformException catch (e) {
      log('BootService: Error checking auto-restart job: ${e.message}');
      return false;
    }
  }

  @override
  Future<void> handleForceStopDetected() async {
    try {
      await _channel.invokeMethod<void>('handleForceStopDetected');
    } on PlatformException catch (e) {
      log('BootService: Error handling force-stop: ${e.message}');
    }
  }

  @override
  Future<DateTime?> getLastBootTime() async {
    try {
      final result = await _channel.invokeMethod<int>('getLastBootTime');
      if (result != null && result > 0) {
        return DateTime.fromMillisecondsSinceEpoch(result);
      }
      return null;
    } on PlatformException catch (e) {
      log('BootService: Error getting last boot time: ${e.message}');
      return null;
    }
  }

  @override
  Future<int> getBootCount() async {
    try {
      final result = await _channel.invokeMethod<int>('getBootCount');
      return result ?? 0;
    } on PlatformException catch (e) {
      log('BootService: Error getting boot count: ${e.message}');
      return 0;
    }
  }

  @override
  Future<int> getRestartCount() async {
    try {
      final result = await _channel.invokeMethod<int>('getRestartCount');
      return result ?? 0;
    } on PlatformException catch (e) {
      log('BootService: Error getting restart count: ${e.message}');
      return 0;
    }
  }

  @override
  Future<DateTime?> getLastRestartTime() async {
    try {
      final result = await _channel.invokeMethod<int>('getLastRestartTime');
      if (result != null && result > 0) {
        return DateTime.fromMillisecondsSinceEpoch(result);
      }
      return null;
    } on PlatformException catch (e) {
      log('BootService: Error getting last restart time: ${e.message}');
      return null;
    }
  }

  @override
  Future<void> startProtectionService() async {
    try {
      await _channel.invokeMethod<void>('startProtectionService');
    } on PlatformException catch (e) {
      log('BootService: Error starting protection service: ${e.message}');
    }
  }

  @override
  Future<void> stopProtectionService() async {
    try {
      await _channel.invokeMethod<void>('stopProtectionService');
    } on PlatformException catch (e) {
      log('BootService: Error stopping protection service: ${e.message}');
    }
  }

  @override
  Future<bool> isProtectionServiceRunning() async {
    try {
      final result = await _channel.invokeMethod<bool>('isProtectionServiceRunning');
      return result ?? false;
    } on PlatformException catch (e) {
      log('BootService: Error checking protection service: ${e.message}');
      return false;
    }
  }

  @override
  Stream<BootEvent> get bootEvents => _bootEventsController.stream;

  @override
  Stream<AutoRestartEvent> get autoRestartEvents => _autoRestartEventsController.stream;
}
