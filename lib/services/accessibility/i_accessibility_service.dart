/// Interface for Accessibility Service
///
/// Provides methods to interact with the native Android Accessibility Service
/// for app blocking, power menu blocking, and password overlay display.
///
/// Requirements: 1.3, 2.2, 3.1, 11.2, 12.2, 12.3, 23.2, 27.3
abstract class IAccessibilityService {
  /// Check if the Accessibility Service is enabled in system settings
  Future<bool> isServiceEnabled();

  /// Open system Accessibility Settings to enable the service
  Future<void> openAccessibilitySettings();

  /// Check if Protected Mode is currently active
  Future<bool> isProtectedModeActive();

  /// Enable Protected Mode - activates all blocking features
  Future<void> enableProtectedMode();

  /// Disable Protected Mode - deactivates all blocking features
  Future<void> disableProtectedMode();

  /// Configure which features should be blocked
  ///
  /// [blockSettings] - Block access to Settings app
  /// [blockFileManagers] - Block access to file manager apps
  /// [blockPowerMenu] - Block access to power menu
  /// [blockQuickSettings] - Block access to Quick Settings panel
  Future<void> setBlockingOptions({
    bool blockSettings = true,
    bool blockFileManagers = true,
    bool blockPowerMenu = true,
    bool blockQuickSettings = true,
  });

  /// Get current blocking status
  Future<Map<String, bool>> getBlockingStatus();

  /// Show password overlay for a specific action
  ///
  /// [action] - The action that requires password verification
  Future<void> showPasswordOverlay(PendingAction action);

  /// Hide the password overlay
  Future<void> hidePasswordOverlay();

  /// Update the password hash and salt used for verification
  ///
  /// [hash] - SHA-256 hash of the password
  /// [salt] - Random salt used for hashing
  Future<void> updatePassword(String hash, String salt);

  /// Check if a specific package is blocked
  Future<bool> isPackageBlocked(String packageName);

  /// Show custom lock screen message overlay
  ///
  /// Displays a full-screen message with owner contact information
  /// when the device is remotely locked.
  ///
  /// [message] - Custom message to display
  /// [ownerContact] - Owner's contact information (phone number or email)
  /// [instructions] - Additional instructions for finder
  ///
  /// Requirement 8.2: Display custom full-screen message with owner contact information
  Future<void> showLockScreenMessage({
    String? message,
    String? ownerContact,
    String? instructions,
  });

  /// Hide the lock screen message overlay
  Future<void> hideLockScreenMessage();

  /// Check if lock screen message is currently showing
  Future<bool> isLockScreenMessageShowing();

  /// Stream of accessibility events from the native service
  Stream<AccessibilityEvent> get events;

  /// Dispose resources
  void dispose();
}

/// Enum for pending actions that require password verification
enum PendingAction {
  /// Disable Protected Mode
  disableProtectedMode,

  /// Access Settings app
  accessSettings,

  /// Access file manager app
  accessFileManager,

  /// Disable Device Administrator
  disableDeviceAdmin,

  /// Exit Kiosk Mode
  exitKioskMode,
}

/// Extension to convert PendingAction to native string
extension PendingActionExtension on PendingAction {
  String toNativeString() {
    switch (this) {
      case PendingAction.disableProtectedMode:
        return 'DISABLE_PROTECTED_MODE';
      case PendingAction.accessSettings:
        return 'ACCESS_SETTINGS';
      case PendingAction.accessFileManager:
        return 'ACCESS_FILE_MANAGER';
      case PendingAction.disableDeviceAdmin:
        return 'DISABLE_DEVICE_ADMIN';
      case PendingAction.exitKioskMode:
        return 'EXIT_KIOSK_MODE';
    }
  }
}

/// Accessibility event from the native service
class AccessibilityEvent {
  /// Event action type
  final String action;

  /// Timestamp of the event
  final DateTime timestamp;

  /// Additional event data
  final Map<String, dynamic> data;

  AccessibilityEvent({
    required this.action,
    required this.timestamp,
    this.data = const {},
  });

  factory AccessibilityEvent.fromMap(Map<dynamic, dynamic> map) {
    return AccessibilityEvent(
      action: map['action'] as String? ?? 'UNKNOWN',
      timestamp: DateTime.fromMillisecondsSinceEpoch(
        (map['timestamp'] as int?) ?? DateTime.now().millisecondsSinceEpoch,
      ),
      data: Map<String, dynamic>.from(
        map.map((key, value) => MapEntry(key.toString(), value)),
      ),
    );
  }

  @override
  String toString() {
    return 'AccessibilityEvent(action: $action, timestamp: $timestamp, data: $data)';
  }
}
