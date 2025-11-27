/// Location service module for the Anti-Theft Protection app.
///
/// Provides location tracking functionality including:
/// - Periodic location updates
/// - High-frequency tracking for panic mode
/// - Location history storage
/// - Adaptive tracking based on battery level
/// - Background tracking using WorkManager
///
/// Requirements: 5.1, 5.2, 5.3, 5.5, 10.1, 10.3, 10.4, 21.4
library;

export 'background_location_service.dart';
export 'i_location_service.dart';
export 'location_service.dart';
