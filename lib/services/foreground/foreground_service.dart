import 'dart:async';

import 'package:flutter/services.dart';

import 'i_foreground_service.dart';

/// Implementation of IForegroundService.
///
/// Communicates with the native Android ProtectionForegroundService
/// to provide persistent background monitoring.
///
/// Requirements:
/// - 2.4: Auto-restart using JobScheduler within 3 seconds
/// - 5.5: Continue tracking even when app is in background
class ForegroundService implements IForegroundService {
  static const String _channelName = 'com.example.find_phone/foreground_service';
  static const String _eventChannelName = 'com.example.find_phone/foreground_service_events';

  final MethodChannel _methodChannel = const MethodChannel(_channelName);
  final EventChannel _eventChannel = const EventChannel(_eventChannelName);

  StreamController<ForegroundServiceEvent>? _eventController;
  StreamSubscription? _eventSubscription;

  bool _isInitialized = false;

  /// Singleton instance
  static ForegroundService? _instance;

  /// Get singleton instance
  static ForegroundService get instance {
    _instance ??= ForegroundService._();
    return _instance!;
  }

  ForegroundService._();

  /// Initialize the service
  Future<void> initialize() async {
    if (_isInitialized) return;

    _eventController = StreamController<ForegroundServiceEvent>.broadcast();

    _eventSubscription = _eventChannel.receiveBroadcastStream().listen(
      (dynamic event) {
        if (event is Map) {
          final serviceEvent = _parseEvent(Map<String, dynamic>.from(event));
          _eventController?.add(serviceEvent);
        }
      },
      onError: (error) {
        _eventController?.addError(error);
      },
    );

    _isInitialized = true;
  }

  /// Dispose resources
  Future<void> dispose() async {
    await _eventSubscription?.cancel();
    await _eventController?.close();
    _eventController = null;
    _isInitialized = false;
  }

  ForegroundServiceEvent _parseEvent(Map<String, dynamic> map) {
    final action = map['action'] as String?;
    ForegroundServiceEventType type;

    switch (action) {
      case 'PROTECTION_SERVICE_STARTED':
        type = ForegroundServiceEventType.started;
        break;
      case 'PROTECTION_SERVICE_STOPPED':
        type = ForegroundServiceEventType.stopped;
        break;
      case 'FORCE_STOP_DETECTED':
        type = ForegroundServiceEventType.forceStopDetected;
        break;
      case 'SERVICE_RESTARTED':
        type = ForegroundServiceEventType.restarted;
        break;
      case 'HEARTBEAT':
        type = ForegroundServiceEventType.heartbeat;
        break;
      default:
        type = ForegroundServiceEventType.started;
    }

    return ForegroundServiceEvent(
      type: type,
      timestamp: DateTime.fromMillisecondsSinceEpoch(
        map['timestamp'] as int? ?? DateTime.now().millisecondsSinceEpoch,
      ),
      metadata: map,
    );
  }

  @override
  Future<bool> startService() async {
    try {
      final result = await _methodChannel.invokeMethod<bool>('startService');
      return result ?? false;
    } on PlatformException catch (e) {
      print('Error starting foreground service: ${e.message}');
      return false;
    }
  }

  @override
  Future<bool> stopService() async {
    try {
      final result = await _methodChannel.invokeMethod<bool>('stopService');
      return result ?? false;
    } on PlatformException catch (e) {
      print('Error stopping foreground service: ${e.message}');
      return false;
    }
  }

  @override
  Future<bool> isServiceRunning() async {
    try {
      final result = await _methodChannel.invokeMethod<bool>('isServiceRunning');
      return result ?? false;
    } on PlatformException catch (e) {
      print('Error checking service status: ${e.message}');
      return false;
    }
  }

  @override
  Future<void> updateNotification({String? title, String? message}) async {
    try {
      await _methodChannel.invokeMethod('updateNotification', {
        'title': title,
        'message': message,
      });
    } on PlatformException catch (e) {
      print('Error updating notification: ${e.message}');
    }
  }

  @override
  Future<DateTime?> getLastHeartbeat() async {
    try {
      final result = await _methodChannel.invokeMethod<int>('getLastHeartbeat');
      if (result != null && result > 0) {
        return DateTime.fromMillisecondsSinceEpoch(result);
      }
      return null;
    } on PlatformException catch (e) {
      print('Error getting last heartbeat: ${e.message}');
      return null;
    }
  }

  @override
  Future<int> getStartCount() async {
    try {
      final result = await _methodChannel.invokeMethod<int>('getStartCount');
      return result ?? 0;
    } on PlatformException catch (e) {
      print('Error getting start count: ${e.message}');
      return 0;
    }
  }

  @override
  Stream<ForegroundServiceEvent> get events {
    if (!_isInitialized) {
      initialize();
    }
    return _eventController!.stream;
  }
}
