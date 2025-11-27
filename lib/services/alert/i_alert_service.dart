import '../../domain/entities/location_data.dart';
import '../../domain/entities/security_event.dart';

/// Callback for when an alert is triggered.
typedef AlertCallback = Future<void> Function(AlertInfo alert);

/// Interface for Alert and Notification Service.
///
/// This interface defines the contract for sending notifications,
/// SMS alerts, and managing security event responses.
///
/// Requirements:
/// - 7.3: Send notification with event details on suspicious activity
/// - 13.3: Send SMS to Emergency Contact on SIM change
/// - 17.4: Send SMS alert on 10 failed unlock attempts
/// - 18.2: Hide notification or show as system service
abstract class IAlertService {
  /// Initialize the alert service.
  ///
  /// Sets up notification channels and prepares for alert handling.
  /// Must be called before any other operations.
  Future<void> initialize();

  /// Dispose of the alert service.
  ///
  /// Releases resources and cleans up.
  Future<void> dispose();

  // ==================== Notifications ====================

  /// Show a suspicious activity notification.
  ///
  /// Displays a notification with details about the security event.
  ///
  /// [event] - The security event that triggered the notification
  /// [title] - Optional custom title for the notification
  /// [body] - Optional custom body text
  ///
  /// Requirements: 7.3 - Send notification with event details
  Future<void> showSuspiciousActivityNotification({
    required SecurityEvent event,
    String? title,
    String? body,
  });

  /// Show a hidden notification for background service.
  ///
  /// Displays a minimal notification that appears as a system service.
  /// Used to maintain foreground service status while being discreet.
  ///
  /// [title] - The notification title (should be generic)
  /// [body] - The notification body (should be minimal)
  ///
  /// Requirements: 18.2 - Hide notification or show as system service
  Future<void> showHiddenServiceNotification({
    String title = 'System Service',
    String body = 'Running',
  });

  /// Update the hidden service notification.
  ///
  /// Updates the existing service notification without creating a new one.
  ///
  /// [title] - New title for the notification
  /// [body] - New body text
  Future<void> updateHiddenServiceNotification({
    String? title,
    String? body,
  });

  /// Cancel a notification by ID.
  ///
  /// [notificationId] - The ID of the notification to cancel
  Future<void> cancelNotification(int notificationId);

  /// Cancel all notifications.
  Future<void> cancelAllNotifications();

  // ==================== SMS Alerts ====================

  /// Send SMS alert to Emergency Contact.
  ///
  /// Sends an SMS message to the configured Emergency Contact
  /// with details about the security event.
  ///
  /// [event] - The security event that triggered the alert
  /// [location] - Optional current location to include
  /// [photoPath] - Optional path to captured photo
  ///
  /// Requirements: 13.3, 17.4 - Send SMS to Emergency Contact
  Future<bool> sendSmsAlert({
    required SecurityEvent event,
    LocationData? location,
    String? photoPath,
  });

  /// Send SIM change alert to Emergency Contact.
  ///
  /// Sends an SMS with new SIM details when SIM card is changed.
  ///
  /// [newSimIccid] - The ICCID of the new SIM card
  /// [newSimImsi] - The IMSI of the new SIM card
  /// [newSimCarrier] - The carrier name of the new SIM
  /// [location] - Optional current location
  ///
  /// Requirements: 13.3 - Send SMS with new SIM details
  Future<bool> sendSimChangeAlert({
    String? newSimIccid,
    String? newSimImsi,
    String? newSimCarrier,
    LocationData? location,
  });

  /// Send failed unlock attempts alert.
  ///
  /// Sends an SMS when too many failed unlock attempts are detected.
  ///
  /// [attemptCount] - Number of failed attempts
  /// [location] - Optional current location
  /// [photoPath] - Optional path to captured photo
  ///
  /// Requirements: 17.4 - Send SMS alert on 10 failed unlock attempts
  Future<bool> sendFailedUnlockAlert({
    required int attemptCount,
    LocationData? location,
    String? photoPath,
  });

  /// Send panic mode alert.
  ///
  /// Sends an SMS when panic mode is activated.
  ///
  /// [location] - Current location
  /// [photoPath] - Optional path to captured photo
  Future<bool> sendPanicModeAlert({
    LocationData? location,
    String? photoPath,
  });

