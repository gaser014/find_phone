import '../../domain/entities/location_data.dart';
import '../../domain/entities/remote_command.dart';

/// Callback for when an SMS command is received.
typedef SmsCommandCallback = Future<void> Function(RemoteCommand command);

/// Interface for SMS operations in the Anti-Theft Protection app.
///
/// This interface defines the contract for sending and receiving SMS messages,
/// handling remote commands, and managing emergency contact communication.
///
/// Requirements:
/// - 8.1: Receive and process SMS commands (LOCK#, WIPE#, LOCATE#, ALARM#)
/// - 8.4: Reply with GPS coordinates and Google Maps link
/// - 8.6: Ignore commands from non-Emergency Contact numbers
/// - 8.7: Send authentication failure SMS for incorrect passwords
abstract class ISmsService {
  /// Initialize the SMS service.
  ///
  /// Sets up SMS receivers and prepares for message handling.
  /// Must be called before any other operations.
  Future<void> initialize();

  /// Dispose of the SMS service.
  ///
  /// Releases resources and unregisters receivers.
  Future<void> dispose();

  /// Send an SMS message to the specified phone number.
  ///
  /// Returns true if the SMS was sent successfully, false otherwise.
  ///
  /// [phoneNumber] - The recipient's phone number
  /// [message] - The message content to send
  ///
  /// Requirements: 8.4 - Reply with current GPS coordinates
  Future<bool> sendSms(String phoneNumber, String message);

  /// Send an SMS with delivery confirmation.
  ///
  /// Returns true if the SMS was sent and delivered, false otherwise.
  /// This method waits for delivery confirmation before returning.
  ///
  /// [phoneNumber] - The recipient's phone number
  /// [message] - The message content to send
  /// [timeout] - Maximum time to wait for delivery confirmation
  ///
  /// Requirements: 8.4 - Send SMS with delivery confirmation
  Future<bool> sendSmsWithDeliveryConfirmation(
    String phoneNumber,
    String message, {
    Duration timeout = const Duration(seconds: 30),
  });

  /// Register a callback for incoming SMS commands.
  ///
  /// The callback will be invoked when a valid remote command is received.
  ///
  /// [callback] - Function to call when a command is received
  void registerCommandCallback(SmsCommandCallback callback);

  /// Unregister the SMS command callback.
  void unregisterCommandCallback();

  /// Start listening for incoming SMS messages.
  ///
  /// Begins monitoring for SMS commands from the Emergency Contact.
  ///
  /// Requirements: 8.1 - Receive SMS commands
  Future<void> startListening();

  /// Stop listening for incoming SMS messages.
  Future<void> stopListening();

  /// Check if the service is currently listening for SMS.
  bool get isListening;

  /// Handle an incoming SMS message.
  ///
  /// Parses the message, validates the sender, and processes any commands.
  /// Returns the parsed RemoteCommand if valid, null otherwise.
  ///
  /// [sender] - The phone number that sent the message
  /// [message] - The message content
  ///
  /// Requirements: 8.1, 8.6 - Parse and validate SMS commands
  Future<RemoteCommand?> handleIncomingSms(String sender, String message);

  /// Validate if a phone number is the Emergency Contact.
  ///
  /// Returns true if the number matches the stored Emergency Contact.
  ///
  /// [phoneNumber] - The phone number to validate
  ///
  /// Requirements: 8.6 - Validate Emergency Contact
  Future<bool> isEmergencyContact(String phoneNumber);

  /// Get the stored Emergency Contact number.
  ///
  /// Returns null if no Emergency Contact is configured.
  Future<String?> getEmergencyContact();

  /// Set the Emergency Contact number.
  ///
  /// [phoneNumber] - The phone number to set as Emergency Contact
  ///
  /// Requirements: 16.2 - Store Emergency Contact encrypted
  Future<void> setEmergencyContact(String phoneNumber);

  /// Validate a phone number format.
  ///
  /// Returns true if the phone number is in a valid format.
  ///
  /// [phoneNumber] - The phone number to validate
  ///
  /// Requirements: 16.2 - Validate phone number format
  bool validatePhoneNumber(String phoneNumber);

  /// Send location information via SMS.
  ///
  /// Sends the current location with GPS coordinates, accuracy,
  /// timestamp, and Google Maps link.
  ///
  /// [phoneNumber] - The recipient's phone number
  /// [location] - The location data to send
  ///
  /// Requirements: 8.4 - Reply with GPS coordinates and Google Maps link
  Future<bool> sendLocationSms(String phoneNumber, LocationData location);

  /// Send an authentication failure response.
  ///
  /// Notifies the sender that their command failed due to incorrect password.
  ///
  /// [phoneNumber] - The recipient's phone number
  ///
  /// Requirements: 8.7 - Send SMS reply indicating authentication failure
  Future<bool> sendAuthenticationFailureSms(String phoneNumber);

  /// Send a command execution confirmation.
  ///
  /// Notifies the sender that their command was executed successfully.
  ///
  /// [phoneNumber] - The recipient's phone number
  /// [commandType] - The type of command that was executed
  Future<bool> sendCommandConfirmationSms(
    String phoneNumber,
    RemoteCommandType commandType,
  );

  /// Send daily status report via SMS.
  ///
  /// Sends a summary of protection status, battery level, location,
  /// and security events count.
  ///
  /// [phoneNumber] - The recipient's phone number
  /// [protectedModeActive] - Whether Protected Mode is enabled
  /// [batteryLevel] - Current battery percentage
  /// [location] - Last known location
  /// [eventCount] - Number of security events since last report
  ///
  /// Requirements: 25.2, 25.3 - Send status report via SMS
  Future<bool> sendDailyStatusReport(
    String phoneNumber, {
    required bool protectedModeActive,
    required int batteryLevel,
    LocationData? location,
    required int eventCount,
  });

  /// Check if SMS permissions are granted.
  ///
  /// Returns true if the app has SMS send and receive permissions.
  Future<bool> hasSmsPermission();

  /// Request SMS permissions.
  ///
  /// Prompts the user to grant SMS permissions.
  /// Returns true if permissions were granted, false otherwise.
  Future<bool> requestSmsPermission();
}
