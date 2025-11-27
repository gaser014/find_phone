import 'dart:async';

import 'package:flutter/services.dart';

import '../../domain/entities/call_log_entry.dart';
import '../../domain/entities/security_event.dart';
import '../../domain/entities/sim_info.dart';
import '../security_log/i_security_log_service.dart';
import '../storage/i_storage_service.dart';
import 'i_monitoring_service.dart';

/// Implementation of the Monitoring Service.
///
/// Provides comprehensive monitoring functionality for detecting
/// suspicious activities and security-related events.
///
/// Requirements:
/// - 6.1: Monitor Airplane Mode status changes continuously
/// - 6.2: Attempt to disable Airplane Mode automatically within 2 seconds
/// - 13.2: Detect SIM card change within 5 seconds
/// - 17.1: Detect failed screen unlock attempts
/// - 17.2: Capture photo on 5 consecutive failed unlock attempts
/// - 19.1: Monitor all incoming and outgoing calls
/// - 19.2: Log phone number, duration, timestamp, and call type
/// - 22.4: Send alert when USB debugging is enabled
/// - 22.5: Log developer options access
class MonitoringService implements IMonitoringService {
  /// Method channel for native Android communication.
  static const MethodChannel _channel =
      MethodChannel('com.example.find_phone/monitoring');

  /// Storage service for persisting data.
  final IStorageService _storageService;

  /// Security log service for logging events.
  final ISecurityLogService? _securityLogService;

  /// Storage keys
  static const String _storedSimInfoKey = 'stored_sim_info';
  static const String _consecutiveFailedUnlocksKey = 'consecutive_failed_unlocks';
  static const String _callLogKey = 'call_log';

  /// Stream controllers for events
  final StreamController<AirplaneModeEvent> _airplaneModeController =
      StreamController<AirplaneModeEvent>.broadcast();
  final StreamController<SimChangeEvent> _simChangeController =
      StreamController<SimChangeEvent>.broadcast();
  final StreamController<UnlockAttemptEvent> _unlockAttemptController =
      StreamController<UnlockAttemptEvent>.broadcast();
  final StreamController<CallEvent> _callEventController =
      StreamController<CallEvent>.broadcast();
  final StreamController<UsbDebuggingEvent> _usbDebuggingController =
      StreamController<UsbDebuggingEvent>.broadcast();
  final StreamController<PowerButtonEvent> _powerButtonController =
      StreamController<PowerButtonEvent>.broadcast();
  final StreamController<AppLaunchEvent> _appLaunchController =
      StreamController<AppLaunchEvent>.broadcast();


  /// Monitoring state flags
  bool _isMonitoring = false;
  bool _isAirplaneModeMonitoring = false;
  bool _isSimMonitoring = false;
  bool _isUnlockMonitoring = false;
  bool _isCallMonitoring = false;
  bool _isUsbDebuggingMonitoring = false;
  bool _isDeveloperOptionsMonitoring = false;
  bool _isPowerButtonMonitoring = false;
  bool _isAppLaunchMonitoring = false;

  /// Timers for periodic monitoring
  Timer? _airplaneModeTimer;
  Timer? _simMonitorTimer;
  Timer? _usbDebuggingTimer;
  Timer? _developerOptionsTimer;

  /// Last known states for change detection
  bool? _lastAirplaneModeState;
  SimInfo? _lastSimInfo;
  bool? _lastUsbDebuggingState;
  bool? _lastDeveloperOptionsState;

  /// Constructor
  MonitoringService({
    required IStorageService storageService,
    ISecurityLogService? securityLogService,
  })  : _storageService = storageService,
        _securityLogService = securityLogService;

  @override
  bool get isMonitoring => _isMonitoring;

  @override
  Stream<AirplaneModeEvent> get airplaneModeEvents =>
      _airplaneModeController.stream;

  @override
  Stream<SimChangeEvent> get simChangeEvents => _simChangeController.stream;

  @override
  Stream<UnlockAttemptEvent> get unlockAttemptEvents =>
      _unlockAttemptController.stream;

  @override
  Stream<CallEvent> get callEvents => _callEventController.stream;

  @override
  Stream<UsbDebuggingEvent> get usbDebuggingEvents =>
      _usbDebuggingController.stream;

