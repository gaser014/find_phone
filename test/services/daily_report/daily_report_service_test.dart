import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:find_phone/domain/entities/location_data.dart';
import 'package:find_phone/domain/entities/protection_config.dart';
import 'package:find_phone/domain/entities/remote_command.dart';
import 'package:find_phone/domain/entities/security_event.dart';
import 'package:find_phone/services/daily_report/daily_report_service.dart';
import 'package:find_phone/services/location/i_location_service.dart';
import 'package:find_phone/services/protection/i_protection_service.dart';
import 'package:find_phone/services/security_log/i_security_log_service.dart';
import 'package:find_phone/services/sms/i_sms_service.dart';
import 'package:find_phone/services/storage/i_storage_service.dart';

/// Mock implementation of IStorageService for testing.
class MockStorageService implements IStorageService {
  final Map<String, dynamic> _storage = {};
  final Map<String, String> _secureStorage = {};

  @override
  Future<void> store(String key, dynamic value) async {
    _storage[key] = value;
  }

  @override
  Future<dynamic> retrieve(String key) async {
    return _storage[key];
  }

  @override
  Future<void> delete(String key) async {
    _storage.remove(key);
  }

  @override
  Future<bool> containsKey(String key) async {
    return _storage.containsKey(key);
  }

  @override
  Future<void> storeSecure(String key, String value) async {
    _secureStorage[key] = value;
  }

  @override
  Future<String?> retrieveSecure(String key) async {
    return _secureStorage[key];
  }

  @override
  Future<void> deleteSecure(String key) async {
    _secureStorage.remove(key);
  }

  @override
  Future<bool> containsSecureKey(String key) async {
    return _secureStorage.containsKey(key);
  }

  @override
  Future<void> clearAll() async {
    _storage.clear();
    _secureStorage.clear();
  }

  @override
  Future<void> clearSecure() async {
    _secureStorage.clear();
  }

  @override
  Future<void> clearNonSecure() async {
    _storage.clear();
  }

  @override
  Future<Set<String>> getAllKeys() async {
    return _storage.keys.toSet();
  }

  @override
  Future<Set<String>> getAllSecureKeys() async {
    return _secureStorage.keys.toSet();
  }

  void clear() {
    _storage.clear();
    _secureStorage.clear();
  }
}


/// Mock implementation of IProtectionService for testing.
class MockProtectionService implements IProtectionService {
  bool _protectedModeActive = false;
  bool _kioskModeActive = false;
  bool _panicModeActive = false;
  bool _stealthModeActive = false;
  ProtectionConfig _config = ProtectionConfig();

  void setProtectedModeActive(bool active) {
    _protectedModeActive = active;
  }

  @override
  Future<bool> isProtectedModeActive() async => _protectedModeActive;

  @override
  Future<bool> enableProtectedMode() async {
    _protectedModeActive = true;
    return true;
  }

  @override
  Future<bool> disableProtectedMode(String password) async {
    _protectedModeActive = false;
    return true;
  }

  @override
  Future<bool> isKioskModeActive() async => _kioskModeActive;

  @override
  Future<bool> enableKioskMode() async {
    _kioskModeActive = true;
    return true;
  }

  @override
  Future<bool> disableKioskMode(String password) async {
    _kioskModeActive = false;
    return true;
  }

  @override
  Future<void> showKioskLockScreen({String? message}) async {}

  @override
  Future<bool> isPanicModeActive() async => _panicModeActive;

  @override
  Future<void> enablePanicMode() async {
    _panicModeActive = true;
  }

  @override
  Future<bool> disablePanicMode(String password) async {
    _panicModeActive = false;
    return true;
  }

  @override
  Future<void> registerVolumeButtonListener() async {}

  @override
  Future<void> unregisterVolumeButtonListener() async {}

  @override
  Future<bool> isStealthModeActive() async => _stealthModeActive;

  @override
  Future<void> enableStealthMode() async {
    _stealthModeActive = true;
  }

  @override
  Future<void> disableStealthMode() async {
    _stealthModeActive = false;
  }

