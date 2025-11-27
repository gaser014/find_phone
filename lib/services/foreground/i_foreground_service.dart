/// Interface for Foreground Service management.
///
/// Provides functionality to manage the persistent foreground service
/// for anti-theft protection monitoring.
///
/// Requirements:
/// - 2.4: Auto-restart using JobScheduler within 3 seconds
/// - 5.5: Continue tracking even when app is in background
abstract class IForegroundService {
  /// Start the foreground service for persistent monitoring.
  ///
  /// This starts the native Android foreground service that:
  /// - Maintains persistent background monitoring
  /// - Handles force-stop detection and auto-restart
  /// - Coordinates location tracking
  ///
  /// Requirements: 2.4, 5.5
  Future<bool> startService();

  /// Stop the foreground service.
  ///
  /// This stops the native Android foreground service.
  /// Should only be called when Protected Mode is disabled.
  Future<bool> stopService();

  /// Check if the foreground service is currently running.
  Future<bool> isServiceRunning();

  /// Update the service notification.
  ///
  /// [title] - Optional custom notification title
  /// [message] - Optional custom notification message
  Future<void> updateNotification({String? title, String? message});

  /// Get the last heartbeat timestamp from the service.
  ///
  /// Returns null if no heartbeat has been recorded.
  Future<DateTime?> getLastHeartbeat();

  /// Get the service start count.
  ///
  /// Returns the number of times the service has been started.
  Future<int> getStartCount();

  /// Stream of service events.
  ///
  /// Emits events when the service state changes.
  Stream<ForegroundServiceEvent> get events;
}

/// Types of foreground service events.
enum ForegroundServiceEventType {
  /// Service was started
  started,

  /// Service was stopped
  stopped,

  /// Force-stop was detected
  forceStopDetected,

  /// Service was restarted after force-stop
  restarted,

  /// Heartbeat recorded
  heartbeat,
}

/// Represents a foreground service event.
class ForegroundServiceEvent {
  /// Event type
  final ForegroundServiceEventType type;

  /// Timestamp of the event
  final DateTime timestamp;

  /// Additional event data
  final Map<String, dynamic>? metadata;

  ForegroundServiceEvent({
    required this.type,
    required this.timestamp,
    this.metadata,
  });

  factory ForegroundServiceEvent.fromMap(Map<String, dynamic> map) {
    return ForegroundServiceEvent(
      type: ForegroundServiceEventType.values.firstWhere(
        (e) => e.name == map['type'],
        orElse: () => ForegroundServiceEventType.started,
      ),
      timestamp: DateTime.fromMillisecondsSinceEpoch(
        map['timestamp'] as int? ?? DateTime.now().millisecondsSinceEpoch,
      ),
      metadata: map['metadata'] as Map<String, dynamic>?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'type': type.name,
      'timestamp': timestamp.millisecondsSinceEpoch,
      'metadata': metadata,
    };
  }
}
