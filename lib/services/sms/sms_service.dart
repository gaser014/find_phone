import 'dart:async';

import 'package:flutter/services.dart';

import '../../domain/entities/location_data.dart';
import '../../domain/entities/remote_command.dart';
import '../../domain/entities/security_event.dart';
import '../authentication/i_authentication_service.dart';
import '../security_log/i_security_log_service.dart';
import '../storage/i_storage_service.dart';
import 'i_sms_service.dart';

/// Storage keys for SMS service data.
class SmsStorageKeys {
  static const String emergencyContact = 'emergency_contact';
}

/// Implementation of ISmsService.
///
/// Provides SMS sending, receiving, and remote command handling.
/// Uses platform channels to communicate with native Android SMS APIs.
///
/// Requirements:
/// - 8.1: Receive and process SMS commands (LOCK#, WIPE#, LOCATE#, ALARM#)
/// - 8.4: Reply with GPS coordinates and Google Maps link
/// - 8.6: Ignore commands from non-Emergency Contact numbers
/// - 8.7: Send authentication failure SMS for incorrect passwords
class SmsService implements ISmsService {
  static const String _smsChannel = 'com.example.find_phone/sms';
  static const String _smsEventsChannel = 'com.example.find_phone/sms_events';

  final IStorageService _storageService;
  final IAuthenticationService _authenticationService;
  final ISecurityLogService? _securityLogService;

  final MethodChannel _methodChannel = const MethodChannel(_smsChannel);
  final EventChannel _eventChannel = const EventChannel(_smsEventsChannel);

  StreamSubscription<dynamic>? _smsSubscription;
  SmsCommandCallback? _commandCallback;
  bool _isListening = false;
  bool _isInitialized = false;

  SmsService({
    required IStorageService storageService,
    required IAuthenticationService authenticationService,
    ISecurityLogService? securityLogService,
  })  : _storageService = storageService,
        _authenticationService = authenticationService,
        _securityLogService = securityLogService;

  @override
  Future<void> initialize() async {
    if (_isInitialized) return;
    _isInitialized = true;
  }

  @override
  Future<void> dispose() async {
    await stopListening();
    _isInitialized = false;
  }

  @override
  Future<bool> sendSms(String phoneNumber, String message) async {
    if (!validatePhoneNumber(phoneNumber)) {
      return false;
    }

    try {
      final result = await _methodChannel.invokeMethod<bool>('sendSms', {
        'phoneNumber': phoneNumber,
        'message': message,
      });
      return result ?? false;
    } on PlatformException catch (e) {
      print('Failed to send SMS: ${e.message}');
      return false;
    }
  }

  @override
  Future<bool> sendSmsWithDeliveryConfirmation(
    String phoneNumber,
    String message, {
    Duration timeout = const Duration(seconds: 30),
  }) async {
    if (!validatePhoneNumber(phoneNumber)) {
      return false;
    }

    try {
      final result = await _methodChannel
          .invokeMethod<bool>('sendSmsWithDeliveryConfirmation', {
        'phoneNumber': phoneNumber,
        'message': message,
        'timeoutMs': timeout.inMilliseconds,
      });
      return result ?? false;
    } on PlatformException catch (e) {
      print('Failed to send SMS with confirmation: ${e.message}');
      return false;
    }
  }

  @override
  void registerCommandCallback(SmsCommandCallback callback) {
    _commandCallback = callback;
  }

  @override
  void unregisterCommandCallback() {
    _commandCallback = null;
  }

  @override
  Future<void> startListening() async {
    if (_isListening) return;

    _smsSubscription = _eventChannel.receiveBroadcastStream().listen(
      (dynamic event) async {
        if (event is Map) {
          final sender = event['sender'] as String?;
          final message = event['message'] as String?;

          if (sender != null && message != null) {
            await handleIncomingSms(sender, message);
          }
        }
      },
      onError: (error) {
        print('SMS event stream error: $error');
      },
    );

    _isListening = true;
  }

