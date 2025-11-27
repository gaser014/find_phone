import 'dart:math';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:find_phone/domain/entities/captured_photo.dart';
import 'package:find_phone/domain/entities/location_data.dart';
import 'package:find_phone/services/camera/i_camera_service.dart';
import 'package:find_phone/services/cloud_upload/cloud_upload_service.dart';
import 'package:find_phone/services/cloud_upload/i_cloud_upload_service.dart';
import 'package:find_phone/services/sms/i_sms_service.dart';
import 'package:find_phone/services/storage/i_storage_service.dart';
import 'package:find_phone/services/whatsapp/i_whatsapp_service.dart';
import 'package:find_phone/domain/entities/remote_command.dart';

/// Mock storage service for testing
class MockStorageService implements IStorageService {
  final Map<String, dynamic> _storage = {};
  final Map<String, String> _secureStorage = {};

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
  Future<void> clearAll() async {
    _storage.clear();
    _secureStorage.clear();
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
  Future<bool> containsKey(String key) async {
    return _storage.containsKey(key);
  }

  @override
  Future<bool> containsSecureKey(String key) async {
    return _secureStorage.containsKey(key);
  }

  @override
  Future<Set<String>> getAllKeys() async {
    return _storage.keys.toSet();
  }

  @override
  Future<Set<String>> getAllSecureKeys() async {
    return _secureStorage.keys.toSet();
  }
}

/// Mock camera service for testing
class MockCameraService implements ICameraService {
  final Map<String, CapturedPhoto> _photos = {};
  final Map<String, List<int>> _photoData = {};

  void addPhoto(CapturedPhoto photo, List<int> data) {
    _photos[photo.id] = photo;
    _photoData[photo.id] = data;
  }

  @override
  Future<CapturedPhoto?> captureFrontPhoto({
    required String reason,
    LocationData? location,
  }) async {
    return null;
  }

  @override
  Future<CapturedPhoto?> captureBackPhoto({
    required String reason,
    LocationData? location,
  }) async {
    return null;
  }

  @override
  Future<List<CapturedPhoto>> getCapturedPhotos() async {
    return _photos.values.toList();
  }

  @override
  Future<List<CapturedPhoto>> getPhotosByReason(String reason) async {
    return _photos.values.where((p) => p.reason == reason).toList();
  }

  @override
  Future<List<CapturedPhoto>> getPhotosByDateRange(
    DateTime start,
    DateTime end,
  ) async {
    return _photos.values.where((p) {
      return p.timestamp.isAfter(start) && p.timestamp.isBefore(end);
    }).toList();
  }

  @override
  Future<CapturedPhoto?> getPhotoById(String photoId) async {
    return _photos[photoId];
  }

  @override
  Future<bool> deletePhoto(String photoId) async {
    _photos.remove(photoId);
    _photoData.remove(photoId);
    return true;
  }

  @override
  Future<int> deletePhotos(List<String> photoIds) async {
    int count = 0;
    for (final id in photoIds) {
      if (_photos.containsKey(id)) {
        _photos.remove(id);
        _photoData.remove(id);
        count++;
      }
    }
    return count;
  }

  @override
  Future<int> cleanupOldPhotos({int daysOld = 30}) async {
    return 0;
  }

  @override
  Future<int> getPhotoCount() async {
    return _photos.length;
  }

  @override
  Future<int> getTotalStorageSize() async {
    int total = 0;
    for (final data in _photoData.values) {
      total += data.length;
    }
    return total;
  }

  @override
  Future<List<int>?> readPhotoData(String photoId) async {
    return _photoData[photoId];
  }

  @override
  Future<void> initialize() async {}

  @override
  Future<void> dispose() async {}

  @override
  Future<bool> hasCameraPermission() async => true;

  @override
  Future<bool> requestCameraPermission() async => true;

  @override
  Future<bool> hasFrontCamera() async => true;

  @override
  Future<bool> hasBackCamera() async => true;

  @override
  bool get isInitialized => true;

  @override
  bool get isCapturing => false;
}

/// Mock SMS service for testing
class MockSmsService implements ISmsService {
  String? _emergencyContact;
  final List<String> _sentMessages = [];
  bool _shouldFail = false;

  void configureEmergencyContact(String contact) {
    _emergencyContact = contact;
  }

  void setShouldFail(bool shouldFail) {
    _shouldFail = shouldFail;
  }

  List<String> get sentMessages => _sentMessages;

