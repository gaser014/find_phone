import 'dart:async';
import 'dart:convert';

import 'package:flutter/services.dart';

import '../../domain/entities/protection_config.dart';
import '../authentication/i_authentication_service.dart';
import '../storage/i_storage_service.dart';
import '../accessibility/i_accessibility_service.dart';
import '../device_admin/i_device_admin_service.dart';
import '../boot/i_boot_service.dart';
import 'i_protection_service.dart';

/// Storage keys for protection configuration.
class ProtectionStorageKeys {
  static const String config = 'protection_config';
  static const String protectedModeActive = 'protected_mode_active';
  static const String kioskModeActive = 'kiosk_mode_active';
  static const String panicModeActive = 'panic_mode_active';
  static const String stealthModeActive = 'stealth_mode_active';
  static const String appIconHidden = 'app_icon_hidden';
  static const String dialerCode = 'dialer_code';
  static const String panicPasswordConfirmation = 'panic_password_confirmation';
}

/// Implementation of IProtectionService.
///
/// Provides comprehensive protection functionality including Protected Mode,
/// Kiosk Mode, Panic Mode, Stealth Mode, and dialer code access.
///
/// Requirements: 1.3, 1.4, 3.1, 3.2, 9.3, 18.1, 18.3, 18.4, 18.5, 21.1, 21.2
class ProtectionService implements IProtectionService {
  final IStorageService _storageService;
  final IAuthenticationService _authService;
  final IAccessibilityService? _accessibilityService;
  final IDeviceAdminService? _deviceAdminService;
  final IBootService? _bootService;
  final bool _skipNativeSetup;

  /// Default dialer code for accessing the app in stealth mode.
  static const String defaultDialerCode = '*#123456#';

  /// Method channel for native protection features.
  static const MethodChannel _channel =
      MethodChannel('com.example.find_phone/protection');

  /// Event channel for protection events.
  static const EventChannel _eventChannel =
      EventChannel('com.example.find_phone/protection_events');

  /// Stream controller for protection events.
  final StreamController<ProtectionEvent> _eventController =
      StreamController<ProtectionEvent>.broadcast();

  /// Current protection configuration.
  ProtectionConfig _config = ProtectionConfig();

  /// Whether the service is initialized.
  bool _isInitialized = false;

  /// Volume button press tracking for panic mode.
  final List<DateTime> _volumeButtonPresses = [];
  static const int _panicVolumeButtonCount = 5;
  static const Duration _panicVolumeButtonWindow = Duration(seconds: 3);

  /// Panic mode password confirmation tracking.
  bool _panicPasswordFirstConfirmed = false;
  DateTime? _panicPasswordFirstConfirmTime;
  static const Duration _panicPasswordConfirmWindow = Duration(seconds: 30);

  ProtectionService({
    required IStorageService storageService,
    required IAuthenticationService authService,
    IAccessibilityService? accessibilityService,
    IDeviceAdminService? deviceAdminService,
    IBootService? bootService,
    bool skipNativeSetup = false,
  })  : _storageService = storageService,
        _authService = authService,
        _accessibilityService = accessibilityService,
        _deviceAdminService = deviceAdminService,
        _bootService = bootService,
        _skipNativeSetup = skipNativeSetup;

  @override
  Future<void> initialize() async {
    if (_isInitialized) return;

    // Load configuration from storage
    _config = await loadConfiguration();

    // Setup native event listener (skip in tests)
    if (!_skipNativeSetup) {
      _setupNativeEventListener();
    }

    _isInitialized = true;
  }

  @override
  Future<void> dispose() async {
    await _eventController.close();
    _isInitialized = false;
  }

  /// Setup listener for native protection events.
  void _setupNativeEventListener() {
    _eventChannel.receiveBroadcastStream().listen((event) {
      if (event is Map) {
        final protectionEvent = ProtectionEvent.fromMap(
          Map<String, dynamic>.from(event),
        );
        _eventController.add(protectionEvent);
      }
    });
  }

  // ==================== Protected Mode ====================

  @override
  Future<bool> enableProtectedMode() async {
    try {
      // Check if Device Admin is active
      if (_deviceAdminService != null) {
        final isAdminActive = await _deviceAdminService.isAdminActive();
        if (!isAdminActive) {
          // Request Device Admin activation
          await _deviceAdminService.requestAdminActivation();
          return false; // User needs to grant permission
        }
      }

      // Check if Accessibility Service is enabled
      if (_accessibilityService != null) {
        final isAccessibilityEnabled =
            await _accessibilityService.isServiceEnabled();
        if (!isAccessibilityEnabled) {
          // Open Accessibility Settings
          await _accessibilityService.openAccessibilitySettings();
          return false; // User needs to enable service
        }
      }

      // Enable Protected Mode in native services
      if (_accessibilityService != null) {
        await _accessibilityService.enableProtectedMode();
      }

      if (_deviceAdminService != null) {
        await _deviceAdminService.setProtectedModeActive(true);
      }

      // Start protection foreground service
      if (_bootService != null) {
        await _bootService.startProtectionService();
        await _bootService.scheduleAutoRestartJob();
      }

      // Update configuration
      _config = _config.copyWith(protectedModeEnabled: true);
      await saveConfiguration();

      // Persist state
      await _storageService.storeSecure(
        ProtectionStorageKeys.protectedModeActive,
        'true',
      );

      // Emit event
      _emitEvent(ProtectionEventType.protectedModeEnabled);

      return true;
    } catch (e) {
      return false;
    }
  }

