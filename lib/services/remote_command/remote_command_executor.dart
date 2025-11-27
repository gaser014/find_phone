import 'dart:async';

import 'package:flutter/services.dart';

import '../../domain/entities/location_data.dart';
import '../../domain/entities/remote_command.dart';
import '../../domain/entities/security_event.dart';
import '../accessibility/i_accessibility_service.dart';
import '../device_admin/i_device_admin_service.dart';
import '../location/i_location_service.dart';
import '../security_log/i_security_log_service.dart';
import '../sms/i_sms_service.dart';
import '../storage/i_storage_service.dart';
import 'i_remote_command_executor.dart';

/// Storage keys for remote command executor.
class RemoteCommandStorageKeys {
  static const String lockScreenMessage = 'lock_screen_message';
  static const String kioskModeActive = 'kiosk_mode_active';
  static const String alarmActive = 'alarm_active';
}

/// Implementation of [IRemoteCommandExecutor].
///
/// Executes remote commands received via SMS:
/// - LOCK: Lock device and enable Kiosk Mode (Requirements 8.1, 8.2)
/// - WIPE: Factory reset via Device Admin (Requirement 8.3)
/// - LOCATE: Reply with GPS coordinates and Maps link (Requirement 8.4)
/// - ALARM: Trigger 2-minute max volume alarm (Requirement 8.5)
///
/// Requirements: 8.1, 8.2, 8.3, 8.4, 8.5
class RemoteCommandExecutor implements IRemoteCommandExecutor {
  static const String _alarmChannel = 'com.example.find_phone/alarm';
  static const String _kioskChannel = 'com.example.find_phone/kiosk';

  final IDeviceAdminService _deviceAdminService;
  final ILocationService _locationService;
  final ISmsService _smsService;
  final IStorageService _storageService;
  final ISecurityLogService? _securityLogService;
  final IAccessibilityService? _accessibilityService;

  final MethodChannel _alarmMethodChannel = const MethodChannel(_alarmChannel);
  final MethodChannel _kioskMethodChannel = const MethodChannel(_kioskChannel);

  Timer? _alarmTimer;
  bool _isInitialized = false;

  RemoteCommandExecutor({
    required IDeviceAdminService deviceAdminService,
    required ILocationService locationService,
    required ISmsService smsService,
    required IStorageService storageService,
    ISecurityLogService? securityLogService,
    IAccessibilityService? accessibilityService,
  })  : _deviceAdminService = deviceAdminService,
        _locationService = locationService,
        _smsService = smsService,
        _storageService = storageService,
        _securityLogService = securityLogService,
        _accessibilityService = accessibilityService;

  @override
  Future<void> initialize() async {
    if (_isInitialized) return;
    _isInitialized = true;
  }

  @override
  Future<void> dispose() async {
    _alarmTimer?.cancel();
    _alarmTimer = null;
    _isInitialized = false;
  }

  @override
  Future<RemoteCommandResult> executeCommand(RemoteCommand command) async {
    switch (command.type) {
      case RemoteCommandType.lock:
        final result = await executeLockCommand();
        // Send confirmation SMS
        await _smsService.sendCommandConfirmationSms(
          command.sender,
          RemoteCommandType.lock,
        );
        return result;

      case RemoteCommandType.wipe:
        // Send confirmation before wipe (device will be wiped)
        await _smsService.sendCommandConfirmationSms(
          command.sender,
          RemoteCommandType.wipe,
        );
        return await executeWipeCommand();

      case RemoteCommandType.locate:
        final result = await executeLocateCommand();
        // Send location via SMS
        if (result.success && result.data != null) {
          final location = LocationData.fromJson(result.data!);
          await _smsService.sendLocationSms(command.sender, location);
        }
        return result;

      case RemoteCommandType.alarm:
        final result = await executeAlarmCommand();
        // Send confirmation SMS
        await _smsService.sendCommandConfirmationSms(
          command.sender,
          RemoteCommandType.alarm,
        );
        return result;
    }
  }