  @override
  Future<void> stopListening() async {
    await _smsSubscription?.cancel();
    _smsSubscription = null;
    _isListening = false;
  }

  @override
  bool get isListening => _isListening;

  @override
  Future<RemoteCommand?> handleIncomingSms(
      String sender, String message) async {
    // Parse the command
    final command = RemoteCommand.parse(sender, message);

    if (command == null) {
      // Not a valid command format, ignore
      return null;
    }

    // Log the received command
    await _logSecurityEvent(
      SecurityEventType.remoteCommandReceived,
      'Remote command received: ${command.type.name}',
      {'sender': sender, 'command_type': command.type.name},
    );

    // Check if sender is emergency contact
    final isEmergency = await isEmergencyContact(sender);
    if (!isEmergency) {
      // Log as suspicious activity
      await _logSecurityEvent(
        SecurityEventType.remoteCommandReceived,
        'Remote command from non-emergency contact rejected',
        {
          'sender': sender,
          'command_type': command.type.name,
          'rejected_reason': 'not_emergency_contact',
        },
      );
      return null;
    }

    // Verify password
    final isPasswordValid =
        await _authenticationService.verifyPassword(command.password);
    if (!isPasswordValid) {
      // Send authentication failure response
      await sendAuthenticationFailureSms(sender);

      // Log the failed attempt
      await _logSecurityEvent(
        SecurityEventType.remoteCommandReceived,
        'Remote command authentication failed',
        {
          'sender': sender,
          'command_type': command.type.name,
          'rejected_reason': 'invalid_password',
        },
      );
      return null;
    }

    // Command is valid, invoke callback if registered
    if (_commandCallback != null) {
      await _commandCallback!(command);
    }

    // Log successful command
    await _logSecurityEvent(
      SecurityEventType.remoteCommandExecuted,
      'Remote command executed: ${command.type.name}',
      {'sender': sender, 'command_type': command.type.name},
    );

    return command;
  }

  @override
  Future<bool> isEmergencyContact(String phoneNumber) async {
    final emergencyContact = await getEmergencyContact();
    if (emergencyContact == null) {
      return false;
    }

    return _normalizePhoneNumber(phoneNumber) ==
        _normalizePhoneNumber(emergencyContact);
  }

  @override
  Future<String?> getEmergencyContact() async {
    return await _storageService.retrieveSecure(SmsStorageKeys.emergencyContact);
  }

  @override
  Future<void> setEmergencyContact(String phoneNumber) async {
    if (!validatePhoneNumber(phoneNumber)) {
      throw ArgumentError('Invalid phone number format');
    }
    await _storageService.storeSecure(
        SmsStorageKeys.emergencyContact, phoneNumber);
  }

  @override
  bool validatePhoneNumber(String phoneNumber) {
    if (phoneNumber.isEmpty) {
      return false;
    }

    // Remove all whitespace and common separators
    final cleaned = phoneNumber.replaceAll(RegExp(r'[\s\-\(\)]'), '');

    // Check for valid phone number pattern
    // Supports international format (+XX...) and local formats
    final phoneRegex = RegExp(r'^\+?[0-9]{7,15}$');
    return phoneRegex.hasMatch(cleaned);
  }

  @override
  Future<bool> sendLocationSms(String phoneNumber, LocationData location) async {
    final message = _formatLocationMessage(location);
    return await sendSms(phoneNumber, message);
  }

  @override
  Future<bool> sendAuthenticationFailureSms(String phoneNumber) async {
    const message = 'Anti-Theft: Authentication failed. '
        'Command rejected due to incorrect password.';
    return await sendSms(phoneNumber, message);
  }