  @override
  Future<void> initialize() async {}

  @override
  Future<void> dispose() async {}

  @override
  Future<bool> sendSms(String phoneNumber, String message) async {
    if (_shouldFail) return false;
    _sentMessages.add(message);
    return true;
  }

  @override
  Future<bool> sendSmsWithDeliveryConfirmation(
    String phoneNumber,
    String message, {
    Duration timeout = const Duration(seconds: 30),
  }) async {
    return sendSms(phoneNumber, message);
  }

  @override
  void registerCommandCallback(SmsCommandCallback callback) {}

  @override
  void unregisterCommandCallback() {}

  @override
  Future<void> startListening() async {}

  @override
  Future<void> stopListening() async {}

  @override
  bool get isListening => false;

  @override
  Future<RemoteCommand?> handleIncomingSms(String sender, String message) async {
    return null;
  }

  @override
  Future<bool> isEmergencyContact(String phoneNumber) async {
    return phoneNumber == _emergencyContact;
  }

  @override
  Future<String?> getEmergencyContact() async {
    return _emergencyContact;
  }

  @override
  Future<void> setEmergencyContact(String phoneNumber) async {
    _emergencyContact = phoneNumber;
  }

  @override
  bool validatePhoneNumber(String phoneNumber) {
    return phoneNumber.isNotEmpty;
  }

  @override
  Future<bool> sendLocationSms(String phoneNumber, LocationData location) async {
    return sendSms(phoneNumber, 'Location: ${location.toGoogleMapsLink()}');
  }

  @override
  Future<bool> sendAuthenticationFailureSms(String phoneNumber) async {
    return sendSms(phoneNumber, 'Authentication failed');
  }

  @override
  Future<bool> sendCommandConfirmationSms(
    String phoneNumber,
    RemoteCommandType commandType,
  ) async {
    return sendSms(phoneNumber, 'Command executed: $commandType');
  }

  @override
  Future<bool> sendDailyStatusReport(
    String phoneNumber, {
    required bool protectedModeActive,
    required int batteryLevel,
    LocationData? location,
    required int eventCount,
  }) async {
    return sendSms(phoneNumber, 'Daily status report');
  }

  @override
  Future<bool> hasSmsPermission() async => true;

  @override
  Future<bool> requestSmsPermission() async => true;
}

/// Mock WhatsApp service for testing
class MockWhatsAppService implements IWhatsAppService {
  final List<String> _sentMessages = [];
  bool _shouldFail = false;
  LocationData? _lastSentLocation;

  void setShouldFail(bool shouldFail) {
    _shouldFail = shouldFail;
  }

  List<String> get sentMessages => _sentMessages;

  @override
  Future<void> initialize() async {}

  @override
  Future<void> dispose() async {}

  @override
  Future<bool> isWhatsAppInstalled() async => true;

  @override
  Future<bool> sendMessage(String phoneNumber, String message) async {
    if (_shouldFail) return false;
    _sentMessages.add(message);
    return true;
  }

  @override
  Future<bool> sendLocationMessage(
    String phoneNumber,
    LocationData location,
    int batteryLevel,
  ) async {
    if (_shouldFail) return false;
    _lastSentLocation = location;
    return true;
  }

  @override
  String formatLocationMessage(LocationData location, int batteryLevel) {
    return 'Location: ${location.toGoogleMapsLink()}';
  }

  @override
  Future<void> startPeriodicLocationSharing({
    required String phoneNumber,
    Duration interval = const Duration(minutes: 15),
  }) async {}

  @override
  Future<void> stopPeriodicLocationSharing() async {}

  @override
  bool get isPeriodicSharingActive => false;

  @override
  Duration get currentInterval => const Duration(minutes: 15);

  @override
  Future<void> enablePanicMode() async {}

  @override
  Future<void> disablePanicMode() async {}

  @override
  bool get isPanicModeActive => false;

  @override
  bool isSignificantLocationChange(LocationData newLocation) => true;

  @override
  Future<void> handleSignificantLocationChange(
    String phoneNumber,
    LocationData location,
    int batteryLevel,
  ) async {}

  @override
  LocationData? get lastSentLocation => _lastSentLocation;

  @override
  void setSmsFallback(
    Future<bool> Function(String phoneNumber, String message) smsFallbackCallback,
  ) {}

  @override
  Future<String?> getWhatsAppContact() async => null;

