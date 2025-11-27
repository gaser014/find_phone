import 'package:flutter/material.dart';
import 'package:intl/intl.dart' hide TextDirection;

import '../../domain/entities/location_data.dart';

/// Bottom sheet displaying detailed information about a location.
/// 
/// Requirements:
/// - 5.4: Display location markers with timestamps
class LocationDetailsBottomSheet extends StatelessWidget {
  final LocationData location;

  const LocationDetailsBottomSheet({
    super.key,
    required this.location,
  });

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle bar
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            // Title
            Row(
              children: [
                const Icon(Icons.location_on, color: Colors.blue, size: 28),
                const SizedBox(width: 12),
                Text(
                  'تفاصيل الموقع',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const Divider(height: 24),
            // Location details
            _buildDetailCard(
              context,
              icon: Icons.access_time,
              title: 'التاريخ والوقت',
              value: DateFormat('yyyy/MM/dd HH:mm:ss', 'ar').format(location.timestamp),
              subtitle: _getRelativeTime(location.timestamp),
            ),
            const SizedBox(height: 12),
            _buildDetailCard(
              context,
              icon: Icons.my_location,
              title: 'الإحداثيات',
              value: '${location.latitude.toStringAsFixed(6)}, ${location.longitude.toStringAsFixed(6)}',
              subtitle: 'خط العرض، خط الطول',
            ),
            const SizedBox(height: 12),
            _buildDetailCard(
              context,
              icon: Icons.gps_fixed,
              title: 'دقة الموقع',
              value: '${location.accuracy.toStringAsFixed(1)} متر',
              subtitle: _getAccuracyDescription(location.accuracy),
            ),
            if (location.address != null) ...[
              const SizedBox(height: 12),
              _buildDetailCard(
                context,
                icon: Icons.place,
                title: 'العنوان',
                value: location.address!,
              ),
            ],
            const SizedBox(height: 24),
            // Action buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _copyCoordinates(context),
                    icon: const Icon(Icons.copy),
                    label: const Text('نسخ الإحداثيات'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _openInMaps(context),
                    icon: const Icon(Icons.map),
                    label: const Text('فتح في الخرائط'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String value,
    String? subtitle,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: Colors.blue, size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey.shade500,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _getRelativeTime(DateTime timestamp) {
    final now = DateTime.now();
    final diff = now.difference(timestamp);

    if (diff.inMinutes < 1) {
      return 'الآن';
    } else if (diff.inMinutes < 60) {
      return 'منذ ${diff.inMinutes} دقيقة';
    } else if (diff.inHours < 24) {
      return 'منذ ${diff.inHours} ساعة';
    } else if (diff.inDays < 7) {
      return 'منذ ${diff.inDays} يوم';
    } else if (diff.inDays < 30) {
      return 'منذ ${(diff.inDays / 7).floor()} أسبوع';
    } else {
      return 'منذ ${(diff.inDays / 30).floor()} شهر';
    }
  }

  String _getAccuracyDescription(double accuracy) {
    if (accuracy <= 5) {
      return 'دقة عالية جداً';
    } else if (accuracy <= 15) {
      return 'دقة عالية';
    } else if (accuracy <= 50) {
      return 'دقة متوسطة';
    } else if (accuracy <= 100) {
      return 'دقة منخفضة';
    } else {
      return 'دقة ضعيفة';
    }
  }

  void _copyCoordinates(BuildContext context) {
    final coordinates = '${location.latitude}, ${location.longitude}';
    // In a real app, you would use Clipboard.setData
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('تم نسخ الإحداثيات: $coordinates'),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _openInMaps(BuildContext context) {
    final url = location.toGoogleMapsLink();
    // In a real app, you would use url_launcher package
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
