import 'dart:async';

/// Represents a trusted computer device.
class TrustedDevice {
  /// Unique identifier for the device (USB device ID or fingerprint)
  final String deviceId;

  /// Human-readable name for the device
  final String? deviceName;

  /// When the device was added as trusted
  final DateTime addedAt;

  /// Optional description or notes
  final String? description;

  TrustedDevice({
    required this.deviceId,
    this.deviceName,
    required this.addedAt,
    this.description,
  });

  Map<String, dynamic> toJson() => {
        'deviceId': deviceId,
        'deviceName': deviceName,
        'addedAt': addedAt.toIso8601String(),
        'description': description,
      };

  factory TrustedDevice.fromJson(Map<String, dynamic> json) {
    return TrustedDevice(
      deviceId: json['deviceId'] as String,
      deviceName: json['deviceName'] as String?,
      addedAt: DateTime.parse(json['addedAt'] as String),
      description: json['description'] as String?,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TrustedDevice &&
          runtimeType == other.runtimeType &&
          deviceId == other.deviceId;

  @override
  int get hashCode => deviceId.hashCode;

  @override
  String toString() =>
      'TrustedDevice(deviceId: $deviceId, deviceName: $deviceName, addedAt: $addedAt)';
}


/// Represents a USB connection event.
class UsbConnectionEvent {
  /// Whether a USB cable is connected
  final bool isConnected;

  /// The device ID of the connected computer (if available)
  final String? deviceId;

  /// The device name (if available)
  final String? deviceName;

  /// When the event occurred
  final DateTime timestamp;

  /// Whether the connected device is trusted
  final bool isTrusted;

  /// The USB mode (charging, MTP, PTP, etc.)
  final UsbMode mode;

  UsbConnectionEvent({
    required this.isConnected,
    this.deviceId,
    this.deviceName,
    required this.timestamp,
    this.isTrusted = false,
    this.mode = UsbMode.charging,
  });

  Map<String, dynamic> toJson() => {
        'isConnected': isConnected,
        'deviceId': deviceId,
        'deviceName': deviceName,
        'timestamp': timestamp.toIso8601String(),
        'isTrusted': isTrusted,
        'mode': mode.name,
      };

  factory UsbConnectionEvent.fromJson(Map<String, dynamic> json) {
    return UsbConnectionEvent(
      isConnected: json['isConnected'] as bool,
      deviceId: json['deviceId'] as String?,
      deviceName: json['deviceName'] as String?,
      timestamp: DateTime.parse(json['timestamp'] as String),
      isTrusted: json['isTrusted'] as bool? ?? false,
      mode: UsbMode.values.firstWhere(
        (e) => e.name == json['mode'],
        orElse: () => UsbMode.charging,
      ),
    );
  }
}

/// USB connection modes.
enum UsbMode {
  /// Charging only - no data transfer
  charging,

  /// Media Transfer Protocol - file transfer
  mtp,

  /// Picture Transfer Protocol - photo transfer
  ptp,

  /// MIDI mode
  midi,

  /// USB debugging (ADB)
  adb,

  /// Unknown mode
  unknown,
}

/// Interface for USB and Trusted Devices Service.
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
abstract class IUsbService {
  /// Initialize the USB service.
  Future<void> initialize();

  /// Dispose of resources.
  Future<void> dispose();

  // ==================== USB Connection Detection ====================

  /// Stream of USB connection events.
  ///
  /// Emits events when USB cable is connected or disconnected.
  ///
  /// Requirement 28.1: Detect USB cable connection immediately
  Stream<UsbConnectionEvent> get usbConnectionEvents;

  /// Check if USB cable is currently connected.
  Future<bool> isUsbConnected();

  /// Get the current USB connection mode.
  Future<UsbMode> getCurrentUsbMode();

  /// Get the connected device ID (if available).
  Future<String?> getConnectedDeviceId();

  /// Start monitoring USB connections.
  Future<void> startUsbMonitoring();

  /// Stop monitoring USB connections.
  Future<void> stopUsbMonitoring();

  // ==================== Trusted Devices Management ====================

  /// Get all trusted devices.
  ///
  /// Requirement 29.1: Store trusted device identifier in encrypted storage
  Future<List<TrustedDevice>> getTrustedDevices();

  /// Check if a device is trusted.
  ///
  /// Requirement 28.2: Check if connected computer is in trusted devices list
  Future<bool> isDeviceTrusted(String deviceId);

  /// Add a device to the trusted list.
  ///
  /// Requires password verification before adding.
  ///
  /// Requirement 28.4: Add trusted computer with Master Password
  /// Requirement 29.1: Store in encrypted persistent storage
  Future<bool> addTrustedDevice(TrustedDevice device);

  /// Remove a device from the trusted list.
  ///
  /// Requires password verification before removing.
  Future<bool> removeTrustedDevice(String deviceId);

  /// Clear all trusted devices.
  ///
  /// Requires password verification.
  Future<bool> clearAllTrustedDevices();

  /// Restore trusted devices from storage.
  ///
  /// Called on app startup to restore persisted devices.
  ///
  /// Requirement 29.2: Restore trusted devices list after power cycle
  Future<void> restoreTrustedDevices();

  // ==================== USB Data Transfer Blocking ====================

  /// Block USB data transfer.
  ///
  /// Sets USB mode to charging only.
  ///
  /// Requirement 28.3: Block USB data transfer for untrusted computers
  Future<bool> blockUsbDataTransfer();

  /// Allow USB data transfer.
  ///
  /// Only allowed for trusted devices.
  Future<bool> allowUsbDataTransfer();

  /// Check if USB data transfer is currently blocked.
  Future<bool> isUsbDataTransferBlocked();

  /// Handle USB connection event.
  ///
  /// Automatically blocks data transfer if device is not trusted.
  Future<void> handleUsbConnection(UsbConnectionEvent event);

  // ==================== USB Debugging Protection ====================

  /// Check if USB debugging (ADB) is enabled.
  Future<bool> isAdbEnabled();

  /// Block ADB connection from untrusted computer.
  ///
  /// Requirement 28.5: Trigger alarm for USB debugging from untrusted computer
  Future<bool> blockAdbConnection();
}