  @override
  Future<RemoteCommandResult> executeLockCommand({String? customMessage}) async {
    try {
      // Log the command execution
      await _logSecurityEvent(
        SecurityEventType.remoteCommandExecuted,
        'LOCK command executed',
        {'custom_message': customMessage},
      );

      // Lock the device using Device Admin
      final lockSuccess = await _deviceAdminService.lockDevice();
      if (!lockSuccess) {
        return RemoteCommandResult(
          success: false,
          message: 'Failed to lock device. Device Admin may not be active.',
        );
      }

      // Enable Kiosk Mode
      final kioskSuccess = await _enableKioskMode();
      if (!kioskSuccess) {
        // Device is locked but Kiosk Mode failed
        return RemoteCommandResult(
          success: true,
          message: 'Device locked but Kiosk Mode could not be enabled.',
        );
      }

      // Get emergency contact for display
      final emergencyContact = await _smsService.getEmergencyContact();

      // Show custom lock screen message overlay (Requirement 8.2)
      // Display full-screen message with owner contact information
      if (_accessibilityService != null) {
        await _accessibilityService.showLockScreenMessage(
          message: customMessage ?? 'هذا الجهاز مقفل بواسطة تطبيق الحماية من السرقة',
          ownerContact: emergencyContact,
          instructions: 'إذا وجدت هذا الجهاز، يرجى الاتصال بالمالك على الرقم أعلاه',
        );
      }

      // Set custom lock screen message if provided
      if (customMessage != null && customMessage.isNotEmpty) {
        await setLockScreenMessage(customMessage);
        await _deviceAdminService.lockDeviceWithMessage(customMessage);
      }

      // Store Kiosk Mode state
      await _storageService.store(
        RemoteCommandStorageKeys.kioskModeActive,
        true,
      );

      return RemoteCommandResult(
        success: true,
        message: 'Device locked and Kiosk Mode enabled successfully.',
      );
    } catch (e) {
      return RemoteCommandResult(
        success: false,
        message: 'Error executing LOCK command: $e',
      );
    }
  }

  @override
  Future<RemoteCommandResult> executeWipeCommand() async {
    try {
      // Log the command execution before wipe
      await _logSecurityEvent(
        SecurityEventType.remoteCommandExecuted,
        'WIPE command executed - Factory reset initiated',
        {},
      );

      // Get and send last known location before wipe
      try {
        final location = await _locationService.getCurrentLocation();
        final emergencyContact = await _smsService.getEmergencyContact();
        if (emergencyContact != null) {
          await _smsService.sendSms(
            emergencyContact,
            'Anti-Theft: Factory reset initiated. Last location: ${location.toGoogleMapsLink()}',
          );
        }
      } catch (_) {
        // Continue with wipe even if location fails
      }

      // Execute factory reset via Device Admin
      final wipeSuccess = await _deviceAdminService.wipeDevice(
        reason: 'Remote WIPE command from Emergency Contact',
      );

      if (!wipeSuccess) {
        return RemoteCommandResult(
          success: false,
          message: 'Failed to initiate factory reset. Device Admin may not be active.',
        );
      }

      return RemoteCommandResult(
        success: true,
        message: 'Factory reset initiated. All data will be erased.',
      );
    } catch (e) {
      return RemoteCommandResult(
        success: false,
        message: 'Error executing WIPE command: $e',
      );
    }
  }

  @override
  Future<RemoteCommandResult> executeLocateCommand() async {
    try {
      // Log the command execution
      await _logSecurityEvent(
        SecurityEventType.remoteCommandExecuted,
        'LOCATE command executed',
        {},
      );

      // Get current location
      final location = await _locationService.getCurrentLocation();

      // Log the location
      await _logSecurityEvent(
        SecurityEventType.locationTracked,
        'Location retrieved for LOCATE command',
        {
          'latitude': location.latitude,
          'longitude': location.longitude,
          'accuracy': location.accuracy,
        },
      );

      return RemoteCommandResult(
        success: true,
        message: 'Location retrieved successfully.',
        data: location.toJson(),
      );
    } catch (e) {
      // Try to get last known location
      try {
        final lastLocation = await _locationService.getLastKnownLocation();
        if (lastLocation != null) {
          return RemoteCommandResult(
            success: true,
            message: 'Current location unavailable. Returning last known location.',
            data: lastLocation.toJson(),
          );
        }
      } catch (_) {
        // Ignore
      }

      return RemoteCommandResult(
        success: false,
        message: 'Error getting location: $e',
      );
    }
  }

