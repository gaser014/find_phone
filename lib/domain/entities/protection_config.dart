import 'package:flutter/material.dart';

/// Represents a time range for auto-protection scheduling.
class TimeRange {
  /// Start time of the range
  final TimeOfDay startTime;
  
  /// End time of the range
  final TimeOfDay endTime;
  
  /// Days of the week when this range is active (1=Monday, 7=Sunday)
  final List<int> daysOfWeek;

  TimeRange({
    required this.startTime,
    required this.endTime,
    required this.daysOfWeek,
  });

  factory TimeRange.fromJson(Map<String, dynamic> json) {
    return TimeRange(
      startTime: TimeOfDay(
        hour: json['startHour'] as int,
        minute: json['startMinute'] as int,
      ),
      endTime: TimeOfDay(
        hour: json['endHour'] as int,
        minute: json['endMinute'] as int,
      ),
      daysOfWeek: List<int>.from(json['daysOfWeek'] as List),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'startHour': startTime.hour,
      'startMinute': startTime.minute,
      'endHour': endTime.hour,
      'endMinute': endTime.minute,
      'daysOfWeek': daysOfWeek,
    };
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is TimeRange &&
        other.startTime == startTime &&
        other.endTime == endTime &&
        _listEquals(other.daysOfWeek, daysOfWeek);
  }

  bool _listEquals<T>(List<T> a, List<T> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  @override
  int get hashCode => startTime.hashCode ^ endTime.hashCode ^ daysOfWeek.hashCode;
}


/// Configuration for the anti-theft protection system.
/// 
/// Contains all settings for protection features including
/// protected mode, kiosk mode, stealth mode, monitoring options,
/// and scheduling.
class ProtectionConfig {
  /// Whether protected mode is currently enabled
  final bool protectedModeEnabled;
  
  /// Whether kiosk mode is currently enabled
  final bool kioskModeEnabled;
  
  /// Whether stealth mode is currently enabled
  final bool stealthModeEnabled;
  
  /// Whether panic mode is currently enabled
  final bool panicModeEnabled;
  
  /// Emergency contact phone number for alerts and remote commands
  final String? emergencyContact;
  
  /// Interval for location tracking
  final Duration locationTrackingInterval;
  
  /// Whether auto-protection is enabled
  final bool autoProtectionEnabled;
  
  /// Schedule for auto-protection
  final List<TimeRange>? autoProtectionSchedule;
  
  /// Trusted WiFi SSID (home network)
  final String? trustedWifiSsid;
  
  /// Whether to monitor calls
  final bool monitorCalls;
  
  /// Whether to monitor airplane mode changes
  final bool monitorAirplaneMode;
  
  /// Whether to monitor SIM card changes
  final bool monitorSimCard;
  
  /// Whether to block Settings app access
  final bool blockSettings;
  
  /// Whether to block power menu access
  final bool blockPowerMenu;
  
  /// Whether to block file manager apps
  final bool blockFileManagers;
  
  /// Whether daily status report is enabled
  final bool dailyReportEnabled;
  
  /// Time to send daily status report
  final TimeOfDay? dailyReportTime;
  
  /// WhatsApp number for location sharing
  final String? whatsappNumber;
  
  /// Whether to enable audio recording on suspicious activity
  final bool audioRecordingEnabled;
  
  /// Custom lock screen message for remote lock
  final String? lockScreenMessage;

  ProtectionConfig({
    this.protectedModeEnabled = false,
    this.kioskModeEnabled = false,
    this.stealthModeEnabled = false,
    this.panicModeEnabled = false,
    this.emergencyContact,
    this.locationTrackingInterval = const Duration(minutes: 5),
    this.autoProtectionEnabled = false,
    this.autoProtectionSchedule,
    this.trustedWifiSsid,
    this.monitorCalls = true,
    this.monitorAirplaneMode = true,
    this.monitorSimCard = true,
    this.blockSettings = true,
    this.blockPowerMenu = true,
    this.blockFileManagers = true,
    this.dailyReportEnabled = false,
    this.dailyReportTime,
    this.whatsappNumber,
    this.audioRecordingEnabled = false,
    this.lockScreenMessage,
  });

