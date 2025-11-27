import 'dart:async';
import 'dart:convert';

import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/entities/location_data.dart';
import 'i_location_service.dart';

/// Implementation of [ILocationService] using Geolocator (FusedLocationProvider).
///
/// Provides location tracking with support for:
/// - Periodic location updates (default: 5 minutes)
/// - High-frequency tracking mode (30 seconds for panic mode)
/// - Location history storage with timestamps
/// - Adaptive tracking based on battery level
/// - Background tracking support
///
/// Requirements: 5.1, 5.2, 5.3, 10.1, 10.3, 21.4
class LocationService implements ILocationService {
  /// Storage key for location history
  static const String _locationHistoryKey = 'location_history';
  
  /// Storage key for tracking state
  static const String _trackingStateKey = 'location_tracking_state';
  
  /// Default tracking interval (5 minutes)
  static const Duration _defaultInterval = Duration(minutes: 5);
  
  /// High-frequency tracking interval (30 seconds for panic mode)
  static const Duration _highFrequencyInterval = Duration(seconds: 30);
  
  /// Low battery threshold for adaptive tracking
  static const int _lowBatteryThreshold = 20;
  
  /// Critical battery threshold
  static const int _criticalBatteryThreshold = 10;
  
  /// Maximum location history entries to keep
  static const int _maxHistoryEntries = 1000;

  /// Shared preferences instance for storage
  SharedPreferences? _prefs;
  
  /// Timer for periodic location updates
  Timer? _trackingTimer;
  
  /// Current tracking interval
  Duration _currentInterval = _defaultInterval;
  
  /// Whether tracking is currently active
  bool _isTracking = false;
  
  /// Whether high-frequency mode is active
  bool _isHighFrequencyMode = false;
  
  /// Whether adaptive tracking is enabled
  bool _isAdaptiveTrackingEnabled = false;
  
  /// Whether the service is initialized
  bool _isInitialized = false;
  
  /// Stream subscription for position updates
  StreamSubscription<Position>? _positionSubscription;

  @override
  bool get isTracking => _isTracking;

  @override
  bool get isHighFrequencyMode => _isHighFrequencyMode;

  @override
  Duration get currentInterval => _currentInterval;

  @override
  bool get isAdaptiveTrackingEnabled => _isAdaptiveTrackingEnabled;

  /// Check if the service is initialized
  bool get isInitialized => _isInitialized;

  @override
  Future<void> initialize() async {
    if (_isInitialized) return;
    
    _prefs = await SharedPreferences.getInstance();
    
    // Restore tracking state if it was active before
    final wasTracking = _prefs?.getBool(_trackingStateKey) ?? false;
    if (wasTracking) {
      await startTracking();
    }
    
    _isInitialized = true;
  }

  @override
  Future<void> dispose() async {
    await stopTracking();
    _positionSubscription?.cancel();
    _positionSubscription = null;
    _isInitialized = false;
  }

  @override
  Future<bool> hasLocationPermission() async {
    final permission = await Geolocator.checkPermission();
    return permission == LocationPermission.always ||
           permission == LocationPermission.whileInUse;
  }

  @override
  Future<bool> requestLocationPermission() async {
    LocationPermission permission = await Geolocator.checkPermission();
    
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    
    if (permission == LocationPermission.deniedForever) {
      // Permissions are permanently denied
      return false;
    }
    
    return permission == LocationPermission.always ||
           permission == LocationPermission.whileInUse;
  }

  @override
  Future<bool> isLocationServiceEnabled() async {
    return await Geolocator.isLocationServiceEnabled();
  }

  @override
  Future<void> startTracking({Duration interval = _defaultInterval}) async {
    if (!_isInitialized) {
      throw StateError('LocationService not initialized. Call initialize() first.');
    }
    
    if (_isTracking) {
      // Already tracking, update interval if different
      if (_currentInterval != interval && !_isHighFrequencyMode) {
        _currentInterval = interval;
        _restartTrackingTimer();
      }
      return;
    }
    
    // Check permissions
    final hasPermission = await hasLocationPermission();
    if (!hasPermission) {
      final granted = await requestLocationPermission();
      if (!granted) {
        throw Exception('Location permission not granted');
      }
    }
    
    // Check if location services are enabled
    final serviceEnabled = await isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw Exception('Location services are disabled');
    }
    
    _currentInterval = interval;
    _isTracking = true;
    
    // Save tracking state
    await _prefs?.setBool(_trackingStateKey, true);
    
    // Get initial location
    await _captureAndStoreLocation();
    
