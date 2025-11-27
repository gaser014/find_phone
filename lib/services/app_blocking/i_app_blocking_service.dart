/// Interface for App Blocking Service
///
/// Provides methods to block access to specific apps and system features
/// when Protected Mode is active.
///
/// Requirements:
/// - 12.1, 27.1: Block Settings app completely
/// - 23.1, 23.2: Block file manager apps with password overlay
/// - 23.3, 23.4: 1-minute file manager access timeout
/// - 30.1, 30.2: Block screen lock changes
/// - 31.1, 31.2: Block account addition
/// - 32.1, 32.2, 32.3: Block app installation/uninstallation
/// - 33.1: Block factory reset from Settings
abstract class IAppBlockingService {
  /// Initialize the app blocking service
  Future<void> initialize();

  /// Dispose of resources
  Future<void> dispose();

  // ==================== Settings Blocking ====================

  /// Enable complete Settings app blocking
  ///
  /// Requirement 12.1, 27.1: Block all access to Settings app
  Future<void> enableSettingsBlocking();

  /// Disable Settings app blocking
  Future<void> disableSettingsBlocking();

  /// Check if Settings blocking is enabled
  Future<bool> isSettingsBlockingEnabled();

  // ==================== File Manager Blocking ====================

  /// Enable file manager app blocking with password overlay
  ///
  /// Requirement 23.1, 23.2: Block file manager apps with password overlay
  Future<void> enableFileManagerBlocking();

  /// Disable file manager app blocking
  Future<void> disableFileManagerBlocking();

  /// Check if file manager blocking is enabled
  Future<bool> isFileManagerBlockingEnabled();

  /// Grant temporary file manager access after password verification
  ///
  /// Requirement 23.3: Allow file manager access for 1 minute
  Future<void> grantTemporaryFileManagerAccess();

  /// Revoke file manager access
  ///
  /// Requirement 23.4: Automatically close file manager after timeout
  Future<void> revokeFileManagerAccess();

  /// Check if temporary file manager access is active
  Future<bool> hasTemporaryFileManagerAccess();

  /// Get remaining time for file manager access in seconds
  Future<int> getFileManagerAccessRemainingSeconds();

  // ==================== Screen Lock Change Blocking ====================

  /// Enable screen lock change blocking
  ///
  /// Requirement 30.1, 30.2: Block attempts to change screen lock
  Future<void> enableScreenLockChangeBlocking();

  /// Disable screen lock change blocking
  Future<void> disableScreenLockChangeBlocking();

  /// Check if screen lock change blocking is enabled
  Future<bool> isScreenLockChangeBlockingEnabled();

  // ==================== Account Addition Blocking ====================

  /// Enable account addition blocking
  ///
  /// Requirement 31.1, 31.2: Block attempts to add new accounts
  Future<void> enableAccountAdditionBlocking();

  /// Disable account addition blocking
  Future<void> disableAccountAdditionBlocking();

  /// Check if account addition blocking is enabled
  Future<bool> isAccountAdditionBlockingEnabled();

  // ==================== App Installation Blocking ====================

  /// Enable app installation/uninstallation blocking
  ///
  /// Requirement 32.1, 32.2, 32.3: Block app installation and uninstallation
  Future<void> enableAppInstallationBlocking();

  /// Disable app installation/uninstallation blocking
  Future<void> disableAppInstallationBlocking();

  /// Check if app installation blocking is enabled
  Future<bool> isAppInstallationBlockingEnabled();

  // ==================== Factory Reset Blocking ====================

  /// Enable factory reset blocking from Settings
  ///
  /// Requirement 33.1: Block factory reset attempts from Settings
  Future<void> enableFactoryResetBlocking();

  /// Disable factory reset blocking
  Future<void> disableFactoryResetBlocking();

  /// Check if factory reset blocking is enabled
  Future<bool> isFactoryResetBlockingEnabled();

  // ==================== USB Data Transfer Blocking ====================

  /// Enable USB data transfer blocking for untrusted computers
  ///
  /// Requirement 28.3: Block USB data transfer for untrusted computers
  Future<void> enableUsbDataTransferBlocking();

  /// Disable USB data transfer blocking
  Future<void> disableUsbDataTransferBlocking();

  /// Check if USB data transfer blocking is enabled
  Future<bool> isUsbDataTransferBlockingEnabled();

  // ==================== Blocking Status ====================

  /// Get comprehensive blocking status
  Future<AppBlockingStatus> getBlockingStatus();

  /// Enable all blocking features
  Future<void> enableAllBlocking();

  /// Disable all blocking features
  Future<void> disableAllBlocking();

  // ==================== Events ====================

  /// Stream of app blocking events
  Stream<AppBlockingEvent> get events;
}

/// Represents the current status of all blocking features
class AppBlockingStatus {
  final bool settingsBlocking;
  final bool fileManagerBlocking;
  final bool screenLockChangeBlocking;
  final bool accountAdditionBlocking;
  final bool appInstallationBlocking;
  final bool factoryResetBlocking;
  final bool usbDataTransferBlocking;
  final bool hasTemporaryFileManagerAccess;
  final int fileManagerAccessRemainingSeconds;