  @override
  Future<bool> disableProtectedMode(String password) async {
    try {
      // Verify password
      final isValid = await _authService.verifyPassword(password);
      if (!isValid) {
        _emitEvent(ProtectionEventType.passwordFailed);
        return false;
      }

      _emitEvent(ProtectionEventType.passwordSucceeded);

      // Disable Protected Mode in native services
      if (_accessibilityService != null) {
        await _accessibilityService.disableProtectedMode();
      }

      if (_deviceAdminService != null) {
        await _deviceAdminService.setProtectedModeActive(false);
        // Allow deactivation for 30 seconds
        await _deviceAdminService.allowDeactivation();
      }

      // Stop protection foreground service
      if (_bootService != null) {
        await _bootService.stopProtectionService();
        await _bootService.cancelAutoRestartJob();
      }

      // Update configuration
      _config = _config.copyWith(protectedModeEnabled: false);
      await saveConfiguration();

      // Persist state
      await _storageService.storeSecure(
        ProtectionStorageKeys.protectedModeActive,
        'false',
      );

      // Emit event
      _emitEvent(ProtectionEventType.protectedModeDisabled);

      return true;
    } catch (e) {
      return false;
    }
  }

  @override
  Future<bool> isProtectedModeActive() async {
    final stored = await _storageService.retrieveSecure(
      ProtectionStorageKeys.protectedModeActive,
    );
    return stored == 'true';
  }

  // ==================== Kiosk Mode ====================

  @override
  Future<bool> enableKioskMode() async {
    try {
      // Enable Kiosk Mode via native channel
      await _channel.invokeMethod('enableKioskMode');

      // Update configuration
      _config = _config.copyWith(kioskModeEnabled: true);
      await saveConfiguration();

      // Persist state
      await _storageService.storeSecure(
        ProtectionStorageKeys.kioskModeActive,
        'true',
      );

      // Emit event
      _emitEvent(ProtectionEventType.kioskModeEnabled);

      return true;
    } on PlatformException {
      return false;
    }
  }

  @override
  Future<bool> disableKioskMode(String password) async {
    try {
      // Verify password
      final isValid = await _authService.verifyPassword(password);
      if (!isValid) {
        _emitEvent(ProtectionEventType.passwordFailed);
        return false;
      }

      _emitEvent(ProtectionEventType.passwordSucceeded);

      // Disable Kiosk Mode via native channel
      await _channel.invokeMethod('disableKioskMode');

      // Update configuration
      _config = _config.copyWith(kioskModeEnabled: false);
      await saveConfiguration();

      // Persist state
      await _storageService.storeSecure(
        ProtectionStorageKeys.kioskModeActive,
        'false',
      );

      // Emit event
      _emitEvent(ProtectionEventType.kioskModeDisabled);

      return true;
    } on PlatformException {
      return false;
    }
  }

  @override
  Future<bool> isKioskModeActive() async {
    final stored = await _storageService.retrieveSecure(
      ProtectionStorageKeys.kioskModeActive,
    );
    return stored == 'true';
  }

  @override
  Future<void> showKioskLockScreen({String? message}) async {
    try {
      await _channel.invokeMethod('showKioskLockScreen', {
        'message': message ?? _config.lockScreenMessage,
      });
    } on PlatformException {
      // Handle error silently
    }
  }

  // ==================== Panic Mode ====================

  @override
  Future<void> enablePanicMode() async {
    try {
      // Enable Kiosk Mode
      await enableKioskMode();

      // Trigger alarm via native channel
      await _channel.invokeMethod('triggerPanicAlarm');

      // Capture photo (will be handled by camera service)
      await _channel.invokeMethod('capturePanicPhoto');

      // Send SMS to Emergency Contact (will be handled by SMS service)
      if (_config.emergencyContact != null) {
        await _channel.invokeMethod('sendPanicSms', {
          'phoneNumber': _config.emergencyContact,
        });
      }

      // Enable high-frequency location tracking
      await _channel.invokeMethod('enableHighFrequencyTracking');

      // Update configuration
      _config = _config.copyWith(panicModeEnabled: true);
      await saveConfiguration();

      // Persist state
      await _storageService.storeSecure(
        ProtectionStorageKeys.panicModeActive,
        'true',
      );

      // Show fake "Device Locked by Administrator" screen
      await showKioskLockScreen(
        message: 'Device Locked by Administrator',
      );

      // Emit event
      _emitEvent(ProtectionEventType.panicModeActivated);
    } on PlatformException {
      // Handle error silently
    }
  }

