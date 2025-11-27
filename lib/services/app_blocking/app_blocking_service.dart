import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../accessibility/i_accessibility_service.dart';
import '../storage/i_storage_service.dart';
import 'i_app_blocking_service.dart';

/// Storage keys for app blocking configuration
class AppBlockingStorageKeys {
  static const String settingsBlocking = 'app_blocking_settings';
  static const String fileManagerBlocking = 'app_blocking_file_manager';
  static const String screenLockChangeBlocking = 'app_blocking_screen_lock';
  static const String accountAdditionBlocking = 'app_blocking_account';
  static const String appInstallationBlocking = 'app_blocking_installation';
  static const String factoryResetBlocking = 'app_blocking_factory_reset';
  static const String usbDataTransferBlocking = 'app_blocking_usb';
  static const String fileManagerAccessUntil = 'file_manager_access_until';
}

/// Implementation of IAppBlockingService
///
/// Provides comprehensive app blocking functionality using the native
/// Android Accessibility Service and Device Admin capabilities.
///
/// Requirements:
/// - 12.1, 27.1: Block Settings app completely
/// - 23.1, 23.2: Block file manager apps with password overlay
/// - 23.3, 23.4: 1-minute file manager access timeout
/// - 30.1, 30.2: Block screen lock changes
/// - 31.1, 31.2: Block account addition
/// - 32.1, 32.2, 32.3: Block app installation/uninstallation
/// - 33.1: Block factory reset from Settings
class AppBlockingService implements IAppBlockingService {
  static const MethodChannel _channel = MethodChannel(
    'com.example.find_phone/app_blocking',
  );
  static const EventChannel _eventChannel = EventChannel(
    'com.example.find_phone/app_blocking_events',
  );

  final IStorageService _storageService;
  final IAccessibilityService? _accessibilityService;

  final StreamController<AppBlockingEvent> _eventController =
      StreamController<AppBlockingEvent>.broadcast();

  StreamSubscription? _eventSubscription;
  Timer? _fileManagerAccessTimer;

  /// File manager access timeout duration (1 minute)
  static const Duration fileManagerAccessTimeout = Duration(minutes: 1);

  AppBlockingService({
    required IStorageService storageService,
    IAccessibilityService? accessibilityService,
  })  : _storageService = storageService,
        _accessibilityService = accessibilityService;

  @override
  Future<void> initialize() async {
    // Setup event listener from native side
    _eventSubscription = _eventChannel.receiveBroadcastStream().listen(
      (dynamic event) {
        if (event is Map) {
          final blockingEvent = AppBlockingEvent.fromMap(
            Map<String, dynamic>.from(event),
          );
          _eventController.add(blockingEvent);
        }
      },
      onError: (error) {
        debugPrint('App blocking event error: $error');
      },
    );

    // Restore blocking states from storage
    await _restoreBlockingStates();
  }

  @override
  Future<void> dispose() async {
    _eventSubscription?.cancel();
    _fileManagerAccessTimer?.cancel();
    await _eventController.close();
  }

  /// Restore blocking states from persistent storage
  Future<void> _restoreBlockingStates() async {
    final settingsBlocking = await _storageService.retrieveSecure(
      AppBlockingStorageKeys.settingsBlocking,
    );
    if (settingsBlocking == 'true') {
      await _setNativeSettingsBlocking(true);
    }

    final fileManagerBlocking = await _storageService.retrieveSecure(
      AppBlockingStorageKeys.fileManagerBlocking,
    );
    if (fileManagerBlocking == 'true') {
      await _setNativeFileManagerBlocking(true);
    }

    final screenLockBlocking = await _storageService.retrieveSecure(
      AppBlockingStorageKeys.screenLockChangeBlocking,
    );
    if (screenLockBlocking == 'true') {
      await _setNativeScreenLockChangeBlocking(true);
    }

    final accountBlocking = await _storageService.retrieveSecure(
      AppBlockingStorageKeys.accountAdditionBlocking,
    );
    if (accountBlocking == 'true') {
      await _setNativeAccountAdditionBlocking(true);
    }

    final installBlocking = await _storageService.retrieveSecure(
      AppBlockingStorageKeys.appInstallationBlocking,
    );
    if (installBlocking == 'true') {
      await _setNativeAppInstallationBlocking(true);
    }

    final factoryResetBlocking = await _storageService.retrieveSecure(
      AppBlockingStorageKeys.factoryResetBlocking,
    );
    if (factoryResetBlocking == 'true') {
      await _setNativeFactoryResetBlocking(true);
    }

    final usbBlocking = await _storageService.retrieveSecure(
      AppBlockingStorageKeys.usbDataTransferBlocking,
    );
    if (usbBlocking == 'true') {
      await _setNativeUsbDataTransferBlocking(true);
    }
  }

