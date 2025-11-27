import 'dart:async';

import 'package:flutter/services.dart';

import 'i_battery_service.dart';

/// Implementation of IBatteryService.
///
/// Communicates with native Android to manage battery optimization
/// and monitor battery status.
///
/// Requirements:
/// - 10.1: Use battery-efficient location tracking methods
/// - 10.3: Reduce tracking frequency to conserve power when battery is low
class BatteryService implements IBatteryService {
  static const String _channelName = 'com.example.find_phone/battery';
  static const String _eventChannelName = 'com.example.find_phone/battery_events';

  final MethodChannel _methodChannel = const MethodChannel(_channelName);
  final EventChannel _eventChannel = const EventChannel(_eventChannelName);

  StreamController<int>? _batteryLevelController;
  StreamController<bool>? _chargingStateController;
  StreamSubscription? _eventSubscription;

  bool _isInitialized = false;

  /// Singleton instance
  static BatteryService? _instance;

  /// Get singleton instance
  static BatteryService get instance {
    _instance ??= BatteryService._();
    return _instance!;
  }

  BatteryService._();

  @override
  Future<void> initialize() async {
    if (_isInitialized) return;

    _batteryLevelController = StreamController<int>.broadcast();
    _chargingStateController = StreamController<bool>.broadcast();

    _eventSubscription = _eventChannel.receiveBroadcastStream().listen(
      (dynamic event) {
        if (event is Map) {
          final map = Map<String, dynamic>.from(event);
          final type = map['type'] as String?;

          if (type == 'battery_level') {
            final level = map['level'] as int?;
            if (level != null) {
              _batteryLevelController?.add(level);
            }
          } else if (type == 'charging_state') {
            final isCharging = map['isCharging'] as bool?;
            if (isCharging != null) {
              _chargingStateController?.add(isCharging);
            }
          }
        }
      },
      onError: (error) {
        _batteryLevelController?.addError(error);
        _chargingStateController?.addError(error);
      },
    );

    _isInitialized = true;
  }

  @override
  Future<void> dispose() async {
    await _eventSubscription?.cancel();
    await _batteryLevelController?.close();
    await _chargingStateController?.close();
    _batteryLevelController = null;
    _chargingStateController = null;
    _isInitialized = false;
  }

  @override
  Future<bool> isIgnoringBatteryOptimizations() async {
    try {
      final result = await _methodChannel.invokeMethod<bool>(
        'isIgnoringBatteryOptimizations',
      );
      return result ?? false;
    } on PlatformException catch (e) {
      print('Error checking battery optimization status: ${e.message}');
      return false;
    }
  }

  @override
  Future<bool> requestBatteryOptimizationExemption() async {
    try {
      final result = await _methodChannel.invokeMethod<bool>(
        'requestBatteryOptimizationExemption',
      );
      return result ?? false;
    } on PlatformException catch (e) {
      print('Error requesting battery optimization exemption: ${e.message}');
      return false;
    }
  }

  @override
  Future<int> getBatteryLevel() async {
    try {
      final result = await _methodChannel.invokeMethod<int>('getBatteryLevel');
      return result ?? 100;
    } on PlatformException catch (e) {
      print('Error getting battery level: ${e.message}');
      return 100;
    }
  }

  @override
  Future<bool> isCharging() async {
    try {
      final result = await _methodChannel.invokeMethod<bool>('isCharging');
      return result ?? false;
    } on PlatformException catch (e) {
      print('Error checking charging status: ${e.message}');
      return false;
    }
  }

  @override
  Future<bool> isBatterySaverEnabled() async {
    try {
      final result = await _methodChannel.invokeMethod<bool>(
        'isBatterySaverEnabled',
      );
      return result ?? false;
    } on PlatformException catch (e) {
      print('Error checking battery saver status: ${e.message}');
      return false;
    }
  }

  @override
  Stream<int> get batteryLevelChanges {
    if (!_isInitialized) {
      initialize();
    }
    return _batteryLevelController!.stream;
  }

  @override
  Stream<bool> get chargingStateChanges {
    if (!_isInitialized) {
      initialize();
    }
    return _chargingStateController!.stream;
  }
}