  const AppBlockingStatus({
    this.settingsBlocking = false,
    this.fileManagerBlocking = false,
    this.screenLockChangeBlocking = false,
    this.accountAdditionBlocking = false,
    this.appInstallationBlocking = false,
    this.factoryResetBlocking = false,
    this.usbDataTransferBlocking = false,
    this.hasTemporaryFileManagerAccess = false,
    this.fileManagerAccessRemainingSeconds = 0,
  });

  AppBlockingStatus copyWith({
    bool? settingsBlocking,
    bool? fileManagerBlocking,
    bool? screenLockChangeBlocking,
    bool? accountAdditionBlocking,
    bool? appInstallationBlocking,
    bool? factoryResetBlocking,
    bool? usbDataTransferBlocking,
    bool? hasTemporaryFileManagerAccess,
    int? fileManagerAccessRemainingSeconds,
  }) {
    return AppBlockingStatus(
      settingsBlocking: settingsBlocking ?? this.settingsBlocking,
      fileManagerBlocking: fileManagerBlocking ?? this.fileManagerBlocking,
      screenLockChangeBlocking:
          screenLockChangeBlocking ?? this.screenLockChangeBlocking,
      accountAdditionBlocking:
          accountAdditionBlocking ?? this.accountAdditionBlocking,
      appInstallationBlocking:
          appInstallationBlocking ?? this.appInstallationBlocking,
      factoryResetBlocking: factoryResetBlocking ?? this.factoryResetBlocking,
      usbDataTransferBlocking:
          usbDataTransferBlocking ?? this.usbDataTransferBlocking,
      hasTemporaryFileManagerAccess:
          hasTemporaryFileManagerAccess ?? this.hasTemporaryFileManagerAccess,
      fileManagerAccessRemainingSeconds: fileManagerAccessRemainingSeconds ??
          this.fileManagerAccessRemainingSeconds,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'settingsBlocking': settingsBlocking,
      'fileManagerBlocking': fileManagerBlocking,
      'screenLockChangeBlocking': screenLockChangeBlocking,
      'accountAdditionBlocking': accountAdditionBlocking,
      'appInstallationBlocking': appInstallationBlocking,
      'factoryResetBlocking': factoryResetBlocking,
      'usbDataTransferBlocking': usbDataTransferBlocking,
      'hasTemporaryFileManagerAccess': hasTemporaryFileManagerAccess,
      'fileManagerAccessRemainingSeconds': fileManagerAccessRemainingSeconds,
    };
  }

  factory AppBlockingStatus.fromJson(Map<String, dynamic> json) {
    return AppBlockingStatus(
      settingsBlocking: json['settingsBlocking'] as bool? ?? false,
      fileManagerBlocking: json['fileManagerBlocking'] as bool? ?? false,
      screenLockChangeBlocking:
          json['screenLockChangeBlocking'] as bool? ?? false,
      accountAdditionBlocking:
          json['accountAdditionBlocking'] as bool? ?? false,
      appInstallationBlocking:
          json['appInstallationBlocking'] as bool? ?? false,
      factoryResetBlocking: json['factoryResetBlocking'] as bool? ?? false,
      usbDataTransferBlocking:
          json['usbDataTransferBlocking'] as bool? ?? false,
      hasTemporaryFileManagerAccess:
          json['hasTemporaryFileManagerAccess'] as bool? ?? false,
      fileManagerAccessRemainingSeconds:
          json['fileManagerAccessRemainingSeconds'] as int? ?? 0,
    );
  }
}

/// Types of app blocking events
enum AppBlockingEventType {
  /// Settings access was blocked
  settingsBlocked,

  /// File manager access was blocked
  fileManagerBlocked,

  /// File manager access was granted temporarily
  fileManagerAccessGranted,

  /// File manager access was revoked
  fileManagerAccessRevoked,

  /// Screen lock change was blocked
  screenLockChangeBlocked,

  /// Account addition was blocked
  accountAdditionBlocked,

  /// App installation was blocked
  appInstallationBlocked,

  /// App uninstallation was blocked
  appUninstallationBlocked,

  /// Factory reset was blocked
  factoryResetBlocked,

  /// USB data transfer was blocked
  usbDataTransferBlocked,
}

/// Represents an app blocking event
class AppBlockingEvent {
  final AppBlockingEventType type;
  final DateTime timestamp;
  final String? packageName;
  final String? appName;
  final Map<String, dynamic>? metadata;

  AppBlockingEvent({
    required this.type,
    required this.timestamp,
    this.packageName,
    this.appName,
    this.metadata,
  });

  factory AppBlockingEvent.fromMap(Map<String, dynamic> map) {
    return AppBlockingEvent(
      type: AppBlockingEventType.values.firstWhere(
        (e) => e.name == map['type'],
        orElse: () => AppBlockingEventType.settingsBlocked,
      ),
      timestamp: DateTime.fromMillisecondsSinceEpoch(
        map['timestamp'] as int? ?? DateTime.now().millisecondsSinceEpoch,
      ),
      packageName: map['packageName'] as String?,
      appName: map['appName'] as String?,
      metadata: map['metadata'] as Map<String, dynamic>?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'type': type.name,
      'timestamp': timestamp.millisecondsSinceEpoch,
      'packageName': packageName,
      'appName': appName,
      'metadata': metadata,
    };
  }

  @override
  String toString() {
    return 'AppBlockingEvent(type: $type, timestamp: $timestamp, '
        'packageName: $packageName, appName: $appName)';
  }
}
