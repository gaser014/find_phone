/// Remote Command Execution Service
///
/// Provides functionality for executing remote commands received via SMS:
/// - LOCK: Lock device and enable Kiosk Mode
/// - WIPE: Factory reset via Device Admin
/// - LOCATE: Reply with GPS coordinates and Maps link
/// - ALARM: Trigger 2-minute max volume alarm
///
/// Requirements: 8.1, 8.2, 8.3, 8.4, 8.5
library remote_command;

export 'i_remote_command_executor.dart';
export 'remote_command_executor.dart';
