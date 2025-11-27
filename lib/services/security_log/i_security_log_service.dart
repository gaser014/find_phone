import 'dart:io';

import '../../domain/entities/security_event.dart';

/// Interface for security log operations in the Anti-Theft Protection app.
///
/// This interface defines the contract for logging, retrieving, and managing
/// security events. All events are stored in an encrypted database.
///
/// Requirements: 4.3 - Record unauthorized access events in secure log storage
abstract class ISecurityLogService {
  /// Log a security event.
  ///
  /// Creates a new security event record with the provided details.
  /// The event is stored in encrypted storage with all metadata.
  ///
  /// [event] - The security event to log
  ///
  /// Requirements: 4.1 - Log attempts with timestamp and location
  Future<void> logEvent(SecurityEvent event);

  /// Get all security events.
  ///
  /// Returns all logged security events in chronological order.
  ///
  /// Requirements: 9.4 - Display events in chronological order
  Future<List<SecurityEvent>> getAllEvents();

  /// Get security events by type.
  ///
  /// Returns all events matching the specified type.
  ///
  /// [type] - The type of events to retrieve
  ///
  /// Requirements: 9.4 - Display events with filtering options
  Future<List<SecurityEvent>> getEventsByType(SecurityEventType type);

  /// Get security events within a date range.
  ///
  /// Returns all events that occurred between the start and end dates.
  ///
  /// [start] - The start of the date range (inclusive)
  /// [end] - The end of the date range (inclusive)
  ///
  /// Requirements: 9.4 - Display events with filtering options
  Future<List<SecurityEvent>> getEventsByDateRange(DateTime start, DateTime end);

  /// Get security events by type within a date range.
  ///
  /// Returns events matching both the type and date range criteria.
  ///
  /// [type] - The type of events to retrieve
  /// [start] - The start of the date range (inclusive)
  /// [end] - The end of the date range (inclusive)
  Future<List<SecurityEvent>> getEventsByTypeAndDateRange(
    SecurityEventType type,
    DateTime start,
    DateTime end,
  );

  /// Get a single security event by ID.
  ///
  /// Returns the event with the specified ID, or null if not found.
  ///
  /// [id] - The unique identifier of the event
  Future<SecurityEvent?> getEventById(String id);

  /// Get the count of security events.
  ///
  /// Returns the total number of logged events.
  Future<int> getEventCount();

  /// Get the count of security events by type.
  ///
  /// [type] - The type of events to count
  Future<int> getEventCountByType(SecurityEventType type);

  /// Clear all security logs.
  ///
  /// This is a destructive operation that removes all logged events.
  /// Requires password verification before execution.
  ///
  /// [password] - The master password for verification
  ///
  /// Returns true if logs were cleared successfully, false if password invalid
  Future<bool> clearLogs(String password);

  /// Export security logs as an encrypted file.
  ///
  /// Creates an encrypted backup file containing all security logs.
  ///
  /// [password] - The password to use for encryption
  ///
  /// Returns the exported file
  ///
  /// Requirements: 15.1 - Export all settings and logs as encrypted file
  Future<File> exportLogs(String password);

  /// Import security logs from an encrypted file.
  ///
  /// Restores security logs from a previously exported backup file.
  ///
  /// [file] - The encrypted backup file to import
  /// [password] - The password to decrypt the file
  ///
  /// Returns true if import was successful, false otherwise
  Future<bool> importLogs(File file, String password);

  /// Get the most recent security events.
  ///
  /// Returns the specified number of most recent events.
  ///
  /// [limit] - Maximum number of events to return
  Future<List<SecurityEvent>> getRecentEvents(int limit);

  /// Delete a specific security event.
  ///
  /// [id] - The unique identifier of the event to delete
  ///
  /// Returns true if the event was deleted, false if not found
  Future<bool> deleteEvent(String id);

  /// Initialize the security log service.
  ///
  /// Sets up the encrypted database and prepares for logging.
  /// Must be called before any other operations.
  ///
  /// [encryptionKey] - The key to use for database encryption
  Future<void> initialize(String encryptionKey);

  /// Close the security log service.
  ///
  /// Releases resources and closes the database connection.
  Future<void> close();

  /// Check if the service is initialized.
  bool get isInitialized;
}
