import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:provider/provider.dart';

import '../../domain/entities/location_data.dart';
import '../providers/location_history_provider.dart';
import '../widgets/location_details_bottom_sheet.dart';
import '../widgets/location_filter_dialog.dart';

/// Location History Screen displaying all tracked locations on a map.
/// 
/// Requirements:
/// - 5.4: Display all tracked locations on a map with timestamps
class LocationHistoryScreen extends StatefulWidget {
  const LocationHistoryScreen({super.key});

  @override
  State<LocationHistoryScreen> createState() => _LocationHistoryScreenState();
}

class _LocationHistoryScreenState extends State<LocationHistoryScreen> {
  GoogleMapController? _mapController;
  bool _showList = false;

  @override
  void initState() {
    super.initState();
    // Load data when screen initializes
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<LocationHistoryProvider>().loadLocationHistory();
    });
  }

  @override
  void dispose() {
    _mapController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl, // Arabic RTL support
      child: Scaffold(
        appBar: AppBar(
          title: const Text('سجل المواقع'),
          centerTitle: true,
          actions: [
            IconButton(
              icon: Icon(_showList ? Icons.map : Icons.list),
              onPressed: () => setState(() => _showList = !_showList),
              tooltip: _showList ? 'عرض الخريطة' : 'عرض القائمة',
            ),
            IconButton(
              icon: const Icon(Icons.filter_list),
              onPressed: () => _showFilterDialog(context),
              tooltip: 'تصفية',
            ),
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: () {
                context.read<LocationHistoryProvider>().loadLocationHistory();
              },
              tooltip: 'تحديث',
            ),
          ],
        ),
        body: Consumer<LocationHistoryProvider>(
          builder: (context, provider, child) {
            if (provider.isLoading) {
              return const Center(
                child: CircularProgressIndicator(),
              );
            }

            if (provider.error != null) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline, size: 48, color: Colors.red),
                    const SizedBox(height: 16),
                    Text(
                      provider.error!,
                      style: const TextStyle(color: Colors.red),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () => provider.loadLocationHistory(),
                      child: const Text('إعادة المحاولة'),
                    ),
                  ],
                ),
              );
            }

            if (provider.allLocations.isEmpty) {
              return _buildEmptyState();
            }

            return _showList
                ? _buildLocationList(provider)
                : _buildMapView(provider);
          },
        ),
        floatingActionButton: Consumer<LocationHistoryProvider>(
          builder: (context, provider, child) {
            if (provider.allLocations.isEmpty || _showList) {
              return const SizedBox.shrink();
            }
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                FloatingActionButton.small(
                  heroTag: 'fit_bounds',
                  onPressed: () => _fitBounds(provider),
                  child: const Icon(Icons.fit_screen),
                ),
                const SizedBox(height: 8),
                FloatingActionButton.small(
                  heroTag: 'current_location',
                  onPressed: () => _goToMostRecent(provider),
                  child: const Icon(Icons.my_location),
                ),
              ],
            );
          },
        ),
      ),
    );
  }


  /// Builds the map view showing all locations
  /// Requirements: 5.4 - Display all tracked locations on a map
  Widget _buildMapView(LocationHistoryProvider provider) {
    return Stack(
      children: [
        GoogleMap(
          initialCameraPosition: CameraPosition(
            target: provider.initialCameraPosition,
            zoom: 14,
          ),
          markers: provider.markers,
          polylines: provider.polylines,
          onMapCreated: (controller) {
            _mapController = controller;
            // Fit bounds after map is created
            Future.delayed(const Duration(milliseconds: 500), () {
              _fitBounds(provider);
            });
          },
          myLocationEnabled: true,
          myLocationButtonEnabled: false,
          zoomControlsEnabled: false,
          mapToolbarEnabled: false,
        ),
        // Location count badge
        Positioned(
          top: 16,
          right: 16,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.location_on, size: 16, color: Colors.blue),
                const SizedBox(width: 4),
                Text(
                  '${provider.filteredLocationCount} موقع',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ),
        // Filter indicator
        if (provider.filter.hasFilters)
          Positioned(
            top: 16,
            left: 16,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.orange.shade100,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.orange),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.filter_alt, size: 16, color: Colors.orange),
                  const SizedBox(width: 4),
                  const Text(
                    'تصفية نشطة',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.orange,
                    ),
                  ),
                  const SizedBox(width: 4),
                  GestureDetector(
                    onTap: () => provider.clearFilters(),
                    child: const Icon(Icons.close, size: 16, color: Colors.orange),
                  ),
                ],
              ),
            ),
          ),
        // Legend
        Positioned(
          bottom: 16,
          right: 16,
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildLegendItem(Colors.green, 'الموقع الأحدث'),
                const SizedBox(height: 4),
                _buildLegendItem(Colors.red, 'الموقع الأقدم'),
                const SizedBox(height: 4),
                _buildLegendItem(Colors.blue, 'مواقع أخرى'),
              ],
            ),
          ),
        ),
        // Selected location details
        if (provider.selectedLocation != null)
          Positioned(
            bottom: 100,
            left: 16,
            right: 16,
            child: _buildSelectedLocationCard(provider.selectedLocation!),
          ),
      ],
    );
  }

  Widget _buildLegendItem(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: const TextStyle(fontSize: 11),
        ),
      ],
    );
  }

  Widget _buildSelectedLocationCard(LocationData location) {
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                const Icon(Icons.location_on, color: Colors.blue),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'تفاصيل الموقع',
                    style: Theme.of(context).textTheme.titleMedium,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 20),
                  onPressed: () {
                    context.read<LocationHistoryProvider>().selectLocation(null);
                  },
                ),
              ],
            ),
            const Divider(),
            _buildDetailRow('خط العرض', location.latitude.toStringAsFixed(6)),
            _buildDetailRow('خط الطول', location.longitude.toStringAsFixed(6)),
            _buildDetailRow('الدقة', '${location.accuracy.toStringAsFixed(1)} متر'),
            _buildDetailRow(
              'التاريخ',
              DateFormat('yyyy/MM/dd HH:mm:ss', 'ar').format(location.timestamp),
            ),
            if (location.address != null)
              _buildDetailRow('العنوان', location.address!),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => _openInMaps(location),
                icon: const Icon(Icons.map, size: 16),
                label: const Text(
                  'فتح في الخرائط',
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              '$label:',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 12),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  /// Builds the list view showing all locations
  /// Requirements: 5.4 - Display all tracked locations with timestamps
  Widget _buildLocationList(LocationHistoryProvider provider) {
    final locations = provider.filteredLocations;

    return Column(
      children: [
        // Summary header
        Container(
          padding: const EdgeInsets.all(16),
          color: Colors.grey.shade100,
          child: Row(
            children: [
              const Icon(Icons.location_on, color: Colors.blue),
              const SizedBox(width: 8),
              Text(
                '${locations.length} موقع مسجل',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              if (provider.filter.hasFilters)
                TextButton.icon(
                  onPressed: () => provider.clearFilters(),
                  icon: const Icon(Icons.clear, size: 16),
                  label: const Text('مسح التصفية'),
                ),
            ],
          ),
        ),
        // Location list
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(8),
            itemCount: locations.length,
            itemBuilder: (context, index) {
              final location = locations[index];
              final isFirst = index == 0;
              final isLast = index == locations.length - 1;
              
              return _buildLocationTile(location, isFirst, isLast, index);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildLocationTile(
    LocationData location,
    bool isFirst,
    bool isLast,
    int index,
  ) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: isFirst
              ? Colors.green
              : isLast
                  ? Colors.red
                  : Colors.blue,
          child: Text(
            '${index + 1}',
            style: const TextStyle(color: Colors.white, fontSize: 12),
          ),
        ),
        title: Text(
          isFirst
              ? 'الموقع الأحدث'
              : isLast
                  ? 'الموقع الأقدم'
                  : 'الموقع ${index + 1}',
          style: const TextStyle(fontWeight: FontWeight.bold),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              DateFormat('yyyy/MM/dd HH:mm:ss', 'ar').format(location.timestamp),
              style: const TextStyle(fontSize: 12),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              'الدقة: ${location.accuracy.toStringAsFixed(1)} متر',
              style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
        trailing: Wrap(
          spacing: 0,
          children: [
            IconButton(
              icon: const Icon(Icons.map, size: 20),
              onPressed: () {
                setState(() => _showList = false);
                _goToLocation(location);
              },
              tooltip: 'عرض على الخريطة',
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
            ),
            IconButton(
              icon: const Icon(Icons.open_in_new, size: 20),
              onPressed: () => _openInMaps(location),
              tooltip: 'فتح في الخرائط',
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
            ),
          ],
        ),
        onTap: () => _showLocationDetails(context, location),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.location_off, size: 64, color: Colors.grey.shade400),
          const SizedBox(height: 16),
          const Text(
            'لا توجد مواقع مسجلة',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'سيتم تسجيل المواقع عند تفعيل وضع الحماية',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }

  void _showFilterDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => const LocationFilterDialog(),
    );
  }

  void _showLocationDetails(BuildContext context, LocationData location) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => LocationDetailsBottomSheet(location: location),
    );
  }

  void _fitBounds(LocationHistoryProvider provider) {
    if (_mapController != null && provider.bounds != null) {
      _mapController!.animateCamera(
        CameraUpdate.newLatLngBounds(provider.bounds!, 50),
      );
    }
  }

  void _goToMostRecent(LocationHistoryProvider provider) {
    final mostRecent = provider.mostRecentLocation;
    if (_mapController != null && mostRecent != null) {
      _mapController!.animateCamera(
        CameraUpdate.newLatLngZoom(
          LatLng(mostRecent.latitude, mostRecent.longitude),
          16,
        ),
      );
      provider.selectLocation(mostRecent);
    }
  }

  void _goToLocation(LocationData location) {
    if (_mapController != null) {
      _mapController!.animateCamera(
        CameraUpdate.newLatLngZoom(
          LatLng(location.latitude, location.longitude),
          16,
        ),
      );
      context.read<LocationHistoryProvider>().selectLocation(location);
    }
  }

  void _openInMaps(LocationData location) {
    // Open in external maps app using the Google Maps link
    final url = location.toGoogleMapsLink();
    // In a real app, you would use url_launcher package
    // For now, we'll show a dialog with the link
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('رابط الموقع'),
        content: SelectableText(url),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إغلاق'),
          ),
        ],
      ),
    );
  }
}
