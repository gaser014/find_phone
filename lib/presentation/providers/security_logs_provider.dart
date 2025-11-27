import 'package:flutter/foundation.dart';

import '../../domain/entities/security_event.dart';
import '../../domain/entities/call_log_entry.dart';
import '../../domain/entities/captured_photo.dart';
import '../../services/security_log/i_security_log_service.dart';

/// Filter options for security logs
class SecurityLogsFilter {
  final SecurityEventType? eventType;
  final DateTime? startDate;
  final DateTime? endDate;

  const SecurityLogsFilter({
    this.eventType,
    this.startDate,
    this.endDate,
  });

  SecurityLogsFilter copyWith({
    SecurityEventType? eventType,
    DateTime? startDate,
    DateTime? endDate,
    bool clearEventType = false,
    bool clearStartDate = false,
    bool clearEndDate = false,
  }) {
    return SecurityLogsFilter(
      eventType: clearEventType ? null : (eventType ?? this.eventType),
      startDate: clearStartDate ? null : (startDate ?? this.startDate),
      endDate: clearEndDate ? null : (endDate ?? this.endDate),
    );
  }

  bool get hasFilters => eventType != null || startDate != null || endDate != null;

  void clear() {}
}

/// Provider for managing security logs state.
/// 
/// Requirements:
/// - 9.4: Display events in chronological order with filtering options
/// - 4.4: Display all unauthorized access attempts
/// - 19.4, 19.5: Display call logs with Emergency Contact highlighting
class SecurityLogsProvider extends ChangeNotifier {
  final ISecurityLogService _securityLogService;

  SecurityLogsProvider({
    required ISecurityLogService securityLogService,
  }) : _securityLogService = securityLogService;

  // State
  List<SecurityEvent> _allEvents = [];
  List<CallLogEntry> _callLogs = [];
  final List<CapturedPhoto> _capturedPhotos = [];
  SecurityLogsFilter _filter = const SecurityLogsFilter();
  bool _isLoading = false;
  String? _error;

  // Getters
  List<SecurityEvent> get allEvents => _allEvents;
  List<CallLogEntry> get callLogs => _callLogs;
  List<CapturedPhoto> get capturedPhotos => _capturedPhotos;
  SecurityLogsFilter get filter => _filter;
  bool get isLoading => _isLoading;
  String? get error => _error;

  /// Returns filtered events based on current filter settings
  /// Requirements: 9.4 - Display events with filtering options
  List<SecurityEvent> get filteredEvents {
    List<SecurityEvent> events = List.from(_allEvents);

    // Filter by event type
    if (_filter.eventType != null) {
      events = events.where((e) => e.type == _filter.eventType).toList();
    }

    // Filter by date range
    if (_filter.startDate != null) {
      events = events.where((e) => 
        e.timestamp.isAfter(_filter.startDate!) || 
        e.timestamp.isAtSameMomentAs(_filter.startDate!)
      ).toList();
    }

    if (_filter.endDate != null) {
      // Add one day to include the entire end date
      final endOfDay = DateTime(
        _filter.endDate!.year,
        _filter.endDate!.month,
        _filter.endDate!.day,
        23, 59, 59,
      );
      events = events.where((e) => 
        e.timestamp.isBefore(endOfDay) || 
        e.timestamp.isAtSameMomentAs(endOfDay)
      ).toList();
    }

    // Sort by timestamp descending (most recent first)
    events.sort((a, b) => b.timestamp.compareTo(a.timestamp));

    return events;
  }

  /// Returns only unauthorized access events
  /// Requirements: 4.4 - Display all unauthorized access attempts
  List<SecurityEvent> get unauthorizedAccessEvents {
    final unauthorizedTypes = [
      SecurityEventType.failedLogin,
      SecurityEventType.screenUnlockFailed,
      SecurityEventType.settingsAccessed,
      SecurityEventType.fileManagerAccessed,
      SecurityEventType.deviceAdminDeactivationAttempted,
      SecurityEventType.accountAdditionAttempted,
      SecurityEventType.appInstallationAttempted,
      SecurityEventType.appUninstallationAttempted,
      SecurityEventType.screenLockChangeAttempted,
      SecurityEventType.factoryResetAttempted,
      SecurityEventType.usbDebuggingEnabled,
      SecurityEventType.developerOptionsAccessed,
      SecurityEventType.powerMenuBlocked,
      SecurityEventType.simCardChanged,
      SecurityEventType.airplaneModeChanged,
    ];

    return _allEvents
        .where((e) => unauthorizedTypes.contains(e.type))
        .toList()
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
  }

