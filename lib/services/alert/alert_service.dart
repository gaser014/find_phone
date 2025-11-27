import 'dart:async';

import 'package:flutter/services.dart';

import '../../domain/entities/location_data.dart';
import '../../domain/entities/security_event.dart';
import '../camera/i_camera_service.dart';
import '../location/i_location_service.dart';
import '../security_log/i_security_log_service.dart';
import '../sms/i_sms_service.dart';
import '../storage/i_storage_service.dart';
import 'i_alert_service.dart';

/// Storage keys for alert service configuration.
class AlertStorageKeys {
  static const String smsAlertsEnabled = 'sms_alerts_enabled';
  static const String notificationsEnabled = 'notifications_enabled';
  static const String emergencyContact = 'emergency_contact';
}

/// Notification IDs used by the alert service.
class AlertNotificationIds {
  static const int hiddenService = 1;
  static const int suspiciousActivity = 100;
  static const int simChange = 101;
  static const int failedUnlock = 102;
  static const int panicMode = 103;
}

/// Implementation of IAlertService.
///
/// Provides alert and notification functionality for security events:
/// - Local notifications for suspicious activity
/// - SMS alerts to Emergency Contact
/// - Photo capture on security events
/// - Hidden service notification for background operation
///
/// Requirements:
/// - 7.3: Send notification with event details on suspicious activity
/// - 13.3: Send SMS to Emergency Contact on SIM change
/// - 17.4: Send SMS alert on 10 failed unlock attempts
/// - 18.2: Hide notification or show as system service
class AlertService implements IAlertService {
  static const String _notificationChannel = 'com.example.find_phone/notifications';

  final IStorageService _storageService;
  final ISmsService? _smsService;
  final ILocationService? _locationService;
  final ICameraService? _cameraService;
  final ISecurityLogService? _securityLogService;

  final MethodChannel _methodChannel = const MethodChannel(_notificationChannel);

  AlertCallback? _alertCallback;
  bool _isInitialized = false;

  /// Counter for notification IDs
  int _notificationIdCounter = 200;

  AlertService({
    required IStorageService storageService,
    ISmsService? smsService,
    ILocationService? locationService,
    ICameraService? cameraService,
    ISecurityLogService? securityLogService,
  })  : _storageService = storageService,
        _smsService = smsService,
        _locationService = locationService,
        _cameraService = cameraService,
        _securityLogService = securityLogService;

  @override
  Future<void> initialize() async {
    if (_isInitialized) return;
    
    // Initialize notification channels on Android
    try {
      await _methodChannel.invokeMethod('createNotificationChannels');
    } on PlatformException {
      // Ignore if not available
    }
    
    _isInitialized = true;
  }

  @override
  Future<void> dispose() async {
    _alertCallback = null;
    _isInitialized = false;
  }

  // ==================== Notifications ====================

  @override
  Future<void> showSuspiciousActivityNotification({
    required SecurityEvent event,
    String? title,
    String? body,
  }) async {
    final notificationTitle = title ?? _getTitleForEventType(event.type);
    final notificationBody = body ?? event.description;

    try {
      await _methodChannel.invokeMethod('showNotification', {
        'id': _getNextNotificationId(),
        'channelId': 'security_alerts',
        'title': notificationTitle,
        'body': notificationBody,
        'priority': 'high',
        'autoCancel': true,
        'metadata': {
          'eventType': event.type.name,
          'eventId': event.id,
          'timestamp': event.timestamp.toIso8601String(),
        },
      });

      // Notify callback
      _notifyCallback(AlertInfo(
        type: AlertType.notification,
        event: event,
        timestamp: DateTime.now(),
        success: true,
      ));
    } on PlatformException catch (e) {
      _notifyCallback(AlertInfo(
        type: AlertType.notification,
        event: event,
        timestamp: DateTime.now(),
        success: false,
        errorMessage: e.message,
      ));
    }
  }

  @override
  Future<void> showHiddenServiceNotification({
    String title = 'System Service',
    String body = 'Running',
  }) async {
    try {
      await _methodChannel.invokeMethod('showNotification', {
        'id': AlertNotificationIds.hiddenService,
        'channelId': 'background_service',
        'title': title,
        'body': body,
        'priority': 'low',
        'ongoing': true,
        'silent': true,
        'autoCancel': false,
      });
    } on PlatformException {
      // Ignore errors for hidden notification
    }
  }

