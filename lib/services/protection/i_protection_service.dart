import '../../domain/entities/protection_config.dart';

/// Interface for Protection Service
///
/// Provides comprehensive protection functionality including:
/// - Protected Mode management (Requirement 1.3, 1.4)
/// - Kiosk Mode using Task Locking (Requirement 3.1, 3.2)
/// - Panic Mode activation (Requirement 21.1, 21.2)
/// - Stealth Mode (Requirement 18.1, 18.3)
/// - Dialer code access (Requirement 18.4, 18.5)
///
/// Requirements: 1.3, 1.4, 3.1, 3.2, 9.3, 18.1, 18.3, 18.4, 18.5, 21.1, 21.2
abstract class IProtectionService {
  /// Initialize the protection service.
  ///
  /// Must be called before using any other methods.
  Future<void> initialize();

  /// Dispose of resources.
  Future<void> dispose();

  // ==================== Protected Mode ====================

  /// Enable Protected Mode.
  ///
  /// Activates all protection features including:
  /// - Device Administrator permissions
  /// - Accessibility Service
  /// - Location tracking
  /// - Event monitoring
  ///
  /// Requirement 1.3: Request and activate Device Administrator and Accessibility Service
  Future<bool> enableProtectedMode();

  /// Disable Protected Mode.
  ///
  /// Requires Master Password verification before deactivation.
  ///
  /// [password] - The Master Password for verification
  ///
  /// Requirement 1.4: Require Master Password for configuration changes
  Future<bool> disableProtectedMode(String password);

  /// Check if Protected Mode is currently active.
  Future<bool> isProtectedModeActive();

  // ==================== Kiosk Mode ====================

  /// Enable Kiosk Mode using Task Locking.
  ///
  /// Locks the device to show only the Anti-Theft App interface.
  /// Blocks access to home button, recent apps, and notification panel.
  ///
  /// Requirement 3.1: Lock device to show only Anti-Theft App
  /// Requirement 3.2: Block home button, recent apps, notification panel
  Future<bool> enableKioskMode();

  /// Disable Kiosk Mode.
  ///
  /// Requires Master Password verification.
  ///
  /// [password] - The Master Password for verification
  ///
  /// Requirement 3.4: Exit Kiosk Mode with correct password
  Future<bool> disableKioskMode(String password);

  /// Check if Kiosk Mode is currently active.
  Future<bool> isKioskModeActive();

  /// Show custom lock screen in Kiosk Mode.
  ///
  /// [message] - Optional custom message to display
  ///
  /// Requirement 3.5: Show custom lock screen requiring Master Password
  Future<void> showKioskLockScreen({String? message});

  // ==================== Panic Mode ====================

  /// Enable Panic Mode.
  ///
  /// Activates emergency protection including:
  /// - Kiosk Mode
  /// - Alarm trigger
  /// - Photo capture
  /// - SMS to Emergency Contact
  /// - High-frequency location tracking (30 seconds)
  ///
  /// Requirement 21.2: Enable Kiosk Mode, trigger alarm, capture photo, send SMS
  Future<void> enablePanicMode();

  /// Disable Panic Mode.
  ///
  /// Requires Master Password entered twice for confirmation.
  ///
  /// [password] - The Master Password (must be entered twice)
  ///
  /// Requirement 21.5: Require Master Password entered twice
  Future<bool> disablePanicMode(String password);

  /// Check if Panic Mode is currently active.
  Future<bool> isPanicModeActive();

  /// Register volume button listener for panic mode activation.
  ///
  /// Monitors for 5 quick volume down presses.
  ///
  /// Requirement 21.1: Activate panic mode on 5 quick volume down presses
  Future<void> registerVolumeButtonListener();

  /// Unregister volume button listener.
  Future<void> unregisterVolumeButtonListener();

  // ==================== Stealth Mode ====================

  /// Enable Stealth Mode.
  ///
  /// Hides the app from:
  /// - Recent apps list (Overview screen)
  /// - App launcher (optional, based on settings)
  ///
  /// Requirement 18.1: Exclude from recent apps list
  /// Requirement 18.3: Optionally hide icon from launcher
  Future<void> enableStealthMode();

  /// Disable Stealth Mode.
  Future<void> disableStealthMode();