  // ==================== Settings Blocking ====================

  @override
  Future<void> enableSettingsBlocking() async {
    await _setNativeSettingsBlocking(true);
    await _storageService.storeSecure(
      AppBlockingStorageKeys.settingsBlocking,
      'true',
    );

    // Also update accessibility service if available
    if (_accessibilityService != null) {
      final status = await _accessibilityService.getBlockingStatus();
      await _accessibilityService.setBlockingOptions(
        blockSettings: true,
        blockFileManagers: status['block_file_managers'] ?? true,
        blockPowerMenu: status['block_power_menu'] ?? true,
        blockQuickSettings: status['block_quick_settings'] ?? true,
      );
    }
  }

  @override
  Future<void> disableSettingsBlocking() async {
    await _setNativeSettingsBlocking(false);
    await _storageService.storeSecure(
      AppBlockingStorageKeys.settingsBlocking,
      'false',
    );

    if (_accessibilityService != null) {
      final status = await _accessibilityService.getBlockingStatus();
      await _accessibilityService.setBlockingOptions(
        blockSettings: false,
        blockFileManagers: status['block_file_managers'] ?? true,
        blockPowerMenu: status['block_power_menu'] ?? true,
        blockQuickSettings: status['block_quick_settings'] ?? true,
      );
    }
  }

  @override
  Future<bool> isSettingsBlockingEnabled() async {
    final stored = await _storageService.retrieveSecure(
      AppBlockingStorageKeys.settingsBlocking,
    );
    return stored == 'true';
  }

  Future<void> _setNativeSettingsBlocking(bool enabled) async {
    try {
      await _channel.invokeMethod('setSettingsBlocking', {'enabled': enabled});
    } on PlatformException catch (e) {
      debugPrint('Error setting settings blocking: ${e.message}');
    }
  }

  // ==================== File Manager Blocking ====================

  @override
  Future<void> enableFileManagerBlocking() async {
    await _setNativeFileManagerBlocking(true);
    await _storageService.storeSecure(
      AppBlockingStorageKeys.fileManagerBlocking,
      'true',
    );

    if (_accessibilityService != null) {
      final status = await _accessibilityService.getBlockingStatus();
      await _accessibilityService.setBlockingOptions(
        blockSettings: status['block_settings'] ?? true,
        blockFileManagers: true,
        blockPowerMenu: status['block_power_menu'] ?? true,
        blockQuickSettings: status['block_quick_settings'] ?? true,
      );
    }
  }

  @override
  Future<void> disableFileManagerBlocking() async {
    await _setNativeFileManagerBlocking(false);
    await _storageService.storeSecure(
      AppBlockingStorageKeys.fileManagerBlocking,
      'false',
    );

    if (_accessibilityService != null) {
      final status = await _accessibilityService.getBlockingStatus();
      await _accessibilityService.setBlockingOptions(
        blockSettings: status['block_settings'] ?? true,
        blockFileManagers: false,
        blockPowerMenu: status['block_power_menu'] ?? true,
        blockQuickSettings: status['block_quick_settings'] ?? true,
      );
    }
  }

  @override
  Future<bool> isFileManagerBlockingEnabled() async {
    final stored = await _storageService.retrieveSecure(
      AppBlockingStorageKeys.fileManagerBlocking,
    );
    return stored == 'true';
  }

  @override
  Future<void> grantTemporaryFileManagerAccess() async {
    final accessUntil = DateTime.now().add(fileManagerAccessTimeout);
    await _storageService.storeSecure(
      AppBlockingStorageKeys.fileManagerAccessUntil,
      accessUntil.millisecondsSinceEpoch.toString(),
    );

    // Notify native side
    try {
      await _channel.invokeMethod('grantTemporaryFileManagerAccess', {
        'durationMs': fileManagerAccessTimeout.inMilliseconds,
      });
    } on PlatformException catch (e) {
      debugPrint('Error granting file manager access: ${e.message}');
    }

    // Schedule automatic revocation
    _fileManagerAccessTimer?.cancel();
    _fileManagerAccessTimer = Timer(fileManagerAccessTimeout, () {
      revokeFileManagerAccess();
    });

    _eventController.add(AppBlockingEvent(
      type: AppBlockingEventType.fileManagerAccessGranted,
      timestamp: DateTime.now(),
      metadata: {
        'accessUntil': accessUntil.millisecondsSinceEpoch,
        'durationSeconds': fileManagerAccessTimeout.inSeconds,
      },
    ));
  }

