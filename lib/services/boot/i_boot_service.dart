/// Interface for Boot and Auto-Restart Service
///
/// This interface defines the contract for managing boot events and
/// auto-restart functionality for the Anti-Theft Protection app.
///
/// Requirements: 2.4, 2.5, 2.6, 20.1
abstract class IBootService {
  /// Check if the app was started after a device boot
  Future<bool> wasStartedAfterBoot();

  /// Check if Protected Mode should be restored after boot
  /// Requirement 2.5: Restore Protected Mode state from encrypted storage
  Future<bool> shouldRestoreProtectedMode();

  /// Restore Protected Mode state after boot
  /// Requirement 2.5: Start automatically via BOOT_COMPLETED receiver
  Future<void> restoreProtectedModeState();

  /// Check if the device booted in Safe Mode
  /// Requirement 20.1: Detect Safe Mode boot
  Future<bool> isInSafeMode();

  /// Handle Safe Mode boot detection
  /// Requirement 20.1: Trigger alarm immediately upon Safe Mode boot
  Future<void> handleSafeModeBoot();

  /// Schedule auto-restart job for persistence
  /// Requirement 2.4: Auto-restart using JobScheduler
  Future<void> scheduleAutoRestartJob();

  /// Cancel auto-restart job
  Future<void> cancelAutoRestartJob();

  /// Check if auto-restart job is scheduled
  Future<bool> isAutoRestartJobScheduled();

  /// Handle force-stop detection
  /// Requirement 2.6: Log force-stop as suspicious activity
  Future<void> handleForceStopDetected();

  /// Get the last boot time
  Future<DateTime?> getLastBootTime();

  /// Get the boot count since app installation
  Future<int> getBootCount();

  /// Get the restart count (after force-stops)
  Future<int> getRestartCount();

  /// Get the last restart time
  Future<DateTime?> getLastRestartTime();

  /// Start the protection foreground service
  Future<void> startProtectionService();

  /// Stop the protection foreground service
  Future<void> stopProtectionService();

  /// Check if protection service is running
  Future<bool> isProtectionServiceRunning();

  /// Stream of boot events
  Stream<BootEvent> get bootEvents;

  /// Stream of auto-restart events
  Stream<AutoRestartEvent> get autoRestartEvents;
}

/// Represents a boot event
class BootEvent {
  final BootEventType type;
  final DateTime timestamp;
  final bool protectedModeRestored;
  final bool isSafeMode;
  final Map<String, dynamic>? metadata;

  BootEvent({
    required this.type,
    required this.timestamp,
    this.protectedModeRestored = false,
    this.isSafeMode = false,
    this.metadata,
  });

  factory BootEvent.fromMap(Map<String, dynamic> map) {
    return BootEvent(
      type: BootEventType.values.firstWhere(
        (e) => e.name == map['type'],
        orElse: () => BootEventType.bootCompleted,
      ),
      timestamp: DateTime.fromMillisecondsSinceEpoch(
        map['timestamp'] as int? ?? DateTime.now().millisecondsSinceEpoch,
      ),
      protectedModeRestored: map['protected_mode_restored'] as bool? ?? false,
      isSafeMode: map['safe_mode'] as bool? ?? false,
      metadata: map['metadata'] as Map<String, dynamic>?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'type': type.name,
      'timestamp': timestamp.millisecondsSinceEpoch,
      'protected_mode_restored': protectedModeRestored,
      'safe_mode': isSafeMode,
      'metadata': metadata,
    };
  }
}

/// Types of boot events
enum BootEventType {
  bootCompleted,
  quickBootPowerOn,
  reboot,
  safeModeDetected,
}

/// Represents an auto-restart event
class AutoRestartEvent {
  final AutoRestartEventType type;
  final DateTime timestamp;
  final int restartCount;
  final bool triggerAlarm;
  final Map<String, dynamic>? metadata;

  AutoRestartEvent({
    required this.type,
    required this.timestamp,
    this.restartCount = 0,
    this.triggerAlarm = false,
    this.metadata,
  });

  factory AutoRestartEvent.fromMap(Map<String, dynamic> map) {
    return AutoRestartEvent(
      type: AutoRestartEventType.values.firstWhere(
        (e) => e.name == map['type'],
        orElse: () => AutoRestartEventType.serviceRestarted,
      ),
      timestamp: DateTime.fromMillisecondsSinceEpoch(
        map['timestamp'] as int? ?? DateTime.now().millisecondsSinceEpoch,
      ),
      restartCount: map['restart_count'] as int? ?? 0,
      triggerAlarm: map['trigger_alarm'] as bool? ?? false,
      metadata: map['metadata'] as Map<String, dynamic>?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'type': type.name,
      'timestamp': timestamp.millisecondsSinceEpoch,
      'restart_count': restartCount,
      'trigger_alarm': triggerAlarm,
      'metadata': metadata,
    };
  }
}

/// Types of auto-restart events
enum AutoRestartEventType {
  serviceRestarted,
  forceStopDetected,
  healthCheckPassed,
  healthCheckFailed,
  accessibilityServiceStopped,
}
