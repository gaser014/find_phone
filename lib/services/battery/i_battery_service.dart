/// Interface for Battery Optimization management.
///
/// Provides functionality to manage battery optimization settings
/// to ensure the anti-theft protection service runs reliably.
///
/// Requirements:
/// - 10.1: Use battery-efficient location tracking methods
/// - 10.3: Reduce tracking frequency to conserve power when battery is low
abstract class IBatteryService {
  /// Check if the app is exempt from battery optimization.
  ///
  /// Returns true if the app is whitelisted from battery optimization.
  Future<bool> isIgnoringBatteryOptimizations();

  /// Request battery optimization exemption.
  ///
  /// Opens the system settings to allow the user to exempt the app
  /// from battery optimization.
  ///
  /// Returns true if the request was initiated successfully.
  Future<bool> requestBatteryOptimizationExemption();

  /// Get the current battery level.
  ///
  /// Returns the battery percentage (0-100).
  Future<int> getBatteryLevel();

  /// Check if the device is currently charging.
  Future<bool> isCharging();

  /// Check if battery saver mode is enabled.
  Future<bool> isBatterySaverEnabled();

  /// Stream of battery level changes.
  Stream<int> get batteryLevelChanges;

  /// Stream of charging state changes.
  Stream<bool> get chargingStateChanges;

  /// Initialize the battery service.
  Future<void> initialize();

  /// Dispose of resources.
  Future<void> dispose();
}