  @override
  Stream<PowerButtonEvent> get powerButtonEvents =>
      _powerButtonController.stream;

  @override
  Stream<AppLaunchEvent> get appLaunchEvents => _appLaunchController.stream;

  @override
  Future<void> initialize() async {
    // Set up method channel handler for native events
    _channel.setMethodCallHandler(_handleMethodCall);
  }

  @override
  Future<void> dispose() async {
    await stopMonitoring();
    await _airplaneModeController.close();
    await _simChangeController.close();
    await _unlockAttemptController.close();
    await _callEventController.close();
    await _usbDebuggingController.close();
    await _powerButtonController.close();
    await _appLaunchController.close();
  }

  /// Handle method calls from native code.
  Future<dynamic> _handleMethodCall(MethodCall call) async {
    switch (call.method) {
      case 'onAirplaneModeChanged':
        _handleAirplaneModeChange(call.arguments as Map<dynamic, dynamic>);
        break;
      case 'onSimChanged':
        _handleSimChange(call.arguments as Map<dynamic, dynamic>);
        break;
      case 'onUnlockAttempt':
        _handleUnlockAttempt(call.arguments as Map<dynamic, dynamic>);
        break;
      case 'onCallEvent':
        _handleCallEvent(call.arguments as Map<dynamic, dynamic>);
        break;
      case 'onUsbDebuggingChanged':
        _handleUsbDebuggingChange(call.arguments as Map<dynamic, dynamic>);
        break;
      case 'onPowerButtonPressed':
        _handlePowerButtonPress(call.arguments as Map<dynamic, dynamic>);
        break;
      case 'onAppLaunched':
        _handleAppLaunch(call.arguments as Map<dynamic, dynamic>);
        break;
    }
  }

  // ==================== General Monitoring ====================

  @override
  Future<void> startMonitoring() async {
    if (_isMonitoring) return;

    await startAirplaneModeMonitoring();
    await startSimMonitoring();
    await startUnlockMonitoring();
    await startCallMonitoring();
    await startUsbDebuggingMonitoring();
    await startDeveloperOptionsMonitoring();
    await startPowerButtonMonitoring();
    await startAppLaunchMonitoring();

    _isMonitoring = true;
  }

  @override
  Future<void> stopMonitoring() async {
    await stopAirplaneModeMonitoring();
    await stopSimMonitoring();
    await stopUnlockMonitoring();
    await stopCallMonitoring();
    await stopUsbDebuggingMonitoring();
    await stopDeveloperOptionsMonitoring();
    await stopPowerButtonMonitoring();
    await stopAppLaunchMonitoring();

    _isMonitoring = false;
  }


  // ==================== Airplane Mode Monitoring ====================

  @override
  Future<bool> isAirplaneModeEnabled() async {
    try {
      final result = await _channel.invokeMethod<bool>('isAirplaneModeEnabled');
      return result ?? false;
    } on PlatformException {
      return false;
    }
  }

  @override
  Future<bool> disableAirplaneMode() async {
    try {
      final result = await _channel.invokeMethod<bool>('disableAirplaneMode');
      return result ?? false;
    } on PlatformException {
      return false;
    }
  }

  @override
  Future<void> startAirplaneModeMonitoring() async {
    if (_isAirplaneModeMonitoring) return;

    _lastAirplaneModeState = await isAirplaneModeEnabled();

    // Poll every 500ms for airplane mode changes (to detect within 2 seconds)
    _airplaneModeTimer = Timer.periodic(
      const Duration(milliseconds: 500),
      (_) => _checkAirplaneModeChange(),
    );

    try {
      await _channel.invokeMethod('startAirplaneModeMonitoring');
    } on PlatformException {
      // Native monitoring not available, rely on polling
    }

    _isAirplaneModeMonitoring = true;
  }

  @override
  Future<void> stopAirplaneModeMonitoring() async {
    _airplaneModeTimer?.cancel();
    _airplaneModeTimer = null;

    try {
      await _channel.invokeMethod('stopAirplaneModeMonitoring');
    } on PlatformException {
      // Ignore
    }

    _isAirplaneModeMonitoring = false;
  }