  @override
  Future<void> updateHiddenServiceNotification({
    String? title,
    String? body,
  }) async {
    await showHiddenServiceNotification(
      title: title ?? 'System Service',
      body: body ?? 'Running',
    );
  }

  @override
  Future<void> cancelNotification(int notificationId) async {
    try {
      await _methodChannel.invokeMethod('cancelNotification', {
        'id': notificationId,
      });
    } on PlatformException {
      // Ignore errors
    }
  }

  @override
  Future<void> cancelAllNotifications() async {
    try {
      await _methodChannel.invokeMethod('cancelAllNotifications');
    } on PlatformException {
      // Ignore errors
    }
  }

  // ==================== SMS Alerts ====================

  @override
  Future<bool> sendSmsAlert({
    required SecurityEvent event,
    LocationData? location,
    String? photoPath,
  }) async {
    if (_smsService == null) return false;

    final emergencyContact = await getEmergencyContact();
    if (emergencyContact == null) return false;

    final smsEnabled = await areSmsAlertsEnabled();
    if (!smsEnabled) return false;

    final message = _buildAlertMessage(event, location, photoPath);
    final success = await _smsService.sendSms(emergencyContact, message);

    _notifyCallback(AlertInfo(
      type: AlertType.sms,
      event: event,
      timestamp: DateTime.now(),
      success: success,
      metadata: {'phoneNumber': emergencyContact},
    ));

    return success;
  }

  @override
  Future<bool> sendSimChangeAlert({
    String? newSimIccid,
    String? newSimImsi,
    String? newSimCarrier,
    LocationData? location,
  }) async {
    if (_smsService == null) return false;

    final emergencyContact = await getEmergencyContact();
    if (emergencyContact == null) return false;

    final buffer = StringBuffer();
    buffer.writeln('⚠️ ANTI-THEFT ALERT: SIM CARD CHANGED');
    buffer.writeln('================================');
    buffer.writeln('Time: ${_formatTimestamp(DateTime.now())}');
    
    if (newSimCarrier != null) {
      buffer.writeln('New Carrier: $newSimCarrier');
    }
    if (newSimIccid != null) {
      buffer.writeln('New ICCID: $newSimIccid');
    }
    if (newSimImsi != null) {
      buffer.writeln('New IMSI: $newSimImsi');
    }
    
    if (location != null) {
      buffer.writeln('Location: ${location.toGoogleMapsLink()}');
    }
    
    buffer.writeln('================================');
    buffer.writeln('Device may have been stolen!');

    final success = await _smsService.sendSms(emergencyContact, buffer.toString());

    // Create event for logging
    final event = SecurityEvent(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      type: SecurityEventType.simCardChanged,
      timestamp: DateTime.now(),
      description: 'SIM card changed - alert sent',
      metadata: {
        'newSimIccid': newSimIccid,
        'newSimImsi': newSimImsi,
        'newSimCarrier': newSimCarrier,
        'alertSent': success,
      },
    );

    _notifyCallback(AlertInfo(
      type: AlertType.sms,
      event: event,
      timestamp: DateTime.now(),
      success: success,
    ));

    return success;
  }

  @override
  Future<bool> sendFailedUnlockAlert({
    required int attemptCount,
    LocationData? location,
    String? photoPath,
  }) async {
    if (_smsService == null) return false;

    final emergencyContact = await getEmergencyContact();
    if (emergencyContact == null) return false;

    final buffer = StringBuffer();
    buffer.writeln('⚠️ ANTI-THEFT ALERT: FAILED UNLOCK ATTEMPTS');
    buffer.writeln('================================');
    buffer.writeln('Time: ${_formatTimestamp(DateTime.now())}');
    buffer.writeln('Failed Attempts: $attemptCount');
    
    if (location != null) {
      buffer.writeln('Location: ${location.toGoogleMapsLink()}');
    }
    
    if (photoPath != null) {
      buffer.writeln('Photo captured: Yes');
    }
    
    buffer.writeln('================================');
    buffer.writeln('Someone may be trying to access your device!');

    final success = await _smsService.sendSms(emergencyContact, buffer.toString());

    // Create event for logging
    final event = SecurityEvent(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      type: SecurityEventType.screenUnlockFailed,
      timestamp: DateTime.now(),
      description: 'Multiple failed unlock attempts - alert sent',
      metadata: {
        'attemptCount': attemptCount,
        'alertSent': success,
      },
      photoPath: photoPath,
    );

    _notifyCallback(AlertInfo(
      type: AlertType.sms,
      event: event,
      timestamp: DateTime.now(),
      success: success,
    ));

    return success;
  }