  @override
  Future<RemoteCommandResult> executeAlarmCommand() async {
    try {
      // Log the command execution
      await _logSecurityEvent(
        SecurityEventType.remoteCommandExecuted,
        'ALARM command executed',
        {'duration_minutes': 2},
      );

      // Trigger alarm via native channel
      final alarmSuccess = await _triggerAlarm();
      if (!alarmSuccess) {
        return RemoteCommandResult(
          success: false,
          message: 'Failed to trigger alarm.',
        );
      }

      // Store alarm state
      await _storageService.store(
        RemoteCommandStorageKeys.alarmActive,
        true,
      );

      // Set timer to stop alarm after 2 minutes
      _alarmTimer?.cancel();
      _alarmTimer = Timer(const Duration(minutes: 2), () async {
        await _stopAlarmInternal();
      });

      return RemoteCommandResult(
        success: true,
        message: 'Alarm triggered at maximum volume for 2 minutes.',
      );
    } catch (e) {
      return RemoteCommandResult(
        success: false,
        message: 'Error executing ALARM command: $e',
      );
    }
  }

  @override
  Future<void> setLockScreenMessage(String message) async {
    await _storageService.storeSecure(
      RemoteCommandStorageKeys.lockScreenMessage,
      message,
    );
  }

  @override
  Future<String?> getLockScreenMessage() async {
    return await _storageService.retrieveSecure(
      RemoteCommandStorageKeys.lockScreenMessage,
    );
  }

  @override
  Future<bool> isKioskModeActive() async {
    final value = await _storageService.retrieve(
      RemoteCommandStorageKeys.kioskModeActive,
    );
    return value == true;
  }

  @override
  Future<bool> isAlarmPlaying() async {
    try {
      final result = await _alarmMethodChannel.invokeMethod<bool>('isAlarmPlaying');
      return result ?? false;
    } on PlatformException {
      return false;
    }
  }

  @override
  Future<bool> stopAlarm() async {
    return await _stopAlarmInternal();
  }

  /// Enable Kiosk Mode via native channel.
  Future<bool> _enableKioskMode() async {
    try {
      final result = await _kioskMethodChannel.invokeMethod<bool>('enableKioskMode');
      return result ?? false;
    } on PlatformException {
      return false;
    }
  }

  /// Trigger alarm via native channel.
  Future<bool> _triggerAlarm() async {
    try {
      final result = await _alarmMethodChannel.invokeMethod<bool>('triggerAlarm', {
        'duration': 120000, // 2 minutes in milliseconds
        'maxVolume': true,
        'ignoreVolumeSettings': true,
      });
      return result ?? false;
    } on PlatformException {
      return false;
    }
  }

  /// Stop alarm internally.
  Future<bool> _stopAlarmInternal() async {
    try {
      _alarmTimer?.cancel();
      _alarmTimer = null;

      final result = await _alarmMethodChannel.invokeMethod<bool>('stopAlarm');
      await _storageService.store(
        RemoteCommandStorageKeys.alarmActive,
        false,
      );
      return result ?? false;
    } on PlatformException {
      return false;
    }
  }

  /// Log a security event.
  Future<void> _logSecurityEvent(
    SecurityEventType type,
    String description,
    Map<String, dynamic> metadata,
  ) async {
    if (_securityLogService == null) return;

    Map<String, dynamic>? locationMap;
    try {
      final location = await _locationService.getCurrentLocation();
      locationMap = location.toJson();
    } catch (_) {
      // Ignore location errors
    }

    final event = SecurityEvent(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      type: type,
      timestamp: DateTime.now(),
      description: description,
      metadata: metadata,
      location: locationMap,
    );

    await _securityLogService.logEvent(event);
  }
}