  @override
  Future<void> revokeFileManagerAccess() async {
    _fileManagerAccessTimer?.cancel();
    _fileManagerAccessTimer = null;

    await _storageService.storeSecure(
      AppBlockingStorageKeys.fileManagerAccessUntil,
      '0',
    );

    // Notify native side
    try {
      await _channel.invokeMethod('revokeFileManagerAccess');
    } on PlatformException catch (e) {
      debugPrint('Error revoking file manager access: ${e.message}');
    }

    _eventController.add(AppBlockingEvent(
      type: AppBlockingEventType.fileManagerAccessRevoked,
      timestamp: DateTime.now(),
    ));
  }

  @override
  Future<bool> hasTemporaryFileManagerAccess() async {
    final accessUntilStr = await _storageService.retrieveSecure(
      AppBlockingStorageKeys.fileManagerAccessUntil,
    );
    if (accessUntilStr == null || accessUntilStr == '0') return false;

    final accessUntil = int.tryParse(accessUntilStr) ?? 0;
    return DateTime.now().millisecondsSinceEpoch < accessUntil;
  }

  @override
  Future<int> getFileManagerAccessRemainingSeconds() async {
    final accessUntilStr = await _storageService.retrieveSecure(
      AppBlockingStorageKeys.fileManagerAccessUntil,
    );
    if (accessUntilStr == null || accessUntilStr == '0') return 0;

    final accessUntil = int.tryParse(accessUntilStr) ?? 0;
    final remaining = accessUntil - DateTime.now().millisecondsSinceEpoch;
    return remaining > 0 ? (remaining / 1000).ceil() : 0;
  }

  Future<void> _setNativeFileManagerBlocking(bool enabled) async {
    try {
      await _channel.invokeMethod(
        'setFileManagerBlocking',
        {'enabled': enabled},
      );
    } on PlatformException catch (e) {
      debugPrint('Error setting file manager blocking: ${e.message}');
    }
  }

  // ==================== Screen Lock Change Blocking ====================

  @override
  Future<void> enableScreenLockChangeBlocking() async {
    await _setNativeScreenLockChangeBlocking(true);
    await _storageService.storeSecure(
      AppBlockingStorageKeys.screenLockChangeBlocking,
      'true',
    );
  }

  @override
  Future<void> disableScreenLockChangeBlocking() async {
    await _setNativeScreenLockChangeBlocking(false);
    await _storageService.storeSecure(
      AppBlockingStorageKeys.screenLockChangeBlocking,
      'false',
    );
  }

  @override
  Future<bool> isScreenLockChangeBlockingEnabled() async {
    final stored = await _storageService.retrieveSecure(
      AppBlockingStorageKeys.screenLockChangeBlocking,
    );
    return stored == 'true';
  }

  Future<void> _setNativeScreenLockChangeBlocking(bool enabled) async {
    try {
      await _channel.invokeMethod(
        'setScreenLockChangeBlocking',
        {'enabled': enabled},
      );
    } on PlatformException catch (e) {
      debugPrint('Error setting screen lock change blocking: ${e.message}');
    }
  }

  // ==================== Account Addition Blocking ====================

  @override
  Future<void> enableAccountAdditionBlocking() async {
    await _setNativeAccountAdditionBlocking(true);
    await _storageService.storeSecure(
      AppBlockingStorageKeys.accountAdditionBlocking,
      'true',
    );
  }

  @override
  Future<void> disableAccountAdditionBlocking() async {
    await _setNativeAccountAdditionBlocking(false);
    await _storageService.storeSecure(
      AppBlockingStorageKeys.accountAdditionBlocking,
      'false',
    );
  }

  @override
  Future<bool> isAccountAdditionBlockingEnabled() async {
    final stored = await _storageService.retrieveSecure(
      AppBlockingStorageKeys.accountAdditionBlocking,
    );
    return stored == 'true';
  }

  Future<void> _setNativeAccountAdditionBlocking(bool enabled) async {
    try {
      await _channel.invokeMethod(
        'setAccountAdditionBlocking',
        {'enabled': enabled},
      );
    } on PlatformException catch (e) {
      debugPrint('Error setting account addition blocking: ${e.message}');
    }
  }

  // ==================== App Installation Blocking ====================

  @override
  Future<void> enableAppInstallationBlocking() async {
    await _setNativeAppInstallationBlocking(true);
    await _storageService.storeSecure(
      AppBlockingStorageKeys.appInstallationBlocking,
      'true',
    );
  }