  @override
  Future<void> setHideAppIcon(bool hide) async {}

  @override
  Future<bool> isAppIconHidden() async => false;

  @override
  Future<void> registerDialerCodeListener() async {}

  @override
  Future<void> unregisterDialerCodeListener() async {}

  @override
  Future<void> setDialerCode(String code) async {}

  @override
  Future<String> getDialerCode() async => '*#123456#';

  @override
  Future<void> handleDialerCodeEntry() async {}

  @override
  Future<ProtectionConfig> getConfiguration() async => _config;

  @override
  Future<bool> updateConfiguration(ProtectionConfig config, String password) async {
    _config = config;
    return true;
  }

  @override
  Future<void> saveConfiguration() async {}

  @override
  Future<ProtectionConfig> loadConfiguration() async => _config;

  @override
  Stream<ProtectionEvent> get events => const Stream.empty();

  @override
  Future<void> initialize() async {}

  @override
  Future<void> dispose() async {}
}

/// Mock implementation of ILocationService for testing.
class MockLocationService implements ILocationService {
  LocationData? _lastLocation;
  final List<LocationData> _locationHistory = [];
  int _batteryLevel = 100;
  bool _isTracking = false;
  bool _isHighFrequencyMode = false;
  Duration _currentInterval = const Duration(minutes: 5);
  bool _adaptiveTrackingEnabled = false;

  void setLastLocation(LocationData? location) {
    _lastLocation = location;
    if (location != null) {
      _locationHistory.add(location);
    }
  }

  void setBatteryLevel(int level) {
    _batteryLevel = level;
  }

  @override
  Future<LocationData?> getLastKnownLocation() async => _lastLocation;

  @override
  Future<LocationData> getCurrentLocation() async {
    return _lastLocation ?? LocationData(
      latitude: 0.0,
      longitude: 0.0,
      accuracy: 0.0,
      timestamp: DateTime.now(),
    );
  }

  @override
  Future<List<LocationData>> getLocationHistory({DateTime? since}) async {
    if (since == null) return List.from(_locationHistory);
    return _locationHistory.where((l) => l.timestamp.isAfter(since)).toList();
  }

  @override
  Future<void> startTracking({Duration interval = const Duration(minutes: 5)}) async {
    _isTracking = true;
    _currentInterval = interval;
  }

  @override
  Future<void> stopTracking() async {
    _isTracking = false;
  }

  @override
  bool get isTracking => _isTracking;

  @override
  Future<void> enableHighFrequencyTracking() async {
    _isHighFrequencyMode = true;
    _currentInterval = const Duration(seconds: 30);
  }

  @override
  Future<void> disableHighFrequencyTracking() async {
    _isHighFrequencyMode = false;
    _currentInterval = const Duration(minutes: 5);
  }

  @override
  bool get isHighFrequencyMode => _isHighFrequencyMode;

  @override
  Duration get currentInterval => _currentInterval;

  @override
  Future<void> clearLocationHistory() async {
    _locationHistory.clear();
  }

  @override
  Future<int> getLocationCount() async => _locationHistory.length;

  @override
  Future<void> initialize() async {}

  @override
  Future<void> dispose() async {}

  @override
  Future<bool> hasLocationPermission() async => true;

  @override
  Future<bool> requestLocationPermission() async => true;

  @override
  Future<bool> isLocationServiceEnabled() async => true;

  @override
  Future<int> getBatteryLevel() async => _batteryLevel;

  @override
  Future<void> setAdaptiveTracking(bool enabled) async {
    _adaptiveTrackingEnabled = enabled;
  }

  @override
  bool get isAdaptiveTrackingEnabled => _adaptiveTrackingEnabled;
}


/// Mock implementation of ISecurityLogService for testing.
class MockSecurityLogService implements ISecurityLogService {
  final List<SecurityEvent> _events = [];
  bool _isInitialized = false;

  List<SecurityEvent> get events => List.unmodifiable(_events);

  void addEvent(SecurityEvent event) {
    _events.add(event);
  }

  void addEvents(List<SecurityEvent> events) {
    _events.addAll(events);
  }

