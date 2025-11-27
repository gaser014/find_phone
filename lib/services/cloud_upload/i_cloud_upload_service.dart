import '../../domain/entities/captured_photo.dart';

/// Status of a cloud upload operation.
enum CloudUploadStatus {
  /// Upload is pending in the queue.
  pending,
  /// Upload is currently in progress.
  inProgress,
  /// Upload completed successfully.
  completed,
  /// Upload failed after all retries.
  failed,
  /// Upload was cancelled.
  cancelled,
}

/// Represents a queued upload item.
class QueuedUpload {
  /// Unique identifier for this upload.
  final String id;

  /// The photo to upload.
  final CapturedPhoto photo;

  /// Current status of the upload.
  final CloudUploadStatus status;

  /// Number of retry attempts made.
  final int retryCount;

  /// Maximum number of retries allowed.
  final int maxRetries;

  /// Timestamp when the upload was queued.
  final DateTime queuedAt;

  /// Timestamp of the last attempt.
  final DateTime? lastAttemptAt;

  /// Error message if upload failed.
  final String? errorMessage;

  /// Cloud URL if upload succeeded.
  final String? cloudUrl;

  QueuedUpload({
    required this.id,
    required this.photo,
    required this.status,
    this.retryCount = 0,
    this.maxRetries = 5,
    required this.queuedAt,
    this.lastAttemptAt,
    this.errorMessage,
    this.cloudUrl,
  });

  /// Create a copy with updated fields.
  QueuedUpload copyWith({
    CloudUploadStatus? status,
    int? retryCount,
    DateTime? lastAttemptAt,
    String? errorMessage,
    String? cloudUrl,
  }) {
    return QueuedUpload(
      id: id,
      photo: photo,
      status: status ?? this.status,
      retryCount: retryCount ?? this.retryCount,
      maxRetries: maxRetries,
      queuedAt: queuedAt,
      lastAttemptAt: lastAttemptAt ?? this.lastAttemptAt,
      errorMessage: errorMessage ?? this.errorMessage,
      cloudUrl: cloudUrl ?? this.cloudUrl,
    );
  }

  /// Convert to JSON for storage.
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'photo': photo.toJson(),
      'status': status.index,
      'retryCount': retryCount,
      'maxRetries': maxRetries,
      'queuedAt': queuedAt.toIso8601String(),
      'lastAttemptAt': lastAttemptAt?.toIso8601String(),
      'errorMessage': errorMessage,
      'cloudUrl': cloudUrl,
    };
  }

  /// Create from JSON.
  factory QueuedUpload.fromJson(Map<String, dynamic> json) {
    return QueuedUpload(
      id: json['id'] as String,
      photo: CapturedPhoto.fromJson(json['photo'] as Map<String, dynamic>),
      status: CloudUploadStatus.values[json['status'] as int],
      retryCount: json['retryCount'] as int? ?? 0,
      maxRetries: json['maxRetries'] as int? ?? 5,
      queuedAt: DateTime.parse(json['queuedAt'] as String),
      lastAttemptAt: json['lastAttemptAt'] != null
          ? DateTime.parse(json['lastAttemptAt'] as String)
          : null,
      errorMessage: json['errorMessage'] as String?,
      cloudUrl: json['cloudUrl'] as String?,
    );
  }
}

/// Result of a cloud upload operation.
class CloudUploadResult {
  /// Whether the upload was successful.
  final bool success;

  /// The cloud URL where the photo is accessible.
  final String? cloudUrl;

  /// Error message if upload failed.
  final String? errorMessage;

  /// The queued upload item.
  final QueuedUpload queuedUpload;

  CloudUploadResult({
    required this.success,
    this.cloudUrl,
    this.errorMessage,
    required this.queuedUpload,
  });
}

/// Interface for cloud photo upload operations in the Anti-Theft Protection app.
///
/// This interface defines the contract for uploading intruder photos to cloud
/// storage, managing an offline queue, and sharing upload links via WhatsApp/SMS.
///
/// Requirements:
/// - 35.1: Upload intruder photos to cloud storage immediately
/// - 35.2: Send link via WhatsApp and SMS to Emergency Contact
/// - 35.3: Queue photos for upload when internet is unavailable
/// - 35.5: Retry up to 5 times with exponential backoff
abstract class ICloudUploadService {
  /// Initialize the cloud upload service.
  ///
  /// Sets up cloud storage connection and loads pending uploads from queue.
  /// Must be called before any other operations.
  Future<void> initialize();