  /// Creates a ProtectionConfig from JSON map
  factory ProtectionConfig.fromJson(Map<String, dynamic> json) {
    return ProtectionConfig(
      protectedModeEnabled: json['protectedModeEnabled'] as bool? ?? false,
      kioskModeEnabled: json['kioskModeEnabled'] as bool? ?? false,
      stealthModeEnabled: json['stealthModeEnabled'] as bool? ?? false,
      panicModeEnabled: json['panicModeEnabled'] as bool? ?? false,
      emergencyContact: json['emergencyContact'] as String?,
      locationTrackingInterval: Duration(
        minutes: json['locationTrackingIntervalMinutes'] as int? ?? 5,
      ),
      autoProtectionEnabled: json['autoProtectionEnabled'] as bool? ?? false,
      autoProtectionSchedule: json['autoProtectionSchedule'] != null
          ? (json['autoProtectionSchedule'] as List)
              .map((e) => TimeRange.fromJson(Map<String, dynamic>.from(e as Map)))
              .toList()
          : null,
      trustedWifiSsid: json['trustedWifiSsid'] as String?,
      monitorCalls: json['monitorCalls'] as bool? ?? true,
      monitorAirplaneMode: json['monitorAirplaneMode'] as bool? ?? true,
      monitorSimCard: json['monitorSimCard'] as bool? ?? true,
      blockSettings: json['blockSettings'] as bool? ?? true,
      blockPowerMenu: json['blockPowerMenu'] as bool? ?? true,
      blockFileManagers: json['blockFileManagers'] as bool? ?? true,
      dailyReportEnabled: json['dailyReportEnabled'] as bool? ?? false,
      dailyReportTime: json['dailyReportHour'] != null
          ? TimeOfDay(
              hour: json['dailyReportHour'] as int,
              minute: json['dailyReportMinute'] as int? ?? 0,
            )
          : null,
      whatsappNumber: json['whatsappNumber'] as String?,
      audioRecordingEnabled: json['audioRecordingEnabled'] as bool? ?? false,
      lockScreenMessage: json['lockScreenMessage'] as String?,
    );
  }

  /// Converts the ProtectionConfig to a JSON map
  Map<String, dynamic> toJson() {
    return {
      'protectedModeEnabled': protectedModeEnabled,
      'kioskModeEnabled': kioskModeEnabled,
      'stealthModeEnabled': stealthModeEnabled,
      'panicModeEnabled': panicModeEnabled,
      'emergencyContact': emergencyContact,
      'locationTrackingIntervalMinutes': locationTrackingInterval.inMinutes,
      'autoProtectionEnabled': autoProtectionEnabled,
      'autoProtectionSchedule': autoProtectionSchedule?.map((e) => e.toJson()).toList(),
      'trustedWifiSsid': trustedWifiSsid,
      'monitorCalls': monitorCalls,
      'monitorAirplaneMode': monitorAirplaneMode,
      'monitorSimCard': monitorSimCard,
      'blockSettings': blockSettings,
      'blockPowerMenu': blockPowerMenu,
      'blockFileManagers': blockFileManagers,
      'dailyReportEnabled': dailyReportEnabled,
      'dailyReportHour': dailyReportTime?.hour,
      'dailyReportMinute': dailyReportTime?.minute,
      'whatsappNumber': whatsappNumber,
      'audioRecordingEnabled': audioRecordingEnabled,
      'lockScreenMessage': lockScreenMessage,
    };
  }