  /// Send generic security alert.
  ///
  /// Sends a custom SMS alert to Emergency Contact.
  ///
  /// [message] - The message to send
  /// [includeLocation] - Whether to include current location
  Future<bool> sendSecurityAlert({
    required String message,
    bool includeLocation = true,
  });

  // ==================== Photo Capture ====================

  /// Capture a photo for a security event.
  ///
  /// Captures a front camera photo and associates it with the event.
  ///
  /// [event] - The security event that triggered the capture
  /// [reason] - The reason for capturing (defaults to event type)
  ///
  /// Returns the photo path if successful, null otherwise.
  ///
  /// Requirements: 4.2, 12.5, 13.5 - Capture photo on security events
  Future<String?> captureSecurityPhoto({
    required SecurityEvent event,
    String? reason,
  });

  /// Capture photo on settings access attempt.
  ///
  /// Requirements: 12.5 - Capture front camera photo on Settings access
  Future<String?> capturePhotoOnSettingsAccess();

  /// Capture photo on SIM change.
  ///
  /// Requirements: 13.5 - Capture front camera photo on SIM change
  Future<String?> capturePhotoOnSimChange();

  /// Capture photo on failed login attempts.
  ///
  /// Requirements: 4.2 - Capture photo on three incorrect password attempts
  Future<String?> capturePhotoOnFailedLogin(int attemptCount);

  /// Capture photo on file manager access.
  ///
  /// Requirements: 23.5 - Capture front camera photo on file manager access
  Future<String?> capturePhotoOnFileManagerAccess();

  // ==================== Alert Handling ====================

  /// Handle a security event and trigger appropriate alerts.
  ///
  /// Analyzes the event type and triggers notifications, SMS alerts,
  /// and photo capture as appropriate.
  ///
  /// [event] - The security event to handle
  /// [capturePhoto] - Whether to capture a photo for this event
  ///
  /// Returns true if all alerts were sent successfully.
  Future<bool> handleSecurityEvent({
    required SecurityEvent event,
    bool capturePhoto = false,
  });

  /// Register a callback for when alerts are triggered.
  ///
  /// [callback] - Function to call when an alert is triggered
  void registerAlertCallback(AlertCallback callback);

  /// Unregister the alert callback.
  void unregisterAlertCallback();

  // ==================== Configuration ====================

  /// Check if notifications are enabled.
  Future<bool> areNotificationsEnabled();

  /// Request notification permissions.
  ///
  /// Returns true if permissions were granted.
  Future<bool> requestNotificationPermission();

  /// Get the Emergency Contact number.
  Future<String?> getEmergencyContact();

  /// Set the Emergency Contact number.
  ///
  /// [phoneNumber] - The phone number to set
  Future<void> setEmergencyContact(String phoneNumber);

  /// Check if SMS alerts are enabled.
  Future<bool> areSmsAlertsEnabled();

  /// Set whether SMS alerts are enabled.
  ///
  /// [enabled] - Whether to enable SMS alerts
  Future<void> setSmsAlertsEnabled(bool enabled);
}

/// Information about a triggered alert.
class AlertInfo {
  /// Type of alert
  final AlertType type;

  /// The security event that triggered the alert
  final SecurityEvent event;

  /// When the alert was triggered
  final DateTime timestamp;

  /// Whether the alert was sent successfully
  final bool success;

  /// Error message if alert failed
  final String? errorMessage;

  /// Additional metadata
  final Map<String, dynamic>? metadata;

  AlertInfo({
    required this.type,
    required this.event,
    required this.timestamp,
    required this.success,
    this.errorMessage,
    this.metadata,
  });

  Map<String, dynamic> toJson() {
    return {
      'type': type.name,
      'event': event.toJson(),
      'timestamp': timestamp.toIso8601String(),
      'success': success,
      'errorMessage': errorMessage,
      'metadata': metadata,
    };
  }
}

/// Types of alerts that can be triggered.
enum AlertType {
  /// Local notification
  notification,

  /// SMS to Emergency Contact
  sms,

  /// Photo capture
  photoCapture,

  /// Alarm trigger
  alarm,
}
