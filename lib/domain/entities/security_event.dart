/// Security event types for the anti-theft protection system.
/// 
/// These event types categorize all security-related activities
/// that are logged by the application.
enum SecurityEventType {
  /// Failed login attempt with incorrect password
  failedLogin,
  
  /// Successful login with correct password
  successfulLogin,
  
  /// Protected mode was enabled
  protectedModeEnabled,
  
  /// Protected mode was disabled
  protectedModeDisabled,
  
  /// Kiosk mode was enabled
  kioskModeEnabled,
  
  /// Kiosk mode was disabled
  kioskModeDisabled,
  
  /// Panic mode was activated
  panicModeActivated,
  
  /// Airplane mode was changed
  airplaneModeChanged,
  
  /// SIM card was changed or removed
  simCardChanged,
  
  /// Settings app was accessed
  settingsAccessed,
  
  /// Power menu was blocked
  powerMenuBlocked,
  
  /// App was force stopped
  appForceStop,
  
  /// Remote command was received via SMS
  remoteCommandReceived,
  
  /// Remote command was executed
  remoteCommandExecuted,
  
  /// Location was tracked
  locationTracked,
  
  /// Photo was captured
  photoCapture,
  
  /// Call was logged
  callLogged,
  
  /// Safe mode was detected on boot
  safeModeDetected,
  
  /// USB debugging was enabled
  usbDebuggingEnabled,
  
  /// File manager app was accessed
  fileManagerAccessed,
  
  /// Screen unlock failed
  screenUnlockFailed,
  
  /// Device admin deactivation attempted
  deviceAdminDeactivationAttempted,
  
  /// Account addition attempted
  accountAdditionAttempted,
  
  /// App installation attempted
  appInstallationAttempted,
  
  /// App uninstallation attempted
  appUninstallationAttempted,
  
  /// Screen lock change attempted
  screenLockChangeAttempted,
  
  /// Factory reset attempted
  factoryResetAttempted,
  
  /// USB connection detected
  usbConnectionDetected,
  
  /// Developer options accessed
  developerOptionsAccessed,
}


/// Represents a security event logged by the anti-theft protection system.
/// 
/// Each event contains metadata about the security-related activity,
/// including timestamp, location, and optional photo evidence.
class SecurityEvent {
  /// Unique identifier for the event
  final String id;
  
  /// Type of security event
  final SecurityEventType type;
  
  /// When the event occurred
  final DateTime timestamp;
  
  /// Human-readable description of the event
  final String description;
  
  /// Additional metadata about the event
  final Map<String, dynamic> metadata;
  
  /// Location where the event occurred (if available)
  final Map<String, dynamic>? location;
  
  /// Path to captured photo (if applicable)
  final String? photoPath;

  SecurityEvent({
    required this.id,
    required this.type,
    required this.timestamp,
    required this.description,
    required this.metadata,
    this.location,
    this.photoPath,
  });

  /// Creates a SecurityEvent from JSON map
  factory SecurityEvent.fromJson(Map<String, dynamic> json) {
    return SecurityEvent(
      id: json['id'] as String,
      type: SecurityEventType.values.firstWhere(
        (e) => e.name == json['type'],
        orElse: () => SecurityEventType.failedLogin,
      ),
      timestamp: DateTime.parse(json['timestamp'] as String),
      description: json['description'] as String,
      metadata: Map<String, dynamic>.from(json['metadata'] as Map),
      location: json['location'] != null
          ? Map<String, dynamic>.from(json['location'] as Map)
          : null,
      photoPath: json['photoPath'] as String?,
    );
  }

  /// Converts the SecurityEvent to a JSON map
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type.name,
      'timestamp': timestamp.toIso8601String(),
      'description': description,
      'metadata': metadata,
      'location': location,
      'photoPath': photoPath,
    };
  }

  /// Creates a copy of this event with optional field overrides
  SecurityEvent copyWith({
    String? id,
    SecurityEventType? type,
    DateTime? timestamp,
    String? description,
    Map<String, dynamic>? metadata,
    Map<String, dynamic>? location,
    String? photoPath,
  }) {
    return SecurityEvent(
      id: id ?? this.id,
      type: type ?? this.type,
      timestamp: timestamp ?? this.timestamp,
      description: description ?? this.description,
      metadata: metadata ?? this.metadata,
      location: location ?? this.location,
      photoPath: photoPath ?? this.photoPath,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is SecurityEvent &&
        other.id == id &&
        other.type == type &&
        other.timestamp == timestamp &&
        other.description == description;
  }

  @override
  int get hashCode {
    return id.hashCode ^
        type.hashCode ^
        timestamp.hashCode ^
        description.hashCode;
  }

  @override
  String toString() {
    return 'SecurityEvent(id: $id, type: $type, timestamp: $timestamp, description: $description)';
  }
}
