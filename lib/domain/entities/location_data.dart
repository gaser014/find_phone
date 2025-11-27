/// Represents location data captured by the anti-theft protection system.
/// 
/// Contains GPS coordinates, accuracy, timestamp, and optional address.
/// Provides utility methods for generating Google Maps links.
class LocationData {
  /// Latitude coordinate
  final double latitude;
  
  /// Longitude coordinate
  final double longitude;
  
  /// Accuracy of the location in meters
  final double accuracy;
  
  /// When the location was recorded
  final DateTime timestamp;
  
  /// Human-readable address (if reverse geocoded)
  final String? address;

  LocationData({
    required this.latitude,
    required this.longitude,
    required this.accuracy,
    required this.timestamp,
    this.address,
  });

  /// Generates a Google Maps link for this location
  String toGoogleMapsLink() {
    return 'https://maps.google.com/?q=$latitude,$longitude';
  }

  /// Creates a LocationData from JSON map
  factory LocationData.fromJson(Map<String, dynamic> json) {
    return LocationData(
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      accuracy: (json['accuracy'] as num).toDouble(),
      timestamp: DateTime.parse(json['timestamp'] as String),
      address: json['address'] as String?,
    );
  }

  /// Converts the LocationData to a JSON map
  Map<String, dynamic> toJson() {
    return {
      'latitude': latitude,
      'longitude': longitude,
      'accuracy': accuracy,
      'timestamp': timestamp.toIso8601String(),
      'address': address,
    };
  }

  /// Creates a copy of this location with optional field overrides
  LocationData copyWith({
    double? latitude,
    double? longitude,
    double? accuracy,
    DateTime? timestamp,
    String? address,
  }) {
    return LocationData(
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      accuracy: accuracy ?? this.accuracy,
      timestamp: timestamp ?? this.timestamp,
      address: address ?? this.address,
    );
  }

  /// Calculates distance to another location in meters (Haversine formula)
  double distanceTo(LocationData other) {
    const double earthRadius = 6371000; // meters
    final double lat1Rad = latitude * (3.141592653589793 / 180);
    final double lat2Rad = other.latitude * (3.141592653589793 / 180);
    final double deltaLat = (other.latitude - latitude) * (3.141592653589793 / 180);
    final double deltaLon = (other.longitude - longitude) * (3.141592653589793 / 180);

    final double a = _sin(deltaLat / 2) * _sin(deltaLat / 2) +
        _cos(lat1Rad) * _cos(lat2Rad) * _sin(deltaLon / 2) * _sin(deltaLon / 2);
    final double c = 2 * _atan2(_sqrt(a), _sqrt(1 - a));

    return earthRadius * c;
  }

  // Math helper functions to avoid dart:math import issues in some contexts
  double _sin(double x) => _taylorSin(x);
  double _cos(double x) => _taylorSin(x + 1.5707963267948966);
  double _sqrt(double x) => _newtonSqrt(x);
  double _atan2(double y, double x) => _approximateAtan2(y, x);

  double _taylorSin(double x) {
    // Normalize to [-pi, pi]
    const double pi = 3.141592653589793;
    while (x > pi) x -= 2 * pi;
    while (x < -pi) x += 2 * pi;
    
    double result = x;
    double term = x;
    for (int i = 1; i <= 10; i++) {
      term *= -x * x / ((2 * i) * (2 * i + 1));
      result += term;
    }
    return result;
  }

  double _newtonSqrt(double x) {
    if (x <= 0) return 0;
    double guess = x / 2;
    for (int i = 0; i < 20; i++) {
      guess = (guess + x / guess) / 2;
    }
    return guess;
  }

  double _approximateAtan2(double y, double x) {
    const double pi = 3.141592653589793;
    if (x > 0) return _atan(y / x);
    if (x < 0 && y >= 0) return _atan(y / x) + pi;
    if (x < 0 && y < 0) return _atan(y / x) - pi;
    if (x == 0 && y > 0) return pi / 2;
    if (x == 0 && y < 0) return -pi / 2;
    return 0;
  }

  double _atan(double x) {
    // Taylor series approximation for atan
    if (x.abs() > 1) {
      const double pi = 3.141592653589793;
      return (x > 0 ? pi / 2 : -pi / 2) - _atan(1 / x);
    }
    double result = x;
    double term = x;
    for (int i = 1; i <= 15; i++) {
      term *= -x * x;
      result += term / (2 * i + 1);
    }
    return result;
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is LocationData &&
        other.latitude == latitude &&
        other.longitude == longitude &&
        other.accuracy == accuracy &&
        other.timestamp == timestamp &&
        other.address == address;
  }

  @override
  int get hashCode {
    return latitude.hashCode ^
        longitude.hashCode ^
        accuracy.hashCode ^
        timestamp.hashCode ^
        (address?.hashCode ?? 0);
  }

  @override
  String toString() {
    return 'LocationData(lat: $latitude, lng: $longitude, accuracy: ${accuracy}m, timestamp: $timestamp)';
  }
}