  @override
  Future<void> logEvent(SecurityEvent event) async {
    _events.add(event);
  }

  @override
  Future<List<SecurityEvent>> getAllEvents() async {
    return List.from(_events);
  }

  @override
  Future<List<SecurityEvent>> getEventsByType(SecurityEventType type) async {
    return _events.where((e) => e.type == type).toList();
  }

  @override
  Future<List<SecurityEvent>> getEventsByDateRange(DateTime start, DateTime end) async {
    return _events.where((e) => 
      (e.timestamp.isAfter(start) || e.timestamp.isAtSameMomentAs(start)) && 
      (e.timestamp.isBefore(end) || e.timestamp.isAtSameMomentAs(end))
    ).toList();
  }

  @override
  Future<List<SecurityEvent>> getEventsByTypeAndDateRange(
    SecurityEventType type,
    DateTime start,
    DateTime end,
  ) async {
    return _events.where((e) => 
      e.type == type && 
      (e.timestamp.isAfter(start) || e.timestamp.isAtSameMomentAs(start)) && 
      (e.timestamp.isBefore(end) || e.timestamp.isAtSameMomentAs(end))
    ).toList();
  }

  @override
  Future<SecurityEvent?> getEventById(String id) async {
    try {
      return _events.firstWhere((e) => e.id == id);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<int> getEventCount() async {
    return _events.length;
  }

  @override
  Future<int> getEventCountByType(SecurityEventType type) async {
    return _events.where((e) => e.type == type).length;
  }

  @override
  Future<bool> clearLogs(String password) async {
    _events.clear();
    return true;
  }

  @override
  Future<File> exportLogs(String password) async {
    throw UnimplementedError();
  }

  @override
  Future<bool> importLogs(File file, String password) async {
    throw UnimplementedError();
  }

  @override
  Future<List<SecurityEvent>> getRecentEvents(int limit) async {
    final sorted = List<SecurityEvent>.from(_events)
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return sorted.take(limit).toList();
  }

  @override
  Future<bool> deleteEvent(String id) async {
    final index = _events.indexWhere((e) => e.id == id);
    if (index >= 0) {
      _events.removeAt(index);
      return true;
    }
    return false;
  }

  @override
  Future<void> initialize(String encryptionKey) async {
    _isInitialized = true;
  }

  @override
  Future<void> close() async {
    _isInitialized = false;
  }

  @override
  bool get isInitialized => _isInitialized;

  void clear() {
    _events.clear();
  }
}

/// Mock implementation of ISmsService for testing.
class MockSmsService implements ISmsService {
  String? _emergencyContact;
  final List<String> _sentMessages = [];
  bool _isListening = false;

  List<String> get sentMessages => List.unmodifiable(_sentMessages);

  void setEmergencyContactValue(String? contact) {
    _emergencyContact = contact;
  }

  @override
  Future<void> initialize() async {}

  @override
  Future<void> dispose() async {}

  @override
  Future<bool> sendSms(String phoneNumber, String message) async {
    _sentMessages.add(message);
    return true;
  }

  @override
  Future<bool> sendSmsWithDeliveryConfirmation(
    String phoneNumber,
    String message, {
    Duration timeout = const Duration(seconds: 30),
  }) async {
    _sentMessages.add(message);
    return true;
  }

  @override
  void registerCommandCallback(SmsCommandCallback callback) {}

  @override
  void unregisterCommandCallback() {}

  @override
  Future<void> startListening() async {
    _isListening = true;
  }

  @override
  Future<void> stopListening() async {
    _isListening = false;
  }

  @override
  bool get isListening => _isListening;

  @override
  Future<RemoteCommand?> handleIncomingSms(String sender, String message) async {
    return null;
  }

  @override
  Future<bool> isEmergencyContact(String phoneNumber) async {
    return phoneNumber == _emergencyContact;
  }

  @override
  Future<String?> getEmergencyContact() async => _emergencyContact;

  @override
  Future<void> setEmergencyContact(String phoneNumber) async {
    _emergencyContact = phoneNumber;
  }

  @override
  bool validatePhoneNumber(String phoneNumber) {
    if (phoneNumber.isEmpty) return false;
    final cleaned = phoneNumber.replaceAll(RegExp(r'[\s\-\(\)]'), '');
    final phoneRegex = RegExp(r'^\+?[0-9]{7,15}$');
    return phoneRegex.hasMatch(cleaned);
  }

  @override
  Future<bool> sendLocationSms(String phoneNumber, LocationData location) async {
    return true;
  }

  @override
  Future<bool> sendAuthenticationFailureSms(String phoneNumber) async {
    return true;
  }

  @override
  Future<bool> sendCommandConfirmationSms(
    String phoneNumber,
    RemoteCommandType commandType,
  ) async {
    return true;
  }

  @override
  Future<bool> sendDailyStatusReport(
    String phoneNumber, {
    required bool protectedModeActive,
    required int batteryLevel,
    LocationData? location,
    required int eventCount,
  }) async {
    return true;
  }

  @override
  Future<bool> hasSmsPermission() async => true;

  @override
  Future<bool> requestSmsPermission() async => true;

  void clearSentMessages() {
    _sentMessages.clear();
  }
}


void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('DailyReportService', () {
    late MockStorageService storageService;
    late MockProtectionService protectionService;
    late MockLocationService locationService;
    late MockSecurityLogService securityLogService;
    late MockSmsService smsService;
    late DailyReportService dailyReportService;
    final random = Random();

    /// Generates a random phone number string
    String generatePhoneNumber() {
      final countryCode = random.nextInt(99) + 1;
      final number = random.nextInt(999999999) + 100000000;
      return '+$countryCode$number';
    }

    /// Generates a random location
    LocationData generateLocation() {
      return LocationData(
        latitude: (random.nextDouble() * 180) - 90,
        longitude: (random.nextDouble() * 360) - 180,
        accuracy: random.nextDouble() * 100,
        timestamp: DateTime.now().subtract(Duration(minutes: random.nextInt(60))),
      );
    }

    /// Generates random security events
    List<SecurityEvent> generateSecurityEvents(int count) {
      final types = SecurityEventType.values;
      return List.generate(count, (i) => SecurityEvent(
        id: 'event_$i',
        type: types[random.nextInt(types.length)],
        timestamp: DateTime.now().subtract(Duration(hours: random.nextInt(24))),
        description: 'Test event $i',
        metadata: {'test': true},
      ));
    }

    setUp(() {
      storageService = MockStorageService();
      protectionService = MockProtectionService();
      locationService = MockLocationService();
      securityLogService = MockSecurityLogService();
      smsService = MockSmsService();
      
      dailyReportService = DailyReportService(
        storageService: storageService,
        protectionService: protectionService,
        locationService: locationService,
        securityLogService: securityLogService,
        smsService: smsService,
      );

      // Mock the daily report method channel - throw exception to use location service fallback
      const MethodChannel channel = MethodChannel('com.example.find_phone/daily_report');
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
        switch (methodCall.method) {
          case 'getBatteryLevel':
            // Throw to fall back to location service
            throw PlatformException(code: 'UNAVAILABLE', message: 'Battery level not available');
          case 'scheduleDailyReportTask':
            return true;
          case 'cancelDailyReportTask':
            return true;
          default:
            return null;
        }
      });
    });

    tearDown(() {
      const MethodChannel channel = MethodChannel('com.example.find_phone/daily_report');
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });

    group('Report Time Configuration', () {
      test('can set and get report time', () async {
        const reportTime = TimeOfDay(hour: 9, minute: 30);
        
        await dailyReportService.setReportTime(reportTime);
        final retrievedTime = await dailyReportService.getReportTime();
        
        expect(retrievedTime, isNotNull);
        expect(retrievedTime!.hour, equals(9));
        expect(retrievedTime.minute, equals(30));
      });

      test('returns null when no report time is set', () async {
        final retrievedTime = await dailyReportService.getReportTime();
        expect(retrievedTime, isNull);
      });

      test('can enable and disable daily reports', () async {
        await dailyReportService.setReportTime(const TimeOfDay(hour: 8, minute: 0));
        
        await dailyReportService.enableDailyReports();
        expect(await dailyReportService.isDailyReportsEnabled(), isTrue);
        
        await dailyReportService.disableDailyReports();
        expect(await dailyReportService.isDailyReportsEnabled(), isFalse);
      });
    });

    group('Status Report Completeness', () {
      /// **Feature: anti-theft-protection, Property 23: Status Report Completeness**
      /// **Validates: Requirements 25.2**
      ///
      /// For any daily status report generated, the report SHALL include
      /// Protected Mode status, battery level, last known location, and count of security events.
      test('property: generated report contains all required fields', () async {
        // Run 100 iterations with random data
        for (int i = 0; i < 100; i++) {
          // Setup random state
          final isProtected = random.nextBool();
          final batteryLevel = random.nextInt(101); // 0-100
          final hasLocation = random.nextBool();
          final eventCount = random.nextInt(50);
          
          protectionService.setProtectedModeActive(isProtected);
          locationService.setBatteryLevel(batteryLevel);
          
          if (hasLocation) {
            locationService.setLastLocation(generateLocation());
          } else {
            locationService.setLastLocation(null);
          }
          
          securityLogService.clear();
          if (eventCount > 0) {
            securityLogService.addEvents(generateSecurityEvents(eventCount));
          }
          
          // Generate report
          final report = await dailyReportService.generateReport();
          
          // Verify all required fields are present
          expect(report.protectedModeActive, equals(isProtected),
              reason: 'Report should include Protected Mode status');
          
          // Battery level should be present (may come from method channel or location service)
          expect(report.batteryLevel, isA<int>(),
              reason: 'Report should include battery level');
          expect(report.batteryLevel, greaterThanOrEqualTo(0),
              reason: 'Battery level should be non-negative');
          expect(report.batteryLevel, lessThanOrEqualTo(100),
              reason: 'Battery level should not exceed 100');
          
          // Location should match what was set
          if (hasLocation) {
            expect(report.lastLocation, isNotNull,
                reason: 'Report should include location when available');
          }
          
          // Event count should be present
          expect(report.securityEventCount, isA<int>(),
              reason: 'Report should include security event count');
          expect(report.securityEventCount, greaterThanOrEqualTo(0),
              reason: 'Event count should be non-negative');
          
          // Generated timestamp should be present
          expect(report.generatedAt, isNotNull,
              reason: 'Report should include generation timestamp');
        }
      });

      test('property: SMS message contains all required information', () async {
        // Run 100 iterations with random data
        for (int i = 0; i < 100; i++) {
          // Setup random state
          final isProtected = random.nextBool();
          final batteryLevel = random.nextInt(101);
          final hasLocation = random.nextBool();
          final eventCount = random.nextInt(50);
          
          protectionService.setProtectedModeActive(isProtected);
          locationService.setBatteryLevel(batteryLevel);
          
          LocationData? location;
          if (hasLocation) {
            location = generateLocation();
            locationService.setLastLocation(location);
          } else {
            locationService.setLastLocation(null);
          }
          
          securityLogService.clear();
          if (eventCount > 0) {
            securityLogService.addEvents(generateSecurityEvents(eventCount));
          }
          
          // Generate report
          final report = await dailyReportService.generateReport();
          final smsMessage = report.toSmsMessage();
          
          // Verify SMS contains required information
          expect(smsMessage.contains('Status:'), isTrue,
              reason: 'SMS should contain status field');
          expect(
            smsMessage.contains('Protected') || smsMessage.contains('Unprotected'),
            isTrue,
            reason: 'SMS should indicate protection status',
          );
          
          expect(smsMessage.contains('Battery:'), isTrue,
              reason: 'SMS should contain battery field');
          expect(smsMessage.contains('%'), isTrue,
              reason: 'SMS should show battery percentage');
          
          if (hasLocation && report.lastLocation != null) {
            expect(smsMessage.contains('Location:'), isTrue,
                reason: 'SMS should contain location when available');
            expect(smsMessage.contains('maps.google.com'), isTrue,
                reason: 'SMS should contain Google Maps link');
          }
          
          expect(smsMessage.contains('Events:'), isTrue,
              reason: 'SMS should contain events field');
        }
      });

      test('property: "All OK" message when no security events', () async {
        // Run 100 iterations
        for (int i = 0; i < 100; i++) {
          // Setup with no events
          protectionService.setProtectedModeActive(random.nextBool());
          locationService.setBatteryLevel(random.nextInt(101));
          securityLogService.clear();
          
          // Generate report
          final report = await dailyReportService.generateReport();
          
          // Verify isAllOk property
          expect(report.isAllOk, isTrue,
              reason: 'Report with no events should be "All OK"');
          expect(report.securityEventCount, equals(0),
              reason: 'Event count should be 0');
          
          // Verify SMS message
          final smsMessage = report.toSmsMessage();
          expect(smsMessage.contains('All OK'), isTrue,
              reason: 'SMS should contain "All OK" when no events');
        }
      });

      test('property: low battery warning when below 15%', () async {
        // Run 100 iterations
        for (int i = 0; i < 100; i++) {
          // Setup with low battery (0-14%)
          final lowBattery = random.nextInt(15);
          locationService.setBatteryLevel(lowBattery);
          protectionService.setProtectedModeActive(random.nextBool());
          securityLogService.clear();
          
          // Generate report
          final report = await dailyReportService.generateReport();
          
          // Verify isLowBattery property
          expect(report.isLowBattery, isTrue,
              reason: 'Report should indicate low battery when below 15%');
          
          // Verify SMS message contains warning
          final smsMessage = report.toSmsMessage();
          expect(smsMessage.contains('LOW BATTERY'), isTrue,
              reason: 'SMS should contain low battery warning');
        }
      });

      test('property: no low battery warning when 15% or above', () async {
        // Run 100 iterations
        for (int i = 0; i < 100; i++) {
          // Setup with normal battery (15-100%)
          final normalBattery = 15 + random.nextInt(86);
          locationService.setBatteryLevel(normalBattery);
          protectionService.setProtectedModeActive(random.nextBool());
          securityLogService.clear();
          
          // Generate report
          final report = await dailyReportService.generateReport();
          
          // Verify isLowBattery property
          expect(report.isLowBattery, isFalse,
              reason: 'Report should not indicate low battery when 15% or above');
          
          // Verify SMS message does not contain warning
          final smsMessage = report.toSmsMessage();
          expect(smsMessage.contains('LOW BATTERY'), isFalse,
              reason: 'SMS should not contain low battery warning when 15% or above');
        }
      });
    });

    group('Report Sending', () {
      test('sends report to emergency contact', () async {
        final emergencyContact = generatePhoneNumber();
        smsService.setEmergencyContactValue(emergencyContact);
        
        protectionService.setProtectedModeActive(true);
        locationService.setBatteryLevel(80);
        locationService.setLastLocation(generateLocation());
        
        final success = await dailyReportService.sendDailyReport();
        
        expect(success, isTrue);
        expect(smsService.sentMessages.length, equals(1));
        expect(smsService.sentMessages.first.contains('Anti-Theft Daily Report'), isTrue);
      });

      test('fails when no emergency contact is set', () async {
        smsService.setEmergencyContactValue(null);
        
        final success = await dailyReportService.sendDailyReport();
        
        expect(success, isFalse);
        expect(smsService.sentMessages.isEmpty, isTrue);
      });

      test('updates last report time after successful send', () async {
        final emergencyContact = generatePhoneNumber();
        smsService.setEmergencyContactValue(emergencyContact);
        
        final beforeSend = DateTime.now();
        await dailyReportService.sendDailyReport();
        final afterSend = DateTime.now();
        
        final lastReportTime = await dailyReportService.getLastReportTime();
        
        expect(lastReportTime, isNotNull);
        expect(lastReportTime!.isAfter(beforeSend.subtract(const Duration(seconds: 1))), isTrue);
        expect(lastReportTime.isBefore(afterSend.add(const Duration(seconds: 1))), isTrue);
      });
    });
  });
}
