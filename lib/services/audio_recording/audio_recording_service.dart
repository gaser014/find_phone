import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';
import 'package:uuid/uuid.dart';

import '../../domain/entities/audio_recording.dart';
import '../../domain/entities/location_data.dart';
import '../storage/storage.dart';
import 'i_audio_recording_service.dart';

/// Storage keys for audio recording service data.
class AudioStorageKeys {
  static const String recordingsMetadata = 'audio_recordings_metadata';
  static const String encryptionKey = 'audio_encryption_key';
}

/// Implementation of IAudioRecordingService.
///
/// Provides audio recording functionality with encryption for
/// security event documentation. Recordings are stored in the app's private
/// directory with XOR encryption.
///
/// Requirements:
/// - 34.1: Start audio recording on suspicious activity for 30 seconds
/// - 34.2: Store recordings encrypted with event details
/// - 34.3: Continuous recording in panic mode
/// - 34.4: Audio playback in security logs
class AudioRecordingService implements IAudioRecordingService {
  final IStorageService _storageService;
  final Uuid _uuid = const Uuid();

  AudioRecorder? _audioRecorder;
  bool _isInitialized = false;
  bool _isRecording = false;
  bool _isContinuousRecordingActive = false;
  Timer? _continuousRecordingTimer;
  List<AudioRecording> _continuousRecordings = [];
  LocationData? _continuousRecordingLocation;

  /// Directory name for storing recordings.
  static const String _recordingsDirectory = 'security_audio';

  /// Directory name for temporary playback files.
  static const String _tempDirectory = 'audio_temp';

  /// Default recording duration in seconds.
  static const int defaultRecordingDuration = 30;

  /// Continuous recording segment duration in seconds.
  static const int continuousSegmentDuration = 60;

  AudioRecordingService({required IStorageService storageService})
      : _storageService = storageService;

  @override
  bool get isInitialized => _isInitialized;

  @override
  bool get isRecording => _isRecording;

  @override
  bool get isContinuousRecordingActive => _isContinuousRecordingActive;

