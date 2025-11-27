import 'dart:async';
import 'dart:convert';
import 'dart:ui';

import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/entities/location_data.dart';

/// Background location tracking service using flutter_background_service.
///
/// This service handles location tracking when the app is in the background
/// or terminated. It uses a foreground service for reliable tracking.
///
/// Requirements: 5.5 - Continue tracking even when app is in background
/// Requirements: 10.4 - Use background service for reliable task scheduling
class BackgroundLocationService {
  /// Storage key for location history
  static const String locationHistoryKey = 'location_history';
  
  /// Maximum location history entries to keep
  static const int maxHistoryEntries = 1000;
  
  /// Default tracking interval in minutes
  static const int defaultIntervalMinutes = 5;
  
  /// High-frequency tracking interval in minutes
  static const int highFrequencyIntervalMinutes = 1;

  static final FlutterBackgroundService _service = FlutterBackgroundService();
  static int _currentIntervalMinutes = defaultIntervalMinutes;

  /// Initialize the background service for location tracking.
  ///
  /// Must be called once at app startup, typically in main().
  static Future<void> initialize() async {
    await _service.configure(
      androidConfiguration: AndroidConfiguration(
        onStart: onStart,
        autoStart: false,
        isForegroundMode: true,
        notificationChannelId: 'location_tracking_channel',
        initialNotificationTitle: 'Location Tracking',
        initialNotificationContent: 'Tracking location in background',
        foregroundServiceNotificationId: 888,
        foregroundServiceTypes: [AndroidForegroundType.location],
      ),
      iosConfiguration: IosConfiguration(
        autoStart: false,
        onForeground: onStart,
        onBackground: onIosBackground,
      ),
    );
  }


  /// Start periodic background location tracking.
  ///
  /// [intervalMinutes] - Interval between location captures
  static Future<void> startPeriodicTracking({
    int intervalMinutes = defaultIntervalMinutes,
  }) async {
    _currentIntervalMinutes = intervalMinutes;
    
    final isRunning = await _service.isRunning();
    if (!isRunning) {
      await _service.startService();
    }
    
    // Send interval update to the service
    _service.invoke('setInterval', {'minutes': intervalMinutes});
  }

  /// Stop periodic background location tracking.
  static Future<void> stopPeriodicTracking() async {
    final isRunning = await _service.isRunning();
    if (isRunning) {
      _service.invoke('stopService');
    }
  }

  /// Request an immediate one-time location capture.
  ///
  /// Useful for capturing location on specific events.
  static Future<void> captureLocationNow() async {
    final isRunning = await _service.isRunning();
    if (isRunning) {
      _service.invoke('captureNow');
    } else {
      // If service not running, capture directly
      await _captureAndStoreLocation();
    }
  }

  /// Cancel all background location tasks.
  static Future<void> cancelAllTasks() async {
    await stopPeriodicTracking();
  }

  /// Check if background location tracking is supported.
  ///
  /// Returns true if the device supports background location tracking.
  static Future<bool> isSupported() async {
    return true;
  }
  
  /// Check if the background service is currently running.
  static Future<bool> isRunning() async {
    return await _service.isRunning();
  }
}

/// Entry point for the background service on Android.
@pragma('vm:entry-point')
Future<void> onStart(ServiceInstance service) async {
  DartPluginRegistrant.ensureInitialized();
  
  int intervalMinutes = BackgroundLocationService.defaultIntervalMinutes;
  Timer? locationTimer;
  
  void startTimer() {
    locationTimer?.cancel();
    locationTimer = Timer.periodic(
      Duration(minutes: intervalMinutes),
      (_) => _captureAndStoreLocation(),
    );
  }
  
  // Listen for interval updates
  service.on('setInterval').listen((event) {
    if (event != null && event['minutes'] != null) {
      intervalMinutes = event['minutes'] as int;
      startTimer();
    }
  });
  
  // Listen for immediate capture requests
  service.on('captureNow').listen((_) {
    _captureAndStoreLocation();
  });
  
  // Listen for stop requests
  service.on('stopService').listen((_) {
    locationTimer?.cancel();
    service.stopSelf();
  });
  
  // Start the timer
  startTimer();
  
  // Capture location immediately on start
  await _captureAndStoreLocation();
}

/// Entry point for iOS background execution.
@pragma('vm:entry-point')
Future<bool> onIosBackground(ServiceInstance service) async {
  DartPluginRegistrant.ensureInitialized();
  await _captureAndStoreLocation();
  return true;
}

/// Capture current location and store it.
Future<void> _captureAndStoreLocation() async {
  try {
    // Check permissions
    final permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      return;
    }
    
    // Check if location services are enabled
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return;
    }
    
    // Get current position
    final position = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        timeLimit: Duration(seconds: 30),
      ),
    );
    
    // Create location data
    final location = LocationData(
      latitude: position.latitude,
      longitude: position.longitude,
      accuracy: position.accuracy,
      timestamp: DateTime.now(),
    );
    
    // Store location
    await _storeLocation(location);
  } catch (e) {
    // Silently fail - background tasks should not crash
  }
}

/// Store a location in the history.
Future<void> _storeLocation(LocationData location) async {
  try {
    final prefs = await SharedPreferences.getInstance();
    
    // Get existing history
    final historyJson = prefs.getString(BackgroundLocationService.locationHistoryKey);
    List<LocationData> history = [];
    
    if (historyJson != null && historyJson.isNotEmpty) {
      try {
        final List<dynamic> historyList = jsonDecode(historyJson);
        history = historyList
            .map((json) => LocationData.fromJson(json as Map<String, dynamic>))
            .toList();
      } catch (e) {
        // If parsing fails, start with empty history
        history = [];
      }
    }
    
    // Add new location at the beginning
    history.insert(0, location);
    
    // Trim to max entries
    if (history.length > BackgroundLocationService.maxHistoryEntries) {
      history = history.sublist(0, BackgroundLocationService.maxHistoryEntries);
    }
    
    // Save to storage
    final updatedHistoryJson = jsonEncode(
      history.map((loc) => loc.toJson()).toList(),
    );
    await prefs.setString(
      BackgroundLocationService.locationHistoryKey,
      updatedHistoryJson,
    );
  } catch (e) {
    // Silently fail
  }
}
