/// Interface for authentication operations in the Anti-Theft Protection app.
///
/// This interface defines the contract for managing user authentication,
/// including password setup, verification, and failed attempt tracking.
///
/// Requirements:
/// - 1.1: Create Master Password with minimum 8 characters including letters and numbers
/// - 1.2: Validate password strength and store securely using SHA-256 hashing with salt
/// - 1.4: Require Master Password for configuration changes or app exit
/// - 1.5: Trigger security alert after 3 consecutive incorrect password attempts
/// - 1.6: Reset failed attempt counter on successful login
abstract class IAuthenticationService {
  /// Initialize master password on first run.
  ///
  /// Creates a new master password for the application.
  /// The password must meet strength requirements (min 8 chars, letters and numbers).
  ///
  /// Returns true if password was successfully set, false otherwise.
  ///
  /// [password] - The password to set as master password
  ///
  /// Requirements: 1.1, 1.2
  Future<bool> setupMasterPassword(String password);

  /// Verify the provided password against the stored master password.
  ///
  /// Returns true if the password matches, false otherwise.
  /// On failure, increments the failed attempt counter.
  /// On success, resets the failed attempt counter.
  ///
  /// [password] - The password to verify
  ///
  /// Requirements: 1.4, 1.6
  Future<bool> verifyPassword(String password);

  /// Check if a master password has been set.
  ///
  /// Returns true if a password exists, false otherwise.
  Future<bool> isPasswordSet();

  /// Change the master password.
  ///
  /// Requires verification of the old password before setting the new one.
  /// The new password must meet strength requirements.
  ///
  /// Returns true if password was successfully changed, false otherwise.
  ///
  /// [oldPassword] - The current master password for verification
  /// [newPassword] - The new password to set
  ///
  /// Requirements: 1.2
  Future<bool> changeMasterPassword(String oldPassword, String newPassword);

  /// Record a failed authentication attempt.
  ///
  /// Increments the failed attempt counter and stores the timestamp.
  ///
  /// Requirements: 1.5
  Future<void> recordFailedAttempt();

  /// Get the current count of consecutive failed attempts.
  ///
  /// Returns the number of failed attempts since last successful login.
  ///
  /// Requirements: 1.5
  Future<int> getFailedAttemptsCount();

  /// Reset the failed attempts counter to zero.
  ///
  /// Called after successful authentication.
  ///
  /// Requirements: 1.6
  Future<void> resetFailedAttempts();

  /// Check if the account is locked due to too many failed attempts.
  ///
  /// Returns true if the failed attempt threshold (3) has been reached.
  ///
  /// Requirements: 1.5
  Future<bool> isLocked();

  /// Validate password strength.
  ///
  /// Password must be at least 8 characters and contain both letters and numbers.
  ///
  /// Returns true if password meets requirements, false otherwise.
  ///
  /// [password] - The password to validate
  ///
  /// Requirements: 1.1
  bool validatePasswordStrength(String password);

  /// Get the timestamp of the last failed attempt.
  ///
  /// Returns null if no failed attempts have been recorded.
  Future<DateTime?> getLastFailedAttemptTime();

  /// Check if security alert should be triggered.
  ///
  /// Returns true if failed attempts have reached the threshold (3).
  ///
  /// Requirements: 1.5
  Future<bool> shouldTriggerSecurityAlert();
}
