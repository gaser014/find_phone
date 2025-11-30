import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Service for managing Kiosk Mode on screen lock.
///
/// This service provides:
/// - Enable/disable Kiosk Mode when screen locks
/// - Auto-enable mobile data when Kiosk activates
/// - Block USB connections in Kiosk Mode
/// - Password-only unlock mechanism
class KioskOnLockService {
  static const MethodChannel _channel =
      MethodChannel('com.example.find_phone/kiosk_on_lock');
  static const EventChannel _eventChannel =
      EventChannel('com.example.find_phone/kiosk_on_lock_events');

  static KioskOnLockService? _instance;
  StreamController<KioskOnLockEvent>? _eventController;
  StreamSubscription? _eventSubscription;

  KioskOnLockService._();

  /// Get singleton instance
  static KioskOnLockService get instance {
    _instance ??= KioskOnLockService._();
    return _instance!;
  }

  /// Initialize the service
  Future<void> initialize() async {
    _eventController ??= StreamController<KioskOnLockEvent>.broadcast();
    _eventSubscription ??= _eventChannel
        .receiveBroadcastStream()
        .listen(_handleEvent, onError: _handleError);
  }

  /// Dispose the service
  Future<void> dispose() async {
    await _eventSubscription?.cancel();
    _eventSubscription = null;
    await _eventController?.close();
    _eventController = null;
  }

  void _handleEvent(dynamic event) {
    if (event is Map) {
      final map = Map<String, dynamic>.from(event);
      final kioskEvent = KioskOnLockEvent.fromMap(map);
      _eventController?.add(kioskEvent);
    }
  }

  void _handleError(dynamic error) {
    // Error handling for kiosk events
    debugPrint('KioskOnLockService event error: $error');
  }

  /// Stream of Kiosk on Lock events
  Stream<KioskOnLockEvent> get events {
    initialize();
    return _eventController!.stream;
  }

  /// Enable Kiosk Mode on screen lock
  Future<bool> enableKioskOnLock() async {
    try {
      final result = await _channel.invokeMethod<bool>('enableKioskOnLock');
      return result ?? false;
    } on PlatformException catch (e) {
      debugPrint('Error enabling Kiosk on Lock: ${e.message}');
      return false;
    }
  }

  /// Disable Kiosk Mode on screen lock
  Future<bool> disableKioskOnLock() async {
    try {
      final result = await _channel.invokeMethod<bool>('disableKioskOnLock');
      return result ?? false;
    } on PlatformException catch (e) {
      debugPrint('Error disabling Kiosk on Lock: ${e.message}');
      return false;
    }
  }

  /// Check if Kiosk on Lock is enabled
  Future<bool> isKioskOnLockEnabled() async {
    try {
      final result = await _channel.invokeMethod<bool>('isKioskOnLockEnabled');
      return result ?? false;
    } on PlatformException catch (e) {
      debugPrint('Error checking Kiosk on Lock status: ${e.message}');
      return false;
    }
  }

  /// Enable auto mobile data when Kiosk activates
  Future<bool> setAutoEnableMobileData(bool enable) async {
    try {
      final result = await _channel.invokeMethod<bool>(
        'setAutoEnableMobileData',
        {'enable': enable},
      );
      return result ?? false;
    } on PlatformException catch (e) {
      debugPrint('Error setting auto mobile data: ${e.message}');
      return false;
    }
  }

  /// Check if auto mobile data is enabled
  Future<bool> isAutoMobileDataEnabled() async {
    try {
      final result = await _channel.invokeMethod<bool>('isAutoMobileDataEnabled');
      return result ?? false;
    } on PlatformException catch (e) {
      debugPrint('Error checking auto mobile data: ${e.message}');
      return false;
    }
  }

  /// Manually trigger Kiosk Lock Screen
  Future<bool> showKioskLockScreen() async {
    try {
      final result = await _channel.invokeMethod<bool>('showKioskLockScreen');
      return result ?? false;
    } on PlatformException catch (e) {
      debugPrint('Error showing Kiosk Lock Screen: ${e.message}');
      return false;
    }
  }

