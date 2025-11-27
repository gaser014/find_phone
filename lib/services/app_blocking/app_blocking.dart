/// App Blocking Service
///
/// Provides comprehensive app blocking functionality for the Anti-Theft Protection app.
///
/// Requirements:
/// - 12.1, 27.1: Block Settings app completely
/// - 23.1, 23.2: Block file manager apps with password overlay
/// - 23.3, 23.4: 1-minute file manager access timeout
/// - 30.1, 30.2: Block screen lock changes
/// - 31.1, 31.2: Block account addition
/// - 32.1, 32.2, 32.3: Block app installation/uninstallation
/// - 33.1: Block factory reset from Settings
library;

export 'i_app_blocking_service.dart';
export 'app_blocking_service.dart';
