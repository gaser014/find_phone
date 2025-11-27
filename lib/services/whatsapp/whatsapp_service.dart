import 'dart:async';

import 'package:flutter/services.dart';

import '../../domain/entities/location_data.dart';
import '../location/i_location_service.dart';
import '../storage/i_storage_service.dart';
import 'i_whatsapp_service.dart';

/// Storage keys for WhatsApp service data.
class WhatsAppStorageKeys {
  static const String whatsAppContact = 'whatsapp_contact';
  static const String lastSentLocation = 'whatsapp_last_sent_location';
  static const String isPanicMode = 'whatsapp_panic_mode';
}

/// Implementation of IWhatsAppService.
///
/// Provides WhatsApp messaging functionality for location sharing with support for:
/// - Periodic location updates (default: 15 minutes)
/// - Significant location change detection (100m threshold)
/// - Panic mode with increased frequency (2 minutes)
/// - SMS fallback when WhatsApp is unavailable
///
/// Requirements: 26.1, 26.2, 26.3, 26.4, 26.5
class WhatsAppService implements IWhatsAppService {
  static const String _whatsAppChannel = 'com.example.find_phone/whatsapp';

  final IStorageService _storageService;
  final ILocationService _locationService;

  final MethodChannel _methodChannel = const MethodChannel(_whatsAppChannel);

  /// Timer for periodic location sharing.
  Timer? _periodicTimer;

  /// Current sharing interval.
  Duration _currentInterval = IWhatsAppService.defaultInterval;

  /// Whether periodic sharing is active.
  bool _isPeriodicSharingActive = false;

  /// Whether panic mode is active.
  bool _isPanicModeActive = false;

  /// Last sent location for significant change detection.
  LocationData? _lastSentLocation;

  /// Phone number for periodic sharing.
  String? _periodicSharingPhoneNumber;

  /// SMS fallback callback.
  Future<bool> Function(String phoneNumber, String message)? _smsFallbackCallback;

  /// Whether the service is initialized.
  bool _isInitialized = false;

  WhatsAppService({
    required IStorageService storageService,
    required ILocationService locationService,
  })  : _storageService = storageService,
        _locationService = locationService;

  @override
  Future<void> initialize() async {
    if (_isInitialized) return;

    // Load last sent location from storage
    final lastLocationJson = await _storageService.retrieve(
      WhatsAppStorageKeys.lastSentLocation,
    );
    if (lastLocationJson != null && lastLocationJson is Map<String, dynamic>) {
      _lastSentLocation = LocationData.fromJson(lastLocationJson);
    }

    // Load panic mode state
    final panicModeStr = await _storageService.retrieveSecure(
      WhatsAppStorageKeys.isPanicMode,
    );
    _isPanicModeActive = panicModeStr == 'true';

    _isInitialized = true;
  }

  @override
  Future<void> dispose() async {
    await stopPeriodicLocationSharing();
    _isInitialized = false;
  }

  @override
  Future<bool> isWhatsAppInstalled() async {
    try {
      final result = await _methodChannel.invokeMethod<bool>('isWhatsAppInstalled');
      return result ?? false;
    } on PlatformException {
      return false;
    }
  }

  @override
  Future<bool> sendMessage(String phoneNumber, String message) async {
    try {
      // First check if WhatsApp is installed
      final isInstalled = await isWhatsAppInstalled();
      
      if (!isInstalled) {
        // Try SMS fallback
        return await _trySendViaSms(phoneNumber, message);
      }

      // Send via WhatsApp Intent
      final result = await _methodChannel.invokeMethod<bool>('sendWhatsAppMessage', {
        'phoneNumber': _normalizePhoneNumber(phoneNumber),
        'message': message,
      });

      if (result == true) {
        return true;
      }

      // If WhatsApp send failed, try SMS fallback
      return await _trySendViaSms(phoneNumber, message);
    } on PlatformException {
      // Try SMS fallback on error
      return await _trySendViaSms(phoneNumber, message);
    }
  }

  @override
  Future<bool> sendLocationMessage(
    String phoneNumber,
    LocationData location,
    int batteryLevel,
  ) async {
    final message = formatLocationMessage(location, batteryLevel);
    final success = await sendMessage(phoneNumber, message);

    if (success) {
      // Update last sent location
      _lastSentLocation = location;
      await _saveLastSentLocation(location);
    }

    return success;
  }

  @override
  String formatLocationMessage(LocationData location, int batteryLevel) {
    final buffer = StringBuffer();
    
    buffer.writeln('📍 Anti-Theft Location Update');
    buffer.writeln('');
    buffer.writeln('🌐 GPS: ${location.latitude.toStringAsFixed(6)}, ${location.longitude.toStringAsFixed(6)}');
    buffer.writeln('📏 Accuracy: ${location.accuracy.toStringAsFixed(0)}m');
    buffer.writeln('🔋 Battery: $batteryLevel%');
    buffer.writeln('🕐 Time: ${_formatTimestamp(location.timestamp)}');
    buffer.writeln('');
    buffer.writeln('🗺️ Map: ${location.toGoogleMapsLink()}');
    
    if (batteryLevel < 15) {
      buffer.writeln('');
      buffer.writeln('⚠️ LOW BATTERY WARNING');
    }

    return buffer.toString();
  }