  /// Unlock Kiosk Mode with password
  Future<bool> unlockKiosk(String password) async {
    try {
      final result = await _channel.invokeMethod<bool>(
        'unlockKiosk',
        {'password': password},
      );
      return result ?? false;
    } on PlatformException catch (e) {
      debugPrint('Error unlocking Kiosk: ${e.message}');
      return false;
    }
  }

  /// Get Kiosk on Lock configuration
  Future<KioskOnLockConfig> getConfiguration() async {
    try {
      final result = await _channel.invokeMethod<Map>('getConfiguration');
      if (result != null) {
        return KioskOnLockConfig.fromMap(Map<String, dynamic>.from(result));
      }
      return KioskOnLockConfig();
    } on PlatformException catch (e) {
      debugPrint('Error getting configuration: ${e.message}');
      return KioskOnLockConfig();
    }
  }

  /// Update Kiosk on Lock configuration
  Future<bool> updateConfiguration(KioskOnLockConfig config) async {
    try {
      final result = await _channel.invokeMethod<bool>(
        'updateConfiguration',
        config.toMap(),
      );
      return result ?? false;
    } on PlatformException catch (e) {
      debugPrint('Error updating configuration: ${e.message}');
      return false;
    }
  }
  
  /// Test Telegram connection
  Future<bool> testTelegramConnection(String botToken, String chatId) async {
    try {
      final result = await _channel.invokeMethod<bool>(
        'testTelegramConnection',
        {
          'botToken': botToken,
          'chatId': chatId,
        },
      );
      return result ?? false;
    } on PlatformException catch (e) {
      debugPrint('Error testing Telegram connection: ${e.message}');
      return false;
    }
  }

  /// Uninstall the app
  Future<bool> uninstallApp() async {
    try {
      final result = await _channel.invokeMethod<bool>('uninstallApp');
      return result ?? false;
    } on PlatformException catch (e) {
      debugPrint('Error uninstalling app: ${e.message}');
      return false;
    }
  }
}

/// Kiosk on Lock event types
enum KioskOnLockEventType {
  kioskActivated,
  kioskDeactivated,
  passwordFailed,
  passwordSucceeded,
  mobileDataEnabled,
  mobileDataFailed,
  usbBlocked,
  screenLocked,
  screenUnlocked,
  unknown,
}

/// Kiosk on Lock event
class KioskOnLockEvent {
  final KioskOnLockEventType type;
  final DateTime timestamp;
  final Map<String, dynamic>? metadata;

  KioskOnLockEvent({
    required this.type,
    required this.timestamp,
    this.metadata,
  });

  factory KioskOnLockEvent.fromMap(Map<String, dynamic> map) {
    final action = map['action'] as String?;
    final timestamp = map['timestamp'] as int? ?? DateTime.now().millisecondsSinceEpoch;

    KioskOnLockEventType type;
    switch (action) {
      case 'KIOSK_LOCK_SCREEN_SHOWN':
      case 'KIOSK_ACTIVATED':
        type = KioskOnLockEventType.kioskActivated;
        break;
      case 'KIOSK_UNLOCKED':
      case 'KIOSK_DEACTIVATED':
        type = KioskOnLockEventType.kioskDeactivated;
        break;
      case 'PASSWORD_FAILED':
        type = KioskOnLockEventType.passwordFailed;
        break;
      case 'PASSWORD_SUCCEEDED':
        type = KioskOnLockEventType.passwordSucceeded;
        break;
      case 'DATA_STATE_CHANGED':
        type = map['enabled'] == true
            ? KioskOnLockEventType.mobileDataEnabled
            : KioskOnLockEventType.unknown;
        break;
      case 'DATA_ENABLE_FAILED':
        type = KioskOnLockEventType.mobileDataFailed;
        break;
      case 'USB_BLOCKED':
        type = KioskOnLockEventType.usbBlocked;
        break;
      case 'SCREEN_LOCKED':
        type = KioskOnLockEventType.screenLocked;
        break;
      case 'SCREEN_UNLOCKED':
        type = KioskOnLockEventType.screenUnlocked;
        break;
      default:
        type = KioskOnLockEventType.unknown;
    }

    final metadata = Map<String, dynamic>.from(map);
    metadata.remove('action');
    metadata.remove('timestamp');

    return KioskOnLockEvent(
      type: type,
      timestamp: DateTime.fromMillisecondsSinceEpoch(timestamp),
      metadata: metadata.isNotEmpty ? metadata : null,
    );
  }
}

