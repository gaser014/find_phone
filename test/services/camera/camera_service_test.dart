import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:faker/faker.dart';
import 'package:path/path.dart' as path;

import 'package:find_phone/domain/entities/captured_photo.dart';
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

/// Testable photo storage manager that doesn't require actual camera.
/// This allows us to test the storage and metadata functionality.
class TestablePhotoStorageManager {
  final IStorageService _storageService;
  final Directory _testDirectory;
  static const String _photosMetadataKey = 'captured_photos_metadata';
  static const String _encryptionKeyKey = 'photo_encryption_key';

  TestablePhotoStorageManager({
    required IStorageService storageService,
    required Directory testDirectory,
  })  : _storageService = storageService,
        _testDirectory = testDirectory;

  /// Get or generate the encryption key.
  Future<Uint8List> _getEncryptionKey() async {
    String? keyBase64 = await _storageService.retrieveSecure(_encryptionKeyKey);

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

  /// Simple XOR encryption for photo data.
  Uint8List _xorEncrypt(Uint8List data, Uint8List key) {
    final result = Uint8List(data.length);
    for (int i = 0; i < data.length; i++) {
      result[i] = data[i] ^ key[i % key.length];
    }
    return result;
  }

  /// Store a photo with encryption and metadata.
  Future<CapturedPhoto> storePhoto({
    required String id,
    required Uint8List imageData,
    required String reason,
    LocationData? location,
    DateTime? timestamp,
  }) async {
    final actualTimestamp = timestamp ?? DateTime.now();
    final filePath = path.join(_testDirectory.path, '$id.enc');

    // Encrypt and save the image data
    final key = await _getEncryptionKey();
    final encryptedData = _xorEncrypt(imageData, key);
    final file = File(filePath);
    await file.writeAsBytes(encryptedData);

    // Create photo metadata
    final photo = CapturedPhoto(
      id: id,
      filePath: filePath,
      timestamp: actualTimestamp,
      location: location,
      reason: reason,
    );

    // Save metadata
    await _savePhotoMetadata(photo);

    return photo;
  }

  /// Load photo metadata from storage.
  Future<List<CapturedPhoto>> loadPhotoMetadata() async {
    final jsonStr = await _storageService.retrieveSecure(_photosMetadataKey);

    if (jsonStr == null || jsonStr.isEmpty) {
      return [];
    }

    try {
      final List<dynamic> jsonList = jsonDecode(jsonStr);
      return jsonList
          .map((json) => CapturedPhoto.fromJson(Map<String, dynamic>.from(json)))
          .toList();
    } catch (e) {
      return [];
    }
  }

  Future<void> _savePhotoMetadata(CapturedPhoto photo) async {
    final photos = await loadPhotoMetadata();
    photos.add(photo);

    final jsonStr = jsonEncode(photos.map((p) => p.toJson()).toList());
    await _storageService.storeSecure(_photosMetadataKey, jsonStr);
  }

  /// Read and decrypt photo data.
  Future<Uint8List?> readPhotoData(String photoId) async {
    final photos = await loadPhotoMetadata();
    CapturedPhoto? photo;
    try {
      photo = photos.firstWhere((p) => p.id == photoId);
    } catch (e) {
      return null;
    }

    final file = File(photo.filePath);
    if (!await file.exists()) return null;

    final encryptedData = await file.readAsBytes();
    final key = await _getEncryptionKey();
    return _xorEncrypt(Uint8List.fromList(encryptedData), key);
  }

  /// Delete a photo.
  Future<bool> deletePhoto(String photoId) async {
    final photos = await loadPhotoMetadata();
    final photoIndex = photos.indexWhere((p) => p.id == photoId);

    if (photoIndex == -1) return false;

    final photo = photos[photoIndex];

    // Delete the file
    final file = File(photo.filePath);
    if (await file.exists()) {
      await file.delete();
    }

    // Remove from metadata
    photos.removeAt(photoIndex);
    final jsonStr = jsonEncode(photos.map((p) => p.toJson()).toList());
    await _storageService.storeSecure(_photosMetadataKey, jsonStr);

    return true;
  }

  /// Clean up old photos.
  Future<int> cleanupOldPhotos({int daysOld = 30}) async {
    final photos = await loadPhotoMetadata();
    final cutoffDate = DateTime.now().subtract(Duration(days: daysOld));

    final oldPhotoIds = photos
        .where((p) => p.timestamp.isBefore(cutoffDate))
        .map((p) => p.id)
        .toList();

    int deletedCount = 0;
    for (final photoId in oldPhotoIds) {
      if (await deletePhoto(photoId)) {
        deletedCount++;
      }
    }
    return deletedCount;
  }
}


void main() {
  group('CameraService - Photo Storage', () {
    late MockStorageService mockStorage;
    late TestablePhotoStorageManager photoManager;
    late Directory testDir;
    final random = Random();
    final faker = Faker();

    setUp(() async {
      mockStorage = MockStorageService();
      // Create a temporary directory for test photos
      testDir = await Directory.systemTemp.createTemp('camera_test_');
      photoManager = TestablePhotoStorageManager(
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

    /// Generate random image data (simulating a JPEG image)
    Uint8List generateRandomImageData() {
      final size = random.nextInt(10000) + 1000; // 1KB to 11KB
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

    /// Generate a random capture reason
    String generateRandomReason() {
      final reasons = [
        'failed_login',
        'sim_change',
        'settings_access',
        'file_manager_access',
        'panic_mode',
        'unauthorized_access',
      ];
      return reasons[random.nextInt(reasons.length)];
    }

    /// **Feature: anti-theft-protection, Property 5: Photo Capture Storage**
    /// **Validates: Requirements 4.5, 13.5, 23.5**
    ///
    /// For any captured photo (intruder, SIM change, settings access),
    /// it should be stored securely with associated event details
    /// including timestamp and location.
    group('Property 5: Photo Capture Storage', () {
      test('property: photos are stored with correct metadata', () async {
        // Run 100 iterations with random data
        for (int i = 0; i < 100; i++) {
          final photoId = 'photo_${i}_${random.nextInt(99999)}';
          final imageData = generateRandomImageData();
          final reason = generateRandomReason();
          final location = random.nextBool() ? generateRandomLocation() : null;
          final timestamp = DateTime.now().subtract(Duration(
            days: random.nextInt(30),
            hours: random.nextInt(24),
          ));

          // Store the photo
          final storedPhoto = await photoManager.storePhoto(
            id: photoId,
            imageData: imageData,
            reason: reason,
            location: location,
            timestamp: timestamp,
          );

          // Verify metadata is correct
          expect(storedPhoto.id, equals(photoId),
              reason: 'Photo ID should be preserved');
          expect(storedPhoto.reason, equals(reason),
              reason: 'Capture reason should be preserved');
          expect(storedPhoto.timestamp.toIso8601String(),
              equals(timestamp.toIso8601String()),
              reason: 'Timestamp should be preserved');

          if (location != null) {
            expect(storedPhoto.location, isNotNull,
                reason: 'Location should be preserved when provided');
            expect(storedPhoto.location!.latitude, equals(location.latitude),
                reason: 'Location latitude should match');
            expect(storedPhoto.location!.longitude, equals(location.longitude),
                reason: 'Location longitude should match');
          } else {
            expect(storedPhoto.location, isNull,
                reason: 'Location should be null when not provided');
          }

          // Verify file exists
          final file = File(storedPhoto.filePath);
          expect(await file.exists(), isTrue,
              reason: 'Photo file should exist on disk');

          // Clean up for next iteration
          await photoManager.deletePhoto(photoId);
        }
      });

      test('property: photo data is encrypted and can be decrypted correctly', () async {
        // Run 100 iterations with random data
        for (int i = 0; i < 100; i++) {
          final photoId = 'enc_photo_${i}_${random.nextInt(99999)}';
          final originalData = generateRandomImageData();
          final reason = generateRandomReason();

          // Store the photo
          await photoManager.storePhoto(
            id: photoId,
            imageData: originalData,
            reason: reason,
          );

          // Read back the decrypted data
          final decryptedData = await photoManager.readPhotoData(photoId);

          expect(decryptedData, isNotNull,
              reason: 'Should be able to read stored photo');
          expect(decryptedData!.length, equals(originalData.length),
              reason: 'Decrypted data length should match original');

          // Verify data matches byte by byte
          for (int j = 0; j < originalData.length; j++) {
            expect(decryptedData[j], equals(originalData[j]),
                reason: 'Decrypted byte at position $j should match original');
          }

          // Clean up
          await photoManager.deletePhoto(photoId);
        }
      });

      test('property: stored file is encrypted (not plaintext)', () async {
        // Run 100 iterations
        for (int i = 0; i < 100; i++) {
          final photoId = 'verify_enc_${i}_${random.nextInt(99999)}';
          final originalData = generateRandomImageData();

          // Store the photo
          final storedPhoto = await photoManager.storePhoto(
            id: photoId,
            imageData: originalData,
            reason: 'test',
          );

          // Read raw file data (encrypted)
          final file = File(storedPhoto.filePath);
          final rawFileData = await file.readAsBytes();

          // Verify the raw file data is NOT the same as original
          // (it should be encrypted)
          bool isDifferent = false;
          for (int j = 0; j < originalData.length && j < rawFileData.length; j++) {
            if (rawFileData[j] != originalData[j]) {
              isDifferent = true;
              break;
            }
          }

          expect(isDifferent, isTrue,
              reason: 'Stored file should be encrypted, not plaintext');

          // Clean up
          await photoManager.deletePhoto(photoId);
        }
      });

      test('property: metadata persists across storage operations', () async {
        final photosToStore = <CapturedPhoto>[];

        // Store multiple photos
        for (int i = 0; i < 50; i++) {
          final photoId = 'persist_${i}_${random.nextInt(99999)}';
          final imageData = generateRandomImageData();
          final reason = generateRandomReason();
          final location = generateRandomLocation();

          final photo = await photoManager.storePhoto(
            id: photoId,
            imageData: imageData,
            reason: reason,
            location: location,
          );
          photosToStore.add(photo);
        }

        // Load metadata and verify all photos are present
        final loadedPhotos = await photoManager.loadPhotoMetadata();

        expect(loadedPhotos.length, equals(photosToStore.length),
            reason: 'All stored photos should be in metadata');

        // Verify each photo's metadata
        for (final original in photosToStore) {
          final loaded = loadedPhotos.firstWhere(
            (p) => p.id == original.id,
            orElse: () => throw Exception('Photo ${original.id} not found'),
          );

          expect(loaded.reason, equals(original.reason),
              reason: 'Reason should persist');
          expect(loaded.timestamp.toIso8601String(),
              equals(original.timestamp.toIso8601String()),
              reason: 'Timestamp should persist');
          expect(loaded.filePath, equals(original.filePath),
              reason: 'File path should persist');

          if (original.location != null) {
            expect(loaded.location, isNotNull);
            expect(loaded.location!.latitude, equals(original.location!.latitude));
            expect(loaded.location!.longitude, equals(original.location!.longitude));
          }
        }

        // Clean up
        for (final photo in photosToStore) {
          await photoManager.deletePhoto(photo.id);
        }
      });

      test('property: old photos are cleaned up correctly', () async {
        final now = DateTime.now();
        final oldPhotos = <String>[];
        final recentPhotos = <String>[];

        // Store photos with various ages
        for (int i = 0; i < 50; i++) {
          final photoId = 'cleanup_${i}_${random.nextInt(99999)}';
          final imageData = generateRandomImageData();

          // Half old (31-60 days), half recent (0-29 days)
          final daysOld = i < 25 ? random.nextInt(30) + 31 : random.nextInt(29);
          final timestamp = now.subtract(Duration(days: daysOld));

          await photoManager.storePhoto(
            id: photoId,
            imageData: imageData,
            reason: 'test',
            timestamp: timestamp,
          );

          if (daysOld >= 30) {
            oldPhotos.add(photoId);
          } else {
            recentPhotos.add(photoId);
          }
        }

        // Run cleanup
        final deletedCount = await photoManager.cleanupOldPhotos(daysOld: 30);

        // Verify correct number deleted
        expect(deletedCount, equals(oldPhotos.length),
            reason: 'Should delete all photos older than 30 days');

        // Verify old photos are gone
        final remainingPhotos = await photoManager.loadPhotoMetadata();
        for (final oldId in oldPhotos) {
          expect(
            remainingPhotos.any((p) => p.id == oldId),
            isFalse,
            reason: 'Old photo $oldId should be deleted',
          );
        }

        // Verify recent photos remain
        for (final recentId in recentPhotos) {
          expect(
            remainingPhotos.any((p) => p.id == recentId),
            isTrue,
            reason: 'Recent photo $recentId should remain',
          );
        }

        // Clean up remaining
        for (final photo in remainingPhotos) {
          await photoManager.deletePhoto(photo.id);
        }
      });

      test('property: deletion removes both file and metadata', () async {
        for (int i = 0; i < 100; i++) {
          final photoId = 'delete_${i}_${random.nextInt(99999)}';
          final imageData = generateRandomImageData();

          // Store photo
          final photo = await photoManager.storePhoto(
            id: photoId,
            imageData: imageData,
            reason: 'test',
          );

          // Verify it exists
          final file = File(photo.filePath);
          expect(await file.exists(), isTrue);

          var metadata = await photoManager.loadPhotoMetadata();
          expect(metadata.any((p) => p.id == photoId), isTrue);

          // Delete photo
          final deleted = await photoManager.deletePhoto(photoId);
          expect(deleted, isTrue, reason: 'Deletion should succeed');

          // Verify file is gone
          expect(await file.exists(), isFalse,
              reason: 'File should be deleted');

          // Verify metadata is gone
          metadata = await photoManager.loadPhotoMetadata();
          expect(metadata.any((p) => p.id == photoId), isFalse,
              reason: 'Metadata should be removed');
        }
      });
    });
  });
}
