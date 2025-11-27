import 'package:flutter/material.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:provider/provider.dart';

import '../../domain/entities/security_event.dart';
import '../../domain/entities/call_log_entry.dart';
import '../providers/security_logs_provider.dart';
import '../widgets/security_event_tile.dart';
import '../widgets/call_log_tile.dart';
import '../widgets/photo_viewer_dialog.dart';
import '../widgets/filter_bottom_sheet.dart';

/// Security Logs Screen displaying all security events in chronological order.
/// 
/// Requirements:
/// - 9.4: Display events in chronological order with filtering options
/// - 4.4: Display all unauthorized access attempts
/// - 19.4, 19.5: Display call logs with Emergency Contact highlighting
class SecurityLogsScreen extends StatefulWidget {
  const SecurityLogsScreen({super.key});

  @override
  State<SecurityLogsScreen> createState() => _SecurityLogsScreenState();
}

class _SecurityLogsScreenState extends State<SecurityLogsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    
    // Load data when screen initializes
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<SecurityLogsProvider>().loadAllData();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl, // Arabic RTL support
      child: Scaffold(
        appBar: AppBar(
          title: const Text('سجلات الأمان'),
          centerTitle: true,
          actions: [
            IconButton(
              icon: const Icon(Icons.filter_list),
              onPressed: () => _showFilterBottomSheet(context),
              tooltip: 'تصفية',
            ),
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: () {
                context.read<SecurityLogsProvider>().loadAllData();
              },
              tooltip: 'تحديث',
            ),
          ],
          bottom: TabBar(
            controller: _tabController,
            tabs: const [
              Tab(text: 'جميع الأحداث', icon: Icon(Icons.list)),
              Tab(text: 'محاولات الوصول', icon: Icon(Icons.warning)),
              Tab(text: 'سجل المكالمات', icon: Icon(Icons.phone)),
            ],
          ),
        ),
        body: Consumer<SecurityLogsProvider>(
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
                      onPressed: () => provider.loadAllData(),
                      child: const Text('إعادة المحاولة'),
                    ),
                  ],
                ),
              );
            }

            return TabBarView(
              controller: _tabController,
              children: [
                _buildAllEventsTab(provider),
                _buildUnauthorizedAccessTab(provider),
                _buildCallLogsTab(provider),
              ],
            );
          },
        ),
      ),
    );
  }

  /// Builds the "All Events" tab showing all security events
  /// Requirements: 9.4 - Display events in chronological order
  Widget _buildAllEventsTab(SecurityLogsProvider provider) {
    final events = provider.filteredEvents;

    if (events.isEmpty) {
      return _buildEmptyState(
        icon: Icons.event_note,
        message: 'لا توجد أحداث أمنية',
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(8),
      itemCount: events.length,
      itemBuilder: (context, index) {
        final event = events[index];
        return SecurityEventTile(
          event: event,
          onTap: () => _showEventDetails(context, event),
          onPhotoTap: event.photoPath != null
              ? () => _showPhotoViewer(context, event.photoPath!)
              : null,
        );
      },
    );
  }

  /// Builds the "Unauthorized Access" tab showing only unauthorized access attempts
  /// Requirements: 4.4 - Display all unauthorized access attempts
  Widget _buildUnauthorizedAccessTab(SecurityLogsProvider provider) {
    final events = provider.unauthorizedAccessEvents;

    if (events.isEmpty) {
      return _buildEmptyState(
        icon: Icons.security,
        message: 'لا توجد محاولات وصول غير مصرح بها',
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(8),
      itemCount: events.length,
      itemBuilder: (context, index) {
        final event = events[index];
        return SecurityEventTile(
          event: event,
          onTap: () => _showEventDetails(context, event),
          onPhotoTap: event.photoPath != null
              ? () => _showPhotoViewer(context, event.photoPath!)
              : null,
          isUnauthorizedAccess: true,
        );
      },
    );
  }

  /// Builds the "Call Logs" tab showing all call logs
  /// Requirements: 19.4, 19.5 - Display call logs with Emergency Contact highlighting
  Widget _buildCallLogsTab(SecurityLogsProvider provider) {
    final callLogs = provider.callLogs;

    if (callLogs.isEmpty) {
      return _buildEmptyState(
        icon: Icons.phone_missed,
        message: 'لا توجد سجلات مكالمات',
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(8),
      itemCount: callLogs.length,
      itemBuilder: (context, index) {
        final callLog = callLogs[index];
        return CallLogTile(
          callLog: callLog,
          onTap: () => _showCallLogDetails(context, callLog),
        );
      },
    );
  }

  Widget _buildEmptyState({required IconData icon, required String message}) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 64, color: Colors.grey),
          const SizedBox(height: 16),
          Text(
            message,
            style: const TextStyle(
              fontSize: 16,
              color: Colors.grey,
            ),
          ),
        ],
      ),
    );
  }

  void _showFilterBottomSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => const FilterBottomSheet(),
    );
  }

  void _showEventDetails(BuildContext context, SecurityEvent event) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(_getEventTypeLabel(event.type)),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildDetailRow('الوصف', event.description),
              _buildDetailRow(
                'التاريخ',
                DateFormat('yyyy/MM/dd HH:mm:ss', 'ar').format(event.timestamp),
              ),
              if (event.location != null) ...[
                _buildDetailRow(
                  'الموقع',
                  'خط العرض: ${event.location!['latitude']}\n'
                  'خط الطول: ${event.location!['longitude']}',
                ),
              ],
              if (event.photoPath != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      _showPhotoViewer(context, event.photoPath!);
                    },
                    icon: const Icon(Icons.photo),
                    label: const Text('عرض الصورة'),
                  ),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إغلاق'),
          ),
        ],
      ),
    );
  }

  void _showCallLogDetails(BuildContext context, CallLogEntry callLog) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(callLog.isEmergencyContact ? 'جهة اتصال الطوارئ' : 'تفاصيل المكالمة'),
        content: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildDetailRow('الرقم', callLog.phoneNumber),
            _buildDetailRow('النوع', _getCallTypeLabel(callLog.type)),
            _buildDetailRow(
              'التاريخ',
              DateFormat('yyyy/MM/dd HH:mm:ss', 'ar').format(callLog.timestamp),
            ),
            _buildDetailRow('المدة', callLog.formattedDuration),
            if (callLog.isEmergencyContact)
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Chip(
                  label: Text('جهة اتصال الطوارئ'),
                  backgroundColor: Colors.green,
                  labelStyle: TextStyle(color: Colors.white),
                ),
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إغلاق'),
          ),
        ],
      ),
    );
  }

  void _showPhotoViewer(BuildContext context, String photoPath) {
    showDialog(
      context: context,
      builder: (context) => PhotoViewerDialog(photoPath: photoPath),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$label: ',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
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

  String _getCallTypeLabel(CallType type) {
    switch (type) {
      case CallType.incoming:
        return 'واردة';
      case CallType.outgoing:
        return 'صادرة';
      case CallType.missed:
        return 'فائتة';
    }
  }
}