/// Kiosk on Lock configuration
class KioskOnLockConfig {
  final bool kioskOnLockEnabled;
  final bool autoEnableMobileData;
  final bool blockUsbOnKiosk;
  final bool capturePhotoOnFailedAttempt;
  final bool triggerAlarmOnMultipleFailures;
  final int alarmTriggerThreshold;
  final String emergencyNumber1; // Emergency phone number
  final String telegramBotToken; // Telegram Bot Token
  final String telegramChatId; // Telegram Chat ID
  final String kioskPassword; // Dynamic kiosk password

  KioskOnLockConfig({
    this.kioskOnLockEnabled = false,
    this.autoEnableMobileData = true,
    this.blockUsbOnKiosk = true,
    this.capturePhotoOnFailedAttempt = true,
    this.triggerAlarmOnMultipleFailures = true,
    this.alarmTriggerThreshold = 3,
    this.emergencyNumber1 = '',
    this.telegramBotToken = '',
    this.telegramChatId = '',
    this.kioskPassword = '123456',
  });

  factory KioskOnLockConfig.fromMap(Map<String, dynamic> map) {
    return KioskOnLockConfig(
      kioskOnLockEnabled: map['kioskOnLockEnabled'] as bool? ?? false,
      autoEnableMobileData: map['autoEnableMobileData'] as bool? ?? true,
      blockUsbOnKiosk: map['blockUsbOnKiosk'] as bool? ?? true,
      capturePhotoOnFailedAttempt: map['capturePhotoOnFailedAttempt'] as bool? ?? true,
      triggerAlarmOnMultipleFailures: map['triggerAlarmOnMultipleFailures'] as bool? ?? true,
      alarmTriggerThreshold: map['alarmTriggerThreshold'] as int? ?? 3,
      emergencyNumber1: map['emergencyNumber1'] as String? ?? '',
      telegramBotToken: map['telegramBotToken'] as String? ?? '',
      telegramChatId: map['telegramChatId'] as String? ?? '',
      kioskPassword: map['kioskPassword'] as String? ?? '123456',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'kioskOnLockEnabled': kioskOnLockEnabled,
      'autoEnableMobileData': autoEnableMobileData,
      'blockUsbOnKiosk': blockUsbOnKiosk,
      'capturePhotoOnFailedAttempt': capturePhotoOnFailedAttempt,
      'triggerAlarmOnMultipleFailures': triggerAlarmOnMultipleFailures,
      'alarmTriggerThreshold': alarmTriggerThreshold,
      'emergencyNumber1': emergencyNumber1,
      'telegramBotToken': telegramBotToken,
      'telegramChatId': telegramChatId,
      'kioskPassword': kioskPassword,
    };
  }

  KioskOnLockConfig copyWith({
    bool? kioskOnLockEnabled,
    bool? autoEnableMobileData,
    bool? blockUsbOnKiosk,
    bool? capturePhotoOnFailedAttempt,
    bool? triggerAlarmOnMultipleFailures,
    int? alarmTriggerThreshold,
    String? emergencyNumber1,
    String? telegramBotToken,
    String? telegramChatId,
    String? kioskPassword,
  }) {
    return KioskOnLockConfig(
      kioskOnLockEnabled: kioskOnLockEnabled ?? this.kioskOnLockEnabled,
      autoEnableMobileData: autoEnableMobileData ?? this.autoEnableMobileData,
      blockUsbOnKiosk: blockUsbOnKiosk ?? this.blockUsbOnKiosk,
      capturePhotoOnFailedAttempt: capturePhotoOnFailedAttempt ?? this.capturePhotoOnFailedAttempt,
      triggerAlarmOnMultipleFailures: triggerAlarmOnMultipleFailures ?? this.triggerAlarmOnMultipleFailures,
      alarmTriggerThreshold: alarmTriggerThreshold ?? this.alarmTriggerThreshold,
      emergencyNumber1: emergencyNumber1 ?? this.emergencyNumber1,
      telegramBotToken: telegramBotToken ?? this.telegramBotToken,
      telegramChatId: telegramChatId ?? this.telegramChatId,
      kioskPassword: kioskPassword ?? this.kioskPassword,
    );
  }
}
