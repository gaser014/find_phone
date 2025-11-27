import 'dart:async';
import 'dart:convert';

import 'package:flutter/services.dart';

import '../storage/i_storage_service.dart';
import 'i_usb_service.dart';

/// Implementation of the USB and Trusted Devices Service.
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
class UsbService implements IUsbService {
  /// Method channel for native Android communication.
  static const MethodChannel _channel =
      MethodChannel('com.example.find_phone/usb');

  /// Storage service for persisting trusted devices.
  final IStorageService _storageService;

  /// Storage key for trusted devices list.
  static const String _trustedDevicesKey = 'trusted_devices';

  /// In-memory cache of trusted devices.
  List<TrustedDevice> _trustedDevices = [];

  /// Stream controller for USB connection events.
  final StreamController<UsbConnectionEvent> _usbConnectionController =
      StreamController<UsbConnectionEvent>.broadcast();

  /// Whether USB monitoring is active.
  bool _isMonitoring = false;

  /// Timer for polling USB state.
  Timer? _usbPollTimer;

  /// Last known USB connection state.
  bool? _lastUsbConnected;

  /// Constructor.
  UsbService({
    required IStorageService storageService,
  }) : _storageService = storageService;

  @override
  Stream<UsbConnectionEvent> get usbConnectionEvents =>
      _usbConnectionController.stream;

  @override
  Future<void> initialize() async {
    // Set up method channel handler for native events
    _channel.setMethodCallHandler(_handleMethodCall);

    // Restore trusted devices from storage
    await restoreTrustedDevices();
  }

  @override
  Future<void> dispose() async {
    await stopUsbMonitoring();
    await _usbConnectionController.close();
  }

  /// Handle method calls from native code.
  Future<dynamic> _handleMethodCall(MethodCall call) async {
    switch (call.method) {
      case 'onUsbConnectionChanged':
        _handleUsbConnectionChange(call.arguments as Map<dynamic, dynamic>);
        break;
      case 'onUsbModeChanged':
        _handleUsbModeChange(call.arguments as Map<dynamic, dynamic>);
        break;
    }
  }


  // ==================== USB Connection Detection ====================

  @override
  Future<bool> isUsbConnected() async {
    try {
      final result = await _channel.invokeMethod<bool>('isUsbConnected');
      return result ?? false;
    } on PlatformException {
      return false;
    }
  }

  @override
  Future<UsbMode> getCurrentUsbMode() async {
    try {
      final result = await _channel.invokeMethod<String>('getCurrentUsbMode');
      return _parseUsbMode(result);
    } on PlatformException {
      return UsbMode.unknown;
    }
  }

  @override
  Future<String?> getConnectedDeviceId() async {
    try {
      final result = await _channel.invokeMethod<String>('getConnectedDeviceId');
      return result;
    } on PlatformException {
      return null;
    }
  }

  @override
  Future<void> startUsbMonitoring() async {
    if (_isMonitoring) return;

    _lastUsbConnected = await isUsbConnected();

    // Poll every 500ms for USB connection changes (immediate detection)
    _usbPollTimer = Timer.periodic(
      const Duration(milliseconds: 500),
      (_) => _checkUsbConnectionChange(),
    );

    try {
      await _channel.invokeMethod('startUsbMonitoring');
    } on PlatformException {
      // Native monitoring not available, rely on polling
    }

    _isMonitoring = true;
  }

  @override
  Future<void> stopUsbMonitoring() async {
    _usbPollTimer?.cancel();
    _usbPollTimer = null;

    try {
      await _channel.invokeMethod('stopUsbMonitoring');
    } on PlatformException {
      // Ignore
    }

    _isMonitoring = false;
  }

  Future<void> _checkUsbConnectionChange() async {
    final currentConnected = await isUsbConnected();

    if (_lastUsbConnected != null && currentConnected != _lastUsbConnected) {
      final deviceId = currentConnected ? await getConnectedDeviceId() : null;
      final mode = currentConnected ? await getCurrentUsbMode() : UsbMode.charging;
      final isTrusted = deviceId != null ? await isDeviceTrusted(deviceId) : false;

      final event = UsbConnectionEvent(
        isConnected: currentConnected,
        deviceId: deviceId,
        timestamp: DateTime.now(),
        isTrusted: isTrusted,
        mode: mode,
      );

      _usbConnectionController.add(event);

      // Handle the connection event (block if untrusted)
      await handleUsbConnection(event);
    }

    _lastUsbConnected = currentConnected;
  }

  void _handleUsbConnectionChange(Map<dynamic, dynamic> args) async {
    final isConnected = args['isConnected'] as bool? ?? false;
    final deviceId = args['deviceId'] as String?;
    final deviceName = args['deviceName'] as String?;
    final modeStr = args['mode'] as String?;

    final mode = _parseUsbMode(modeStr);
    final isTrusted = deviceId != null ? await isDeviceTrusted(deviceId) : false;

    final event = UsbConnectionEvent(
      isConnected: isConnected,
      deviceId: deviceId,
      deviceName: deviceName,
      timestamp: DateTime.now(),
      isTrusted: isTrusted,
      mode: mode,
    );

    _usbConnectionController.add(event);

    // Handle the connection event (block if untrusted)
    await handleUsbConnection(event);
  }