  /// Returns events that have associated photos
  List<SecurityEvent> get eventsWithPhotos {
    return _allEvents
        .where((e) => e.photoPath != null && e.photoPath!.isNotEmpty)
        .toList()
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
  }

  /// Load all security data
  Future<void> loadAllData() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await loadEvents();
      await loadCallLogs();
      _error = null;
    } catch (e) {
      _error = 'فشل في تحميل البيانات: ${e.toString()}';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Load security events from the service
  /// Requirements: 9.4 - Display events in chronological order
  Future<void> loadEvents() async {
    try {
      _allEvents = await _securityLogService.getAllEvents();
      // Sort by timestamp descending (most recent first)
      _allEvents.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    } catch (e) {
      _error = 'فشل في تحميل الأحداث: ${e.toString()}';
      rethrow;
    }
  }

  /// Load call logs from security events
  /// Requirements: 19.4 - Display all calls that occurred during Protected Mode
  Future<void> loadCallLogs() async {
    try {
      // Get call logged events and extract call log entries from metadata
      final callEvents = await _securityLogService.getEventsByType(
        SecurityEventType.callLogged,
      );

      _callLogs = callEvents.map((event) {
        final metadata = event.metadata;
        return CallLogEntry(
          id: event.id,
          phoneNumber: metadata['phoneNumber'] as String? ?? 'غير معروف',
          type: _parseCallType(metadata['callType'] as String?),
          timestamp: event.timestamp,
          duration: Duration(seconds: metadata['durationSeconds'] as int? ?? 0),
          isEmergencyContact: metadata['isEmergencyContact'] as bool? ?? false,
        );
      }).toList();

      // Sort by timestamp descending
      _callLogs.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    } catch (e) {
      _error = 'فشل في تحميل سجل المكالمات: ${e.toString()}';
      rethrow;
    }
  }

  CallType _parseCallType(String? typeStr) {
    switch (typeStr) {
      case 'incoming':
        return CallType.incoming;
      case 'outgoing':
        return CallType.outgoing;
      case 'missed':
        return CallType.missed;
      default:
        return CallType.incoming;
    }
  }

  /// Update filter settings
  /// Requirements: 9.4 - Display events with filtering options
  void updateFilter(SecurityLogsFilter newFilter) {
    _filter = newFilter;
    notifyListeners();
  }

  /// Clear all filters
  void clearFilters() {
    _filter = const SecurityLogsFilter();
    notifyListeners();
  }

  /// Set event type filter
  void setEventTypeFilter(SecurityEventType? type) {
    _filter = _filter.copyWith(
      eventType: type,
      clearEventType: type == null,
    );
    notifyListeners();
  }

  /// Set date range filter
  void setDateRangeFilter(DateTime? start, DateTime? end) {
    _filter = _filter.copyWith(
      startDate: start,
      endDate: end,
      clearStartDate: start == null,
      clearEndDate: end == null,
    );
    notifyListeners();
  }

  /// Get event by ID
  SecurityEvent? getEventById(String id) {
    try {
      return _allEvents.firstWhere((e) => e.id == id);
    } catch (e) {
      return null;
    }
  }

  /// Get count of events by type
  int getEventCountByType(SecurityEventType type) {
    return _allEvents.where((e) => e.type == type).length;
  }

  /// Get total event count
  int get totalEventCount => _allEvents.length;

  /// Get unauthorized access count
  int get unauthorizedAccessCount => unauthorizedAccessEvents.length;

  /// Get call logs count
  int get callLogsCount => _callLogs.length;
}