  @override
  Future<bool> sendPanicModeAlert({
    LocationData? location,
    String? photoPath,
  }) async {
    if (_smsService == null) return false;

    final emergencyContact = await getEmergencyContact();
    if (emergencyContact == null) return false;

    final buffer = StringBuffer();
    buffer.writeln('🚨 PANIC MODE ACTIVATED 🚨');
    buffer.writeln('================================');
    buffer.writeln('Time: ${_formatTimestamp(DateTime.now())}');
    
    if (location != null) {
      buffer.writeln('Location: ${location.toGoogleMapsLink()}');
      buffer.writeln('GPS: ${location.latitude.toStringAsFixed(6)}, ${location.longitude.toStringAsFixed(6)}');
    }
    
    if (photoPath != null) {
      buffer.writeln('Photo captured: Yes');
    }
    
    buffer.writeln('================================');
    buffer.writeln('EMERGENCY! Device owner needs help!');

    final success = await _smsService.sendSms(emergencyContact, buffer.toString());

    // Create event for logging
    final event = SecurityEvent(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      type: SecurityEventType.panicModeActivated,
      timestamp: DateTime.now(),
      description: 'Panic mode activated - alert sent',
      metadata: {
        'alertSent': success,
      },
      photoPath: photoPath,
    );

    _notifyCallback(AlertInfo(
      type: AlertType.sms,
      event: event,
      timestamp: DateTime.now(),
      success: success,
    ));

    return success;
  }

