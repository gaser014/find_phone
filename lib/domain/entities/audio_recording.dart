import 'location_data.dart';

/// Represents an audio recording captured by the anti-theft protection system.
///
/// Audio recordings are captured during security events such as suspicious
/// activity detection or panic mode activation.
///
/// Requirements: 34.1, 34.2, 34.3, 34.4
class AudioRecording {
  /// Unique identifier for the recording
  final String id;

  /// File path where the recording is stored (encrypted)
  final String filePath;

  /// When the recording was started
  final DateTime timestamp;

  /// Duration of the recording in seconds
  final int durationSeconds;

  /// Location where the recording was captured (if available)
  final LocationData? location;

  /// Reason for capturing the recording (e.g., "suspicious_activity", "panic_mode")
  final String reason;

  /// Associated security event ID (if applicable)
  final String? securityEventId;

  /// Whether this is part of continuous recording (panic mode)
  final bool isContinuousRecording;

  /// File size in bytes
  final int? fileSizeBytes;

  AudioRecording({
    required this.id,
    required this.filePath,
    required this.timestamp,
    required this.durationSeconds,
    this.location,
    required this.reason,
    this.securityEventId,
    this.isContinuousRecording = false,
    this.fileSizeBytes,
  });

  /// Creates an AudioRecording from JSON map
  factory AudioRecording.fromJson(Map<String, dynamic> json) {
    return AudioRecording(
      id: json['id'] as String,
      filePath: json['filePath'] as String,
      timestamp: DateTime.parse(json['timestamp'] as String),
      durationSeconds: json['durationSeconds'] as int,
      location: json['location'] != null
          ? LocationData.fromJson(
              Map<String, dynamic>.from(json['location'] as Map))
          : null,
      reason: json['reason'] as String,
      securityEventId: json['securityEventId'] as String?,
      isContinuousRecording: json['isContinuousRecording'] as bool? ?? false,
      fileSizeBytes: json['fileSizeBytes'] as int?,
    );
  }

  /// Converts the AudioRecording to a JSON map
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'filePath': filePath,
      'timestamp': timestamp.toIso8601String(),
      'durationSeconds': durationSeconds,
      'location': location?.toJson(),
      'reason': reason,
      'securityEventId': securityEventId,
      'isContinuousRecording': isContinuousRecording,
      'fileSizeBytes': fileSizeBytes,
    };
  }

  /// Creates a copy of this recording with optional field overrides
  AudioRecording copyWith({
    String? id,
    String? filePath,
    DateTime? timestamp,
    int? durationSeconds,
    LocationData? location,
    String? reason,
    String? securityEventId,
    bool? isContinuousRecording,
    int? fileSizeBytes,
  }) {
    return AudioRecording(
      id: id ?? this.id,
      filePath: filePath ?? this.filePath,
      timestamp: timestamp ?? this.timestamp,
      durationSeconds: durationSeconds ?? this.durationSeconds,
      location: location ?? this.location,
      reason: reason ?? this.reason,
      securityEventId: securityEventId ?? this.securityEventId,
      isContinuousRecording:
          isContinuousRecording ?? this.isContinuousRecording,
      fileSizeBytes: fileSizeBytes ?? this.fileSizeBytes,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is AudioRecording &&
        other.id == id &&
        other.filePath == filePath &&
        other.timestamp == timestamp &&
        other.durationSeconds == durationSeconds &&
        other.reason == reason;
  }

  @override
  int get hashCode {
    return id.hashCode ^
        filePath.hashCode ^
        timestamp.hashCode ^
        durationSeconds.hashCode ^
        reason.hashCode;
  }

  @override
  String toString() {
    return 'AudioRecording(id: $id, filePath: $filePath, timestamp: $timestamp, '
        'durationSeconds: $durationSeconds, reason: $reason)';
  }
}