  @override
  Future<bool> sendCommandConfirmationSms(
    String phoneNumber,
    RemoteCommandType commandType,
  ) async {
    String message;
    switch (commandType) {
      case RemoteCommandType.lock:
        message = 'Anti-Theft: Device locked successfully. '
            'Kiosk mode enabled.';
        break;
      case RemoteCommandType.wipe:
        message = 'Anti-Theft: Factory reset initiated. '
            'All data will be erased.';
        break;
      case RemoteCommandType.locate:
        message = 'Anti-Theft: Location request received. '
            'Sending location...';
        break;
      case RemoteCommandType.alarm:
        message = 'Anti-Theft: Alarm triggered. '
            'Playing at maximum volume for 2 minutes.';
        break;
    }
    return await sendSms(phoneNumber, message);
  }

  @override
  Future<bool> sendDailyStatusReport(
    String phoneNumber, {
    required bool protectedModeActive,
    required int batteryLevel,
    LocationData? location,
    required int eventCount,
  }) async {
    final buffer = StringBuffer();
    buffer.writeln('Anti-Theft Daily Report');
    buffer.writeln('=======================');
    buffer.writeln('Status: ${protectedModeActive ? "Protected" : "Unprotected"}');
    buffer.writeln('Battery: $batteryLevel%');

    if (batteryLevel < 15) {
      buffer.writeln('⚠️ LOW BATTERY WARNING');
    }

    if (location != null) {
      buffer.writeln('Location: ${location.toGoogleMapsLink()}');
    }

    if (eventCount == 0) {
      buffer.writeln('Events: All OK - No security events');
    } else {
      buffer.writeln('Events: $eventCount security event(s)');
    }

    return await sendSms(phoneNumber, buffer.toString());
  }

  @override
  Future<bool> hasSmsPermission() async {
    try {
      final result =
          await _methodChannel.invokeMethod<bool>('hasSmsPermission');
      return result ?? false;
    } on PlatformException {
      return false;
    }
  }

  @override
  Future<bool> requestSmsPermission() async {
    try {
      final result =
          await _methodChannel.invokeMethod<bool>('requestSmsPermission');
      return result ?? false;
    } on PlatformException {
      return false;
    }
  }

  /// Format location data into an SMS message.
  ///
  /// Requirements: 8.4 - Reply with GPS coordinates, accuracy, timestamp, and Google Maps link
  String _formatLocationMessage(LocationData location) {
    final buffer = StringBuffer();
    buffer.writeln('Anti-Theft Location');
    buffer.writeln('GPS: ${location.latitude.toStringAsFixed(6)}, '
        '${location.longitude.toStringAsFixed(6)}');
    buffer.writeln('Accuracy: ${location.accuracy.toStringAsFixed(0)}m');
    buffer.writeln('Time: ${_formatTimestamp(location.timestamp)}');
    buffer.writeln('Map: ${location.toGoogleMapsLink()}');
    return buffer.toString();
  }

  /// Format a timestamp for SMS display.
  String _formatTimestamp(DateTime timestamp) {
    return '${timestamp.year}-'
        '${timestamp.month.toString().padLeft(2, '0')}-'
        '${timestamp.day.toString().padLeft(2, '0')} '
        '${timestamp.hour.toString().padLeft(2, '0')}:'
        '${timestamp.minute.toString().padLeft(2, '0')}:'
        '${timestamp.second.toString().padLeft(2, '0')}';
  }

  /// Normalize a phone number for comparison.
  String _normalizePhoneNumber(String phoneNumber) {
    // Remove all non-digit characters except leading +
    final hasPlus = phoneNumber.startsWith('+');
    final digits = phoneNumber.replaceAll(RegExp(r'[^\d]'), '');
    return hasPlus ? '+$digits' : digits;
  }

  /// Log a security event.
  Future<void> _logSecurityEvent(
    SecurityEventType type,
    String description,
    Map<String, dynamic> metadata,
  ) async {
    if (_securityLogService == null) return;

    final event = SecurityEvent(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      type: type,
      timestamp: DateTime.now(),
      description: description,
      metadata: metadata,
    );

    await _securityLogService.logEvent(event);
  }
}