  @override
  Future<void> setWhatsAppContact(String phoneNumber) async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Set up mock method channel handlers
  const connectivityChannel = MethodChannel('com.example.find_phone/connectivity');
  const cloudUploadChannel = MethodChannel('com.example.find_phone/cloud_upload');

  setUpAll(() {
    // Mock connectivity channel
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(connectivityChannel, (MethodCall methodCall) async {
      if (methodCall.method == 'isInternetAvailable') {
        return false; // Return false to test offline queue behavior
      }
      return null;
    });

    // Mock cloud upload channel
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(cloudUploadChannel, (MethodCall methodCall) async {
      if (methodCall.method == 'uploadPhoto') {
        // Simulate successful upload
        final args = methodCall.arguments as Map<dynamic, dynamic>;
        final photoId = args['photoId'] as String;
        return 'https://cloud.antitheft.app/photos/$photoId';
      }
      return null;
    });
  });

  tearDownAll(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(connectivityChannel, null);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(cloudUploadChannel, null);
  });

  group('CloudUploadService', () {
    final random = Random();
    late MockStorageService mockStorageService;
    late MockCameraService mockCameraService;
    late MockSmsService mockSmsService;
    late MockWhatsAppService mockWhatsAppService;
    late CloudUploadService cloudUploadService;

    setUp(() {
      mockStorageService = MockStorageService();
      mockCameraService = MockCameraService();
      mockSmsService = MockSmsService();
      mockWhatsAppService = MockWhatsAppService();
      
      // Set up emergency contact
      mockSmsService.configureEmergencyContact('+201027888372');
      
      cloudUploadService = CloudUploadService(
        storageService: mockStorageService,
        cameraService: mockCameraService,
        smsService: mockSmsService,
        whatsAppService: mockWhatsAppService,
      );
    });

    /// Generates a random photo ID
    String generatePhotoId() {
      return 'photo_${random.nextInt(1000000)}';
    }

    /// Generates a random latitude between -90 and 90
    double generateLatitude() {
      return (random.nextDouble() * 180) - 90;
    }

    /// Generates a random longitude between -180 and 180
    double generateLongitude() {
      return (random.nextDouble() * 360) - 180;
    }

    /// Generates a random accuracy between 1 and 100 meters
    double generateAccuracy() {
      return random.nextDouble() * 99 + 1;
    }

    /// Generates a random LocationData
    LocationData generateLocationData() {
      return LocationData(
        latitude: generateLatitude(),
        longitude: generateLongitude(),
        accuracy: generateAccuracy(),
        timestamp: DateTime.now().subtract(Duration(
          days: random.nextInt(30),
          hours: random.nextInt(24),
          minutes: random.nextInt(60),
        )),
      );
    }

    /// Generates a random capture reason
    String generateReason() {
      final reasons = [
        'failed_login',
        'sim_change',
        'settings_access',
        'file_manager_access',
        'panic_mode',
        'screen_unlock_failed',
      ];
      return reasons[random.nextInt(reasons.length)];
    }

    /// Generates a random CapturedPhoto
    CapturedPhoto generateCapturedPhoto() {
      return CapturedPhoto(
        id: generatePhotoId(),
        filePath: '/path/to/photo_${random.nextInt(1000)}.enc',
        timestamp: DateTime.now().subtract(Duration(
          days: random.nextInt(30),
          hours: random.nextInt(24),
          minutes: random.nextInt(60),
        )),
        location: random.nextBool() ? generateLocationData() : null,
        reason: generateReason(),
      );
    }

    /// Generates random photo data
    List<int> generatePhotoData() {
      final length = random.nextInt(10000) + 1000;
      return List.generate(length, (_) => random.nextInt(256));
    }

    /// Format capture reason for display (mirrors service implementation)
    String _formatReason(String reason) {
      switch (reason) {
        case 'failed_login':
          return 'Failed login attempt';
        case 'sim_change':
          return 'SIM card changed';
        case 'settings_access':
          return 'Settings access attempt';
        case 'file_manager_access':
          return 'File manager access attempt';
        case 'panic_mode':
          return 'Panic mode activated';
        case 'screen_unlock_failed':
          return 'Failed screen unlock';
        default:
          return reason;
      }
    }

    group('Property 22: Cloud Photo Upload and Notification', () {
      /// **Feature: anti-theft-protection, Property 22: Cloud Photo Upload and Notification**
      /// **Validates: Requirements 35.1, 35.2**
      ///
      /// For any intruder photo captured, it should be uploaded to cloud storage
      /// and the link sent via WhatsApp and SMS to Emergency Contact.
      test('property: queued photos are stored with correct metadata', () async {
        await cloudUploadService.initialize();

        // Run 100 iterations with random data
        for (int i = 0; i < 100; i++) {
          final photo = generateCapturedPhoto();
          final photoData = generatePhotoData();
          
          // Add photo to mock camera service
          mockCameraService.addPhoto(photo, photoData);

          // Queue the photo for upload
          final queuedUpload = await cloudUploadService.queuePhotoForUpload(photo);

          // Verify the queued upload has correct metadata
          expect(queuedUpload.id, isNotEmpty);
          expect(queuedUpload.photo.id, equals(photo.id));
          expect(queuedUpload.photo.reason, equals(photo.reason));
          expect(queuedUpload.photo.timestamp, equals(photo.timestamp));
          expect(queuedUpload.status, equals(CloudUploadStatus.pending));
          expect(queuedUpload.retryCount, equals(0));
          expect(queuedUpload.maxRetries, equals(5));
          expect(queuedUpload.queuedAt, isNotNull);

          // Verify photo location is preserved if present
          if (photo.location != null) {
            expect(queuedUpload.photo.location, isNotNull);
            expect(
              queuedUpload.photo.location!.latitude,
              equals(photo.location!.latitude),
            );
            expect(
              queuedUpload.photo.location!.longitude,
              equals(photo.location!.longitude),
            );
          }
        }

        await cloudUploadService.dispose();
      });

      /// **Feature: anti-theft-protection, Property 22: Cloud Photo Upload and Notification**
      /// **Validates: Requirements 35.1, 35.2**
      test('property: share message contains required information', () async {
        await cloudUploadService.initialize();

        // Run 100 iterations with random data
        for (int i = 0; i < 100; i++) {
          final photo = generateCapturedPhoto();
          final cloudUrl = 'https://cloud.antitheft.app/photos/${photo.id}';

          // Share the upload link
          await cloudUploadService.shareUploadLink(cloudUrl, photo);

          // Check that messages were sent
          final whatsAppMessages = mockWhatsAppService.sentMessages;
          final smsMessages = mockSmsService.sentMessages;

          // At least one message should be sent
          expect(
            whatsAppMessages.isNotEmpty || smsMessages.isNotEmpty,
            isTrue,
            reason: 'At least one notification should be sent',
          );

          // Get the last sent message
          final lastMessage = whatsAppMessages.isNotEmpty
              ? whatsAppMessages.last
              : smsMessages.last;

          // Verify message contains cloud URL
          expect(
            lastMessage.contains(cloudUrl),
            isTrue,
            reason: 'Message should contain cloud URL',
          );

          // Verify message contains photo reason (formatted)
          final formattedReason = _formatReason(photo.reason);
          expect(
            lastMessage.contains(formattedReason),
            isTrue,
            reason: 'Message should contain formatted reason: $formattedReason (original: ${photo.reason})',
          );

          // Verify message contains timestamp info
          expect(
            lastMessage.contains(photo.timestamp.year.toString()),
            isTrue,
            reason: 'Message should contain timestamp year',
          );

          // If photo has location, verify it's included
          if (photo.location != null) {
            expect(
              lastMessage.contains('maps.google.com') ||
              lastMessage.contains('Location'),
              isTrue,
              reason: 'Message should contain location info when available',
            );
          }
        }

        await cloudUploadService.dispose();
      });

      /// **Feature: anti-theft-protection, Property 22: Cloud Photo Upload and Notification**
      /// **Validates: Requirements 35.5**
      test('property: exponential backoff delay increases correctly', () async {
        // Run 100 iterations
        for (int i = 0; i < 100; i++) {
          // Test each retry count from 0 to 4 (5 retries total)
          for (int retryCount = 0; retryCount < 5; retryCount++) {
            final delay = cloudUploadService.calculateBackoffDelay(retryCount);
            
            // Expected delay: 2^retryCount seconds
            final expectedSeconds = (1 << retryCount); // pow(2, retryCount)
            
            expect(
              delay.inSeconds,
              equals(expectedSeconds),
              reason: 'Backoff delay for retry $retryCount should be $expectedSeconds seconds',
            );
          }

          // Verify delays are strictly increasing
          Duration? previousDelay;
          for (int retryCount = 0; retryCount < 5; retryCount++) {
            final delay = cloudUploadService.calculateBackoffDelay(retryCount);
            
            if (previousDelay != null) {
              expect(
                delay > previousDelay,
                isTrue,
                reason: 'Backoff delay should increase with each retry',
              );
            }
            previousDelay = delay;
          }
        }
      });

      /// **Feature: anti-theft-protection, Property 22: Cloud Photo Upload and Notification**
      /// **Validates: Requirements 35.3**
      test('property: queue persists across service restarts', () async {
        // Run 100 iterations
        for (int i = 0; i < 100; i++) {
          // Create a fresh storage for each iteration
          final storage = MockStorageService();
          final camera = MockCameraService();
          
          // Create first service instance
          var service = CloudUploadService(
            storageService: storage,
            cameraService: camera,
            smsService: mockSmsService,
            whatsAppService: mockWhatsAppService,
          );
          await service.initialize();

          // Queue some photos
          final photosToQueue = random.nextInt(5) + 1;
          final queuedIds = <String>[];
          
          for (int j = 0; j < photosToQueue; j++) {
            final photo = generateCapturedPhoto();
            final photoData = generatePhotoData();
            camera.addPhoto(photo, photoData);
            
            final queued = await service.queuePhotoForUpload(photo);
            queuedIds.add(queued.id);
          }

          // Dispose the service (saves queue)
          await service.dispose();

          // Create new service instance with same storage
          service = CloudUploadService(
            storageService: storage,
            cameraService: camera,
            smsService: mockSmsService,
            whatsAppService: mockWhatsAppService,
          );
          await service.initialize();

          // Verify queue was restored
          final restoredQueue = await service.getQueuedUploads();
          
          expect(
            restoredQueue.length,
            equals(photosToQueue),
            reason: 'Queue should persist across service restarts',
          );

          // Verify all queued IDs are present
          for (final id in queuedIds) {
            expect(
              restoredQueue.any((u) => u.id == id),
              isTrue,
              reason: 'Queued upload $id should be restored',
            );
          }

          await service.dispose();
        }
      });

      /// **Feature: anti-theft-protection, Property 22: Cloud Photo Upload and Notification**
      /// **Validates: Requirements 35.1**
      test('property: QueuedUpload serialization round-trip preserves data', () async {
        // Run 100 iterations
        for (int i = 0; i < 100; i++) {
          final photo = generateCapturedPhoto();
          final status = CloudUploadStatus.values[random.nextInt(CloudUploadStatus.values.length)];
          final retryCount = random.nextInt(6);
          final cloudUrl = random.nextBool() 
              ? 'https://cloud.antitheft.app/photos/${photo.id}'
              : null;
          final errorMessage = random.nextBool() ? 'Test error ${random.nextInt(100)}' : null;

          final original = QueuedUpload(
            id: 'upload_${random.nextInt(1000000)}',
            photo: photo,
            status: status,
            retryCount: retryCount,
            maxRetries: 5,
            queuedAt: DateTime.now().subtract(Duration(hours: random.nextInt(24))),
            lastAttemptAt: random.nextBool() ? DateTime.now() : null,
            errorMessage: errorMessage,
            cloudUrl: cloudUrl,
          );

          // Serialize to JSON
          final json = original.toJson();

          // Deserialize from JSON
          final restored = QueuedUpload.fromJson(json);

          // Verify all fields are preserved
          expect(restored.id, equals(original.id));
          expect(restored.photo.id, equals(original.photo.id));
          expect(restored.photo.reason, equals(original.photo.reason));
          expect(restored.status, equals(original.status));
          expect(restored.retryCount, equals(original.retryCount));
          expect(restored.maxRetries, equals(original.maxRetries));
          expect(restored.errorMessage, equals(original.errorMessage));
          expect(restored.cloudUrl, equals(original.cloudUrl));

          // Verify timestamps (with some tolerance for serialization)
          expect(
            restored.queuedAt.difference(original.queuedAt).inSeconds.abs(),
            lessThan(2),
            reason: 'queuedAt should be preserved',
          );

          if (original.lastAttemptAt != null) {
            expect(restored.lastAttemptAt, isNotNull);
            expect(
              restored.lastAttemptAt!.difference(original.lastAttemptAt!).inSeconds.abs(),
              lessThan(2),
              reason: 'lastAttemptAt should be preserved',
            );
          }
        }
      });
    });
  });
}