  /// Check if Stealth Mode is currently active.
  Future<bool> isStealthModeActive();

  /// Set whether to hide the app icon from launcher.
  ///
  /// [hide] - True to hide icon, false to show
  ///
  /// Requirement 18.3: Optionally hide icon based on stealth mode setting
  Future<void> setHideAppIcon(bool hide);

  /// Check if app icon is hidden from launcher.
  Future<bool> isAppIconHidden();

  // ==================== Dialer Code Access ====================

  /// Register dialer code listener.
  ///
  /// Monitors for the secret dialer code (*#123456#) to open the app.
  ///
  /// Requirement 18.4: Only accessible via dialer code when stealth mode enabled
  Future<void> registerDialerCodeListener();

  /// Unregister dialer code listener.
  Future<void> unregisterDialerCodeListener();

  /// Set the dialer code for accessing the app.
  ///
  /// [code] - The dialer code (default: *#123456#)
  ///
  /// Requirement 18.4: Accessible via dialer code
  Future<void> setDialerCode(String code);

  /// Get the current dialer code.
  Future<String> getDialerCode();

  /// Handle dialer code entry.
  ///
  /// Called when the dialer code is detected.
  /// Opens the app and requests Master Password.
  ///
  /// Requirement 18.5: Open and request Master Password
  Future<void> handleDialerCodeEntry();

  // ==================== Configuration ====================

  /// Get the current protection configuration.
  Future<ProtectionConfig> getConfiguration();

  /// Update the protection configuration.
  ///
  /// Requires Master Password verification for any changes.
  ///
  /// [config] - The new configuration
  /// [password] - The Master Password for verification
  ///
  /// Requirement 1.4: Require Master Password for configuration changes
  /// Requirement 9.3: Require Master Password confirmation for setting changes
  Future<bool> updateConfiguration(ProtectionConfig config, String password);

  /// Save the current configuration to persistent storage.
  Future<void> saveConfiguration();

  /// Load configuration from persistent storage.
  Future<ProtectionConfig> loadConfiguration();

  // ==================== Events ====================

  /// Stream of protection events.
  Stream<ProtectionEvent> get events;
}

/// Protection event types
enum ProtectionEventType {
  /// Protected Mode was enabled
  protectedModeEnabled,

  /// Protected Mode was disabled
  protectedModeDisabled,

  /// Kiosk Mode was enabled
  kioskModeEnabled,

  /// Kiosk Mode was disabled
  kioskModeDisabled,

  /// Panic Mode was activated
  panicModeActivated,

  /// Panic Mode was deactivated
  panicModeDeactivated,

  /// Stealth Mode was enabled
  stealthModeEnabled,

  /// Stealth Mode was disabled
  stealthModeDisabled,

  /// Volume button sequence detected (panic trigger)
  volumeButtonSequenceDetected,

  /// Dialer code entered
  dialerCodeEntered,

  /// Configuration changed
  configurationChanged,

  /// Password verification required
  passwordRequired,

  /// Password verification failed
  passwordFailed,

  /// Password verification succeeded
  passwordSucceeded,
}

/// Represents a protection event
class ProtectionEvent {
  /// Event type
  final ProtectionEventType type;

  /// Timestamp of the event
  final DateTime timestamp;

  /// Additional event data
  final Map<String, dynamic>? metadata;

  ProtectionEvent({
    required this.type,
    required this.timestamp,
    this.metadata,
  });

  factory ProtectionEvent.fromMap(Map<String, dynamic> map) {
    return ProtectionEvent(
      type: ProtectionEventType.values.firstWhere(
        (e) => e.name == map['type'],
        orElse: () => ProtectionEventType.protectedModeEnabled,
      ),
      timestamp: DateTime.fromMillisecondsSinceEpoch(
        map['timestamp'] as int? ?? DateTime.now().millisecondsSinceEpoch,
      ),
      metadata: map['metadata'] as Map<String, dynamic>?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'type': type.name,
      'timestamp': timestamp.millisecondsSinceEpoch,
      'metadata': metadata,
    };
  }

  @override
  String toString() {
    return 'ProtectionEvent(type: $type, timestamp: $timestamp, metadata: $metadata)';
  }
}
