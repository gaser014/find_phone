import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:faker/faker.dart';
import 'package:path/path.dart' as path;

import 'package:find_phone/domain/entities/audio_recording.dart';
import 'package:find_phone/domain/entities/location_data.dart';
import 'package:find_phone/services/storage/i_storage_service.dart';

/// Mock implementation of IStorageService for testing.
class MockStorageService implements IStorageService {
  final Map<String, String> _secureStorage = {};
  final Map<String, dynamic> _storage = {};

  @override
  Future<void> storeSecure(String key, String value) async {
    _secureStorage[key] = value;
  }

  @override
  Future<String?> retrieveSecure(String key) async {
    return _secureStorage[key];
  }

  @override
  Future<void> deleteSecure(String key) async {
    _secureStorage.remove(key);
  }

  @override
  Future<bool> containsSecureKey(String key) async {
    return _secureStorage.containsKey(key);
  }

  @override
  Future<void> store(String key, dynamic value) async {
    _storage[key] = value;
  }

  @override
  Future<dynamic> retrieve(String key) async {
    return _storage[key];
  }

  @override
  Future<void> delete(String key) async {
    _storage.remove(key);
  }

  @override
  Future<bool> containsKey(String key) async {
    return _storage.containsKey(key);
  }

  @override
  Future<void> clearAll() async {
    _secureStorage.clear();
    _storage.clear();
  }

  @override
  Future<void> clearSecure() async {
    _secureStorage.clear();
  }

  @override
  Future<void> clearNonSecure() async {
    _storage.clear();
  }

  @override
  Future<Set<String>> getAllSecureKeys() async {
    return _secureStorage.keys.toSet();
  }

  @override
  Future<Set<String>> getAllKeys() async {
    return _storage.keys.toSet();
  }
}

/// Testable audio storage manager that doesn't require actual microphone.
/// This allows us to test the storage and metadata functionality.
class TestableAudioStorageManager {
  final IStorageService _storageService;
  final Directory _testDirectory;
  static const String _recordingsMetadataKey = 'audio_recordings_metadata';
  static const String _encryptionKeyKey = 'audio_encryption_key';

  TestableAudioStorageManager({
    required IStorageService storageService,
    required Directory testDirectory,
  })  : _storageService = storageService,
        _testDirectory = testDirectory;

