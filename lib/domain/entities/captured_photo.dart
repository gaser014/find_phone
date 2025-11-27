import 'location_data.dart';

/// Represents a photo captured by the anti-theft protection system.
/// 
/// Photos are captured during security events such as failed login attempts,
/// SIM card changes, or unauthorized access attempts.
class CapturedPhoto {
  /// Unique identifier for the photo
  final String id;
  
  /// File path where the photo is stored
  final String filePath;
  
  /// When the photo was captured
  final DateTime timestamp;
  
  /// Location where the photo was captured (if available)
  final LocationData? location;
  
  /// Reason for capturing the photo (e.g., "failed_login", "sim_change")
  final String reason;

  CapturedPhoto({
    required this.id,
    required this.filePath,
    required this.timestamp,
    this.location,
    required this.reason,
  });

  /// Creates a CapturedPhoto from JSON map
  factory CapturedPhoto.fromJson(Map<String, dynamic> json) {
    return CapturedPhoto(
      id: json['id'] as String,
      filePath: json['filePath'] as String,
      timestamp: DateTime.parse(json['timestamp'] as String),
      location: json['location'] != null
          ? LocationData.fromJson(Map<String, dynamic>.from(json['location'] as Map))
          : null,
      reason: json['reason'] as String,
    );
  }

  /// Converts the CapturedPhoto to a JSON map
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'filePath': filePath,
      'timestamp': timestamp.toIso8601String(),
      'location': location?.toJson(),
      'reason': reason,
    };
  }

  /// Creates a copy of this photo with optional field overrides
  CapturedPhoto copyWith({
    String? id,
    String? filePath,
    DateTime? timestamp,
    LocationData? location,
    String? reason,
  }) {
    return CapturedPhoto(
      id: id ?? this.id,
      filePath: filePath ?? this.filePath,
      timestamp: timestamp ?? this.timestamp,
      location: location ?? this.location,
      reason: reason ?? this.reason,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is CapturedPhoto &&
        other.id == id &&
        other.filePath == filePath &&
        other.timestamp == timestamp &&
        other.reason == reason;
  }

  @override
  int get hashCode {
    return id.hashCode ^
        filePath.hashCode ^
        timestamp.hashCode ^
        reason.hashCode;
  }

  @override
  String toString() {
    return 'CapturedPhoto(id: $id, filePath: $filePath, timestamp: $timestamp, reason: $reason)';
  }
}
