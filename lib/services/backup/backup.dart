/// Backup and restore services for the Anti-Theft Protection app.
///
/// This library provides functionality for creating encrypted backups
/// of settings and security logs, and restoring them.
///
/// Requirements:
/// - 15.1: Export all settings and logs as encrypted file
/// - 15.2: Encrypt backup using Master Password
/// - 15.3: Require Master Password to decrypt backup
/// - 15.4: Import all settings and security logs
/// - 15.5: Refuse to decrypt after 3 failed attempts
library;

export 'i_backup_service.dart';
export 'backup_service.dart';
