import '../../domain/entities/location_data.dart';

/// Interface for location tracking operations in the Anti-Theft Protection app.
///
/// This interface defines the contract for tracking device location,
/// managing location history, and supporting different tracking modes.
///
/// Requirements: 5.1 - Request location permissions when Protected Mode is enabled
abstract class ILocationService {
  /// Start location tracking with the specified interval.
  ///
  /// Begins periodic location updates at the given interval.
  /// Default interval is 5 minutes as per requirements.
  ///
  /// [interval] - Duration between location updates (default: 5 minutes)
  ///
  /// Requirements: 5.2 - Track device location every 5 minutes
  Future<void> startTracking({Duration interval = const Duration(minutes: 5)});

  /// Stop location tracking.
  ///
  /// Stops all periodic location updates.
  Future<void> stopTracking();

  /// Check if location tracking is currently active.
  ///
  /// Returns true if tracking is running, false otherwise.
  bool get isTracking;

  /// Get the current device location.
  ///
  /// Returns the current location with GPS coordinates, accuracy, and timestamp.
  /// Throws an exception if location cannot be obtained.
  ///
  /// Requirements: 8.4 - Reply with current GPS coordinates
  Future<LocationData> getCurrentLocation();

  /// Get location history.
  ///
  /// Returns all stored location records, optionally filtered by date.
  ///
  /// [since] - Optional start date to filter locations
  ///
  /// Requirements: 5.3 - Store new location with timestamp
  Future<List<LocationData>> getLocationHistory({DateTime? since});

  /// Get the most recent stored location.
  ///
  /// Returns the last recorded location, or null if no history exists.
  Future<LocationData?> getLastKnownLocation();

  /// Enable high-frequency tracking mode.
  ///
  /// Switches to 30-second intervals for panic mode situations.
  ///
  /// Requirements: 21.4 - Start continuous location tracking every 30 seconds
  Future<void> enableHighFrequencyTracking();

  /// Disable high-frequency tracking mode.
  ///
  /// Returns to normal tracking interval.
  Future<void> disableHighFrequencyTracking();

  /// Check if high-frequency tracking is active.
  ///
  /// Returns true if in high-frequency mode, false otherwise.
  bool get isHighFrequencyMode;

  /// Get the current tracking interval.
  ///
  /// Returns the duration between location updates.
  Duration get currentInterval;

  /// Clear all location history.
  ///
  /// Removes all stored location records.
  Future<void> clearLocationHistory();

  /// Get the count of stored locations.
  ///
  /// Returns the total number of location records in history.
  Future<int> getLocationCount();

  /// Initialize the location service.
  ///
  /// Sets up location providers and prepares for tracking.
  /// Must be called before any other operations.
  Future<void> initialize();

  /// Dispose of the location service.
  ///
  /// Releases resources and stops any active tracking.
  Future<void> dispose();

  /// Check if location permissions are granted.
  ///
  /// Returns true if the app has location permissions, false otherwise.
  Future<bool> hasLocationPermission();

  /// Request location permissions.
  ///
  /// Prompts the user to grant location permissions.
  /// Returns true if permissions were granted, false otherwise.
  ///
  /// Requirements: 5.1 - Request location permissions
  Future<bool> requestLocationPermission();

  /// Check if location services are enabled on the device.
  ///
  /// Returns true if GPS/location services are enabled, false otherwise.
  Future<bool> isLocationServiceEnabled();

  /// Get the current battery level.
  ///
  /// Returns battery percentage (0-100) for adaptive tracking.
  ///
  /// Requirements: 10.3 - Reduce tracking frequency to conserve power
  Future<int> getBatteryLevel();

  /// Set adaptive tracking based on battery level.
  ///
  /// Automatically adjusts tracking frequency based on battery status.
  /// When battery is low, tracking frequency is reduced.
  ///
  /// [enabled] - Whether to enable adaptive tracking
  ///
  /// Requirements: 10.3 - Reduce tracking frequency to conserve power
  Future<void> setAdaptiveTracking(bool enabled);

  /// Check if adaptive tracking is enabled.
  bool get isAdaptiveTrackingEnabled;
}