  @override
  Future<bool> sendSecurityAlert({
    required String message,
    bool includeLocation = true,
  }) async {
    if (_smsService == null) return false;

    final emergencyContact = await getEmergencyContact();
    if (emergencyContact == null) return false;

    final buffer = StringBuffer();
    buffer.writeln('⚠️ ANTI-THEFT SECURITY ALERT');
    buffer.writeln('================================');
    buffer.writeln('Time: ${_formatTimestamp(DateTime.now())}');
    buffer.writeln(message);
    
    if (includeLocation && _locationService != null) {
      try {
        final location = await _locationService.getCurrentLocation();
        buffer.writeln('Location: ${location.toGoogleMapsLink()}');
      } catch (_) {
        // Ignore location errors
      }
    }

    return await _smsService.sendSms(emergencyContact, buffer.toString());
  }

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
  }) async {
    if (_cameraService == null) return null;

    LocationData? location;
    try {
      location = await _locationService?.getCurrentLocation();
    } catch (_) {
      // Ignore location errors
    }

    final photo = await _cameraService.captureFrontPhoto(
      reason: reason ?? event.type.name,
      location: location,
    );

    if (photo != null) {
      _notifyCallback(AlertInfo(
        type: AlertType.photoCapture,
        event: event,
        timestamp: DateTime.now(),
        success: true,
        metadata: {
          'photoId': photo.id,
          'photoPath': photo.filePath,
          'reason': reason ?? event.type.name,
        },
      ));
      return photo.filePath;
    }

    _notifyCallback(AlertInfo(
      type: AlertType.photoCapture,
      event: event,
      timestamp: DateTime.now(),
      success: false,
      errorMessage: 'Failed to capture photo',
    ));

    return null;
  }

  /// Capture photo on settings access attempt.
  ///
  /// Requirements: 12.5 - Capture front camera photo on Settings access
  Future<String?> capturePhotoOnSettingsAccess() async {
    final event = SecurityEvent(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      type: SecurityEventType.settingsAccessed,
      timestamp: DateTime.now(),
      description: 'Settings access attempt detected',
      metadata: {},
    );
    return captureSecurityPhoto(event: event, reason: 'settings_access');
  }

  /// Capture photo on SIM change.
  ///
  /// Requirements: 13.5 - Capture front camera photo on SIM change
  Future<String?> capturePhotoOnSimChange() async {
    final event = SecurityEvent(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      type: SecurityEventType.simCardChanged,
      timestamp: DateTime.now(),
      description: 'SIM card change detected',
      metadata: {},
    );
    return captureSecurityPhoto(event: event, reason: 'sim_change');
  }

  /// Capture photo on failed login attempts.
  ///
  /// Requirements: 4.2 - Capture photo on three incorrect password attempts
  Future<String?> capturePhotoOnFailedLogin(int attemptCount) async {
    final event = SecurityEvent(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      type: SecurityEventType.failedLogin,
      timestamp: DateTime.now(),
      description: 'Failed login attempt #$attemptCount',
      metadata: {'attemptCount': attemptCount},
    );
    return captureSecurityPhoto(event: event, reason: 'failed_login');
  }

  /// Capture photo on file manager access.
  ///
  /// Requirements: 23.5 - Capture front camera photo on file manager access
  Future<String?> capturePhotoOnFileManagerAccess() async {
    final event = SecurityEvent(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      type: SecurityEventType.fileManagerAccessed,
      timestamp: DateTime.now(),
      description: 'File manager access attempt detected',
      metadata: {},
    );
    return captureSecurityPhoto(event: event, reason: 'file_manager_access');
  }

  // ==================== Alert Handling ====================

  @override
  Future<bool> handleSecurityEvent({
    required SecurityEvent event,
    bool capturePhoto = false,
  }) async {
    bool allSuccess = true;
    String? photoPath;

    // Capture photo if requested
    if (capturePhoto && _cameraService != null) {
      LocationData? location;
      try {
        location = await _locationService?.getCurrentLocation();
      } catch (_) {}

      final photo = await _cameraService.captureFrontPhoto(
        reason: event.type.name,
        location: location,
      );
      photoPath = photo?.filePath;

      if (photo != null) {
        _notifyCallback(AlertInfo(
          type: AlertType.photoCapture,
          event: event,
          timestamp: DateTime.now(),
          success: true,
          metadata: {'photoId': photo.id, 'photoPath': photo.filePath},
        ));
      }
    }

    // Show notification
    await showSuspiciousActivityNotification(event: event);

    // Send SMS alert for critical events
    if (_shouldSendSmsForEvent(event.type)) {
      LocationData? location;
      try {
        location = await _locationService?.getCurrentLocation();
      } catch (_) {}

      final smsSuccess = await sendSmsAlert(
        event: event,
        location: location,
        photoPath: photoPath,
      );
      allSuccess = allSuccess && smsSuccess;
    }

    // Log the event
    if (_securityLogService != null) {
      final eventWithPhoto = photoPath != null
          ? event.copyWith(photoPath: photoPath)
          : event;
      await _securityLogService.logEvent(eventWithPhoto);
    }

    return allSuccess;
  }

  @override
  void registerAlertCallback(AlertCallback callback) {
    _alertCallback = callback;
  }

  @override
  void unregisterAlertCallback() {
    _alertCallback = null;
  }

  // ==================== Configuration ====================

  @override
  Future<bool> areNotificationsEnabled() async {
    try {
      final result = await _methodChannel.invokeMethod<bool>('areNotificationsEnabled');
      return result ?? true;
    } on PlatformException {
      return true;
    }
  }

  @override
  Future<bool> requestNotificationPermission() async {
    try {
      final result = await _methodChannel.invokeMethod<bool>('requestNotificationPermission');
      return result ?? false;
    } on PlatformException {
      return false;
    }
  }

  @override
  Future<String?> getEmergencyContact() async {
    // First try SMS service
    if (_smsService != null) {
      return await _smsService.getEmergencyContact();
    }
    // Fallback to storage
    return await _storageService.retrieveSecure(AlertStorageKeys.emergencyContact);
  }

  @override
  Future<void> setEmergencyContact(String phoneNumber) async {
    if (_smsService != null) {
      await _smsService.setEmergencyContact(phoneNumber);
    }
    await _storageService.storeSecure(AlertStorageKeys.emergencyContact, phoneNumber);
  }

  @override
  Future<bool> areSmsAlertsEnabled() async {
    final stored = await _storageService.retrieveSecure(AlertStorageKeys.smsAlertsEnabled);
    return stored != 'false'; // Default to enabled
  }

  @override
  Future<void> setSmsAlertsEnabled(bool enabled) async {
    await _storageService.storeSecure(
      AlertStorageKeys.smsAlertsEnabled,
      enabled.toString(),
    );
  }

  // ==================== Private Helpers ====================

  /// Get the next notification ID.
  int _getNextNotificationId() {
    return _notificationIdCounter++;
  }

  /// Get notification title for event type.
  String _getTitleForEventType(SecurityEventType type) {
    switch (type) {
      case SecurityEventType.failedLogin:
        return '⚠️ Failed Login Attempt';
      case SecurityEventType.simCardChanged:
        return '🚨 SIM Card Changed';
      case SecurityEventType.settingsAccessed:
        return '⚠️ Settings Access Blocked';
      case SecurityEventType.powerMenuBlocked:
        return '⚠️ Power Menu Blocked';
      case SecurityEventType.appForceStop:
        return '🚨 App Force Stop Detected';
      case SecurityEventType.panicModeActivated:
        return '🚨 Panic Mode Activated';
      case SecurityEventType.airplaneModeChanged:
        return '⚠️ Airplane Mode Changed';
      case SecurityEventType.screenUnlockFailed:
        return '⚠️ Failed Unlock Attempt';
      case SecurityEventType.usbDebuggingEnabled:
        return '⚠️ USB Debugging Detected';
      case SecurityEventType.fileManagerAccessed:
        return '⚠️ File Manager Access';
      case SecurityEventType.safeModeDetected:
        return '🚨 Safe Mode Detected';
      case SecurityEventType.deviceAdminDeactivationAttempted:
        return '🚨 Admin Deactivation Attempt';
      case SecurityEventType.accountAdditionAttempted:
        return '⚠️ Account Addition Blocked';
      case SecurityEventType.appInstallationAttempted:
        return '⚠️ App Installation Blocked';
      case SecurityEventType.appUninstallationAttempted:
        return '⚠️ App Uninstallation Blocked';
      case SecurityEventType.screenLockChangeAttempted:
        return '⚠️ Screen Lock Change Blocked';
      case SecurityEventType.factoryResetAttempted:
        return '🚨 Factory Reset Blocked';
      case SecurityEventType.usbConnectionDetected:
        return '⚠️ USB Connection Detected';
      case SecurityEventType.developerOptionsAccessed:
        return '⚠️ Developer Options Accessed';
      default:
        return '⚠️ Security Alert';
    }
  }

  /// Build alert message for SMS.
  String _buildAlertMessage(
    SecurityEvent event,
    LocationData? location,
    String? photoPath,
  ) {
    final buffer = StringBuffer();
    buffer.writeln('⚠️ ANTI-THEFT ALERT: ${_getTitleForEventType(event.type)}');
    buffer.writeln('================================');
    buffer.writeln('Time: ${_formatTimestamp(event.timestamp)}');
    buffer.writeln('Event: ${event.description}');
    
    if (location != null) {
      buffer.writeln('Location: ${location.toGoogleMapsLink()}');
    }
    
    if (photoPath != null) {
      buffer.writeln('Photo captured: Yes');
    }
    
    // Add relevant metadata
    if (event.metadata.isNotEmpty) {
      final relevantKeys = ['attemptCount', 'appPackage', 'reason'];
      for (final key in relevantKeys) {
        if (event.metadata.containsKey(key)) {
          buffer.writeln('$key: ${event.metadata[key]}');
        }
      }
    }

    return buffer.toString();
  }

  /// Format timestamp for display.
  String _formatTimestamp(DateTime timestamp) {
    return '${timestamp.year}-'
        '${timestamp.month.toString().padLeft(2, '0')}-'
        '${timestamp.day.toString().padLeft(2, '0')} '
        '${timestamp.hour.toString().padLeft(2, '0')}:'
        '${timestamp.minute.toString().padLeft(2, '0')}:'
        '${timestamp.second.toString().padLeft(2, '0')}';
  }

  /// Check if SMS should be sent for this event type.
  bool _shouldSendSmsForEvent(SecurityEventType type) {
    const criticalEvents = {
      SecurityEventType.simCardChanged,
      SecurityEventType.panicModeActivated,
      SecurityEventType.safeModeDetected,
      SecurityEventType.factoryResetAttempted,
      SecurityEventType.deviceAdminDeactivationAttempted,
    };
    return criticalEvents.contains(type);
  }

  /// Notify the registered callback.
  void _notifyCallback(AlertInfo alert) {
    if (_alertCallback != null) {
      _alertCallback!(alert);
    }
  }
}