  /// Creates a copy of this config with optional field overrides
  ProtectionConfig copyWith({
    bool? protectedModeEnabled,
    bool? kioskModeEnabled,
    bool? stealthModeEnabled,
    bool? panicModeEnabled,
    String? emergencyContact,
    Duration? locationTrackingInterval,
    bool? autoProtectionEnabled,
    List<TimeRange>? autoProtectionSchedule,
    String? trustedWifiSsid,
    bool? monitorCalls,
    bool? monitorAirplaneMode,
    bool? monitorSimCard,
    bool? blockSettings,
    bool? blockPowerMenu,
    bool? blockFileManagers,
    bool? dailyReportEnabled,
    TimeOfDay? dailyReportTime,
    String? whatsappNumber,
    bool? audioRecordingEnabled,
    String? lockScreenMessage,
  }) {
    return ProtectionConfig(
      protectedModeEnabled: protectedModeEnabled ?? this.protectedModeEnabled,
      kioskModeEnabled: kioskModeEnabled ?? this.kioskModeEnabled,
      stealthModeEnabled: stealthModeEnabled ?? this.stealthModeEnabled,
      panicModeEnabled: panicModeEnabled ?? this.panicModeEnabled,
      emergencyContact: emergencyContact ?? this.emergencyContact,
      locationTrackingInterval: locationTrackingInterval ?? this.locationTrackingInterval,
      autoProtectionEnabled: autoProtectionEnabled ?? this.autoProtectionEnabled,
      autoProtectionSchedule: autoProtectionSchedule ?? this.autoProtectionSchedule,
      trustedWifiSsid: trustedWifiSsid ?? this.trustedWifiSsid,
      monitorCalls: monitorCalls ?? this.monitorCalls,
      monitorAirplaneMode: monitorAirplaneMode ?? this.monitorAirplaneMode,
      monitorSimCard: monitorSimCard ?? this.monitorSimCard,
      blockSettings: blockSettings ?? this.blockSettings,
      blockPowerMenu: blockPowerMenu ?? this.blockPowerMenu,
      blockFileManagers: blockFileManagers ?? this.blockFileManagers,
      dailyReportEnabled: dailyReportEnabled ?? this.dailyReportEnabled,
      dailyReportTime: dailyReportTime ?? this.dailyReportTime,
      whatsappNumber: whatsappNumber ?? this.whatsappNumber,
      audioRecordingEnabled: audioRecordingEnabled ?? this.audioRecordingEnabled,
      lockScreenMessage: lockScreenMessage ?? this.lockScreenMessage,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ProtectionConfig &&
        other.protectedModeEnabled == protectedModeEnabled &&
        other.kioskModeEnabled == kioskModeEnabled &&
        other.stealthModeEnabled == stealthModeEnabled &&
        other.panicModeEnabled == panicModeEnabled &&
        other.emergencyContact == emergencyContact &&
        other.locationTrackingInterval == locationTrackingInterval &&
        other.autoProtectionEnabled == autoProtectionEnabled &&
        other.trustedWifiSsid == trustedWifiSsid &&
        other.monitorCalls == monitorCalls &&
        other.monitorAirplaneMode == monitorAirplaneMode &&
        other.monitorSimCard == monitorSimCard &&
        other.blockSettings == blockSettings &&
        other.blockPowerMenu == blockPowerMenu &&
        other.blockFileManagers == blockFileManagers &&
        other.dailyReportEnabled == dailyReportEnabled &&
        other.whatsappNumber == whatsappNumber &&
        other.audioRecordingEnabled == audioRecordingEnabled &&
        other.lockScreenMessage == lockScreenMessage;
  }

  @override
  int get hashCode {
    return protectedModeEnabled.hashCode ^
        kioskModeEnabled.hashCode ^
        stealthModeEnabled.hashCode ^
        panicModeEnabled.hashCode ^
        (emergencyContact?.hashCode ?? 0) ^
        locationTrackingInterval.hashCode ^
        autoProtectionEnabled.hashCode;
  }

  @override
  String toString() {
    return 'ProtectionConfig(protectedMode: $protectedModeEnabled, kioskMode: $kioskModeEnabled, stealthMode: $stealthModeEnabled)';
  }
}
