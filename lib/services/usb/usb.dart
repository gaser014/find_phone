/// USB and Trusted Devices Service
///
/// Provides functionality for:
/// - Detecting USB connections
/// - Managing trusted computer devices
/// - Blocking USB data transfer for untrusted devices
///
/// Requirements:
/// - 28.1: Detect USB cable connection immediately
/// - 28.2: Check if connected computer is in trusted devices list
/// - 28.3: Block USB data transfer for untrusted computers
/// - 28.4: Add trusted computer with Master Password
/// - 29.1: Store trusted device identifier in encrypted persistent storage
/// - 29.2: Restore trusted devices list after device power cycle
library;

export 'i_usb_service.dart';
export 'usb_service.dart';