  @override
  Future<void> disableAppInstallationBlocking() async {
    await _setNativeAppInstallationBlocking(false);
    await _storageService.storeSecure(
      AppBlockingStorageKeys.appInstallationBlocking,
      'false',
    );
  }

  @override
  Future<bool> isAppInstallationBlockingEnabled() async {
    final stored = await _storageService.retrieveSecure(
      AppBlockingStorageKeys.appInstallationBlocking,
    );
    return stored == 'true';
  }

  Future<void> _setNativeAppInstallationBlocking(bool enabled) async {
    try {
      await _channel.invokeMethod(
        'setAppInstallationBlocking',
        {'enabled': enabled},
      );
    } on PlatformException catch (e) {
      debugPrint('Error setting app installation blocking: ${e.message}');
    }
  }

  // ==================== Factory Reset Blocking ====================

  @override
  Future<void> enableFactoryResetBlocking() async {
    await _setNativeFactoryResetBlocking(true);
    await _storageService.storeSecure(
      AppBlockingStorageKeys.factoryResetBlocking,
      'true',
    );
  }

  @override
  Future<void> disableFactoryResetBlocking() async {
    await _setNativeFactoryResetBlocking(false);
    await _storageService.storeSecure(
      AppBlockingStorageKeys.factoryResetBlocking,
      'false',
    );
  }

  @override
  Future<bool> isFactoryResetBlockingEnabled() async {
    final stored = await _storageService.retrieveSecure(
      AppBlockingStorageKeys.factoryResetBlocking,
    );
    return stored == 'true';
  }

  Future<void> _setNativeFactoryResetBlocking(bool enabled) async {
    try {
      await _channel.invokeMethod(
        'setFactoryResetBlocking',
        {'enabled': enabled},
      );
    } on PlatformException catch (e) {
      debugPrint('Error setting factory reset blocking: ${e.message}');
    }
  }

  // ==================== USB Data Transfer Blocking ====================

  @override
  Future<void> enableUsbDataTransferBlocking() async {
    await _setNativeUsbDataTransferBlocking(true);
    await _storageService.storeSecure(
      AppBlockingStorageKeys.usbDataTransferBlocking,
      'true',
    );
  }

  @override
  Future<void> disableUsbDataTransferBlocking() async {
    await _setNativeUsbDataTransferBlocking(false);
    await _storageService.storeSecure(
      AppBlockingStorageKeys.usbDataTransferBlocking,
      'false',
    );
  }

  @override
  Future<bool> isUsbDataTransferBlockingEnabled() async {
    final stored = await _storageService.retrieveSecure(
      AppBlockingStorageKeys.usbDataTransferBlocking,
    );
    return stored == 'true';
  }

  Future<void> _setNativeUsbDataTransferBlocking(bool enabled) async {
    try {
      await _channel.invokeMethod(
        'setUsbDataTransferBlocking',
        {'enabled': enabled},
      );
    } on PlatformException catch (e) {
      debugPrint('Error setting USB data transfer blocking: ${e.message}');
    }
  }

  // ==================== Blocking Status ====================

  @override
  Future<AppBlockingStatus> getBlockingStatus() async {
    return AppBlockingStatus(
      settingsBlocking: await isSettingsBlockingEnabled(),
      fileManagerBlocking: await isFileManagerBlockingEnabled(),
      screenLockChangeBlocking: await isScreenLockChangeBlockingEnabled(),
      accountAdditionBlocking: await isAccountAdditionBlockingEnabled(),
      appInstallationBlocking: await isAppInstallationBlockingEnabled(),
      factoryResetBlocking: await isFactoryResetBlockingEnabled(),
      usbDataTransferBlocking: await isUsbDataTransferBlockingEnabled(),
      hasTemporaryFileManagerAccess: await hasTemporaryFileManagerAccess(),
      fileManagerAccessRemainingSeconds:
          await getFileManagerAccessRemainingSeconds(),
    );
  }

  @override
  Future<void> enableAllBlocking() async {
    await enableSettingsBlocking();
    await enableFileManagerBlocking();
    await enableScreenLockChangeBlocking();
    await enableAccountAdditionBlocking();
    await enableAppInstallationBlocking();
    await enableFactoryResetBlocking();
    await enableUsbDataTransferBlocking();
  }

  @override
  Future<void> disableAllBlocking() async {
    await disableSettingsBlocking();
    await disableFileManagerBlocking();
    await disableScreenLockChangeBlocking();
    await disableAccountAdditionBlocking();
    await disableAppInstallationBlocking();
    await disableFactoryResetBlocking();
    await disableUsbDataTransferBlocking();
  }

  // ==================== Events ====================

  @override
  Stream<AppBlockingEvent> get events => _eventController.stream;
}