  /// Get or generate the encryption key.
  Future<Uint8List> _getEncryptionKey() async {
    String? keyBase64 =
        await _storageService.retrieveSecure(_encryptionKeyKey);

    if (keyBase64 == null) {
      // Generate a new 256-bit key
      final random = Random.secure();
      final key = Uint8List(32);
      for (int i = 0; i < 32; i++) {
        key[i] = random.nextInt(256);
      }
      keyBase64 = base64Encode(key);
      await _storageService.storeSecure(_encryptionKeyKey, keyBase64);
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

  /// Store an audio recording with encryption and metadata.
  Future<AudioRecording> storeRecording({
    required String id,
    required Uint8List audioData,
    required String reason,
    required int durationSeconds,
    LocationData? location,
    String? securityEventId,
    bool isContinuousRecording = false,
    DateTime? timestamp,
  }) async {
    final actualTimestamp = timestamp ?? DateTime.now();
    final filePath = path.join(_testDirectory.path, '$id.enc');

    // Encrypt and save the audio data
    final key = await _getEncryptionKey();
    final encryptedData = _xorEncrypt(audioData, key);
    final file = File(filePath);
    await file.writeAsBytes(encryptedData);

    // Create recording metadata
    final recording = AudioRecording(
      id: id,
      filePath: filePath,
      timestamp: actualTimestamp,
      durationSeconds: durationSeconds,
      location: location,
      reason: reason,
      securityEventId: securityEventId,
      isContinuousRecording: isContinuousRecording,
      fileSizeBytes: audioData.length,
    );

    // Save metadata
    await _saveRecordingMetadata(recording);

    return recording;
  }

  /// Load recording metadata from storage.
  Future<List<AudioRecording>> loadRecordingMetadata() async {
    final jsonStr =
        await _storageService.retrieveSecure(_recordingsMetadataKey);

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

  Future<void> _saveRecordingMetadata(AudioRecording recording) async {
    final recordings = await loadRecordingMetadata();
    recordings.add(recording);

    final jsonStr = jsonEncode(recordings.map((r) => r.toJson()).toList());
    await _storageService.storeSecure(_recordingsMetadataKey, jsonStr);
  }

  /// Read and decrypt audio data.
  Future<Uint8List?> readRecordingData(String recordingId) async {
    final recordings = await loadRecordingMetadata();
    AudioRecording? recording;
    try {
      recording = recordings.firstWhere((r) => r.id == recordingId);
    } catch (e) {
      return null;
    }

    final file = File(recording.filePath);
    if (!await file.exists()) return null;

    final encryptedData = await file.readAsBytes();
    final key = await _getEncryptionKey();
    return _xorEncrypt(Uint8List.fromList(encryptedData), key);
  }

  /// Delete a recording.
  Future<bool> deleteRecording(String recordingId) async {
    final recordings = await loadRecordingMetadata();
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
    final jsonStr = jsonEncode(recordings.map((r) => r.toJson()).toList());
    await _storageService.storeSecure(_recordingsMetadataKey, jsonStr);

    return true;
  }

  /// Clean up old recordings.
  Future<int> cleanupOldRecordings({int daysOld = 30}) async {
    final recordings = await loadRecordingMetadata();
    final cutoffDate = DateTime.now().subtract(Duration(days: daysOld));

    final oldRecordingIds = recordings
        .where((r) => r.timestamp.isBefore(cutoffDate))
        .map((r) => r.id)
        .toList();

    int deletedCount = 0;
    for (final recordingId in oldRecordingIds) {
      if (await deleteRecording(recordingId)) {
        deletedCount++;
      }
    }
    return deletedCount;
  }

  /// Get recordings by security event ID.
  Future<List<AudioRecording>> getRecordingsBySecurityEvent(
      String securityEventId) async {
    final recordings = await loadRecordingMetadata();
    return recordings
        .where((r) => r.securityEventId == securityEventId)
        .toList();
  }
}

void main() {
  group('AudioRecordingService - Audio Storage', () {
    late MockStorageService mockStorage;
    late TestableAudioStorageManager audioManager;
    late Directory testDir;
    final random = Random();
    final faker = Faker();

    setUp(() async {
      mockStorage = MockStorageService();
      // Create a temporary directory for test recordings
      testDir = await Directory.systemTemp.createTemp('audio_test_');
      audioManager = TestableAudioStorageManager(
        storageService: mockStorage,
        testDirectory: testDir,
      );
    });

    tearDown(() async {
      // Clean up test directory
      if (await testDir.exists()) {
        await testDir.delete(recursive: true);
      }
    });

    /// Generate random audio data (simulating an M4A audio file)
    Uint8List generateRandomAudioData() {
      final size = random.nextInt(50000) + 5000; // 5KB to 55KB
      final data = Uint8List(size);
      for (int i = 0; i < size; i++) {
        data[i] = random.nextInt(256);
      }
      return data;
    }

    /// Generate a random location
    LocationData generateRandomLocation() {
      return LocationData(
        latitude: (random.nextDouble() * 180) - 90,
        longitude: (random.nextDouble() * 360) - 180,
        accuracy: random.nextDouble() * 100,
        timestamp: DateTime.now().subtract(Duration(
          minutes: random.nextInt(60),
        )),
        address: random.nextBool() ? faker.address.streetAddress() : null,
      );
    }

    /// Generate a random recording reason
    String generateRandomReason() {
      final reasons = [
        'suspicious_activity',
        'panic_mode',
        'failed_login',
        'sim_change',
        'unauthorized_access',
      ];
      return reasons[random.nextInt(reasons.length)];
    }

    /// Generate a random security event ID
    String generateRandomSecurityEventId() {
      return 'event_${random.nextInt(99999)}_${DateTime.now().millisecondsSinceEpoch}';
    }

    /// **Feature: anti-theft-protection, Property 21: Audio Recording Storage**
    /// **Validates: Requirements 34.2**
    ///
    /// For any audio recording captured during suspicious activity or panic mode,
    /// it should be stored encrypted with associated event details including
    /// timestamp, location, and security event ID.
    group('Property 21: Audio Recording Storage', () {
      test('property: recordings are stored with correct metadata', () async {
        // Run 100 iterations with random data
        for (int i = 0; i < 100; i++) {
          final recordingId = 'recording_${i}_${random.nextInt(99999)}';
          final audioData = generateRandomAudioData();
          final reason = generateRandomReason();
          final durationSeconds = random.nextInt(60) + 10; // 10-70 seconds
          final location = random.nextBool() ? generateRandomLocation() : null;
          final securityEventId =
              random.nextBool() ? generateRandomSecurityEventId() : null;
          final isContinuousRecording = random.nextBool();
          final timestamp = DateTime.now().subtract(Duration(
            days: random.nextInt(30),
            hours: random.nextInt(24),
          ));

          // Store the recording
          final storedRecording = await audioManager.storeRecording(
            id: recordingId,
            audioData: audioData,
            reason: reason,
            durationSeconds: durationSeconds,
            location: location,
            securityEventId: securityEventId,
            isContinuousRecording: isContinuousRecording,
            timestamp: timestamp,
          );

          // Verify metadata is correct
          expect(storedRecording.id, equals(recordingId),
              reason: 'Recording ID should be preserved');
          expect(storedRecording.reason, equals(reason),
              reason: 'Recording reason should be preserved');
          expect(storedRecording.durationSeconds, equals(durationSeconds),
              reason: 'Duration should be preserved');
          expect(storedRecording.timestamp.toIso8601String(),
              equals(timestamp.toIso8601String()),
              reason: 'Timestamp should be preserved');
          expect(storedRecording.securityEventId, equals(securityEventId),
              reason: 'Security event ID should be preserved');
          expect(storedRecording.isContinuousRecording,
              equals(isContinuousRecording),
              reason: 'Continuous recording flag should be preserved');
          expect(storedRecording.fileSizeBytes, equals(audioData.length),
              reason: 'File size should be preserved');

          if (location != null) {
            expect(storedRecording.location, isNotNull,
                reason: 'Location should be preserved when provided');
            expect(
                storedRecording.location!.latitude, equals(location.latitude),
                reason: 'Location latitude should match');
            expect(
                storedRecording.location!.longitude, equals(location.longitude),
                reason: 'Location longitude should match');
          } else {
            expect(storedRecording.location, isNull,
                reason: 'Location should be null when not provided');
          }

          // Verify file exists
          final file = File(storedRecording.filePath);
          expect(await file.exists(), isTrue,
              reason: 'Recording file should exist on disk');

          // Clean up for next iteration
          await audioManager.deleteRecording(recordingId);
        }
      });

      test('property: audio data is encrypted and can be decrypted correctly',
          () async {
        // Run 100 iterations with random data
        for (int i = 0; i < 100; i++) {
          final recordingId = 'enc_recording_${i}_${random.nextInt(99999)}';
          final originalData = generateRandomAudioData();
          final reason = generateRandomReason();

          // Store the recording
          await audioManager.storeRecording(
            id: recordingId,
            audioData: originalData,
            reason: reason,
            durationSeconds: 30,
          );

          // Read back the decrypted data
          final decryptedData =
              await audioManager.readRecordingData(recordingId);

          expect(decryptedData, isNotNull,
              reason: 'Should be able to read stored recording');
          expect(decryptedData!.length, equals(originalData.length),
              reason: 'Decrypted data length should match original');

          // Verify data matches byte by byte
          for (int j = 0; j < originalData.length; j++) {
            expect(decryptedData[j], equals(originalData[j]),
                reason:
                    'Decrypted byte at position $j should match original');
          }

          // Clean up
          await audioManager.deleteRecording(recordingId);
        }
      });

      test('property: stored file is encrypted (not plaintext)', () async {
        // Run 100 iterations
        for (int i = 0; i < 100; i++) {
          final recordingId = 'verify_enc_${i}_${random.nextInt(99999)}';
          final originalData = generateRandomAudioData();

          // Store the recording
          final storedRecording = await audioManager.storeRecording(
            id: recordingId,
            audioData: originalData,
            reason: 'test',
            durationSeconds: 30,
          );

          // Read raw file data (encrypted)
          final file = File(storedRecording.filePath);
          final rawFileData = await file.readAsBytes();

          // Verify the raw file data is NOT the same as original
          // (it should be encrypted)
          bool isDifferent = false;
          for (int j = 0;
              j < originalData.length && j < rawFileData.length;
              j++) {
            if (rawFileData[j] != originalData[j]) {
              isDifferent = true;
              break;
            }
          }

          expect(isDifferent, isTrue,
              reason: 'Stored file should be encrypted, not plaintext');

          // Clean up
          await audioManager.deleteRecording(recordingId);
        }
      });

      test('property: recordings can be retrieved by security event ID',
          () async {
        // Create multiple recordings with different security event IDs
        final securityEventId1 = generateRandomSecurityEventId();
        final securityEventId2 = generateRandomSecurityEventId();

        final recordingsForEvent1 = <String>[];
        final recordingsForEvent2 = <String>[];

        // Store recordings for event 1
        for (int i = 0; i < 5; i++) {
          final recordingId = 'event1_${i}_${random.nextInt(99999)}';
          await audioManager.storeRecording(
            id: recordingId,
            audioData: generateRandomAudioData(),
            reason: 'suspicious_activity',
            durationSeconds: 30,
            securityEventId: securityEventId1,
          );
          recordingsForEvent1.add(recordingId);
        }

        // Store recordings for event 2
        for (int i = 0; i < 3; i++) {
          final recordingId = 'event2_${i}_${random.nextInt(99999)}';
          await audioManager.storeRecording(
            id: recordingId,
            audioData: generateRandomAudioData(),
            reason: 'panic_mode',
            durationSeconds: 60,
            securityEventId: securityEventId2,
          );
          recordingsForEvent2.add(recordingId);
        }

        // Retrieve recordings by security event ID
        final retrievedForEvent1 =
            await audioManager.getRecordingsBySecurityEvent(securityEventId1);
        final retrievedForEvent2 =
            await audioManager.getRecordingsBySecurityEvent(securityEventId2);

        expect(retrievedForEvent1.length, equals(recordingsForEvent1.length),
            reason: 'Should retrieve all recordings for event 1');
        expect(retrievedForEvent2.length, equals(recordingsForEvent2.length),
            reason: 'Should retrieve all recordings for event 2');

        // Verify correct recordings are returned
        for (final recording in retrievedForEvent1) {
          expect(recordingsForEvent1.contains(recording.id), isTrue,
              reason: 'Retrieved recording should belong to event 1');
          expect(recording.securityEventId, equals(securityEventId1),
              reason: 'Security event ID should match');
        }

        for (final recording in retrievedForEvent2) {
          expect(recordingsForEvent2.contains(recording.id), isTrue,
              reason: 'Retrieved recording should belong to event 2');
          expect(recording.securityEventId, equals(securityEventId2),
              reason: 'Security event ID should match');
        }

        // Clean up
        for (final id in [...recordingsForEvent1, ...recordingsForEvent2]) {
          await audioManager.deleteRecording(id);
        }
      });

      test('property: metadata persists across storage operations', () async {
        final recordingsToStore = <AudioRecording>[];

        // Store multiple recordings
        for (int i = 0; i < 50; i++) {
          final recordingId = 'persist_${i}_${random.nextInt(99999)}';
          final audioData = generateRandomAudioData();
          final reason = generateRandomReason();
          final location = generateRandomLocation();
          final durationSeconds = random.nextInt(60) + 10;
          final securityEventId = generateRandomSecurityEventId();

          final recording = await audioManager.storeRecording(
            id: recordingId,
            audioData: audioData,
            reason: reason,
            durationSeconds: durationSeconds,
            location: location,
            securityEventId: securityEventId,
          );
          recordingsToStore.add(recording);
        }

        // Load metadata and verify all recordings are present
        final loadedRecordings = await audioManager.loadRecordingMetadata();

        expect(loadedRecordings.length, equals(recordingsToStore.length),
            reason: 'All stored recordings should be in metadata');

        // Verify each recording's metadata
        for (final original in recordingsToStore) {
          final loaded = loadedRecordings.firstWhere(
            (r) => r.id == original.id,
            orElse: () =>
                throw Exception('Recording ${original.id} not found'),
          );

          expect(loaded.reason, equals(original.reason),
              reason: 'Reason should persist');
          expect(loaded.durationSeconds, equals(original.durationSeconds),
              reason: 'Duration should persist');
          expect(loaded.timestamp.toIso8601String(),
              equals(original.timestamp.toIso8601String()),
              reason: 'Timestamp should persist');
          expect(loaded.filePath, equals(original.filePath),
              reason: 'File path should persist');
          expect(loaded.securityEventId, equals(original.securityEventId),
              reason: 'Security event ID should persist');

          if (original.location != null) {
            expect(loaded.location, isNotNull);
            expect(
                loaded.location!.latitude, equals(original.location!.latitude));
            expect(loaded.location!.longitude,
                equals(original.location!.longitude));
          }
        }

        // Clean up
        for (final recording in recordingsToStore) {
          await audioManager.deleteRecording(recording.id);
        }
      });

      test('property: old recordings are cleaned up correctly', () async {
        final now = DateTime.now();
        final oldRecordings = <String>[];
        final recentRecordings = <String>[];

        // Store recordings with various ages
        for (int i = 0; i < 50; i++) {
          final recordingId = 'cleanup_${i}_${random.nextInt(99999)}';
          final audioData = generateRandomAudioData();

          // Half old (31-60 days), half recent (0-29 days)
          final daysOld =
              i < 25 ? random.nextInt(30) + 31 : random.nextInt(29);
          final timestamp = now.subtract(Duration(days: daysOld));

          await audioManager.storeRecording(
            id: recordingId,
            audioData: audioData,
            reason: 'test',
            durationSeconds: 30,
            timestamp: timestamp,
          );

          if (daysOld >= 30) {
            oldRecordings.add(recordingId);
          } else {
            recentRecordings.add(recordingId);
          }
        }

        // Run cleanup
        final deletedCount =
            await audioManager.cleanupOldRecordings(daysOld: 30);

        // Verify correct number deleted
        expect(deletedCount, equals(oldRecordings.length),
            reason: 'Should delete all recordings older than 30 days');

        // Verify old recordings are gone
        final remainingRecordings = await audioManager.loadRecordingMetadata();
        for (final oldId in oldRecordings) {
          expect(
            remainingRecordings.any((r) => r.id == oldId),
            isFalse,
            reason: 'Old recording $oldId should be deleted',
          );
        }

        // Verify recent recordings remain
        for (final recentId in recentRecordings) {
          expect(
            remainingRecordings.any((r) => r.id == recentId),
            isTrue,
            reason: 'Recent recording $recentId should remain',
          );
        }

        // Clean up remaining
        for (final recording in remainingRecordings) {
          await audioManager.deleteRecording(recording.id);
        }
      });

      test('property: deletion removes both file and metadata', () async {
        for (int i = 0; i < 100; i++) {
          final recordingId = 'delete_${i}_${random.nextInt(99999)}';
          final audioData = generateRandomAudioData();

          // Store recording
          final recording = await audioManager.storeRecording(
            id: recordingId,
            audioData: audioData,
            reason: 'test',
            durationSeconds: 30,
          );

          // Verify it exists
          final file = File(recording.filePath);
          expect(await file.exists(), isTrue);

          var metadata = await audioManager.loadRecordingMetadata();
          expect(metadata.any((r) => r.id == recordingId), isTrue);

          // Delete recording
          final deleted = await audioManager.deleteRecording(recordingId);
          expect(deleted, isTrue, reason: 'Deletion should succeed');

          // Verify file is gone
          expect(await file.exists(), isFalse,
              reason: 'File should be deleted');

          // Verify metadata is gone
          metadata = await audioManager.loadRecordingMetadata();
          expect(metadata.any((r) => r.id == recordingId), isFalse,
              reason: 'Metadata should be removed');
        }
      });

      test('property: continuous recording flag is preserved', () async {
        // Test both continuous and non-continuous recordings
        for (int i = 0; i < 50; i++) {
          final recordingId = 'continuous_${i}_${random.nextInt(99999)}';
          final isContinuous = i % 2 == 0; // Alternate between true and false

          final recording = await audioManager.storeRecording(
            id: recordingId,
            audioData: generateRandomAudioData(),
            reason: isContinuous ? 'panic_mode' : 'suspicious_activity',
            durationSeconds: isContinuous ? 60 : 30,
            isContinuousRecording: isContinuous,
          );

          expect(recording.isContinuousRecording, equals(isContinuous),
              reason: 'Continuous recording flag should be preserved');

          // Verify it persists in metadata
          final metadata = await audioManager.loadRecordingMetadata();
          final loaded = metadata.firstWhere((r) => r.id == recordingId);
          expect(loaded.isContinuousRecording, equals(isContinuous),
              reason: 'Continuous recording flag should persist in metadata');

          // Clean up
          await audioManager.deleteRecording(recordingId);
        }
      });
    });
  });
}