  @override
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      _audioRecorder = AudioRecorder();
      _isInitialized = true;
    } catch (e) {
      _isInitialized = false;
      rethrow;
    }
  }

  @override
  Future<void> dispose() async {
    await stopContinuousRecording();
    await _audioRecorder?.dispose();
    _audioRecorder = null;
    _isInitialized = false;
  }

  @override
  Future<bool> hasMicrophonePermission() async {
    final status = await Permission.microphone.status;
    return status.isGranted;
  }

  @override
  Future<bool> requestMicrophonePermission() async {
    final status = await Permission.microphone.request();
    return status.isGranted;
  }

  /// Get the recordings directory path.
  Future<Directory> _getRecordingsDirectory() async {
    final appDir = await getApplicationDocumentsDirectory();
    final recordingsDir = Directory('${appDir.path}/$_recordingsDirectory');
    if (!await recordingsDir.exists()) {
      await recordingsDir.create(recursive: true);
    }
    return recordingsDir;
  }

  /// Get the temporary directory path for playback files.
  Future<Directory> _getTempDirectory() async {
    final appDir = await getApplicationDocumentsDirectory();
    final tempDir = Directory('${appDir.path}/$_tempDirectory');
    if (!await tempDir.exists()) {
      await tempDir.create(recursive: true);
    }
    return tempDir;
  }

  /// Get or generate the encryption key.
  Future<Uint8List> _getEncryptionKey() async {
    String? keyBase64 = await _storageService.retrieveSecure(
      AudioStorageKeys.encryptionKey,
    );

    if (keyBase64 == null) {
      // Generate a new 256-bit key
      final key = Uint8List(32);
      for (int i = 0; i < 32; i++) {
        key[i] = DateTime.now().microsecondsSinceEpoch % 256;
        await Future.delayed(const Duration(microseconds: 1));
      }
      keyBase64 = base64Encode(key);
      await _storageService.storeSecure(
        AudioStorageKeys.encryptionKey,
        keyBase64,
      );
    }

    return base64Decode(keyBase64);
  }

  /// Simple XOR encryption for audio data.
  Uint8List _xorEncrypt(Uint8List data, Uint8List key) {
    final result = Uint8List(data.length);
    for (int i = 0; i < data.length; i++) {
      result[i] = data[i] ^ key[i % key.length];
    }
    return result;
  }

  /// Save encrypted recording to storage.
  Future<String?> _saveEncryptedRecording(
      String recordingId, Uint8List audioBytes) async {
    try {
      final recordingsDir = await _getRecordingsDirectory();
      final filePath = '${recordingsDir.path}/$recordingId.enc';

      // Encrypt the audio data
      final key = await _getEncryptionKey();
      final encryptedData = _xorEncrypt(audioBytes, key);

      // Write encrypted data to file
      final file = File(filePath);
      await file.writeAsBytes(encryptedData);

      return filePath;
    } catch (e) {
      return null;
    }
  }

  /// Load recording metadata from storage.
  Future<List<AudioRecording>> _loadRecordingMetadata() async {
    final jsonStr = await _storageService.retrieveSecure(
      AudioStorageKeys.recordingsMetadata,
    );

    if (jsonStr == null || jsonStr.isEmpty) {
      return [];
    }

    try {
      final List<dynamic> jsonList = jsonDecode(jsonStr);
      return jsonList
          .map((json) =>
              AudioRecording.fromJson(Map<String, dynamic>.from(json)))
          .toList();
    } catch (e) {
      return [];
    }
  }

  /// Save recording metadata to storage.
  Future<void> _saveRecordingMetadata(AudioRecording recording) async {
    final recordings = await _loadRecordingMetadata();
    recordings.add(recording);

    final jsonStr = jsonEncode(recordings.map((r) => r.toJson()).toList());
    await _storageService.storeSecure(
        AudioStorageKeys.recordingsMetadata, jsonStr);
  }

  /// Update the full recording metadata list.
  Future<void> _updateRecordingMetadataList(
      List<AudioRecording> recordings) async {
    final jsonStr = jsonEncode(recordings.map((r) => r.toJson()).toList());
    await _storageService.storeSecure(
        AudioStorageKeys.recordingsMetadata, jsonStr);
  }

  /// Record audio for a specified duration.
  Future<AudioRecording?> _recordAudio({
    required String reason,
    required int durationSeconds,
    LocationData? location,
    String? securityEventId,
    bool isContinuousRecording = false,
  }) async {
    if (_isRecording) return null;
    _isRecording = true;

    try {
      // Check permissions
      if (!await hasMicrophonePermission()) {
        final granted = await requestMicrophonePermission();
        if (!granted) return null;
      }

      // Initialize if needed
      if (!_isInitialized) {
        await initialize();
      }

      // Generate unique ID and timestamp
      final String recordingId = _uuid.v4();
      final DateTime timestamp = DateTime.now();

      // Get temp file path for recording
      final tempDir = await _getTempDirectory();
      final tempFilePath = '${tempDir.path}/$recordingId.m4a';

      // Start recording
      await _audioRecorder!.start(
        const RecordConfig(
          encoder: AudioEncoder.aacLc,
          bitRate: 128000,
          sampleRate: 44100,
        ),
        path: tempFilePath,
      );

      // Wait for the specified duration
      await Future.delayed(Duration(seconds: durationSeconds));

      // Stop recording
      final path = await _audioRecorder!.stop();
      if (path == null) return null;

      // Read the recorded audio
      final tempFile = File(path);
      if (!await tempFile.exists()) return null;

      final audioBytes = await tempFile.readAsBytes();
      final fileSizeBytes = audioBytes.length;

      // Encrypt and save
      final encryptedFilePath =
          await _saveEncryptedRecording(recordingId, audioBytes);
      if (encryptedFilePath == null) return null;

      // Create recording metadata
      final recording = AudioRecording(
        id: recordingId,
        filePath: encryptedFilePath,
        timestamp: timestamp,
        durationSeconds: durationSeconds,
        location: location,
        reason: reason,
        securityEventId: securityEventId,
        isContinuousRecording: isContinuousRecording,
        fileSizeBytes: fileSizeBytes,
      );

      // Save metadata
      await _saveRecordingMetadata(recording);

      // Clean up temp file
      try {
        await tempFile.delete();
      } catch (_) {}

      return recording;
    } catch (e) {
      return null;
    } finally {
      _isRecording = false;
    }
  }

  @override
  Future<AudioRecording?> recordSuspiciousActivity({
    required String reason,
    LocationData? location,
    String? securityEventId,
  }) async {
    return _recordAudio(
      reason: reason,
      durationSeconds: defaultRecordingDuration,
      location: location,
      securityEventId: securityEventId,
      isContinuousRecording: false,
    );
  }

  @override
  Future<bool> startContinuousRecording({LocationData? location}) async {
    if (_isContinuousRecordingActive) return false;

    _isContinuousRecordingActive = true;
    _continuousRecordings = [];
    _continuousRecordingLocation = location;

    // Start the first segment
    _startContinuousSegment();

    return true;
  }

  /// Start recording a continuous segment.
  void _startContinuousSegment() {
    if (!_isContinuousRecordingActive) return;

    _recordAudio(
      reason: 'panic_mode',
      durationSeconds: continuousSegmentDuration,
      location: _continuousRecordingLocation,
      isContinuousRecording: true,
    ).then((recording) {
      if (recording != null) {
        _continuousRecordings.add(recording);
      }

      // Start next segment if still in continuous mode
      if (_isContinuousRecordingActive) {
        _startContinuousSegment();
      }
    });
  }

  @override
  Future<List<AudioRecording>> stopContinuousRecording() async {
    if (!_isContinuousRecordingActive) return [];

    _isContinuousRecordingActive = false;
    _continuousRecordingTimer?.cancel();
    _continuousRecordingTimer = null;

    // Stop any ongoing recording
    if (_isRecording) {
      try {
        await _audioRecorder?.stop();
      } catch (_) {}
      _isRecording = false;
    }

    final recordings = List<AudioRecording>.from(_continuousRecordings);
    _continuousRecordings = [];
    _continuousRecordingLocation = null;

    return recordings;
  }

  @override
  Future<List<AudioRecording>> getAllRecordings() async {
    final recordings = await _loadRecordingMetadata();
    // Sort by timestamp (newest first)
    recordings.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return recordings;
  }

  @override
  Future<List<AudioRecording>> getRecordingsByReason(String reason) async {
    final recordings = await getAllRecordings();
    return recordings.where((r) => r.reason == reason).toList();
  }

  @override
  Future<List<AudioRecording>> getRecordingsByDateRange(
    DateTime start,
    DateTime end,
  ) async {
    final recordings = await getAllRecordings();
    return recordings.where((r) {
      return r.timestamp.isAfter(start) && r.timestamp.isBefore(end);
    }).toList();
  }

  @override
  Future<AudioRecording?> getRecordingById(String recordingId) async {
    final recordings = await _loadRecordingMetadata();
    try {
      return recordings.firstWhere((r) => r.id == recordingId);
    } catch (e) {
      return null;
    }
  }

  @override
  Future<List<AudioRecording>> getRecordingsBySecurityEvent(
      String securityEventId) async {
    final recordings = await getAllRecordings();
    return recordings
        .where((r) => r.securityEventId == securityEventId)
        .toList();
  }

  @override
  Future<bool> deleteRecording(String recordingId) async {
    try {
      final recordings = await _loadRecordingMetadata();
      final recordingIndex = recordings.indexWhere((r) => r.id == recordingId);

      if (recordingIndex == -1) return false;

      final recording = recordings[recordingIndex];

      // Delete the file
      final file = File(recording.filePath);
      if (await file.exists()) {
        await file.delete();
      }

      // Remove from metadata
      recordings.removeAt(recordingIndex);
      await _updateRecordingMetadataList(recordings);

      return true;
    } catch (e) {
      return false;
    }
  }

  @override
  Future<int> deleteRecordings(List<String> recordingIds) async {
    int deletedCount = 0;
    for (final recordingId in recordingIds) {
      if (await deleteRecording(recordingId)) {
        deletedCount++;
      }
    }
    return deletedCount;
  }

  @override
  Future<int> cleanupOldRecordings({int daysOld = 30}) async {
    final recordings = await _loadRecordingMetadata();
    final cutoffDate = DateTime.now().subtract(Duration(days: daysOld));

    final oldRecordingIds = recordings
        .where((r) => r.timestamp.isBefore(cutoffDate))
        .map((r) => r.id)
        .toList();

    return await deleteRecordings(oldRecordingIds);
  }

  @override
  Future<int> getRecordingCount() async {
    final recordings = await _loadRecordingMetadata();
    return recordings.length;
  }

  @override
  Future<int> getTotalStorageSize() async {
    try {
      final recordingsDir = await _getRecordingsDirectory();
      int totalSize = 0;

      await for (final entity in recordingsDir.list()) {
        if (entity is File) {
          totalSize += await entity.length();
        }
      }

      return totalSize;
    } catch (e) {
      return 0;
    }
  }

  @override
  Future<List<int>?> readRecordingData(String recordingId) async {
    try {
      final recording = await getRecordingById(recordingId);
      if (recording == null) return null;

      final file = File(recording.filePath);
      if (!await file.exists()) return null;

      // Read encrypted data
      final encryptedData = await file.readAsBytes();

      // Decrypt
      final key = await _getEncryptionKey();
      final decryptedData =
          _xorEncrypt(Uint8List.fromList(encryptedData), key);

      return decryptedData.toList();
    } catch (e) {
      return null;
    }
  }

  @override
  Future<String?> getPlaybackFilePath(String recordingId) async {
    try {
      final decryptedData = await readRecordingData(recordingId);
      if (decryptedData == null) return null;

      final tempDir = await _getTempDirectory();
      final tempFilePath = '${tempDir.path}/playback_$recordingId.m4a';

      final file = File(tempFilePath);
      await file.writeAsBytes(decryptedData);

      return tempFilePath;
    } catch (e) {
      return null;
    }
  }

  @override
  Future<void> cleanupPlaybackFiles() async {
    try {
      final tempDir = await _getTempDirectory();
      if (await tempDir.exists()) {
        await for (final entity in tempDir.list()) {
          if (entity is File && entity.path.contains('playback_')) {
            await entity.delete();
          }
        }
      }
    } catch (_) {}
  }
}
