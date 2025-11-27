import 'package:flutter/material.dart';

import '../../domain/entities/location_data.dart';

/// Data class representing a daily status report.
class DailyStatusReport {
  /// Whether Protected Mode is currently active
  final bool protectedModeActive;

  /// Current battery level percentage (0-100)
  final int batteryLevel;

  /// Last known device location
  final LocationData? lastLocation;

  /// Number of security events since last report
  final int securityEventCount;

  /// Timestamp when the report was generated
  final DateTime generatedAt;

  /// Whether this is an "All OK" report (no security events)
  bool get isAllOk => securityEventCount == 0;

  /// Whether battery is low (below 15%)
  bool get isLowBattery => batteryLevel < 15;

  DailyStatusReport({
    required this.protectedModeActive,
    required this.batteryLevel,
    this.lastLocation,
    required this.securityEventCount,
    required this.generatedAt,
  });

  /// Formats the report as a string for SMS.
  ///
  /// Requirements: 25.2 - Include status, battery, location, events count
  /// Requirements: 25.4 - Send simple "All OK" message when no events
  /// Requirements: 25.5 - Include battery warning when below 15%
  String toSmsMessage() {
    final buffer = StringBuffer();
    buffer.writeln('Anti-Theft Daily Report');
    buffer.writeln('=======================');
    buffer.writeln('Status: ${protectedModeActive ? "Protected" : "Unprotected"}');
    buffer.writeln('Battery: $batteryLevel%');

    if (isLowBattery) {
      buffer.writeln('⚠️ LOW BATTERY WARNING');
    }

    if (lastLocation != null) {
      buffer.writeln('Location: ${lastLocation!.toGoogleMapsLink()}');
    }

    if (isAllOk) {
      buffer.writeln('Events: All OK - No security events');
    } else {
      buffer.writeln('Events: $securityEventCount security event(s)');
    }

    return buffer.toString();
  }

  Map<String, dynamic> toJson() {
    return {
      'protectedModeActive': protectedModeActive,
      'batteryLevel': batteryLevel,
      'lastLocation': lastLocation?.toJson(),
      'securityEventCount': securityEventCount,
      'generatedAt': generatedAt.toIso8601String(),
    };
  }
}


/// Interface for daily status report operations in the Anti-Theft Protection app.
///
/// This interface defines the contract for generating and sending daily
/// status reports to the Emergency Contact.
///
/// Requirements:
/// - 25.1: Generate status report at configurable time
/// - 25.2: Include Protected Mode status, battery level, location, events count
/// - 25.3: Send report via SMS to Emergency Contact
/// - 25.4: Send simple "All OK" message when no events
/// - 25.5: Include battery warning when below 15%
abstract class IDailyReportService {
  /// Initialize the daily report service.
  ///
  /// Sets up the scheduled report job and prepares for report generation.
  /// Must be called before any other operations.
  Future<void> initialize();

  /// Dispose of the daily report service.
  ///
  /// Cancels scheduled jobs and releases resources.
  Future<void> dispose();

  /// Set the time for daily report generation.
  ///
  /// [time] - The time of day to send the report
  ///
  /// Requirements: 25.1 - User configurable report time
  Future<void> setReportTime(TimeOfDay time);

  /// Get the currently configured report time.
  ///
  /// Returns null if no report time is configured.
  Future<TimeOfDay?> getReportTime();

  /// Enable daily status reports.
  ///
  /// Schedules the daily report job to run at the configured time.
  ///
  /// Requirements: 25.1 - Generate status report at configurable time
  Future<void> enableDailyReports();

  /// Disable daily status reports.
  ///
  /// Cancels the scheduled daily report job.
  Future<void> disableDailyReports();

  /// Check if daily reports are enabled.
  ///
  /// Returns true if daily reports are scheduled, false otherwise.
  Future<bool> isDailyReportsEnabled();

  /// Generate a status report.
  ///
  /// Creates a report with current protection status, battery level,
  /// last known location, and security events count.
  ///
  /// [since] - Optional start date for counting security events
  ///           (defaults to last 24 hours)
  ///
  /// Requirements: 25.2 - Include status, battery, location, events count
  Future<DailyStatusReport> generateReport({DateTime? since});

  /// Send the daily status report to Emergency Contact.
  ///
  /// Generates a report and sends it via SMS to the configured
  /// Emergency Contact number.
  ///
  /// Returns true if the report was sent successfully, false otherwise.
  ///
  /// Requirements: 25.3 - Send report via SMS to Emergency Contact
  Future<bool> sendDailyReport();

  /// Get the timestamp of the last sent report.
  ///
  /// Returns null if no report has been sent yet.
  Future<DateTime?> getLastReportTime();

  /// Get the count of security events since the last report.
  ///
  /// Returns the number of events that occurred since the last
  /// daily report was sent.
  Future<int> getEventCountSinceLastReport();
}
