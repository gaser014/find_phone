/// Interface for Alarm Service
///
/// Provides functionality for triggering and managing loud alarms
/// for anti-theft protection.
///
/// Requirements: 7.1, 7.2, 7.4, 7.5, 8.5
abstract class IAlarmService {
  /// Initialize the alarm service.
  Future<void> initialize();

  /// Dispose of resources.
  Future<void> dispose();

  /// Trigger a loud alarm at maximum volume.
  ///
  /// [duration] - How long the alarm should play (default: continuous/infinite).
  /// [ignoreVolumeSettings] - If true, plays at max volume regardless of device settings.
  /// [continuous] - If true, alarm plays until explicitly stopped (ignores duration).
  /// [reason] - The reason for triggering the alarm (for logging).
  ///
  /// Requirements: 7.1, 7.4, 8.5
  Future<bool> triggerAlarm({
    Duration duration = const Duration(minutes: 2),
    bool ignoreVolumeSettings = true,
    bool continuous = false,
    String? reason,
  });

  /// Trigger a continuous alarm that plays until password is entered.
  ///
  /// This alarm ignores volume settings and plays at maximum volume.
  /// It will continue playing until [stopAlarmWithPassword] is called
  /// with the correct password.
  ///
  /// [reason] - The reason for triggering the alarm (for logging).
  ///
  /// Requirements: 7.1, 7.2, 7.4
  Future<bool> triggerContinuousAlarm({String? reason});

  /// Stop the currently playing alarm.
  ///
  /// Requirement: 7.5
  Future<bool> stopAlarm();

  /// Check if an alarm is currently playing.
  Future<bool> isAlarmPlaying();

  /// Check if the current alarm requires password to stop.
  ///
  /// Returns true if the alarm was triggered as continuous and
  /// requires password authentication to stop.
  Future<bool> requiresPasswordToStop();

  /// Get the reason why the alarm was triggered.
  ///
  /// Returns null if no alarm is playing or no reason was provided.
  Future<String?> getAlarmReason();

  /// Get the remaining duration of the current alarm.
  ///
  /// Returns Duration.zero if no alarm is playing or if alarm is continuous.
  Future<Duration> getRemainingDuration();

  /// Set the alarm sound resource.
  ///
  /// [soundPath] - Path to the alarm sound file.
  Future<void> setAlarmSound(String soundPath);

  /// Check if the alarm service has audio permissions.
  Future<bool> hasAudioPermission();

  /// Request audio permissions.
  Future<bool> requestAudioPermission();

  /// Get the time when the alarm was triggered.
  ///
  /// Returns null if no alarm is playing.
  DateTime? getAlarmStartTime();

  /// Attempt to stop the alarm with password verification.
  ///
  /// This method should be used when the alarm requires password to stop.
  /// It verifies the password and stops the alarm if correct.
  ///
  /// [verifyPassword] - A function that verifies the password and returns true if correct.
  /// [password] - The password to verify.
  ///
  /// Returns true if the alarm was stopped (password was correct),
  /// false if the password was incorrect or no alarm is playing.
  ///
  /// Requirement: 7.5
  Future<bool> stopAlarmWithPassword(
    Future<bool> Function(String) verifyPassword,
    String password,
  );
}
