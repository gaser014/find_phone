/// Alert and Notification Service
///
/// Provides functionality for sending notifications and SMS alerts
/// for security events in the Anti-Theft Protection app.
///
/// Requirements:
/// - 7.3: Send notification with event details on suspicious activity
/// - 13.3: Send SMS to Emergency Contact on SIM change
/// - 17.4: Send SMS alert on 10 failed unlock attempts
/// - 18.2: Hide notification or show as system service
library alert;

export 'alert_service.dart';
export 'i_alert_service.dart';
