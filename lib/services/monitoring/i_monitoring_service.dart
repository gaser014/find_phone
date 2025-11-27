import '../../domain/entities/call_log_entry.dart';
import '../../domain/entities/sim_info.dart';

/// Event types for monitoring service events.
enum MonitoringEventType {
  /// Airplane mode was toggled
  airplaneModeChanged,

  /// SIM card was changed or removed
  simCardChanged,

  /// Screen unlock attempt failed
  screenUnlockFailed,

  /// Call event (incoming/outgoing/missed)
  callEvent,

  /// USB debugging status changed
  usbDebuggingChanged,

  /// Developer options accessed
  developerOptionsAccessed,

  /// Power button pressed
  powerButtonPressed,

  /// App launched
  appLaunched,
}

/// Represents an airplane mode change event.
class AirplaneModeEvent {
  /// Whether airplane mode is now enabled
  final bool isEnabled;

  /// When the change was detected
  final DateTime timestamp;

  /// Whether this was an authorized change
  final bool isAuthorized;

  AirplaneModeEvent({
    required this.isEnabled,
    required this.timestamp,
    this.isAuthorized = false,
  });

  Map<String, dynamic> toJson() => {
        'isEnabled': isEnabled,
        'timestamp': timestamp.toIso8601String(),
        'isAuthorized': isAuthorized,
      };

  factory AirplaneModeEvent.fromJson(Map<String, dynamic> json) {
    return AirplaneModeEvent(
      isEnabled: json['isEnabled'] as bool,
      timestamp: DateTime.parse(json['timestamp'] as String),
      isAuthorized: json['isAuthorized'] as bool? ?? false,
    );
  }
}


/// Represents a SIM card change event.
class SimChangeEvent {
  /// The previous SIM information
  final SimInfo? previousSim;

  /// The new SIM information
  final SimInfo? newSim;

  /// When the change was detected
  final DateTime timestamp;

  /// Whether the SIM was removed (no new SIM)
  bool get isRemoved => newSim == null || newSim!.isAbsent;

  /// Whether a new SIM was inserted
  bool get isInserted => previousSim == null || previousSim!.isAbsent;