  void _handleUsbModeChange(Map<dynamic, dynamic> args) async {
    final modeStr = args['mode'] as String?;
    final deviceId = args['deviceId'] as String?;

    final mode = _parseUsbMode(modeStr);
    final isTrusted = deviceId != null ? await isDeviceTrusted(deviceId) : false;

    // If mode changed to data transfer mode and device is not trusted, block it
    if (_isDataTransferMode(mode) && !isTrusted) {
      await blockUsbDataTransfer();
    }
  }

  UsbMode _parseUsbMode(String? modeStr) {
    switch (modeStr?.toLowerCase()) {
      case 'charging':
        return UsbMode.charging;
      case 'mtp':
        return UsbMode.mtp;
      case 'ptp':
        return UsbMode.ptp;
      case 'midi':
        return UsbMode.midi;
      case 'adb':
        return UsbMode.adb;
      default:
        return UsbMode.unknown;
    }
  }

  bool _isDataTransferMode(UsbMode mode) {
    return mode == UsbMode.mtp || mode == UsbMode.ptp || mode == UsbMode.adb;
  }


  // ==================== Trusted Devices Management ====================

  @override
  Future<List<TrustedDevice>> getTrustedDevices() async {
    return List.unmodifiable(_trustedDevices);
  }

  @override
  Future<bool> isDeviceTrusted(String deviceId) async {
    return _trustedDevices.any((device) => device.deviceId == deviceId);
  }

  @override
  Future<bool> addTrustedDevice(TrustedDevice device) async {
    // Check if device already exists
    if (await isDeviceTrusted(device.deviceId)) {
      return true; // Already trusted
    }

    // Add to in-memory list
    _trustedDevices.add(device);

    // Persist to encrypted storage
    return await _saveTrustedDevices();
  }

  @override
  Future<bool> removeTrustedDevice(String deviceId) async {
    final initialLength = _trustedDevices.length;
    _trustedDevices.removeWhere((device) => device.deviceId == deviceId);

    if (_trustedDevices.length < initialLength) {
      // Device was removed, persist changes
      return await _saveTrustedDevices();
    }

    return false; // Device not found
  }

  @override
  Future<bool> clearAllTrustedDevices() async {
    _trustedDevices.clear();
    return await _saveTrustedDevices();
  }

  @override
  Future<void> restoreTrustedDevices() async {
    try {
      final jsonStr = await _storageService.retrieveSecure(_trustedDevicesKey);
      if (jsonStr == null || jsonStr.isEmpty) {
        _trustedDevices = [];
        return;
      }

      final List<dynamic> jsonList = json.decode(jsonStr) as List<dynamic>;
      _trustedDevices = jsonList
          .map((e) => TrustedDevice.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
    } catch (e) {
      // If parsing fails, start with empty list
      _trustedDevices = [];
    }
  }

  Future<bool> _saveTrustedDevices() async {
    try {
      final jsonStr = json.encode(
        _trustedDevices.map((d) => d.toJson()).toList(),
      );
      await _storageService.storeSecure(_trustedDevicesKey, jsonStr);
      return true;
    } catch (e) {
      return false;
    }
  }

  // ==================== USB Data Transfer Blocking ====================

  @override
  Future<bool> blockUsbDataTransfer() async {
    try {
      final result = await _channel.invokeMethod<bool>('blockUsbDataTransfer');
      return result ?? false;
    } on PlatformException {
      return false;
    }
  }

  @override
  Future<bool> allowUsbDataTransfer() async {
    try {
      final result = await _channel.invokeMethod<bool>('allowUsbDataTransfer');
      return result ?? false;
    } on PlatformException {
      return false;
    }
  }

  @override
  Future<bool> isUsbDataTransferBlocked() async {
    try {
      final result = await _channel.invokeMethod<bool>('isUsbDataTransferBlocked');
      return result ?? true; // Default to blocked for safety
    } on PlatformException {
      return true;
    }
  }

  @override
  Future<void> handleUsbConnection(UsbConnectionEvent event) async {
    if (!event.isConnected) {
      // USB disconnected, nothing to do
      return;
    }

    // Check if device is trusted
    if (event.deviceId != null && event.isTrusted) {
      // Trusted device, allow data transfer
      await allowUsbDataTransfer();
    } else {
      // Untrusted device, block data transfer
      await blockUsbDataTransfer();
    }
  }

  // ==================== USB Debugging Protection ====================

  @override
  Future<bool> isAdbEnabled() async {
    try {
      final result = await _channel.invokeMethod<bool>('isAdbEnabled');
      return result ?? false;
    } on PlatformException {
      return false;
    }
  }

  @override
  Future<bool> blockAdbConnection() async {
    try {
      final result = await _channel.invokeMethod<bool>('blockAdbConnection');
      return result ?? false;
    } on PlatformException {
      return false;
    }
  }
}
