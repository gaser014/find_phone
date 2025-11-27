/// SMS service module for the Anti-Theft Protection app.
///
/// Provides SMS sending, receiving, and remote command handling.
///
/// Requirements:
/// - 8.1: Receive and process SMS commands
/// - 8.4: Reply with GPS coordinates and Google Maps link
/// - 8.6: Ignore commands from non-Emergency Contact numbers
/// - 8.7: Send authentication failure SMS for incorrect passwords
library;

export 'i_sms_service.dart';
export 'sms_service.dart';
