import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../domain/entities/call_log_entry.dart';

/// A tile widget for displaying a call log entry.
/// 
/// Requirements:
/// - 19.4: Display all calls that occurred during Protected Mode
/// - 19.5: Mark Emergency Contact calls as trusted and highlight differently
class CallLogTile extends StatelessWidget {
  final CallLogEntry callLog;
  final VoidCallback? onTap;

  const CallLogTile({
    super.key,
    required this.callLog,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 0),
      color: callLog.isEmergencyContact ? Colors.green.shade50 : null,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              _buildCallIcon(),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            callLog.phoneNumber,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                              color: callLog.isEmergencyContact 
                                  ? Colors.green.shade700 
                                  : null,
                            ),
                          ),
                        ),
                        if (callLog.isEmergencyContact)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.green,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Text(
                              'طوارئ',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        _buildCallTypeChip(),
                        const SizedBox(width: 8),
                        Text(
                          callLog.formattedDuration,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          Icons.access_time,
                          size: 12,
                          color: Colors.grey.shade500,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _formatTimestamp(callLog.timestamp),
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey.shade500,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_left, color: Colors.grey),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCallIcon() {
    final iconData = _getCallTypeIcon();
    final color = _getCallTypeColor();

    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(
        iconData,
        color: color,
        size: 20,
      ),
    );
  }

  Widget _buildCallTypeChip() {
    final color = _getCallTypeColor();
    final label = _getCallTypeLabel();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          color: color,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  IconData _getCallTypeIcon() {
    switch (callLog.type) {
      case CallType.incoming:
        return Icons.call_received;
      case CallType.outgoing:
        return Icons.call_made;
      case CallType.missed:
        return Icons.call_missed;
    }
  }

  Color _getCallTypeColor() {
    if (callLog.isEmergencyContact) {
      return Colors.green;
    }
    
    switch (callLog.type) {
      case CallType.incoming:
        return Colors.blue;
      case CallType.outgoing:
        return Colors.teal;
      case CallType.missed:
        return Colors.red;
    }
  }

  String _getCallTypeLabel() {
    switch (callLog.type) {
      case CallType.incoming:
        return 'واردة';
      case CallType.outgoing:
        return 'صادرة';
      case CallType.missed:
        return 'فائتة';
    }
  }

  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inMinutes < 1) {
      return 'الآن';
    } else if (difference.inHours < 1) {
      return 'منذ ${difference.inMinutes} دقيقة';
    } else if (difference.inDays < 1) {
      return 'منذ ${difference.inHours} ساعة';
    } else if (difference.inDays < 7) {
      return 'منذ ${difference.inDays} يوم';
    } else {
      return DateFormat('yyyy/MM/dd HH:mm', 'ar').format(timestamp);
    }
  }
}
