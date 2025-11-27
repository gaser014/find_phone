/// Types of phone calls.
enum CallType {
  /// Incoming call received
  incoming,
  
  /// Outgoing call made
  outgoing,
  
  /// Missed incoming call
  missed,
}

/// Represents a call log entry recorded during Protected Mode.
/// 
/// All calls made or received while Protected Mode is active
/// are logged for security monitoring.
class CallLogEntry {
  /// Unique identifier for the log entry
  final String id;
  
  /// Phone number of the other party
  final String phoneNumber;
  
  /// Type of call (incoming, outgoing, missed)
  final CallType type;
  
  /// When the call occurred
  final DateTime timestamp;
  
  /// Duration of the call
  final Duration duration;
  
  /// Whether this number is the Emergency Contact
  final bool isEmergencyContact;

  CallLogEntry({
    required this.id,
    required this.phoneNumber,
    required this.type,
    required this.timestamp,
    required this.duration,
    this.isEmergencyContact = false,
  });

  /// Creates a CallLogEntry from JSON map
  factory CallLogEntry.fromJson(Map<String, dynamic> json) {
    return CallLogEntry(
      id: json['id'] as String,
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

  /// Converts the CallLogEntry to a JSON map
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'phoneNumber': phoneNumber,
      'type': type.name,
      'timestamp': timestamp.toIso8601String(),
      'durationSeconds': duration.inSeconds,
      'isEmergencyContact': isEmergencyContact,
    };
  }

  /// Creates a copy of this entry with optional field overrides
  CallLogEntry copyWith({
    String? id,
    String? phoneNumber,
    CallType? type,
    DateTime? timestamp,
    Duration? duration,
    bool? isEmergencyContact,
  }) {
    return CallLogEntry(
      id: id ?? this.id,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      type: type ?? this.type,
      timestamp: timestamp ?? this.timestamp,
      duration: duration ?? this.duration,
      isEmergencyContact: isEmergencyContact ?? this.isEmergencyContact,
    );
  }

  /// Formats the duration as a human-readable string (e.g., "2:30")
  String get formattedDuration {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  /// Returns a description of the call type in English
  String get typeDescription {
    switch (type) {
      case CallType.incoming:
        return 'Incoming';
      case CallType.outgoing:
        return 'Outgoing';
      case CallType.missed:
        return 'Missed';
    }
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is CallLogEntry &&
        other.id == id &&
        other.phoneNumber == phoneNumber &&
        other.type == type &&
        other.timestamp == timestamp &&
        other.duration == duration &&
        other.isEmergencyContact == isEmergencyContact;
  }

  @override
  int get hashCode {
    return id.hashCode ^
        phoneNumber.hashCode ^
        type.hashCode ^
        timestamp.hashCode ^
        duration.hashCode ^
        isEmergencyContact.hashCode;
  }

  @override
  String toString() {
    return 'CallLogEntry(id: $id, phoneNumber: $phoneNumber, type: $type, timestamp: $timestamp, duration: $formattedDuration)';
  }
}