  @override
  Future<bool> disablePanicMode(String password) async {
    try {
      // Verify password
      final isValid = await _authService.verifyPassword(password);
      if (!isValid) {
        _emitEvent(ProtectionEventType.passwordFailed);
        _panicPasswordFirstConfirmed = false;
        _panicPasswordFirstConfirmTime = null;
        return false;
      }

      // Check if this is the first or second confirmation
      if (!_panicPasswordFirstConfirmed) {
        // First confirmation
        _panicPasswordFirstConfirmed = true;
        _panicPasswordFirstConfirmTime = DateTime.now();
        _emitEvent(ProtectionEventType.passwordRequired, metadata: {
          'reason': 'panic_mode_second_confirmation',
        });
        return false; // Need second confirmation
      }

      // Check if second confirmation is within time window
      if (_panicPasswordFirstConfirmTime != null) {
        final elapsed =
            DateTime.now().difference(_panicPasswordFirstConfirmTime!);
        if (elapsed > _panicPasswordConfirmWindow) {
          // Window expired, reset
          _panicPasswordFirstConfirmed = false;
          _panicPasswordFirstConfirmTime = null;
          _emitEvent(ProtectionEventType.passwordRequired, metadata: {
            'reason': 'panic_mode_confirmation_expired',
          });
          return false;
        }
      }

      // Second confirmation successful
      _panicPasswordFirstConfirmed = false;
      _panicPasswordFirstConfirmTime = null;

      _emitEvent(ProtectionEventType.passwordSucceeded);

      // Stop alarm
      await _channel.invokeMethod('stopPanicAlarm');

      // Disable high-frequency tracking
      await _channel.invokeMethod('disableHighFrequencyTracking');

      // Disable Kiosk Mode
      await disableKioskMode(password);

      // Update configuration
      _config = _config.copyWith(panicModeEnabled: false);
      await saveConfiguration();

      // Persist state
      await _storageService.storeSecure(
        ProtectionStorageKeys.panicModeActive,
        'false',
      );

      // Emit event
      _emitEvent(ProtectionEventType.panicModeDeactivated);

      return true;
    } on PlatformException {
      return false;
    }
  }

  @override
  Future<bool> isPanicModeActive() async {
    final stored = await _storageService.retrieveSecure(
      ProtectionStorageKeys.panicModeActive,
    );
    return stored == 'true';
  }

  @override
  Future<void> registerVolumeButtonListener() async {
    try {
      await _channel.invokeMethod('registerVolumeButtonListener');

      // Setup method call handler for volume button events
      _channel.setMethodCallHandler((call) async {
        if (call.method == 'onVolumeButtonPressed') {
          _handleVolumeButtonPress();
        }
        return null;
      });
    } on PlatformException {
      // Handle error silently
    }
  }

  @override
  Future<void> unregisterVolumeButtonListener() async {
    try {
      await _channel.invokeMethod('unregisterVolumeButtonListener');
      _channel.setMethodCallHandler(null);
    } on PlatformException {
      // Handle error silently
    }
  }

  /// Handle volume button press for panic mode activation.
  void _handleVolumeButtonPress() {
    final now = DateTime.now();

    // Remove old presses outside the window
    _volumeButtonPresses.removeWhere(
      (press) => now.difference(press) > _panicVolumeButtonWindow,
    );

    // Add current press
    _volumeButtonPresses.add(now);

    // Check if we have enough presses
    if (_volumeButtonPresses.length >= _panicVolumeButtonCount) {
      _volumeButtonPresses.clear();
      _emitEvent(ProtectionEventType.volumeButtonSequenceDetected);
      enablePanicMode();
    }
  }

  // ==================== Stealth Mode ====================

  @override
  Future<void> enableStealthMode() async {
    try {
      // Exclude from recent apps
      await _channel.invokeMethod('excludeFromRecentApps', {'exclude': true});

      // Update configuration
      _config = _config.copyWith(stealthModeEnabled: true);
      await saveConfiguration();

      // Persist state
      await _storageService.storeSecure(
        ProtectionStorageKeys.stealthModeActive,
        'true',
      );

      // Emit event
      _emitEvent(ProtectionEventType.stealthModeEnabled);
    } on PlatformException {
      // Handle error silently
    }
  }

