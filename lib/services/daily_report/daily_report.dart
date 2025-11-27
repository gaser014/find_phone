/// Daily status report service for the Anti-Theft Protection app.
///
/// This module provides functionality for generating and sending
/// daily status reports to the Emergency Contact.
///
/// Requirements:
/// - 25.1: Generate status report at configurable time
/// - 25.2: Include Protected Mode status, battery level, location, events count
/// - 25.3: Send report via SMS to Emergency Contact
/// - 25.4: Send simple "All OK" message when no events
/// - 25.5: Include battery warning when below 15%
library daily_report;

export 'i_daily_report_service.dart';
export 'daily_report_service.dart';
