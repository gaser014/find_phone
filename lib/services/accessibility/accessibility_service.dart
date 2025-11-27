import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'i_accessibility_service.dart';

/// Implementation of Accessibility Service using Flutter Method Channel
///
/// Communicates with the native Android AntiTheftAccessibilityService
/// to provide app blocking, power menu blocking, and password overlay features.
///
/// Requirements: 1.3, 2.2, 3.1, 11.2, 12.2, 12.3, 23.2, 27.3
class AccessibilityService implements IAccessibilityService {
  static const _methodChannel = MethodChannel(
    'com.example.find_phone/accessibility',
  );
  static const _eventChannel = EventChannel(
    'com.example.find_phone/accessibility_events',
  );

  StreamController<AccessibilityEvent>? _eventController;
  StreamSubscription? _eventSubscription;

  /// Singleton instance
  static AccessibilityService? _instance;

  /// Get singleton instance
  static AccessibilityService get instance {
    _instance ??= AccessibilityService._();
    return _instance!;
  }

  AccessibilityService._() {
    _initEventStream();
  }

  /// Initialize the event stream from native side
  void _initEventStream() {
    _eventController = StreamController<AccessibilityEvent>.broadcast();

    _eventSubscription = _eventChannel.receiveBroadcastStream().listen(
      (dynamic event) {
        if (event is Map) {
          final accessibilityEvent = AccessibilityEvent.fromMap(event);
          _eventController?.add(accessibilityEvent);
        }
      },
      onError: (error) {
        _eventController?.addError(error);
      },
    );
  }

  @override
  Future<bool> isServiceEnabled() async {
    try {
      final result = await _methodChannel.invokeMethod<bool>(
        'isAccessibilityServiceEnabled',
      );
      return result ?? false;
    } on PlatformException catch (e) {
      debugPrint('Error checking accessibility service: ${e.message}');
      return false;
    }
  }

  @override
  Future<void> openAccessibilitySettings() async {
    try {
      await _methodChannel.invokeMethod('openAccessibilitySettings');
    } on PlatformException catch (e) {
      debugPrint('Error opening accessibility settings: ${e.message}');
    }
  }

  @override
  Future<bool> isProtectedModeActive() async {
    try {
      final result = await _methodChannel.invokeMethod<bool>(
        'isProtectedModeActive',
      );
      return result ?? false;
    } on PlatformException catch (e) {
      debugPrint('Error checking protected mode: ${e.message}');
      return false;
    }
  }

  @override
  Future<void> enableProtectedMode() async {
    try {
      await _methodChannel.invokeMethod('enableProtectedMode');
    } on PlatformException catch (e) {
      debugPrint('Error enabling protected mode: ${e.message}');
    }
  }

  @override
  Future<void> disableProtectedMode() async {
    try {
      await _methodChannel.invokeMethod('disableProtectedMode');
    } on PlatformException catch (e) {
      debugPrint('Error disabling protected mode: ${e.message}');
    }
  }

  @override
  Future<void> setBlockingOptions({
    bool blockSettings = true,
    bool blockFileManagers = true,
    bool blockPowerMenu = true,
    bool blockQuickSettings = true,
  }) async {
    try {
      await _methodChannel.invokeMethod('setBlockingOptions', {
        'blockSettings': blockSettings,
        'blockFileManagers': blockFileManagers,
        'blockPowerMenu': blockPowerMenu,
        'blockQuickSettings': blockQuickSettings,
      });
    } on PlatformException catch (e) {
      debugPrint('Error setting blocking options: ${e.message}');
    }
  }

  @override
  Future<Map<String, bool>> getBlockingStatus() async {
    try {
      final result = await _methodChannel.invokeMethod<Map<dynamic, dynamic>>(
        'getBlockingStatus',
      );
      if (result != null) {
        return result.map(
          (key, value) => MapEntry(key.toString(), value as bool),
        );
      }
      return _defaultBlockingStatus;
    } on PlatformException catch (e) {
      debugPrint('Error getting blocking status: ${e.message}');
      return _defaultBlockingStatus;
    }
  }

  Map<String, bool> get _defaultBlockingStatus => {
    'protected_mode': false,
    'block_settings': true,
    'block_file_managers': true,
    'block_power_menu': true,
    'block_quick_settings': true,
  };

  @override
  Future<void> showPasswordOverlay(PendingAction action) async {
    try {
      await _methodChannel.invokeMethod('showPasswordOverlay', {
        'action': action.toNativeString(),
      });
    } on PlatformException catch (e) {
      debugPrint('Error showing password overlay: ${e.message}');
    }
  }

  @override
  Future<void> hidePasswordOverlay() async {
    try {
      await _methodChannel.invokeMethod('hidePasswordOverlay');
    } on PlatformException catch (e) {
      debugPrint('Error hiding password overlay: ${e.message}');
    }
  }

  @override
  Future<void> updatePassword(String hash, String salt) async {
    try {
      await _methodChannel.invokeMethod('updatePassword', {
        'hash': hash,
        'salt': salt,
      });
    } on PlatformException catch (e) {
      debugPrint('Error updating password: ${e.message}');
    }
  }

  @override
  Future<bool> isPackageBlocked(String packageName) async {
    try {
      final result = await _methodChannel.invokeMethod<bool>(
        'isPackageBlocked',
        {'packageName': packageName},
      );
      return result ?? false;
    } on PlatformException catch (e) {
      debugPrint('Error checking if package is blocked: ${e.message}');
      return false;
    }
  }

  @override
  Future<void> showLockScreenMessage({
    String? message,
    String? ownerContact,
    String? instructions,
  }) async {
    try {
      await _methodChannel.invokeMethod('showLockScreenMessage', {
        'message': message,
        'ownerContact': ownerContact,
        'instructions': instructions,
      });
    } on PlatformException catch (e) {
      debugPrint('Error showing lock screen message: ${e.message}');
    }
  }

  @override
  Future<void> hideLockScreenMessage() async {
    try {
      await _methodChannel.invokeMethod('hideLockScreenMessage');
    } on PlatformException catch (e) {
      debugPrint('Error hiding lock screen message: ${e.message}');
    }
  }

  @override
  Future<bool> isLockScreenMessageShowing() async {
    try {
      final result = await _methodChannel.invokeMethod<bool>(
        'isLockScreenMessageShowing',
      );
      return result ?? false;
    } on PlatformException catch (e) {
      debugPrint('Error checking lock screen message status: ${e.message}');
      return false;
    }
  }

  @override
  Stream<AccessibilityEvent> get events {
    return _eventController?.stream ?? const Stream.empty();
  }

  @override
  void dispose() {
    _eventSubscription?.cancel();
    _eventController?.close();
    _instance = null;
  }
}