  Future<void> _checkAirplaneModeChange() async {
    final currentState = await isAirplaneModeEnabled();

    if (_lastAirplaneModeState != null && currentState != _lastAirplaneModeState) {
      final event = AirplaneModeEvent(
        isEnabled: currentState,
        timestamp: DateTime.now(),
        isAuthorized: false,
      );

      _airplaneModeController.add(event);

      // Auto-disable if enabled without authorization (Requirement 6.2)
      if (currentState) {
        await disableAirplaneMode();
      }
    }

    _lastAirplaneModeState = currentState;
  }

  void _handleAirplaneModeChange(Map<dynamic, dynamic> args) {
    final isEnabled = args['isEnabled'] as bool? ?? false;
    final event = AirplaneModeEvent(
      isEnabled: isEnabled,
      timestamp: DateTime.now(),
      isAuthorized: false,
    );

    _airplaneModeController.add(event);

    // Auto-disable if enabled without authorization (Requirement 6.2)
    if (isEnabled) {
      disableAirplaneMode();
    }
  }


  // ==================== SIM Card Monitoring ====================

  @override
  Future<SimInfo?> getCurrentSimInfo() async {
    try {
      final result = await _channel.invokeMethod<Map<dynamic, dynamic>>('getSimInfo');
      if (result == null) return null;

      return SimInfo(
        iccid: result['iccid'] as String?,
        imsi: result['imsi'] as String?,
        phoneNumber: result['phoneNumber'] as String?,
        carrierName: result['carrierName'] as String?,
        recordedAt: DateTime.now(),
      );
    } on PlatformException {
      return null;
    }
  }

  @override
  Future<SimInfo?> getStoredSimInfo() async {
    final json = await _storageService.retrieve(_storedSimInfoKey);
    if (json == null) return null;

    try {
      return SimInfo.fromJson(Map<String, dynamic>.from(json as Map));
    } catch (e) {
      return null;
    }
  }

  @override
  Future<void> storeCurrentSimInfo() async {
    final simInfo = await getCurrentSimInfo();
    if (simInfo != null) {
      await _storageService.store(_storedSimInfoKey, simInfo.toJson());
      _lastSimInfo = simInfo;
    }
  }

  @override
  Future<void> startSimMonitoring() async {
    if (_isSimMonitoring) return;

    _lastSimInfo = await getCurrentSimInfo();

    // Poll every 2 seconds for SIM changes (to detect within 5 seconds)
    _simMonitorTimer = Timer.periodic(
      const Duration(seconds: 2),
      (_) => _checkSimChange(),
    );

    try {
      await _channel.invokeMethod('startSimMonitoring');
    } on PlatformException {
      // Native monitoring not available, rely on polling
    }

    _isSimMonitoring = true;
  }

  @override
  Future<void> stopSimMonitoring() async {
    _simMonitorTimer?.cancel();
    _simMonitorTimer = null;

    try {
      await _channel.invokeMethod('stopSimMonitoring');
    } on PlatformException {
      // Ignore
    }

    _isSimMonitoring = false;
  }

  Future<void> _checkSimChange() async {
    final currentSim = await getCurrentSimInfo();
    final storedSim = await getStoredSimInfo();

    // Check if SIM has changed from stored SIM
    if (storedSim != null && currentSim != null) {
      if (currentSim.isDifferentFrom(storedSim)) {
        final event = SimChangeEvent(
          previousSim: _lastSimInfo ?? storedSim,
          newSim: currentSim,
          timestamp: DateTime.now(),
        );
        _simChangeController.add(event);
      }
    } else if (storedSim != null && currentSim == null) {
      // SIM was removed
      final event = SimChangeEvent(
        previousSim: _lastSimInfo ?? storedSim,
        newSim: SimInfo.absent(),
        timestamp: DateTime.now(),
      );
      _simChangeController.add(event);
    } else if (_lastSimInfo != null && currentSim != null) {
      // Check against last known SIM
      if (currentSim.isDifferentFrom(_lastSimInfo!)) {
        final event = SimChangeEvent(
          previousSim: _lastSimInfo,
          newSim: currentSim,
          timestamp: DateTime.now(),
        );
        _simChangeController.add(event);
      }
    }

    _lastSimInfo = currentSim;
  }

