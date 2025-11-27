import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show Colors;
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../domain/entities/location_data.dart';
import '../../services/location/i_location_service.dart';

/// Filter options for location history
class LocationHistoryFilter {
  final DateTime? startDate;
  final DateTime? endDate;

  const LocationHistoryFilter({
    this.startDate,
    this.endDate,
  });

  LocationHistoryFilter copyWith({
    DateTime? startDate,
    DateTime? endDate,
    bool clearStartDate = false,
    bool clearEndDate = false,
  }) {
    return LocationHistoryFilter(
      startDate: clearStartDate ? null : (startDate ?? this.startDate),
      endDate: clearEndDate ? null : (endDate ?? this.endDate),
    );
  }

  bool get hasFilters => startDate != null || endDate != null;
}

/// Provider for managing location history state.
/// 
/// Requirements:
/// - 5.4: Display all tracked locations on a map
class LocationHistoryProvider extends ChangeNotifier {
  final ILocationService _locationService;

  LocationHistoryProvider({
    required ILocationService locationService,
  }) : _locationService = locationService;

  // State
  List<LocationData> _allLocations = [];
  LocationHistoryFilter _filter = const LocationHistoryFilter();
  bool _isLoading = false;
  String? _error;
  LocationData? _selectedLocation;
  Set<Marker> _markers = {};
  Set<Polyline> _polylines = {};
  LatLngBounds? _bounds;

  // Getters
  List<LocationData> get allLocations => _allLocations;
  LocationHistoryFilter get filter => _filter;
  bool get isLoading => _isLoading;
  String? get error => _error;
  LocationData? get selectedLocation => _selectedLocation;
  Set<Marker> get markers => _markers;
  Set<Polyline> get polylines => _polylines;
  LatLngBounds? get bounds => _bounds;


  /// Returns filtered locations based on current filter settings
  /// Requirements: 5.4 - Display all tracked locations on a map
  List<LocationData> get filteredLocations {
    List<LocationData> locations = List.from(_allLocations);

    // Filter by date range
    if (_filter.startDate != null) {
      locations = locations.where((loc) => 
        loc.timestamp.isAfter(_filter.startDate!) || 
        loc.timestamp.isAtSameMomentAs(_filter.startDate!)
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
      locations = locations.where((loc) => 
        loc.timestamp.isBefore(endOfDay) || 
        loc.timestamp.isAtSameMomentAs(endOfDay)
      ).toList();
    }

    // Sort by timestamp descending (most recent first)
    locations.sort((a, b) => b.timestamp.compareTo(a.timestamp));

    return locations;
  }

  /// Load all location history data
  Future<void> loadLocationHistory() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _allLocations = await _locationService.getLocationHistory();
      // Sort by timestamp descending (most recent first)
      _allLocations.sort((a, b) => b.timestamp.compareTo(a.timestamp));
      _updateMarkersAndPolylines();
      _error = null;
    } catch (e) {
      _error = 'فشل في تحميل سجل المواقع: ${e.toString()}';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Update markers and polylines based on filtered locations
  void _updateMarkersAndPolylines() {
    final locations = filteredLocations;
    
    if (locations.isEmpty) {
      _markers = {};
      _polylines = {};
      _bounds = null;
      return;
    }

    // Create markers for each location
    _markers = locations.asMap().entries.map((entry) {
      final index = entry.key;
      final location = entry.value;
      final isFirst = index == 0;
      final isLast = index == locations.length - 1;
      
      return Marker(
        markerId: MarkerId('location_$index'),
        position: LatLng(location.latitude, location.longitude),
        infoWindow: InfoWindow(
          title: _getMarkerTitle(index, isFirst, isLast),
          snippet: _formatTimestamp(location.timestamp),
        ),
        icon: _getMarkerIcon(isFirst, isLast),
        onTap: () => selectLocation(location),
      );
    }).toSet();

    // Create polyline connecting all locations (in chronological order)
    final sortedByTime = List<LocationData>.from(locations)
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
    
    if (sortedByTime.length > 1) {
      _polylines = {
        Polyline(
          polylineId: const PolylineId('location_path'),
          points: sortedByTime
              .map((loc) => LatLng(loc.latitude, loc.longitude))
              .toList(),
          color: Colors.blue,
          width: 3,
        ),
      };
    } else {
      _polylines = {};
    }

    // Calculate bounds
    _calculateBounds(locations);
  }

  void _calculateBounds(List<LocationData> locations) {
    if (locations.isEmpty) {
      _bounds = null;
      return;
    }

    double minLat = locations.first.latitude;
    double maxLat = locations.first.latitude;
    double minLng = locations.first.longitude;
    double maxLng = locations.first.longitude;

    for (final location in locations) {
      if (location.latitude < minLat) minLat = location.latitude;
      if (location.latitude > maxLat) maxLat = location.latitude;
      if (location.longitude < minLng) minLng = location.longitude;
      if (location.longitude > maxLng) maxLng = location.longitude;
    }

    // Add some padding
    const padding = 0.01;
    _bounds = LatLngBounds(
      southwest: LatLng(minLat - padding, minLng - padding),
      northeast: LatLng(maxLat + padding, maxLng + padding),
    );
  }

  String _getMarkerTitle(int index, bool isFirst, bool isLast) {
    if (isFirst) return 'الموقع الأحدث';
    if (isLast) return 'الموقع الأقدم';
    return 'الموقع ${index + 1}';
  }

  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final diff = now.difference(timestamp);
    
    if (diff.inMinutes < 1) {
      return 'الآن';
    } else if (diff.inHours < 1) {
      return 'منذ ${diff.inMinutes} دقيقة';
    } else if (diff.inDays < 1) {
      return 'منذ ${diff.inHours} ساعة';
    } else if (diff.inDays < 7) {
      return 'منذ ${diff.inDays} يوم';
    } else {
      return '${timestamp.day}/${timestamp.month}/${timestamp.year}';
    }
  }

  BitmapDescriptor _getMarkerIcon(bool isFirst, bool isLast) {
    if (isFirst) {
      return BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen);
    } else if (isLast) {
      return BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed);
    }
    return BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure);
  }

  /// Select a location to show details
  void selectLocation(LocationData? location) {
    _selectedLocation = location;
    notifyListeners();
  }

  /// Update filter settings
  void updateFilter(LocationHistoryFilter newFilter) {
    _filter = newFilter;
    _updateMarkersAndPolylines();
    notifyListeners();
  }

  /// Clear all filters
  void clearFilters() {
    _filter = const LocationHistoryFilter();
    _updateMarkersAndPolylines();
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
    _updateMarkersAndPolylines();
    notifyListeners();
  }

  /// Get total location count
  int get totalLocationCount => _allLocations.length;

  /// Get filtered location count
  int get filteredLocationCount => filteredLocations.length;

  /// Get the most recent location
  LocationData? get mostRecentLocation {
    if (_allLocations.isEmpty) return null;
    return _allLocations.first;
  }

  /// Get the initial camera position for the map
  LatLng get initialCameraPosition {
    if (_allLocations.isNotEmpty) {
      return LatLng(_allLocations.first.latitude, _allLocations.first.longitude);
    }
    // Default to Cairo, Egypt if no locations
    return const LatLng(30.0444, 31.2357);
  }
}
