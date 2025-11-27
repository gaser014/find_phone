import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../domain/entities/security_event.dart';

/// A tile widget for displaying a security event in a list.
/// 
/// Requirements:
/// - 9.4: Display events in chronological order
/// - 4.4: Display all unauthorized access attempts
class SecurityEventTile extends StatelessWidget {
  final SecurityEvent event;
  final VoidCallback? onTap;
  final VoidCallback? onPhotoTap;
  final bool isUnauthorizedAccess;

  const SecurityEventTile({
    super.key,
    required this.event,
    this.onTap,
    this.onPhotoTap,
    this.isUnauthorizedAccess = false,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 0),
      color: isUnauthorizedAccess ? Colors.red.shade50 : null,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              _buildEventIcon(),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _getEventTypeLabel(event.type),
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: isUnauthorizedAccess ? Colors.red.shade700 : null,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      event.description,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
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
                          _formatTimestamp(event.timestamp),
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey.shade500,
                          ),
                        ),
                        if (event.location != null) ...[
                          const SizedBox(width: 12),
                          Icon(
                            Icons.location_on,
                            size: 12,
                            color: Colors.grey.shade500,
                          ),
                          const SizedBox(width: 2),
                          Text(
                            'موقع متاح',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey.shade500,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              if (event.photoPath != null)
                IconButton(
                  icon: const Icon(Icons.photo_camera, color: Colors.blue),
                  onPressed: onPhotoTap,
                  tooltip: 'عرض الصورة',
                ),
              const Icon(Icons.chevron_left, color: Colors.grey),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEventIcon() {
    final iconData = _getEventIcon(event.type);
    final color = _getEventColor(event.type);

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

  IconData _getEventIcon(SecurityEventType type) {
    switch (type) {
      case SecurityEventType.failedLogin:
        return Icons.lock_outline;
      case SecurityEventType.successfulLogin:
        return Icons.lock_open;
      case SecurityEventType.protectedModeEnabled:
        return Icons.shield;
      case SecurityEventType.protectedModeDisabled:
        return Icons.shield_outlined;
      case SecurityEventType.kioskModeEnabled:
        return Icons.screen_lock_portrait;
      case SecurityEventType.kioskModeDisabled:
        return Icons.screen_lock_portrait;
      case SecurityEventType.panicModeActivated:
        return Icons.warning;
      case SecurityEventType.airplaneModeChanged:
        return Icons.airplanemode_active;
      case SecurityEventType.simCardChanged:
        return Icons.sim_card;
      case SecurityEventType.settingsAccessed:
        return Icons.settings;
      case SecurityEventType.powerMenuBlocked:
        return Icons.power_settings_new;
      case SecurityEventType.appForceStop:
        return Icons.stop_circle;
      case SecurityEventType.remoteCommandReceived:
        return Icons.sms;
      case SecurityEventType.remoteCommandExecuted:
        return Icons.check_circle;
      case SecurityEventType.locationTracked:
        return Icons.location_on;
      case SecurityEventType.photoCapture:
        return Icons.camera_alt;
      case SecurityEventType.callLogged:
        return Icons.phone;
      case SecurityEventType.safeModeDetected:
        return Icons.security;
      case SecurityEventType.usbDebuggingEnabled:
        return Icons.usb;
      case SecurityEventType.fileManagerAccessed:
        return Icons.folder;
      case SecurityEventType.screenUnlockFailed:
        return Icons.lock;
      case SecurityEventType.deviceAdminDeactivationAttempted:
        return Icons.admin_panel_settings;
      case SecurityEventType.accountAdditionAttempted:
        return Icons.person_add;
      case SecurityEventType.appInstallationAttempted:
        return Icons.install_mobile;
      case SecurityEventType.appUninstallationAttempted:
        return Icons.delete;
      case SecurityEventType.screenLockChangeAttempted:
        return Icons.phonelink_lock;
      case SecurityEventType.factoryResetAttempted:
        return Icons.restore;
      case SecurityEventType.usbConnectionDetected:
        return Icons.usb;
      case SecurityEventType.developerOptionsAccessed:
        return Icons.developer_mode;
    }
  }

  Color _getEventColor(SecurityEventType type) {
    switch (type) {
      case SecurityEventType.failedLogin:
      case SecurityEventType.screenUnlockFailed:
      case SecurityEventType.deviceAdminDeactivationAttempted:
      case SecurityEventType.factoryResetAttempted:
      case SecurityEventType.panicModeActivated:
        return Colors.red;
      case SecurityEventType.successfulLogin:
      case SecurityEventType.protectedModeEnabled:
      case SecurityEventType.remoteCommandExecuted:
        return Colors.green;
      case SecurityEventType.settingsAccessed:
      case SecurityEventType.fileManagerAccessed:
      case SecurityEventType.accountAdditionAttempted:
      case SecurityEventType.appInstallationAttempted:
      case SecurityEventType.appUninstallationAttempted:
      case SecurityEventType.screenLockChangeAttempted:
      case SecurityEventType.developerOptionsAccessed:
        return Colors.orange;
      case SecurityEventType.simCardChanged:
      case SecurityEventType.airplaneModeChanged:
      case SecurityEventType.usbDebuggingEnabled:
      case SecurityEventType.usbConnectionDetected:
        return Colors.purple;
      case SecurityEventType.locationTracked:
        return Colors.blue;
      case SecurityEventType.photoCapture:
        return Colors.teal;
      case SecurityEventType.callLogged:
        return Colors.indigo;
      default:
        return Colors.grey;
    }
  }

  String _getEventTypeLabel(SecurityEventType type) {
    switch (type) {
      case SecurityEventType.failedLogin:
        return 'فشل تسجيل الدخول';
      case SecurityEventType.successfulLogin:
        return 'تسجيل دخول ناجح';
      case SecurityEventType.protectedModeEnabled:
        return 'تفعيل وضع الحماية';
      case SecurityEventType.protectedModeDisabled:
        return 'إلغاء وضع الحماية';
      case SecurityEventType.kioskModeEnabled:
        return 'تفعيل وضع Kiosk';
      case SecurityEventType.kioskModeDisabled:
        return 'إلغاء وضع Kiosk';
      case SecurityEventType.panicModeActivated:
        return 'تفعيل وضع الذعر';
      case SecurityEventType.airplaneModeChanged:
        return 'تغيير وضع الطيران';
      case SecurityEventType.simCardChanged:
        return 'تغيير شريحة SIM';
      case SecurityEventType.settingsAccessed:
        return 'الوصول للإعدادات';
      case SecurityEventType.powerMenuBlocked:
        return 'حظر قائمة الطاقة';
      case SecurityEventType.appForceStop:
        return 'إيقاف التطبيق قسرياً';
      case SecurityEventType.remoteCommandReceived:
        return 'استلام أمر عن بعد';
      case SecurityEventType.remoteCommandExecuted:
        return 'تنفيذ أمر عن بعد';
      case SecurityEventType.locationTracked:
        return 'تتبع الموقع';
      case SecurityEventType.photoCapture:
        return 'التقاط صورة';
      case SecurityEventType.callLogged:
        return 'تسجيل مكالمة';
      case SecurityEventType.safeModeDetected:
        return 'اكتشاف الوضع الآمن';
      case SecurityEventType.usbDebuggingEnabled:
        return 'تفعيل تصحيح USB';
      case SecurityEventType.fileManagerAccessed:
        return 'الوصول لمدير الملفات';
      case SecurityEventType.screenUnlockFailed:
        return 'فشل فتح الشاشة';
      case SecurityEventType.deviceAdminDeactivationAttempted:
        return 'محاولة إلغاء صلاحية المسؤول';
      case SecurityEventType.accountAdditionAttempted:
        return 'محاولة إضافة حساب';
      case SecurityEventType.appInstallationAttempted:
        return 'محاولة تثبيت تطبيق';
      case SecurityEventType.appUninstallationAttempted:
        return 'محاولة إزالة تطبيق';
      case SecurityEventType.screenLockChangeAttempted:
        return 'محاولة تغيير قفل الشاشة';
      case SecurityEventType.factoryResetAttempted:
        return 'محاولة إعادة ضبط المصنع';
      case SecurityEventType.usbConnectionDetected:
        return 'اكتشاف اتصال USB';
      case SecurityEventType.developerOptionsAccessed:
        return 'الوصول لخيارات المطور';
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
