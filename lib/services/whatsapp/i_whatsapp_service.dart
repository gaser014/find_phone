import '../../domain/entities/location_data.dart';

/// Interface for WhatsApp messaging operations in the Anti-Theft Protection app.
///
/// This interface defines the contract for sending location updates via WhatsApp,
/// with support for periodic updates, significant location changes, and panic mode.
///
/// Requirements:
/// - 26.1: Send location via WhatsApp every 15 minutes
/// - 26.2: Include GPS coordinates, Google Maps link, battery level, and timestamp
/// - 26.3: Send immediate update when location changes significantly (100m)
/// - 26.4: Fallback to SMS when WhatsApp unavailable
/// - 26.5: Increase frequency to every 2 minutes in panic mode
abstract class IWhatsAppService {
  /// Initialize the WhatsApp service.
  ///
  /// Sets up message sending capabilities and prepares for location sharing.
  /// Must be called before any other operations.
  Future<void> initialize();

  /// Dispose of the WhatsApp service.
  ///
  /// Releases resources and stops any active location sharing.
  Future<void> dispose();

  /// Check if WhatsApp is installed on the device.
  ///
  /// Returns true if WhatsApp is available, false otherwise.
  Future<bool> isWhatsAppInstalled();

  /// Send a message via WhatsApp to the specified phone number.
  ///
  /// Returns true if the message was sent successfully, false otherwise.
  ///
  /// [phoneNumber] - The recipient's phone number (with country code)
  /// [message] - The message content to send
  ///
  /// Requirements: 26.1 - Send location via WhatsApp
  Future<bool> sendMessage(String phoneNumber, String message);

  /// Send location information via WhatsApp.
  ///
  /// Sends the current location with GPS coordinates, Google Maps link,
  /// battery level, and timestamp.
  ///
  /// [phoneNumber] - The recipient's phone number
  /// [location] - The location data to send
  /// [batteryLevel] - Current battery percentage
  ///
  /// Requirements: 26.2 - Include GPS, Maps link, battery, timestamp
  Future<bool> sendLocationMessage(
    String phoneNumber,
    LocationData location,
    int batteryLevel,
  );

  /// Format a location message for WhatsApp.
  ///
  /// Creates a formatted message string with all required information.
  ///
  /// [location] - The location data to format
  /// [batteryLevel] - Current battery percentage
  ///
  /// Requirements: 26.2 - Format with GPS, Maps link, battery, timestamp
  String formatLocationMessage(LocationData location, int batteryLevel);

  /// Start periodic location sharing.
  ///
  /// Begins sending location updates at the specified interval.
  /// Default interval is 15 minutes as per requirements.
  ///
  /// [phoneNumber] - The recipient's phone number
  /// [interval] - Duration between location updates (default: 15 minutes)
  ///
  /// Requirements: 26.1 - Send location every 15 minutes
  Future<void> startPeriodicLocationSharing({
    required String phoneNumber,
    Duration interval = const Duration(minutes: 15),
  });

  /// Stop periodic location sharing.
  Future<void> stopPeriodicLocationSharing();

  /// Check if periodic location sharing is active.
  bool get isPeriodicSharingActive;

  /// Get the current sharing interval.
  Duration get currentInterval;

  /// Enable panic mode location sharing.
  ///
  /// Increases location update frequency to every 2 minutes.
  ///
  /// Requirements: 26.5 - Increase frequency to every 2 minutes in panic mode
  Future<void> enablePanicMode();

  /// Disable panic mode location sharing.
  ///
  /// Returns to normal 15-minute interval.
  Future<void> disablePanicMode();

  /// Check if panic mode is active.
  bool get isPanicModeActive;

  /// Check for significant location change.
  ///
  /// Returns true if the new location is more than 100 meters from the last sent location.
  ///
  /// [newLocation] - The new location to check
  ///
  /// Requirements: 26.3 - Detect significant location change (100m threshold)
  bool isSignificantLocationChange(LocationData newLocation);

  /// Handle significant location change.
  ///
  /// Sends an immediate location update when a significant change is detected.
  ///
  /// [phoneNumber] - The recipient's phone number
  /// [location] - The new location
  /// [batteryLevel] - Current battery percentage
  ///
  /// Requirements: 26.3 - Send immediate update on significant change
  Future<void> handleSignificantLocationChange(
    String phoneNumber,
    LocationData location,
    int batteryLevel,
  );

  /// Get the last sent location.
  ///
  /// Returns the most recently sent location, or null if none sent.
  LocationData? get lastSentLocation;

  /// Set the SMS fallback service.
  ///
  /// Configures the service to use SMS when WhatsApp is unavailable.
  ///
  /// [smsFallbackCallback] - Callback to send SMS when WhatsApp fails
  ///
  /// Requirements: 26.4 - Fallback to SMS when WhatsApp unavailable
  void setSmsFallback(Future<bool> Function(String phoneNumber, String message) smsFallbackCallback);

  /// Get the predefined WhatsApp contact number.
  ///
  /// Returns the configured WhatsApp contact number for location sharing.
  Future<String?> getWhatsAppContact();

  /// Set the WhatsApp contact number.
  ///
  /// [phoneNumber] - The phone number to set as WhatsApp contact
  Future<void> setWhatsAppContact(String phoneNumber);

  /// Significant location change threshold in meters.
  static const double significantChangeThreshold = 100.0;

  /// Default periodic sharing interval (15 minutes).
  static const Duration defaultInterval = Duration(minutes: 15);

  /// Panic mode sharing interval (2 minutes).
  static const Duration panicModeInterval = Duration(minutes: 2);
}