    // Start periodic tracking
    _startTrackingTimer();
  }

  @override
  Future<void> stopTracking() async {
    _trackingTimer?.cancel();
    _trackingTimer = null;
    _isTracking = false;
    _isHighFrequencyMode = false;
    _currentInterval = _defaultInterval;
    
    // Save tracking state
    await _prefs?.setBool(_trackingStateKey, false);
  }

  @override
  Future<LocationData> getCurrentLocation() async {
    final hasPermission = await hasLocationPermission();
    if (!hasPermission) {
      throw Exception('Location permission not granted');
    }
    
    final serviceEnabled = await isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw Exception('Location services are disabled');
    }
    
    final position = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        timeLimit: Duration(seconds: 30),
      ),
    );
    
    return LocationData(
      latitude: position.latitude,
      longitude: position.longitude,
      accuracy: position.accuracy,
      timestamp: DateTime.now(),
    );
  }

  @override
  Future<List<LocationData>> getLocationHistory({DateTime? since}) async {
    if (!_isInitialized) {
      throw StateError('LocationService not initialized. Call initialize() first.');
    }
    
    final historyJson = _prefs?.getString(_locationHistoryKey);
    if (historyJson == null || historyJson.isEmpty) {
      return [];
    }
    
    try {
      final List<dynamic> historyList = jsonDecode(historyJson);
      List<LocationData> locations = historyList
          .map((json) => LocationData.fromJson(json as Map<String, dynamic>))
          .toList();
      
      // Filter by date if specified
      if (since != null) {
        locations = locations
            .where((loc) => loc.timestamp.isAfter(since))
            .toList();
      }
      
      // Sort by timestamp (newest first)
      locations.sort((a, b) => b.timestamp.compareTo(a.timestamp));
      
      return locations;
    } catch (e) {
      // If parsing fails, return empty list
      return [];
    }
  }

  @override
  Future<LocationData?> getLastKnownLocation() async {
    final history = await getLocationHistory();
    return history.isNotEmpty ? history.first : null;
  }

  @override
  Future<void> enableHighFrequencyTracking() async {
    if (!_isInitialized) {
      throw StateError('LocationService not initialized. Call initialize() first.');
    }
    
    _isHighFrequencyMode = true;
    _currentInterval = _highFrequencyInterval;
    
    if (_isTracking) {
      _restartTrackingTimer();
    } else {
      await startTracking(interval: _highFrequencyInterval);
    }
  }

  @override
  Future<void> disableHighFrequencyTracking() async {
    _isHighFrequencyMode = false;
    _currentInterval = _defaultInterval;
    
    if (_isTracking) {
      _restartTrackingTimer();
    }
  }

  @override
  Future<void> clearLocationHistory() async {
    if (!_isInitialized) {
      throw StateError('LocationService not initialized. Call initialize() first.');
    }
    
    await _prefs?.remove(_locationHistoryKey);
  }

  @override
  Future<int> getLocationCount() async {
    final history = await getLocationHistory();
    return history.length;
  }

  @override
  Future<int> getBatteryLevel() async {
    // Note: In a real implementation, this would use a battery plugin
    // For now, we return a default value
    // TODO: Integrate with battery_plus package for actual battery level
    return 100;
  }

  @override
  Future<void> setAdaptiveTracking(bool enabled) async {
    _isAdaptiveTrackingEnabled = enabled;
    
    if (enabled && _isTracking) {
      await _adjustTrackingForBattery();
    }
  }

  /// Start the tracking timer with the current interval
  void _startTrackingTimer() {
    _trackingTimer?.cancel();
    _trackingTimer = Timer.periodic(_currentInterval, (_) async {
      await _captureAndStoreLocation();
      
      // Adjust for battery if adaptive tracking is enabled
      if (_isAdaptiveTrackingEnabled) {
        await _adjustTrackingForBattery();
      }
    });
  }

  /// Restart the tracking timer (used when interval changes)
  void _restartTrackingTimer() {
    _trackingTimer?.cancel();
    _startTrackingTimer();
  }

  /// Capture current location and store it in history
  Future<void> _captureAndStoreLocation() async {
    try {
      final location = await getCurrentLocation();
      await _storeLocation(location);
    } catch (e) {
      // Log error but don't stop tracking
      // In production, this would be logged to security log
    }
  }

  /// Store a location in the history
  Future<void> _storeLocation(LocationData location) async {
    if (!_isInitialized || _prefs == null) return;
    
    final history = await getLocationHistory();
    
    // Add new location at the beginning
    final updatedHistory = [location, ...history];
    
    // Trim to max entries
    final trimmedHistory = updatedHistory.length > _maxHistoryEntries
        ? updatedHistory.sublist(0, _maxHistoryEntries)
        : updatedHistory;
    
    // Save to storage
    final historyJson = jsonEncode(
      trimmedHistory.map((loc) => loc.toJson()).toList(),
    );
    await _prefs?.setString(_locationHistoryKey, historyJson);
  }

  /// Adjust tracking frequency based on battery level
  Future<void> _adjustTrackingForBattery() async {
    if (!_isAdaptiveTrackingEnabled || _isHighFrequencyMode) return;
    
    final batteryLevel = await getBatteryLevel();
    
    Duration newInterval;
    if (batteryLevel <= _criticalBatteryThreshold) {
      // Critical battery: track every 30 minutes
      newInterval = const Duration(minutes: 30);
    } else if (batteryLevel <= _lowBatteryThreshold) {
      // Low battery: track every 15 minutes
      newInterval = const Duration(minutes: 15);
    } else {
      // Normal battery: use default interval
      newInterval = _defaultInterval;
    }
    
    if (newInterval != _currentInterval) {
      _currentInterval = newInterval;
      _restartTrackingTimer();
    }
  }
}