  void _handleSimChange(Map<dynamic, dynamic> args) {
    final previousSimData = args['previousSim'] as Map<dynamic, dynamic>?;
    final newSimData = args['newSim'] as Map<dynamic, dynamic>?;

    SimInfo? previousSim;
    SimInfo? newSim;

    if (previousSimData != null) {
      previousSim = SimInfo(
        iccid: previousSimData['iccid'] as String?,
        imsi: previousSimData['imsi'] as String?,
        phoneNumber: previousSimData['phoneNumber'] as String?,
        carrierName: previousSimData['carrierName'] as String?,
        recordedAt: DateTime.now(),
      );
    }

    if (newSimData != null) {
      newSim = SimInfo(
        iccid: newSimData['iccid'] as String?,
        imsi: newSimData['imsi'] as String?,
        phoneNumber: newSimData['phoneNumber'] as String?,
        carrierName: newSimData['carrierName'] as String?,
        recordedAt: DateTime.now(),
      );
    }

    final event = SimChangeEvent(
      previousSim: previousSim,
      newSim: newSim,
      timestamp: DateTime.now(),
    );

    _simChangeController.add(event);
  }


  // ==================== Screen Unlock Monitoring ====================

  @override
  Future<int> getConsecutiveFailedUnlocks() async {
    final count = await _storageService.retrieve(_consecutiveFailedUnlocksKey);
    return count as int? ?? 0;
  }

  @override
  Future<void> resetFailedUnlockCounter() async {
    await _storageService.store(_consecutiveFailedUnlocksKey, 0);
  }

  @override
  Future<void> startUnlockMonitoring() async {
    if (_isUnlockMonitoring) return;

    try {
      await _channel.invokeMethod('startUnlockMonitoring');
    } on PlatformException {
      // Native monitoring not available
    }

    _isUnlockMonitoring = true;
  }

  @override
  Future<void> stopUnlockMonitoring() async {
    try {
      await _channel.invokeMethod('stopUnlockMonitoring');
    } on PlatformException {
      // Ignore
    }

    _isUnlockMonitoring = false;
  }

  void _handleUnlockAttempt(Map<dynamic, dynamic> args) async {
    final isSuccessful = args['isSuccessful'] as bool? ?? false;

    int consecutiveFailures = await getConsecutiveFailedUnlocks();

    if (isSuccessful) {
      // Reset counter on successful unlock
      await resetFailedUnlockCounter();
      consecutiveFailures = 0;
    } else {
      // Increment counter on failed unlock
      consecutiveFailures++;
      await _storageService.store(_consecutiveFailedUnlocksKey, consecutiveFailures);
    }

    final event = UnlockAttemptEvent(
      isSuccessful: isSuccessful,
      timestamp: DateTime.now(),
      consecutiveFailures: consecutiveFailures,
    );

    _unlockAttemptController.add(event);
  }


  // ==================== Call Monitoring ====================

