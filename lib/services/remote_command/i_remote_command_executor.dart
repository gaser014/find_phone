import '../../domain/entities/remote_command.dart';

/// Result of a remote command execution.
class RemoteCommandResult {
  /// Whether the command was executed successfully.
  final bool success;

  /// Message describing the result.
  final String message;

  /// Additional data returned by the command (e.g., location data).
  final Map<String, dynamic>? data;

  RemoteCommandResult({
    required this.success,
    required this.message,
    this.data,
  });

  @override
  String toString() {
    return 'RemoteCommandResult(success: $success, message: $message, data: $data)';
  }
}

/// Interface for executing remote commands received via SMS.
///
/// This service handles the execution of remote commands:
/// - LOCK: Lock device and enable Kiosk Mode (Requirements 8.1, 8.2)
/// - WIPE: Factory reset via Device Admin (Requirement 8.3)
/// - LOCATE: Reply with GPS coordinates and Maps link (Requirement 8.4)
/// - ALARM: Trigger 2-minute max volume alarm (Requirement 8.5)
///
/// Requirements: 8.1, 8.2, 8.3, 8.4, 8.5
abstract class IRemoteCommandExecutor {
  /// Initialize the remote command executor.
  Future<void> initialize();

  /// Dispose of resources.
  Future<void> dispose();

  /// Execute a remote command.
  ///
  /// [command] - The validated remote command to execute.
  /// Returns a [RemoteCommandResult] indicating success or failure.
  Future<RemoteCommandResult> executeCommand(RemoteCommand command);

  /// Execute LOCK command.
  ///
  /// Locks the device and enables Kiosk Mode.
  /// Optionally displays a custom message on the lock screen.
  ///
  /// [customMessage] - Optional message to display on lock screen.
  ///
  /// Requirements: 8.1, 8.2
  Future<RemoteCommandResult> executeLockCommand({String? customMessage});

  /// Execute WIPE command.
  ///
  /// Performs factory reset via Device Admin.
  /// WARNING: This will erase ALL user data!
  ///
  /// Requirement: 8.3
  Future<RemoteCommandResult> executeWipeCommand();

  /// Execute LOCATE command.
  ///
  /// Gets current GPS location and returns it with Google Maps link.
  ///
  /// Requirement: 8.4
  Future<RemoteCommandResult> executeLocateCommand();

  /// Execute ALARM command.
  ///
  /// Triggers maximum volume alarm for 2 minutes.
  ///
  /// Requirement: 8.5
  Future<RemoteCommandResult> executeAlarmCommand();

  /// Set custom lock screen message.
  ///
  /// [message] - Message to display on lock screen.
  ///
  /// Requirement: 8.2
  Future<void> setLockScreenMessage(String message);

  /// Get the current lock screen message.
  Future<String?> getLockScreenMessage();

  /// Check if Kiosk Mode is currently active.
  Future<bool> isKioskModeActive();

  /// Check if an alarm is currently playing.
  Future<bool> isAlarmPlaying();

  /// Stop the currently playing alarm.
  ///
  /// Requires password verification before stopping.
  Future<bool> stopAlarm();
}