  /// Dispose of the cloud upload service.
  ///
  /// Releases resources and saves pending uploads to persistent storage.
  Future<void> dispose();

  /// Upload a photo to cloud storage.
  ///
  /// Uploads the photo immediately if internet is available, otherwise
  /// queues it for later upload.
  ///
  /// [photo] - The captured photo to upload
  ///
  /// Returns the upload result with cloud URL if successful.
  ///
  /// Requirements: 35.1 - Upload intruder photos to cloud storage
  Future<CloudUploadResult> uploadPhoto(CapturedPhoto photo);

  /// Queue a photo for upload.
  ///
  /// Adds the photo to the offline queue for upload when internet is available.
  ///
  /// [photo] - The captured photo to queue
  ///
  /// Returns the queued upload item.
  ///
  /// Requirements: 35.3 - Queue photos for upload when offline
  Future<QueuedUpload> queuePhotoForUpload(CapturedPhoto photo);

  /// Process the upload queue.
  ///
  /// Attempts to upload all pending photos in the queue.
  /// Uses exponential backoff for retries.
  ///
  /// Requirements: 35.3, 35.5 - Process queue with retry logic
  Future<void> processQueue();

  /// Get all queued uploads.
  ///
  /// Returns a list of all uploads in the queue, regardless of status.
  Future<List<QueuedUpload>> getQueuedUploads();

  /// Get pending uploads.
  ///
  /// Returns uploads that are pending or failed but have retries remaining.
  Future<List<QueuedUpload>> getPendingUploads();

  /// Get completed uploads.
  ///
  /// Returns uploads that completed successfully.
  Future<List<QueuedUpload>> getCompletedUploads();

  /// Get failed uploads.
  ///
  /// Returns uploads that failed after all retries.
  Future<List<QueuedUpload>> getFailedUploads();

  /// Retry a failed upload.
  ///
  /// Resets the retry counter and attempts to upload again.
  ///
  /// [uploadId] - The ID of the upload to retry
  ///
  /// Returns the upload result.
  Future<CloudUploadResult?> retryUpload(String uploadId);

  /// Cancel a queued upload.
  ///
  /// Removes the upload from the queue.
  ///
  /// [uploadId] - The ID of the upload to cancel
  ///
  /// Returns true if the upload was cancelled, false if not found.
  Future<bool> cancelUpload(String uploadId);

  /// Clear completed uploads from the queue.
  ///
  /// Removes all successfully completed uploads from storage.
  ///
  /// Returns the number of uploads cleared.
  Future<int> clearCompletedUploads();

  /// Clear failed uploads from the queue.
  ///
  /// Removes all failed uploads from storage.
  ///
  /// Returns the number of uploads cleared.
  Future<int> clearFailedUploads();

  /// Share the cloud URL via WhatsApp and SMS.
  ///
  /// Sends the photo link to the Emergency Contact.
  ///
  /// [cloudUrl] - The cloud URL to share
  /// [photo] - The photo metadata for context
  ///
  /// Requirements: 35.2 - Send link via WhatsApp and SMS
  Future<bool> shareUploadLink(String cloudUrl, CapturedPhoto photo);

  /// Check if internet connection is available.
  ///
  /// Returns true if the device has internet connectivity.
  Future<bool> isInternetAvailable();

  /// Get the number of pending uploads.
  Future<int> getPendingUploadCount();

  /// Get the number of failed uploads.
  Future<int> getFailedUploadCount();

  /// Calculate exponential backoff delay.
  ///
  /// [retryCount] - The current retry attempt number (0-based)
  ///
  /// Returns the delay duration before the next retry.
  ///
  /// Requirements: 35.5 - Exponential backoff
  Duration calculateBackoffDelay(int retryCount);

  /// Maximum number of retry attempts.
  static const int maxRetries = 5;

  /// Base delay for exponential backoff (1 second).
  static const Duration baseBackoffDelay = Duration(seconds: 1);
}