  @override
  Future<List<CallLogEntry>> getCallLog({DateTime? since}) async {
    final json = await _storageService.retrieve(_callLogKey);
    if (json == null) return [];

    try {
      final List<dynamic> list = json as List<dynamic>;
      final entries = list
          .map((e) => CallLogEntry.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();

      if (since != null) {
        return entries.where((e) => e.timestamp.isAfter(since)).toList();
      }

      return entries;
    } catch (e) {
      return [];
    }
  }

  Future<void> _saveCallLogEntry(CallLogEntry entry) async {
    final existingLog = await getCallLog();
    existingLog.add(entry);

    // Keep only last 1000 entries
    final trimmedLog = existingLog.length > 1000
        ? existingLog.sublist(existingLog.length - 1000)
        : existingLog;

    await _storageService.store(
      _callLogKey,
      trimmedLog.map((e) => e.toJson()).toList(),
    );
  }

  @override
  Future<void> startCallMonitoring() async {
    if (_isCallMonitoring) return;

    try {
      await _channel.invokeMethod('startCallMonitoring');
    } on PlatformException {
      // Native monitoring not available
    }

    _isCallMonitoring = true;
  }

  @override
  Future<void> stopCallMonitoring() async {
    try {
      await _channel.invokeMethod('stopCallMonitoring');
    } on PlatformException {
      // Ignore
    }

    _isCallMonitoring = false;
  }

  void _handleCallEvent(Map<dynamic, dynamic> args) async {
    final phoneNumber = args['phoneNumber'] as String? ?? '';
    final typeStr = args['type'] as String? ?? 'incoming';
    final durationSeconds = args['durationSeconds'] as int? ?? 0;
    final isEmergencyContact = args['isEmergencyContact'] as bool? ?? false;

    final type = CallType.values.firstWhere(
      (e) => e.name == typeStr,
      orElse: () => CallType.incoming,
    );

    final event = CallEvent(
      phoneNumber: phoneNumber,
      type: type,
      timestamp: DateTime.now(),
      duration: Duration(seconds: durationSeconds),
      isEmergencyContact: isEmergencyContact,
    );

    _callEventController.add(event);

    // Save to call log (Requirement 19.2)
    final entry = CallLogEntry(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      phoneNumber: phoneNumber,
      type: type,
      timestamp: DateTime.now(),
      duration: Duration(seconds: durationSeconds),
      isEmergencyContact: isEmergencyContact,
    );

    await _saveCallLogEntry(entry);
  }


  // ==================== USB Debugging Monitoring ====================

  @override
  Future<bool> isUsbDebuggingEnabled() async {
    try {
      final result = await _channel.invokeMethod<bool>('isUsbDebuggingEnabled');
      return result ?? false;
    } on PlatformException {
      return false;
    }
  }

  @override
  Future<void> startUsbDebuggingMonitoring() async {
    if (_isUsbDebuggingMonitoring) return;

    _lastUsbDebuggingState = await isUsbDebuggingEnabled();

    // Poll every 2 seconds for USB debugging changes
    _usbDebuggingTimer = Timer.periodic(
      const Duration(seconds: 2),
      (_) => _checkUsbDebuggingChange(),
    );

    try {
      await _channel.invokeMethod('startUsbDebuggingMonitoring');
    } on PlatformException {
      // Native monitoring not available, rely on polling
    }

    _isUsbDebuggingMonitoring = true;
  }

  @override
  Future<void> stopUsbDebuggingMonitoring() async {
    _usbDebuggingTimer?.cancel();
    _usbDebuggingTimer = null;

    try {
      await _channel.invokeMethod('stopUsbDebuggingMonitoring');
    } on PlatformException {
      // Ignore
    }

    _isUsbDebuggingMonitoring = false;
  }

  Future<void> _checkUsbDebuggingChange() async {
    final currentState = await isUsbDebuggingEnabled();

    if (_lastUsbDebuggingState != null && currentState != _lastUsbDebuggingState) {
      final event = UsbDebuggingEvent(
        isEnabled: currentState,
        timestamp: DateTime.now(),
      );

      _usbDebuggingController.add(event);
    }

    _lastUsbDebuggingState = currentState;
  }

  void _handleUsbDebuggingChange(Map<dynamic, dynamic> args) {
    final isEnabled = args['isEnabled'] as bool? ?? false;
    final event = UsbDebuggingEvent(
      isEnabled: isEnabled,
      timestamp: DateTime.now(),
    );

    _usbDebuggingController.add(event);
  }


  // ==================== Developer Options Monitoring ====================

  @override
  Future<bool> isDeveloperOptionsEnabled() async {
    try {
      final result = await _channel.invokeMethod<bool>('isDeveloperOptionsEnabled');
      return result ?? false;
    } on PlatformException {
      return false;
    }
  }

  @override
  Future<void> checkDeveloperOptionsAccess() async {
    final isEnabled = await isDeveloperOptionsEnabled();

    if (_lastDeveloperOptionsState != null && 
        isEnabled && 
        !_lastDeveloperOptionsState!) {
      // Developer options was just enabled - log this event
      _securityLogService?.logEvent(
        _createDeveloperOptionsEvent(),
      );
    }

    _lastDeveloperOptionsState = isEnabled;
  }

  SecurityEvent _createDeveloperOptionsEvent() {
    return SecurityEvent(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      type: SecurityEventType.developerOptionsAccessed,
      timestamp: DateTime.now(),
      description: 'Developer options were accessed or enabled',
      metadata: {},
    );
  }

  @override
  Future<void> startDeveloperOptionsMonitoring() async {
    if (_isDeveloperOptionsMonitoring) return;

    _lastDeveloperOptionsState = await isDeveloperOptionsEnabled();

    // Poll every 3 seconds for developer options changes
    _developerOptionsTimer = Timer.periodic(
      const Duration(seconds: 3),
      (_) => checkDeveloperOptionsAccess(),
    );

    try {
      await _channel.invokeMethod('startDeveloperOptionsMonitoring');
    } on PlatformException {
      // Native monitoring not available, rely on polling
    }

    _isDeveloperOptionsMonitoring = true;
  }

  @override
  Future<void> stopDeveloperOptionsMonitoring() async {
    _developerOptionsTimer?.cancel();
    _developerOptionsTimer = null;

    try {
      await _channel.invokeMethod('stopDeveloperOptionsMonitoring');
    } on PlatformException {
      // Ignore
    }

    _isDeveloperOptionsMonitoring = false;
  }


  // ==================== Power Button Monitoring ====================

  @override
  Future<void> startPowerButtonMonitoring() async {
    if (_isPowerButtonMonitoring) return;

    try {
      await _channel.invokeMethod('startPowerButtonMonitoring');
    } on PlatformException {
      // Native monitoring not available
    }

    _isPowerButtonMonitoring = true;
  }

  @override
  Future<void> stopPowerButtonMonitoring() async {
    try {
      await _channel.invokeMethod('stopPowerButtonMonitoring');
    } on PlatformException {
      // Ignore
    }

    _isPowerButtonMonitoring = false;
  }

  void _handlePowerButtonPress(Map<dynamic, dynamic> args) {
    final isLongPress = args['isLongPress'] as bool? ?? false;
    final event = PowerButtonEvent(
      isLongPress: isLongPress,
      timestamp: DateTime.now(),
    );

    _powerButtonController.add(event);
  }

  // ==================== App Launch Monitoring ====================

  @override
  Future<void> startAppLaunchMonitoring() async {
    if (_isAppLaunchMonitoring) return;

    try {
      await _channel.invokeMethod('startAppLaunchMonitoring');
    } on PlatformException {
      // Native monitoring not available
    }

    _isAppLaunchMonitoring = true;
  }

  @override
  Future<void> stopAppLaunchMonitoring() async {
    try {
      await _channel.invokeMethod('stopAppLaunchMonitoring');
    } on PlatformException {
      // Ignore
    }

    _isAppLaunchMonitoring = false;
  }

  void _handleAppLaunch(Map<dynamic, dynamic> args) {
    final packageName = args['packageName'] as String? ?? '';
    final appName = args['appName'] as String?;
    final isBlocked = args['isBlocked'] as bool? ?? false;

    final event = AppLaunchEvent(
      packageName: packageName,
      appName: appName,
      timestamp: DateTime.now(),
      isBlocked: isBlocked,
    );

    _appLaunchController.add(event);
  }

  // ==================== Boot Mode Detection ====================

  @override
  Future<BootMode> detectBootMode() async {
    try {
      final result = await _channel.invokeMethod<String>('detectBootMode');
      switch (result) {
        case 'normal':
          return BootMode.normal;
        case 'safe_mode':
          return BootMode.safeMode;
        case 'recovery':
          return BootMode.recovery;
        default:
          return BootMode.unknown;
      }
    } on PlatformException {
      return BootMode.unknown;
    }
  }

  @override
  Future<bool> isInSafeMode() async {
    final bootMode = await detectBootMode();
    return bootMode == BootMode.safeMode;
  }

  // ==================== Permissions ====================

  @override
  Future<bool> hasPhoneStatePermission() async {
    try {
      final result = await _channel.invokeMethod<bool>('hasPhoneStatePermission');
      return result ?? false;
    } on PlatformException {
      return false;
    }
  }

  @override
  Future<bool> requestPhoneStatePermission() async {
    try {
      final result = await _channel.invokeMethod<bool>('requestPhoneStatePermission');
      return result ?? false;
    } on PlatformException {
      return false;
    }
  }

  @override
  Future<bool> hasAllPermissions() async {
    try {
      final result = await _channel.invokeMethod<bool>('hasAllMonitoringPermissions');
      return result ?? false;
    } on PlatformException {
      return false;
    }
  }

  @override
  Future<Map<String, bool>> requestAllPermissions() async {
    try {
      final result = await _channel.invokeMethod<Map<dynamic, dynamic>>('requestAllMonitoringPermissions');
      if (result == null) return {};
      return result.map((key, value) => MapEntry(key.toString(), value as bool));
    } on PlatformException {
      return {};
    }
  }
}