  SimChangeEvent({
    this.previousSim,
    this.newSim,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() => {
        'previousSim': previousSim?.toJson(),
        'newSim': newSim?.toJson(),
        'timestamp': timestamp.toIso8601String(),
      };

  factory SimChangeEvent.fromJson(Map<String, dynamic> json) {
    return SimChangeEvent(
      previousSim: json['previousSim'] != null
          ? SimInfo.fromJson(json['previousSim'] as Map<String, dynamic>)
          : null,
      newSim: json['newSim'] != null
          ? SimInfo.fromJson(json['newSim'] as Map<String, dynamic>)
          : null,
      timestamp: DateTime.parse(json['timestamp'] as String),
    );
  }
}

/// Represents a screen unlock attempt event.
class UnlockAttemptEvent {
  /// Whether the unlock was successful
  final bool isSuccessful;

  /// When the attempt occurred
  final DateTime timestamp;

  /// Number of consecutive failed attempts
  final int consecutiveFailures;

  UnlockAttemptEvent({
    required this.isSuccessful,
    required this.timestamp,
    this.consecutiveFailures = 0,
  });

  Map<String, dynamic> toJson() => {
        'isSuccessful': isSuccessful,
        'timestamp': timestamp.toIso8601String(),
        'consecutiveFailures': consecutiveFailures,
      };

  factory UnlockAttemptEvent.fromJson(Map<String, dynamic> json) {
    return UnlockAttemptEvent(
      isSuccessful: json['isSuccessful'] as bool,
      timestamp: DateTime.parse(json['timestamp'] as String),
      consecutiveFailures: json['consecutiveFailures'] as int? ?? 0,
    );
  }
}

/// Represents a call event.
class CallEvent {
  /// The phone number involved
  final String phoneNumber;

  /// Type of call
  final CallType type;

  /// When the call started
  final DateTime timestamp;

  /// Duration of the call
  final Duration duration;

  /// Whether this is the emergency contact
  final bool isEmergencyContact;

  CallEvent({
    required this.phoneNumber,
    required this.type,
    required this.timestamp,
    this.duration = Duration.zero,
    this.isEmergencyContact = false,
  });

  Map<String, dynamic> toJson() => {
        'phoneNumber': phoneNumber,
        'type': type.name,
        'timestamp': timestamp.toIso8601String(),
        'durationSeconds': duration.inSeconds,
        'isEmergencyContact': isEmergencyContact,
      };

  factory CallEvent.fromJson(Map<String, dynamic> json) {
    return CallEvent(
      phoneNumber: json['phoneNumber'] as String,
      type: CallType.values.firstWhere(
        (e) => e.name == json['type'],
        orElse: () => CallType.incoming,
      ),
      timestamp: DateTime.parse(json['timestamp'] as String),
      duration: Duration(seconds: json['durationSeconds'] as int? ?? 0),
      isEmergencyContact: json['isEmergencyContact'] as bool? ?? false,
    );
  }
}

/// Represents a USB debugging status change event.
class UsbDebuggingEvent {
  /// Whether USB debugging is now enabled
  final bool isEnabled;

  /// When the change was detected
  final DateTime timestamp;

  UsbDebuggingEvent({
    required this.isEnabled,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() => {
        'isEnabled': isEnabled,
        'timestamp': timestamp.toIso8601String(),
      };

  factory UsbDebuggingEvent.fromJson(Map<String, dynamic> json) {
    return UsbDebuggingEvent(
      isEnabled: json['isEnabled'] as bool,
      timestamp: DateTime.parse(json['timestamp'] as String),
    );
  }
}

/// Represents a power button event.
class PowerButtonEvent {
  /// Whether this is a long press
  final bool isLongPress;

  /// When the event occurred
  final DateTime timestamp;

  PowerButtonEvent({
    required this.isLongPress,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() => {
        'isLongPress': isLongPress,
        'timestamp': timestamp.toIso8601String(),
      };

  factory PowerButtonEvent.fromJson(Map<String, dynamic> json) {
    return PowerButtonEvent(
      isLongPress: json['isLongPress'] as bool,
      timestamp: DateTime.parse(json['timestamp'] as String),
    );
  }
}

/// Represents an app launch event.
class AppLaunchEvent {
  /// Package name of the launched app
  final String packageName;

  /// Display name of the app
  final String? appName;

  /// When the launch was detected
  final DateTime timestamp;

  /// Whether this app is blocked
  final bool isBlocked;

  AppLaunchEvent({
    required this.packageName,
    this.appName,
    required this.timestamp,
    this.isBlocked = false,
  });

  Map<String, dynamic> toJson() => {
        'packageName': packageName,
        'appName': appName,
        'timestamp': timestamp.toIso8601String(),
        'isBlocked': isBlocked,
      };

  factory AppLaunchEvent.fromJson(Map<String, dynamic> json) {
    return AppLaunchEvent(
      packageName: json['packageName'] as String,
      appName: json['appName'] as String?,
      timestamp: DateTime.parse(json['timestamp'] as String),
      isBlocked: json['isBlocked'] as bool? ?? false,
    );
  }
}

/// Boot mode detection result.
enum BootMode {
  /// Normal boot
  normal,

  /// Safe mode boot
  safeMode,

  /// Recovery mode (detected after reboot)
  recovery,

  /// Unknown boot mode
  unknown,
}


/// Interface for Monitoring Service
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
abstract class IMonitoringService {
  /// Initialize the monitoring service.
  ///
  /// Must be called before using any other methods.
  Future<void> initialize();

  /// Dispose of resources.
  Future<void> dispose();

  // ==================== General Monitoring ====================

  /// Start monitoring all events.
  ///
  /// Begins monitoring for all configured event types.
  Future<void> startMonitoring();

  /// Stop all monitoring.
  Future<void> stopMonitoring();

  /// Check if monitoring is currently active.
  bool get isMonitoring;

  // ==================== Airplane Mode Monitoring ====================

  /// Stream of airplane mode change events.
  ///
  /// Emits events whenever airplane mode is toggled.
  ///
  /// Requirement 6.1: Monitor Airplane Mode status changes continuously
  Stream<AirplaneModeEvent> get airplaneModeEvents;

  /// Get current airplane mode status.
  ///
  /// Returns true if airplane mode is enabled.
  Future<bool> isAirplaneModeEnabled();

  /// Attempt to disable airplane mode.
  ///
  /// Tries to automatically disable airplane mode when detected.
  /// Returns true if successful, false otherwise.
  ///
  /// Requirement 6.2: Attempt to disable automatically within 2 seconds
  Future<bool> disableAirplaneMode();

  /// Start monitoring airplane mode changes.
  Future<void> startAirplaneModeMonitoring();

  /// Stop monitoring airplane mode changes.
  Future<void> stopAirplaneModeMonitoring();

  // ==================== SIM Card Monitoring ====================

  /// Stream of SIM card change events.
  ///
  /// Emits events when SIM card is removed or changed.
  ///
  /// Requirement 13.2: Detect SIM card change within 5 seconds
  Stream<SimChangeEvent> get simChangeEvents;

  /// Get current SIM card information.
  ///
  /// Returns null if no SIM card is present.
  Future<SimInfo?> getCurrentSimInfo();

  /// Get the stored (original) SIM card information.
  ///
  /// Returns the SIM info that was stored when protection was enabled.
  Future<SimInfo?> getStoredSimInfo();

  /// Store the current SIM card as the authorized SIM.
  ///
  /// Called when Protected Mode is enabled to record the original SIM.
  Future<void> storeCurrentSimInfo();

  /// Start monitoring SIM card changes.
  Future<void> startSimMonitoring();

  /// Stop monitoring SIM card changes.
  Future<void> stopSimMonitoring();

  // ==================== Screen Unlock Monitoring ====================

  /// Stream of screen unlock attempt events.
  ///
  /// Emits events for both successful and failed unlock attempts.
  ///
  /// Requirement 17.1: Detect failed screen unlock attempts
  Stream<UnlockAttemptEvent> get unlockAttemptEvents;

  /// Get the count of consecutive failed unlock attempts.
  Future<int> getConsecutiveFailedUnlocks();

  /// Reset the consecutive failed unlock counter.
  Future<void> resetFailedUnlockCounter();

  /// Start monitoring screen unlock attempts.
  Future<void> startUnlockMonitoring();

  /// Stop monitoring screen unlock attempts.
  Future<void> stopUnlockMonitoring();

  // ==================== Call Monitoring ====================

  /// Stream of call events.
  ///
  /// Emits events for incoming, outgoing, and missed calls.
  ///
  /// Requirement 19.1: Monitor all incoming and outgoing calls
  Stream<CallEvent> get callEvents;

  /// Get call log entries recorded during Protected Mode.
  ///
  /// [since] - Optional start date to filter entries
  ///
  /// Requirement 19.2: Log phone number, duration, timestamp, call type
  Future<List<CallLogEntry>> getCallLog({DateTime? since});

  /// Start monitoring calls.
  Future<void> startCallMonitoring();

  /// Stop monitoring calls.
  Future<void> stopCallMonitoring();

  // ==================== USB Debugging Monitoring ====================

  /// Stream of USB debugging status change events.
  ///
  /// Emits events when USB debugging is enabled or disabled.
  ///
  /// Requirement 22.4: Send alert when USB debugging is enabled
  Stream<UsbDebuggingEvent> get usbDebuggingEvents;

  /// Check if USB debugging is currently enabled.
  Future<bool> isUsbDebuggingEnabled();

  /// Start monitoring USB debugging status.
  Future<void> startUsbDebuggingMonitoring();

  /// Stop monitoring USB debugging status.
  Future<void> stopUsbDebuggingMonitoring();

  // ==================== Developer Options Monitoring ====================

  /// Check if developer options are enabled.
  Future<bool> isDeveloperOptionsEnabled();

  /// Detect if developer options were accessed.
  ///
  /// Requirement 22.5: Log developer options access
  Future<void> checkDeveloperOptionsAccess();

  /// Start monitoring developer options access.
  Future<void> startDeveloperOptionsMonitoring();

  /// Stop monitoring developer options access.
  Future<void> stopDeveloperOptionsMonitoring();

  // ==================== Power Button Monitoring ====================

  /// Stream of power button events.
  ///
  /// Emits events when power button is pressed.
  Stream<PowerButtonEvent> get powerButtonEvents;

  /// Start monitoring power button events.
  Future<void> startPowerButtonMonitoring();

  /// Stop monitoring power button events.
  Future<void> stopPowerButtonMonitoring();

  // ==================== App Launch Monitoring ====================

  /// Stream of app launch events.
  ///
  /// Emits events when apps are launched.
  Stream<AppLaunchEvent> get appLaunchEvents;

  /// Start monitoring app launches.
  Future<void> startAppLaunchMonitoring();

  /// Stop monitoring app launches.
  Future<void> stopAppLaunchMonitoring();

  // ==================== Boot Mode Detection ====================

  /// Detect the current boot mode.
  ///
  /// Returns the detected boot mode (normal, safe mode, etc.)
  ///
  /// Requirement 20.1: Detect Safe Mode boot
  Future<BootMode> detectBootMode();

  /// Check if device booted in safe mode.
  Future<bool> isInSafeMode();

  // ==================== Permissions ====================

  /// Check if phone state permission is granted.
  Future<bool> hasPhoneStatePermission();

  /// Request phone state permission.
  Future<bool> requestPhoneStatePermission();

  /// Check if all required monitoring permissions are granted.
  Future<bool> hasAllPermissions();

  /// Request all required monitoring permissions.
  Future<Map<String, bool>> requestAllPermissions();
}
