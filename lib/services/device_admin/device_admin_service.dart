import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'i_device_admin_service.dart';

/// Implementation of Device Admin Service using Flutter Method Channel
/// 
/// Provides device administration functionality including:
/// - Device locking (Requirement 8.1)
/// - Factory reset/wipe (Requirement 8.3)
/// - 30-second deactivation window management (Requirement 2.3)
/// - Device admin status checking
/// 
/// Requirements: 1.3, 2.1, 2.2, 2.3, 8.1, 8.3
class DeviceAdminService implements IDeviceAdminService {
  static const MethodChannel _channel = MethodChannel('com.example.find_phone/device_admin');
  static const EventChannel _eventChannel = EventChannel('com.example.find_phone/device_admin_events');

  static DeviceAdminService? _instance;
  
  StreamController<DeviceAdminEvent>? _eventController;
  StreamSubscription? _eventSubscription;

  DeviceAdminService._();

  /// Get singleton instance
  static DeviceAdminService get instance {
    _instance ??= DeviceAdminService._();
    return _instance!;
  }

  /// Initialize the service and start listening to events
  void initialize() {
    _eventController ??= StreamController<DeviceAdminEvent>.broadcast();
    _eventSubscription ??= _eventChannel
        .receiveBroadcastStream()
        .listen(_handleEvent, onError: _handleError);
  }

  /// Dispose the service
  void dispose() {
    _eventSubscription?.cancel();
    _eventSubscription = null;
    _eventController?.close();
    _eventController = null;
  }

  void _handleEvent(dynamic event) {
    if (event is Map) {
      final map = Map<String, dynamic>.from(event);
      final deviceAdminEvent = DeviceAdminEvent.fromMap(map);
      _eventController?.add(deviceAdminEvent);
    }
  }

  void _handleError(dynamic error) {
    debugPrint('DeviceAdminService event error: $error');
  }

  @override
  Stream<DeviceAdminEvent> get events {
    initialize();
    return _eventController!.stream;
  }

  @override
  Future<bool> isAdminActive() async {
    try {
      final result = await _channel.invokeMethod<bool>('isAdminActive');
      return result ?? false;
    } on PlatformException catch (e) {
      debugPrint('Error checking admin status: ${e.message}');
      return false;
    }
  }

  @override
  Future<bool> requestAdminActivation() async {
    try {
      final result = await _channel.invokeMethod<bool>('requestAdminActivation');
      return result ?? false;
    } on PlatformException catch (e) {
      debugPrint('Error requesting admin activation: ${e.message}');
      return false;
    }
  }

  @override
  Future<bool> lockDevice() async {
    try {
      final result = await _channel.invokeMethod<bool>('lockDevice');
      return result ?? false;
    } on PlatformException catch (e) {
      debugPrint('Error locking device: ${e.message}');
      return false;
    }
  }

  @override
  Future<bool> lockDeviceWithMessage(String message) async {
    try {
      final result = await _channel.invokeMethod<bool>(
        'lockDeviceWithMessage',
        {'message': message},
      );
      return result ?? false;
    } on PlatformException catch (e) {
      debugPrint('Error locking device with message: ${e.message}');
      return false;
    }
  }


  @override
  Future<bool> wipeDevice({String reason = 'Remote wipe command'}) async {
    try {
      final result = await _channel.invokeMethod<bool>(
        'wipeDevice',
        {'reason': reason},
      );
      return result ?? false;
    } on PlatformException catch (e) {
      debugPrint('Error wiping device: ${e.message}');
      return false;
    }
  }

  @override
  Future<bool> setPasswordQuality(int quality) async {
    try {
      final result = await _channel.invokeMethod<bool>(
        'setPasswordQuality',
        {'quality': quality},
      );
      return result ?? false;
    } on PlatformException catch (e) {
      debugPrint('Error setting password quality: ${e.message}');
      return false;
    }
  }

  @override
  Future<bool> setMinimumPasswordLength(int length) async {
    try {
      final result = await _channel.invokeMethod<bool>(
        'setMinimumPasswordLength',
        {'length': length},
      );
      return result ?? false;
    } on PlatformException catch (e) {
      debugPrint('Error setting minimum password length: ${e.message}');
      return false;
    }
  }

