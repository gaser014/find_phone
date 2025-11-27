/// Represents SIM card information for tracking changes.
/// 
/// Used to detect when a SIM card is removed or changed,
/// which may indicate theft.
class SimInfo {
  /// SIM card serial number (ICCID)
  final String? iccid;
  
  /// International Mobile Subscriber Identity
  final String? imsi;
  
  /// Phone number associated with the SIM
  final String? phoneNumber;
  
  /// Name of the carrier/operator
  final String? carrierName;
  
  /// When this SIM info was recorded
  final DateTime recordedAt;

  SimInfo({
    this.iccid,
    this.imsi,
    this.phoneNumber,
    this.carrierName,
    required this.recordedAt,
  });

  /// Checks if this SIM is different from another SIM.
  /// 
  /// Returns true if either ICCID or IMSI differs.
  bool isDifferentFrom(SimInfo other) {
    // If both have ICCID, compare them
    if (iccid != null && other.iccid != null) {
      if (iccid != other.iccid) return true;
    }
    
    // If both have IMSI, compare them
    if (imsi != null && other.imsi != null) {
      if (imsi != other.imsi) return true;
    }
    
    // If one has identifiers and the other doesn't, they're different
    if ((iccid != null || imsi != null) && 
        (other.iccid == null && other.imsi == null)) {
      return true;
    }
    
    if ((other.iccid != null || other.imsi != null) && 
        (iccid == null && imsi == null)) {
      return true;
    }
    
    return false;
  }

  /// Checks if this represents a valid SIM card (has at least one identifier).
  bool get isValid => iccid != null || imsi != null;

  /// Checks if the SIM card is absent (no identifiers).
  bool get isAbsent => iccid == null && imsi == null;

  /// Creates a SimInfo from JSON map
  factory SimInfo.fromJson(Map<String, dynamic> json) {
    return SimInfo(
      iccid: json['iccid'] as String?,
      imsi: json['imsi'] as String?,
      phoneNumber: json['phoneNumber'] as String?,
      carrierName: json['carrierName'] as String?,
      recordedAt: DateTime.parse(json['recordedAt'] as String),
    );
  }

  /// Converts the SimInfo to a JSON map
  Map<String, dynamic> toJson() {
    return {
      'iccid': iccid,
      'imsi': imsi,
      'phoneNumber': phoneNumber,
      'carrierName': carrierName,
      'recordedAt': recordedAt.toIso8601String(),
    };
  }

  /// Creates a copy of this SimInfo with optional field overrides
  SimInfo copyWith({
    String? iccid,
    String? imsi,
    String? phoneNumber,
    String? carrierName,
    DateTime? recordedAt,
  }) {
    return SimInfo(
      iccid: iccid ?? this.iccid,
      imsi: imsi ?? this.imsi,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      carrierName: carrierName ?? this.carrierName,
      recordedAt: recordedAt ?? this.recordedAt,
    );
  }

  /// Creates a SimInfo representing an absent SIM card
  factory SimInfo.absent() {
    return SimInfo(recordedAt: DateTime.now());
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is SimInfo &&
        other.iccid == iccid &&
        other.imsi == imsi &&
        other.phoneNumber == phoneNumber &&
        other.carrierName == carrierName &&
        other.recordedAt == recordedAt;
  }

  @override
  int get hashCode {
    return (iccid?.hashCode ?? 0) ^
        (imsi?.hashCode ?? 0) ^
        (phoneNumber?.hashCode ?? 0) ^
        (carrierName?.hashCode ?? 0) ^
        recordedAt.hashCode;
  }

  @override
  String toString() {
    return 'SimInfo(iccid: $iccid, imsi: $imsi, carrier: $carrierName, recordedAt: $recordedAt)';
  }
}
