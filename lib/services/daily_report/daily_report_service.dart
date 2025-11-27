import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../location/i_location_service.dart';
import '../protection/i_protection_service.dart';
import '../security_log/i_security_log_service.dart';
import '../sms/i_sms_service.dart';
import '../storage/i_storage_service.dart';
import 'i_daily_report_service.dart';

/// Storage keys for daily report configuration.
class DailyReportStorageKeys {
  static const String reportEnabled = 'daily_report_enabled';
  static const String reportHour = 'daily_report_hour';
  static const String reportMinute = 'daily_report_minute';
  static const String lastReportTime = 'daily_report_last_sent';
}

/// Implementation of IDailyReportService.
///
/// Provides daily status report generation and sending functionality.
/// Uses WorkManager for scheduling daily reports at the configured time.
///
/// Requirements:
/// - 25.1: Generate status report at configurable time
/// - 25.2: Include Protected Mode status, battery level, location, events count
/// - 25.3: Send report via SMS to Emergency Contact
/// - 25.4: Send simple "All OK" message when no events
/// - 25.5: Include battery warning when below 15%
class DailyReportService implements IDailyReportService {
  static const String _channel = 'com.example.find_phone/daily_report';

  final IStorageService _storageService;
  final IProtectionService _protectionService;
  final ILocationService _locationService;
  final ISecurityLogService _securityLogService;
  final ISmsService _smsService;

  final MethodChannel _methodChannel = const MethodChannel(_channel);

  bool _isInitialized = false;
  Timer? _reportTimer;


  DailyReportService({
    required IStorageService storageService,
    required IProtectionService protectionService,
    required ILocationService locationService,
    required ISecurityLogService securityLogService,
    required ISmsService smsService,
  })  : _storageService = storageService,
        _protectionService = protectionService,
        _locationService = locationService,
        _securityLogService = securityLogService,
        _smsService = smsService;

  @override
  Future<void> initialize() async {
    if (_isInitialized) return;

    // Check if daily reports are enabled and schedule if needed
    final isEnabled = await isDailyReportsEnabled();
    if (isEnabled) {
      await _scheduleNextReport();
    }

    _isInitialized = true;
  }

  @override
  Future<void> dispose() async {
    _reportTimer?.cancel();
    _reportTimer = null;
    _isInitialized = false;
  }

  @override
  Future<void> setReportTime(TimeOfDay time) async {
    await _storageService.store(DailyReportStorageKeys.reportHour, time.hour);
    await _storageService.store(DailyReportStorageKeys.reportMinute, time.minute);

    // Reschedule if reports are enabled
    final isEnabled = await isDailyReportsEnabled();
    if (isEnabled) {
      await _scheduleNextReport();
    }
  }

  @override
  Future<TimeOfDay?> getReportTime() async {
    final hour = await _storageService.retrieve(DailyReportStorageKeys.reportHour);
    final minute = await _storageService.retrieve(DailyReportStorageKeys.reportMinute);

    if (hour == null) return null;

    return TimeOfDay(
      hour: hour as int,
      minute: (minute as int?) ?? 0,
    );
  }

  @override
  Future<void> enableDailyReports() async {
    await _storageService.store(DailyReportStorageKeys.reportEnabled, true);
    await _scheduleNextReport();
  }

  @override
  Future<void> disableDailyReports() async {
    await _storageService.store(DailyReportStorageKeys.reportEnabled, false);
    _reportTimer?.cancel();
    _reportTimer = null;

    // Cancel native WorkManager task
    try {
      await _methodChannel.invokeMethod('cancelDailyReportTask');
    } on PlatformException {
      // Handle silently - native scheduling may not be available
    }
  }

  @override
  Future<bool> isDailyReportsEnabled() async {
    final enabled = await _storageService.retrieve(DailyReportStorageKeys.reportEnabled);
    return enabled == true;
  }

  @override
  Future<DailyStatusReport> generateReport({DateTime? since}) async {
    // Get protection status
    final protectedModeActive = await _protectionService.isProtectedModeActive();

    // Get battery level
    final batteryLevel = await _getBatteryLevel();

    // Get last known location
    final lastLocation = await _locationService.getLastKnownLocation();

    // Get security events count since last report or specified time
    final eventsSince = since ?? await _getLastReportTimeOrDefault();
    final eventCount = await _getEventCountSince(eventsSince);

    return DailyStatusReport(
      protectedModeActive: protectedModeActive,
      batteryLevel: batteryLevel,
      lastLocation: lastLocation,
      securityEventCount: eventCount,
      generatedAt: DateTime.now(),
    );
  }

  @override
  Future<bool> sendDailyReport() async {
    // Get emergency contact
    final emergencyContact = await _smsService.getEmergencyContact();
    if (emergencyContact == null) {
      return false;
    }

    // Generate report
    final report = await generateReport();

    // Send via SMS
    final success = await _smsService.sendSms(
      emergencyContact,
      report.toSmsMessage(),
    );

    if (success) {
      // Update last report time
      await _storageService.store(
        DailyReportStorageKeys.lastReportTime,
        DateTime.now().toIso8601String(),
      );
    }

    return success;
  }

  @override
  Future<DateTime?> getLastReportTime() async {
    final stored = await _storageService.retrieve(DailyReportStorageKeys.lastReportTime);
    if (stored == null) return null;
    return DateTime.tryParse(stored as String);
  }

  @override
  Future<int> getEventCountSinceLastReport() async {
    final lastReport = await _getLastReportTimeOrDefault();
    return await _getEventCountSince(lastReport);
  }

  /// Schedule the next daily report.
  Future<void> _scheduleNextReport() async {
    _reportTimer?.cancel();

    final reportTime = await getReportTime();
    if (reportTime == null) return;

    final now = DateTime.now();
    var scheduledTime = DateTime(
      now.year,
      now.month,
      now.day,
      reportTime.hour,
      reportTime.minute,
    );

    // If the time has already passed today, schedule for tomorrow
    if (scheduledTime.isBefore(now)) {
      scheduledTime = scheduledTime.add(const Duration(days: 1));
    }

    final delay = scheduledTime.difference(now);

    // Schedule using Timer for in-app scheduling
    _reportTimer = Timer(delay, () async {
      await sendDailyReport();
      // Schedule next report
      await _scheduleNextReport();
    });

    // Also schedule using native WorkManager for reliability
    try {
      await _methodChannel.invokeMethod('scheduleDailyReportTask', {
        'hour': reportTime.hour,
        'minute': reportTime.minute,
      });
    } on PlatformException {
      // Handle silently - native scheduling may not be available
    }
  }

  /// Get the last report time or default to 24 hours ago.
  Future<DateTime> _getLastReportTimeOrDefault() async {
    final lastReport = await getLastReportTime();
    return lastReport ?? DateTime.now().subtract(const Duration(hours: 24));
  }

  /// Get the count of security events since the specified time.
  Future<int> _getEventCountSince(DateTime since) async {
    final events = await _securityLogService.getEventsByDateRange(
      since,
      DateTime.now(),
    );
    return events.length;
  }

  /// Get the current battery level.
  Future<int> _getBatteryLevel() async {
    try {
      final level = await _methodChannel.invokeMethod<int>('getBatteryLevel');
      return level ?? 100;
    } on PlatformException {
      // Fallback to location service if available
      try {
        return await _locationService.getBatteryLevel();
      } catch (e) {
        return 100; // Default to 100% if unable to get battery level
      }
    }
  }
}
