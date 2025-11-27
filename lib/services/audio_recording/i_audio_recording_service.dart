import '../../domain/entities/audio_recording.dart';
import '../../domain/entities/location_data.dart';

/// Interface for audio recording operations in the Anti-Theft Protection app.
///
/// This interface defines the contract for recording audio during security
/// events, storing recordings securely with encryption, and managing
/// recording lifecycle including playback.
///
/// Requirements:
/// - 34.1: Start audio recording on suspicious activity for 30 seconds
/// - 34.2: Store recordings encrypted with event details
/// - 34.3: Continuous recording in panic mode
/// - 34.4: Audio playback in security logs
abstract class IAudioRecordingService {
  /// Start a 30-second audio recording on suspicious activity.
  ///
  /// Records audio from the device microphone for 30 seconds.
  /// The recording is stored encrypted in the app's private directory.
  ///
  /// [reason] - The reason for recording (e.g., "suspicious_activity")
  /// [location] - Optional location data to associate with the recording
  /// [securityEventId] - Optional associated security event ID
  ///
  /// Returns the recording metadata, or null if recording failed.
  ///
  /// Requirements: 34.1
  Future<AudioRecording?> recordSuspiciousActivity({
    required String reason,
    LocationData? location,
    String? securityEventId,
  });

  /// Start continuous recording for panic mode.
  ///
  /// Begins continuous audio recording that continues until stopped.
  /// Recordings are split into segments for storage efficiency.
  ///
  /// [location] - Optional location data to associate with the recording
  ///
  /// Returns true if continuous recording started successfully.
  ///
  /// Requirements: 34.3
  Future<bool> startContinuousRecording({LocationData? location});

  /// Stop continuous recording.
  ///
  /// Stops the ongoing continuous recording and saves the final segment.
  ///
  /// Returns the list of recordings created during continuous mode.
  ///
  /// Requirements: 34.3
  Future<List<AudioRecording>> stopContinuousRecording();

  /// Check if continuous recording is active.
  ///
  /// Returns true if continuous recording is currently in progress.
  bool get isContinuousRecordingActive;

  /// Get all audio recordings.
  ///
  /// Returns a list of all recordings stored by the service.
  /// Recordings are sorted by timestamp (newest first).
  Future<List<AudioRecording>> getAllRecordings();

  /// Get recordings filtered by reason.
  ///
  /// [reason] - The recording reason to filter by
  ///
  /// Returns recordings matching the specified reason.
  Future<List<AudioRecording>> getRecordingsByReason(String reason);

  /// Get recordings within a date range.
  ///
  /// [start] - Start of the date range
  /// [end] - End of the date range
  ///
  /// Returns recordings captured within the specified range.
  Future<List<AudioRecording>> getRecordingsByDateRange(
      DateTime start, DateTime end);

  /// Get a specific recording by ID.
  ///
  /// [recordingId] - The unique identifier of the recording
  ///
  /// Returns the recording metadata, or null if not found.
  Future<AudioRecording?> getRecordingById(String recordingId);

  /// Get recordings associated with a security event.
  ///
  /// [securityEventId] - The security event ID to filter by
  ///
  /// Returns recordings associated with the specified event.
  Future<List<AudioRecording>> getRecordingsBySecurityEvent(
      String securityEventId);

  /// Delete an audio recording.
  ///
  /// Removes both the recording file and its metadata.
  ///
  /// [recordingId] - The unique identifier of the recording to delete
  ///
  /// Returns true if deletion was successful, false otherwise.
  Future<bool> deleteRecording(String recordingId);

  /// Delete multiple recordings.
  ///
  /// [recordingIds] - List of recording IDs to delete
  ///
  /// Returns the number of recordings successfully deleted.
  Future<int> deleteRecordings(List<String> recordingIds);

  /// Clean up old recordings.
  ///
  /// Removes recordings older than the specified number of days.
  /// Default is 30 days.
  ///
  /// [daysOld] - Delete recordings older than this many days (default: 30)
  ///
  /// Returns the number of recordings deleted.
  Future<int> cleanupOldRecordings({int daysOld = 30});

  /// Get the count of stored recordings.
  ///
  /// Returns the total number of recordings in storage.
  Future<int> getRecordingCount();

  /// Get the total storage size used by recordings.
  ///
  /// Returns the size in bytes.
  Future<int> getTotalStorageSize();

  /// Read the decrypted audio file data.
  ///
  /// [recordingId] - The unique identifier of the recording
  ///
  /// Returns the decrypted audio bytes, or null if not found.
  ///
  /// Requirements: 34.4
  Future<List<int>?> readRecordingData(String recordingId);

  /// Get the file path for playback.
  ///
  /// Creates a temporary decrypted file for playback and returns its path.
  /// The temporary file should be cleaned up after playback.
  ///
  /// [recordingId] - The unique identifier of the recording
  ///
  /// Returns the temporary file path, or null if not found.
  ///
  /// Requirements: 34.4
  Future<String?> getPlaybackFilePath(String recordingId);

  /// Clean up temporary playback files.
  ///
  /// Removes any temporary decrypted files created for playback.
  Future<void> cleanupPlaybackFiles();

  /// Initialize the audio recording service.
  ///
  /// Sets up audio recorder and prepares for recording.
  /// Must be called before any recording operations.
  Future<void> initialize();

  /// Dispose of the audio recording service.
  ///
  /// Releases audio resources and cleans up.
  Future<void> dispose();

  /// Check if microphone permissions are granted.
  ///
  /// Returns true if the app has microphone permissions, false otherwise.
  Future<bool> hasMicrophonePermission();

  /// Request microphone permissions.
  ///
  /// Prompts the user to grant microphone permissions.
  /// Returns true if permissions were granted, false otherwise.
  ///
  /// Requirements: 34.5
  Future<bool> requestMicrophonePermission();

  /// Check if the service is initialized and ready.
  bool get isInitialized;

  /// Check if a recording is currently in progress.
  bool get isRecording;
}
