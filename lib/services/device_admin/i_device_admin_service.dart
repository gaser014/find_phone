/// Interface for Device Admin Service
/// 
/// Provides device administration functionality including:
/// - Device locking (Requirement 8.1)
/// - Factory reset/wipe (Requirement 8.3)
/// - 30-second deactivation window management (Requirement 2.3)
/// - Device admin status checking
/// 
/// Requirements: 1.3, 2.1, 2.2, 2.3, 8.1, 8.3
abstract class IDeviceAdminService {
  /// Check if Device Administrator is active
  Future<bool> isAdminActive();

  /// Request Device Administrator activation
  /// Opens system dialog for user to grant admin permissions
  Future<bool> requestAdminActivation();

  /// Lock the device immediately
  /// Requirement 8.1: LOCK command functionality
  Future<bool> lockDevice();

  /// Lock the device with a custom message displayed on lock screen
  /// Requirement 8.2: Display custom message with owner contact info
  Future<bool> lockDeviceWithMessage(String message);

  /// Wipe all device data (factory reset)
  /// Requirement 8.3: WIPE command functionality
  /// WARNING: This will erase ALL user data on the device!
  Future<bool> wipeDevice({String reason = 'Remote wipe command'});

  /// Set password quality requirements
  Future<bool> setPasswordQuality(int quality);

  /// Set minimum password length
  Future<bool> setMinimumPasswordLength(int length);

  /// Disable or enable the camera system-wide
  Future<bool> setCameraDisabled(bool disable);

  /// Get the number of failed password attempts since last successful unlock
  Future<int> getFailedPasswordAttempts();

  /// Set maximum failed password attempts before device wipe
  Future<bool> setMaximumFailedPasswordsForWipe(int maxAttempts);

  /// Set maximum time to lock after screen off
  Future<bool> setMaximumTimeToLock(int timeMs);

  /// Allow deactivation for 30 seconds
  /// Called after successful password verification
  /// Requirement 2.3
  Future<bool> allowDeactivation();

  /// Revoke deactivation permission
  /// Called when deactivation window expires or is cancelled
  Future<bool> revokeDeactivation();

  /// Check if deactivation is currently allowed
  Future<bool> isDeactivationAllowed();

  /// Get remaining time in deactivation window (milliseconds)
  Future<int> getDeactivationWindowRemaining();

  /// Set protected mode state
  /// This affects how deactivation requests are handled
  Future<bool> setProtectedModeActive(bool active);

  /// Check if protected mode is active
  Future<bool> isProtectedModeActive();

  /// Get device admin status information
  Future<Map<String, dynamic>> getAdminStatus();

  /// Open device admin settings
  Future<bool> openDeviceAdminSettings();

  /// Stream of device admin events
  Stream<DeviceAdminEvent> get events;
}

/// Device Admin Event types
enum DeviceAdminEventType {
  adminEnabled,
  adminDisabled,
  adminDisableRequested,
  deviceLocked,
  deviceLockedWithMessage,
  deviceWipeInitiated,
  deactivationWindowOpened,
  deactivationWindowClosed,
  passwordFailed,
  passwordSucceeded,
  passwordChanged,
  suspiciousActivity,
  unknown,
}

/// Device Admin Event
class DeviceAdminEvent {
  final DeviceAdminEventType type;
  final DateTime timestamp;
  final Map<String, dynamic>? metadata;

  DeviceAdminEvent({
    required this.type,
    required this.timestamp,
    this.metadata,
  });

  factory DeviceAdminEvent.fromMap(Map<String, dynamic> map) {
    final action = map['action'] as String?;
    final timestamp = map['timestamp'] as int? ?? DateTime.now().millisecondsSinceEpoch;
    
    DeviceAdminEventType type;
    switch (action) {
      case 'DEVICE_ADMIN_ENABLED':
        type = DeviceAdminEventType.adminEnabled;
        break;
      case 'DEVICE_ADMIN_DISABLED':
        type = DeviceAdminEventType.adminDisabled;
        break;
      case 'DEVICE_ADMIN_DISABLE_REQUESTED':
        type = DeviceAdminEventType.adminDisableRequested;
        break;
      case 'DEVICE_LOCKED':
        type = DeviceAdminEventType.deviceLocked;
        break;
      case 'DEVICE_LOCKED_WITH_MESSAGE':
        type = DeviceAdminEventType.deviceLockedWithMessage;
        break;
      case 'DEVICE_WIPE_INITIATED':
        type = DeviceAdminEventType.deviceWipeInitiated;
        break;
      case 'DEACTIVATION_WINDOW_OPENED':
        type = DeviceAdminEventType.deactivationWindowOpened;
        break;
      case 'DEACTIVATION_WINDOW_CLOSED':
        type = DeviceAdminEventType.deactivationWindowClosed;
        break;
      case 'PASSWORD_FAILED':
        type = DeviceAdminEventType.passwordFailed;
        break;
      case 'PASSWORD_SUCCEEDED':
        type = DeviceAdminEventType.passwordSucceeded;
        break;
      case 'PASSWORD_CHANGED':
        type = DeviceAdminEventType.passwordChanged;
        break;
      case 'SUSPICIOUS_ACTIVITY':
        type = DeviceAdminEventType.suspiciousActivity;
        break;
      default:
        type = DeviceAdminEventType.unknown;
    }

    // Remove action and timestamp from metadata
    final metadata = Map<String, dynamic>.from(map);
    metadata.remove('action');
    metadata.remove('timestamp');

    return DeviceAdminEvent(
      type: type,
      timestamp: DateTime.fromMillisecondsSinceEpoch(timestamp),
      metadata: metadata.isNotEmpty ? metadata : null,
    );
  }

  @override
  String toString() {
    return 'DeviceAdminEvent(type: $type, timestamp: $timestamp, metadata: $metadata)';
  }
}