  @override
  Future<void> startPeriodicLocationSharing({
    required String phoneNumber,
    Duration interval = const Duration(minutes: 15),
  }) async {
    // Stop any existing periodic sharing
    await stopPeriodicLocationSharing();

    _periodicSharingPhoneNumber = phoneNumber;
    _currentInterval = _isPanicModeActive 
        ? IWhatsAppService.panicModeInterval 
        : interval;
    _isPeriodicSharingActive = true;

    // Send initial location
    await _sendPeriodicLocation();

    // Start periodic timer
    _periodicTimer = Timer.periodic(_currentInterval, (_) async {
      await _sendPeriodicLocation();
    });
  }

  @override
  Future<void> stopPeriodicLocationSharing() async {
    _periodicTimer?.cancel();
    _periodicTimer = null;
    _isPeriodicSharingActive = false;
    _periodicSharingPhoneNumber = null;
  }

  @override
  bool get isPeriodicSharingActive => _isPeriodicSharingActive;

  @override
  Duration get currentInterval => _currentInterval;

  @override
  Future<void> enablePanicMode() async {
    _isPanicModeActive = true;
    _currentInterval = IWhatsAppService.panicModeInterval;

    // Save panic mode state
    await _storageService.storeSecure(
      WhatsAppStorageKeys.isPanicMode,
      'true',
    );

    // Restart periodic sharing with new interval if active
    if (_isPeriodicSharingActive && _periodicSharingPhoneNumber != null) {
      await startPeriodicLocationSharing(
        phoneNumber: _periodicSharingPhoneNumber!,
        interval: IWhatsAppService.panicModeInterval,
      );
    }
  }

  @override
  Future<void> disablePanicMode() async {
    _isPanicModeActive = false;
    _currentInterval = IWhatsAppService.defaultInterval;

    // Save panic mode state
    await _storageService.storeSecure(
      WhatsAppStorageKeys.isPanicMode,
      'false',
    );

    // Restart periodic sharing with normal interval if active
    if (_isPeriodicSharingActive && _periodicSharingPhoneNumber != null) {
      await startPeriodicLocationSharing(
        phoneNumber: _periodicSharingPhoneNumber!,
        interval: IWhatsAppService.defaultInterval,
      );
    }
  }

  @override
  bool get isPanicModeActive => _isPanicModeActive;

  @override
  bool isSignificantLocationChange(LocationData newLocation) {
    if (_lastSentLocation == null) {
      return true; // First location is always significant
    }

    final distance = _lastSentLocation!.distanceTo(newLocation);
    return distance >= IWhatsAppService.significantChangeThreshold;
  }

  @override
  Future<void> handleSignificantLocationChange(
    String phoneNumber,
    LocationData location,
    int batteryLevel,
  ) async {
    if (isSignificantLocationChange(location)) {
      await sendLocationMessage(phoneNumber, location, batteryLevel);
    }
  }

  @override
  LocationData? get lastSentLocation => _lastSentLocation;

  @override
  void setSmsFallback(
    Future<bool> Function(String phoneNumber, String message) smsFallbackCallback,
  ) {
    _smsFallbackCallback = smsFallbackCallback;
  }

  @override
  Future<String?> getWhatsAppContact() async {
    return await _storageService.retrieveSecure(WhatsAppStorageKeys.whatsAppContact);
  }

  @override
  Future<void> setWhatsAppContact(String phoneNumber) async {
    await _storageService.storeSecure(
      WhatsAppStorageKeys.whatsAppContact,
      phoneNumber,
    );
  }

  /// Send periodic location update.
  Future<void> _sendPeriodicLocation() async {
    if (_periodicSharingPhoneNumber == null) return;

    try {
      final location = await _locationService.getCurrentLocation();
      final batteryLevel = await _locationService.getBatteryLevel();

      // Check for significant location change
      if (isSignificantLocationChange(location)) {
        await sendLocationMessage(
          _periodicSharingPhoneNumber!,
          location,
          batteryLevel,
        );
      } else {
        // Still send periodic update even if not significant
        await sendLocationMessage(
          _periodicSharingPhoneNumber!,
          location,
          batteryLevel,
        );
      }
    } catch (e) {
      // Log error but don't stop periodic sharing
      // In production, this would be logged to security log
    }
  }

  /// Try to send message via SMS fallback.
  Future<bool> _trySendViaSms(String phoneNumber, String message) async {
    if (_smsFallbackCallback != null) {
      return await _smsFallbackCallback!(phoneNumber, message);
    }
    return false;
  }

  /// Save last sent location to storage.
  Future<void> _saveLastSentLocation(LocationData location) async {
    await _storageService.store(
      WhatsAppStorageKeys.lastSentLocation,
      location.toJson(),
    );
  }

  /// Normalize phone number for WhatsApp.
  String _normalizePhoneNumber(String phoneNumber) {
    // Remove all non-digit characters except leading +
    final hasPlus = phoneNumber.startsWith('+');
    final digits = phoneNumber.replaceAll(RegExp(r'[^\d]'), '');
    return hasPlus ? '+$digits' : digits;
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
}