  @override
  Future<void> disableStealthMode() async {
    try {
      // Include in recent apps
      await _channel.invokeMethod('excludeFromRecentApps', {'exclude': false});

      // Show app icon if hidden
      await setHideAppIcon(false);

      // Update configuration
      _config = _config.copyWith(stealthModeEnabled: false);
      await saveConfiguration();

      // Persist state
      await _storageService.storeSecure(
        ProtectionStorageKeys.stealthModeActive,
        'false',
      );

      // Emit event
      _emitEvent(ProtectionEventType.stealthModeDisabled);
    } on PlatformException {
      // Handle error silently
    }
  }

  @override
  Future<bool> isStealthModeActive() async {
    final stored = await _storageService.retrieveSecure(
      ProtectionStorageKeys.stealthModeActive,
    );
    return stored == 'true';
  }

  @override
  Future<void> setHideAppIcon(bool hide) async {
    try {
      await _channel.invokeMethod('setAppIconVisibility', {'hide': hide});

      // Persist state
      await _storageService.storeSecure(
        ProtectionStorageKeys.appIconHidden,
        hide.toString(),
      );
    } on PlatformException {
      // Handle error silently
    }
  }

  @override
  Future<bool> isAppIconHidden() async {
    final stored = await _storageService.retrieveSecure(
      ProtectionStorageKeys.appIconHidden,
    );
    return stored == 'true';
  }

  // ==================== Dialer Code Access ====================

  @override
  Future<void> registerDialerCodeListener() async {
    try {
      final code = await getDialerCode();
      await _channel.invokeMethod('registerDialerCodeListener', {
        'code': code,
      });
    } on PlatformException {
      // Handle error silently
    }
  }

  @override
  Future<void> unregisterDialerCodeListener() async {
    try {
      await _channel.invokeMethod('unregisterDialerCodeListener');
    } on PlatformException {
      // Handle error silently
    }
  }

  @override
  Future<void> setDialerCode(String code) async {
    await _storageService.storeSecure(
      ProtectionStorageKeys.dialerCode,
      code,
    );

    // Re-register listener with new code
    await registerDialerCodeListener();
  }

  @override
  Future<String> getDialerCode() async {
    final stored = await _storageService.retrieveSecure(
      ProtectionStorageKeys.dialerCode,
    );
    return stored ?? defaultDialerCode;
  }

  @override
  Future<void> handleDialerCodeEntry() async {
    _emitEvent(ProtectionEventType.dialerCodeEntered);

    // Open the app
    try {
      await _channel.invokeMethod('openApp');
    } on PlatformException {
      // Handle error silently
    }

    // Password will be requested by the UI
    _emitEvent(ProtectionEventType.passwordRequired, metadata: {
      'reason': 'dialer_code_entry',
    });
  }

  // ==================== Configuration ====================

  @override
  Future<ProtectionConfig> getConfiguration() async {
    return _config;
  }

  @override
  Future<bool> updateConfiguration(
    ProtectionConfig config,
    String password,
  ) async {
    // Verify password for any configuration change
    final isValid = await _authService.verifyPassword(password);
    if (!isValid) {
      _emitEvent(ProtectionEventType.passwordFailed);
      return false;
    }

    _emitEvent(ProtectionEventType.passwordSucceeded);

    // Update configuration
    _config = config;
    await saveConfiguration();

    // Apply configuration changes
    await _applyConfigurationChanges(config);

    // Emit event
    _emitEvent(ProtectionEventType.configurationChanged, metadata: {
      'config': config.toJson(),
    });

    return true;
  }

  /// Apply configuration changes to native services.
  Future<void> _applyConfigurationChanges(ProtectionConfig config) async {
    // Update accessibility service blocking options
    if (_accessibilityService != null) {
      await _accessibilityService.setBlockingOptions(
        blockSettings: config.blockSettings,
        blockFileManagers: config.blockFileManagers,
        blockPowerMenu: config.blockPowerMenu,
        blockQuickSettings: true,
      );
    }
  }

  @override
  Future<void> saveConfiguration() async {
    final configJson = jsonEncode(_config.toJson());
    await _storageService.storeSecure(
      ProtectionStorageKeys.config,
      configJson,
    );
  }

  @override
  Future<ProtectionConfig> loadConfiguration() async {
    final configJson = await _storageService.retrieveSecure(
      ProtectionStorageKeys.config,
    );

    if (configJson == null) {
      return ProtectionConfig();
    }

    try {
      final json = jsonDecode(configJson) as Map<String, dynamic>;
      return ProtectionConfig.fromJson(json);
    } catch (e) {
      return ProtectionConfig();
    }
  }

  // ==================== Events ====================

  @override
  Stream<ProtectionEvent> get events => _eventController.stream;

  /// Emit a protection event.
  void _emitEvent(
    ProtectionEventType type, {
    Map<String, dynamic>? metadata,
  }) {
    _eventController.add(ProtectionEvent(
      type: type,
      timestamp: DateTime.now(),
      metadata: metadata,
    ));
  }
}
