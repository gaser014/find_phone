import '../../domain/entities/captured_photo.dart';
import '../../domain/entities/location_data.dart';

/// Interface for camera operations in the Anti-Theft Protection app.
///
/// This interface defines the contract for capturing photos silently,
/// storing them securely with encryption, and managing photo lifecycle.
///
/// Requirements:
/// - 4.2: Capture photo using front camera on security events
/// - 4.5: Store photos securely with associated attempt details
/// - 10.5: Automatic cleanup of old photos (30+ days)
/// - 17.2: Capture front camera photo on failed unlock attempts
abstract class ICameraService {
  /// Capture a photo from the front camera silently.
  ///
  /// Takes a photo without preview or shutter sound for security purposes.
  /// The photo is stored encrypted in the app's private directory.
  ///
  /// [reason] - The reason for capturing (e.g., "failed_login", "sim_change")
  /// [location] - Optional location data to associate with the photo
  ///
  /// Returns the captured photo metadata, or null if capture failed.
  ///
  /// Requirements: 4.2, 17.2
  Future<CapturedPhoto?> captureFrontPhoto({
    required String reason,
    LocationData? location,
  });

  /// Capture a photo from the back camera.
  ///
  /// Takes a photo from the rear camera for additional evidence.
  /// The photo is stored encrypted in the app's private directory.
  ///
  /// [reason] - The reason for capturing
  /// [location] - Optional location data to associate with the photo
  ///
  /// Returns the captured photo metadata, or null if capture failed.
  Future<CapturedPhoto?> captureBackPhoto({
    required String reason,
    LocationData? location,
  });

  /// Get all captured photos.
  ///
  /// Returns a list of all photos stored by the service.
  /// Photos are sorted by timestamp (newest first).
  ///
  /// Requirements: 4.5
  Future<List<CapturedPhoto>> getCapturedPhotos();

  /// Get captured photos filtered by reason.
  ///
  /// [reason] - The capture reason to filter by
  ///
  /// Returns photos matching the specified reason.
  Future<List<CapturedPhoto>> getPhotosByReason(String reason);

  /// Get captured photos within a date range.
  ///
  /// [start] - Start of the date range
  /// [end] - End of the date range
  ///
  /// Returns photos captured within the specified range.
  Future<List<CapturedPhoto>> getPhotosByDateRange(DateTime start, DateTime end);

  /// Get a specific photo by ID.
  ///
  /// [photoId] - The unique identifier of the photo
  ///
  /// Returns the photo metadata, or null if not found.
  Future<CapturedPhoto?> getPhotoById(String photoId);

  /// Delete a captured photo.
  ///
  /// Removes both the photo file and its metadata.
  ///
  /// [photoId] - The unique identifier of the photo to delete
  ///
  /// Returns true if deletion was successful, false otherwise.
  Future<bool> deletePhoto(String photoId);

  /// Delete multiple photos.
  ///
  /// [photoIds] - List of photo IDs to delete
  ///
  /// Returns the number of photos successfully deleted.
  Future<int> deletePhotos(List<String> photoIds);

  /// Clean up old photos.
  ///
  /// Removes photos older than the specified number of days.
  /// Default is 30 days as per requirements.
  ///
  /// [daysOld] - Delete photos older than this many days (default: 30)
  ///
  /// Returns the number of photos deleted.
  ///
  /// Requirements: 10.5
  Future<int> cleanupOldPhotos({int daysOld = 30});

  /// Get the count of stored photos.
  ///
  /// Returns the total number of photos in storage.
  Future<int> getPhotoCount();

  /// Get the total storage size used by photos.
  ///
  /// Returns the size in bytes.
  Future<int> getTotalStorageSize();

  /// Read the encrypted photo file data.
  ///
  /// [photoId] - The unique identifier of the photo
  ///
  /// Returns the decrypted photo bytes, or null if not found.
  Future<List<int>?> readPhotoData(String photoId);

  /// Initialize the camera service.
  ///
  /// Sets up camera controllers and prepares for capture.
  /// Must be called before any capture operations.
  Future<void> initialize();

  /// Dispose of the camera service.
  ///
  /// Releases camera resources and cleans up.
  Future<void> dispose();

  /// Check if camera permissions are granted.
  ///
  /// Returns true if the app has camera permissions, false otherwise.
  Future<bool> hasCameraPermission();

  /// Request camera permissions.
  ///
  /// Prompts the user to grant camera permissions.
  /// Returns true if permissions were granted, false otherwise.
  Future<bool> requestCameraPermission();

  /// Check if the front camera is available.
  ///
  /// Returns true if a front camera exists on the device.
  Future<bool> hasFrontCamera();

  /// Check if the back camera is available.
  ///
  /// Returns true if a back camera exists on the device.
  Future<bool> hasBackCamera();

  /// Check if the service is initialized and ready.
  bool get isInitialized;

  /// Check if a capture is currently in progress.
  bool get isCapturing;
}
