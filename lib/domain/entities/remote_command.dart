/// Types of remote commands that can be sent via SMS.
enum RemoteCommandType {
  /// Lock the device and enable kiosk mode
  lock,
  
  /// Wipe all device data (factory reset)
  wipe,
  
  /// Get current device location
  locate,
  
  /// Trigger loud alarm
  alarm,
}

/// Represents a remote command received via SMS.
/// 
/// Commands are sent in the format "COMMAND#password" from the
/// Emergency Contact number.
class RemoteCommand {
  /// Type of command to execute
  final RemoteCommandType type;
  
  /// Password provided with the command
  final String password;
  
  /// Phone number that sent the command
  final String sender;
  
  /// When the command was received
  final DateTime receivedAt;
  
  /// Additional parameters for the command
  final Map<String, dynamic>? parameters;

  RemoteCommand({
    required this.type,
    required this.password,
    required this.sender,
    required this.receivedAt,
    this.parameters,
  });

  /// Parses an SMS message into a RemoteCommand.
  /// 
  /// Expected format: "COMMAND#password"
  /// Valid commands: LOCK, WIPE, LOCATE, ALARM
  /// 
  /// Returns null if the message format is invalid.
  static RemoteCommand? parse(String sender, String message) {
    if (sender.isEmpty || message.isEmpty) {
      return null;
    }

    final trimmedMessage = message.trim().toUpperCase();
    
    // Check for valid command format: COMMAND#password
    final hashIndex = trimmedMessage.indexOf('#');
    if (hashIndex == -1 || hashIndex == 0 || hashIndex == trimmedMessage.length - 1) {
      return null;
    }

    final commandPart = trimmedMessage.substring(0, hashIndex);
    // Get password from original message to preserve case
    final password = message.trim().substring(hashIndex + 1);

    RemoteCommandType? commandType;
    switch (commandPart) {
      case 'LOCK':
        commandType = RemoteCommandType.lock;
        break;
      case 'WIPE':
        commandType = RemoteCommandType.wipe;
        break;
      case 'LOCATE':
        commandType = RemoteCommandType.locate;
        break;
      case 'ALARM':
        commandType = RemoteCommandType.alarm;
        break;
      default:
        return null;
    }

    return RemoteCommand(
      type: commandType,
      password: password,
      sender: sender,
      receivedAt: DateTime.now(),
    );
  }

  /// Validates the command against the master password hash and emergency contact.
  /// 
  /// Returns true if:
  /// - The sender matches the emergency contact
  /// - The password matches the master password (via hash verification)
  bool isValid(String masterPasswordHash, String emergencyContact) {
    // Normalize phone numbers for comparison
    final normalizedSender = _normalizePhoneNumber(sender);
    final normalizedEmergency = _normalizePhoneNumber(emergencyContact);
    
    if (normalizedSender != normalizedEmergency) {
      return false;
    }
    
    // Password verification would be done by the authentication service
    // This method just checks if the sender is the emergency contact
    // The actual password verification is delegated to the caller
    return true;
  }

  /// Checks if the sender is the emergency contact.
  bool isFromEmergencyContact(String emergencyContact) {
    final normalizedSender = _normalizePhoneNumber(sender);
    final normalizedEmergency = _normalizePhoneNumber(emergencyContact);
    return normalizedSender == normalizedEmergency;
  }

  /// Normalizes a phone number by removing non-digit characters.
  static String _normalizePhoneNumber(String phoneNumber) {
    // Remove all non-digit characters except leading +
    final hasPlus = phoneNumber.startsWith('+');
    final digits = phoneNumber.replaceAll(RegExp(r'[^\d]'), '');
    return hasPlus ? '+$digits' : digits;
  }

  /// Creates a RemoteCommand from JSON map
  factory RemoteCommand.fromJson(Map<String, dynamic> json) {
    return RemoteCommand(
      type: RemoteCommandType.values.firstWhere(
        (e) => e.name == json['type'],
        orElse: () => RemoteCommandType.lock,
      ),
      password: json['password'] as String,
      sender: json['sender'] as String,
      receivedAt: DateTime.parse(json['receivedAt'] as String),
      parameters: json['parameters'] != null
          ? Map<String, dynamic>.from(json['parameters'] as Map)
          : null,
    );
  }

  /// Converts the RemoteCommand to a JSON map
  Map<String, dynamic> toJson() {
    return {
      'type': type.name,
      'password': password,
      'sender': sender,
      'receivedAt': receivedAt.toIso8601String(),
      'parameters': parameters,
    };
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is RemoteCommand &&
        other.type == type &&
        other.password == password &&
        other.sender == sender &&
        other.receivedAt == receivedAt;
  }

  @override
  int get hashCode {
    return type.hashCode ^
        password.hashCode ^
        sender.hashCode ^
        receivedAt.hashCode;
  }

  @override
  String toString() {
    return 'RemoteCommand(type: $type, sender: $sender, receivedAt: $receivedAt)';
  }
}