  @override
  Future<bool> setCameraDisabled(bool disable) async {
    try {
      final result = await _channel.invokeMethod<bool>(
        'setCameraDisabled',
        {'disable': disable},
      );
      return result ?? false;
    } on PlatformException catch (e) {
      debugPrint('Error setting camera state: ${e.message}');
      return false;
    }
  }

  @override
  Future<int> getFailedPasswordAttempts() async {
    try {
      final result = await _channel.invokeMethod<int>('getFailedPasswordAttempts');
      return result ?? 0;
    } on PlatformException catch (e) {
      debugPrint('Error getting failed password attempts: ${e.message}');
      return 0;
    }
  }

  @override
  Future<bool> setMaximumFailedPasswordsForWipe(int maxAttempts) async {
    try {
      final result = await _channel.invokeMethod<bool>(
        'setMaximumFailedPasswordsForWipe',
        {'maxAttempts': maxAttempts},
      );
      return result ?? false;
    } on PlatformException catch (e) {
      debugPrint('Error setting max failed passwords: ${e.message}');
      return false;
    }
  }

  @override
  Future<bool> setMaximumTimeToLock(int timeMs) async {
    try {
      final result = await _channel.invokeMethod<bool>(
        'setMaximumTimeToLock',
        {'timeMs': timeMs},
      );
      return result ?? false;
    } on PlatformException catch (e) {
      debugPrint('Error setting max time to lock: ${e.message}');
      return false;
    }
  }

  @override
  Future<bool> allowDeactivation() async {
    try {
      final result = await _channel.invokeMethod<bool>('allowDeactivation');
      return result ?? false;
    } on PlatformException catch (e) {
      debugPrint('Error allowing deactivation: ${e.message}');
      return false;
    }
  }

  @override
  Future<bool> revokeDeactivation() async {
    try {
      final result = await _channel.invokeMethod<bool>('revokeDeactivation');
      return result ?? false;
    } on PlatformException catch (e) {
      debugPrint('Error revoking deactivation: ${e.message}');
      return false;
    }
  }

  @override
  Future<bool> isDeactivationAllowed() async {
    try {
      final result = await _channel.invokeMethod<bool>('isDeactivationAllowed');
      return result ?? false;
    } on PlatformException catch (e) {
      debugPrint('Error checking deactivation status: ${e.message}');
      return false;
    }
  }

  @override
  Future<int> getDeactivationWindowRemaining() async {
    try {
      final result = await _channel.invokeMethod<int>('getDeactivationWindowRemaining');
      return result ?? 0;
    } on PlatformException catch (e) {
      debugPrint('Error getting deactivation window remaining: ${e.message}');
      return 0;
    }
  }

  @override
  Future<bool> setProtectedModeActive(bool active) async {
    try {
      final result = await _channel.invokeMethod<bool>(
        'setProtectedModeActive',
        {'active': active},
      );
      return result ?? false;
    } on PlatformException catch (e) {
      debugPrint('Error setting protected mode: ${e.message}');
      return false;
    }
  }

  @override
  Future<bool> isProtectedModeActive() async {
    try {
      final result = await _channel.invokeMethod<bool>('isProtectedModeActive');
      return result ?? false;
    } on PlatformException catch (e) {
      debugPrint('Error checking protected mode: ${e.message}');
      return false;
    }
  }

  @override
  Future<Map<String, dynamic>> getAdminStatus() async {
    try {
      final result = await _channel.invokeMethod<Map>('getAdminStatus');
      if (result != null) {
        return Map<String, dynamic>.from(result);
      }
      return {
        'isAdminActive': false,
        'isProtectedModeActive': false,
        'isDeactivationAllowed': false,
        'deactivationWindowRemaining': 0,
        'failedPasswordAttempts': 0,
      };
    } on PlatformException catch (e) {
      debugPrint('Error getting admin status: ${e.message}');
      return {
        'isAdminActive': false,
        'isProtectedModeActive': false,
        'isDeactivationAllowed': false,
        'deactivationWindowRemaining': 0,
        'failedPasswordAttempts': 0,
      };
    }
  }

  @override
  Future<bool> openDeviceAdminSettings() async {
    try {
      final result = await _channel.invokeMethod<bool>('openDeviceAdminSettings');
      return result ?? false;
    } on PlatformException catch (e) {
      debugPrint('Error opening device admin settings: ${e.message}');
      return false;
    }
  }
}
