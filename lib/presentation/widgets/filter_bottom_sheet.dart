import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../domain/entities/security_event.dart';
import '../providers/security_logs_provider.dart';

/// A bottom sheet widget for filtering security logs.
/// 
/// Requirements:
/// - 9.4: Display events with filtering options (by type, date)
class FilterBottomSheet extends StatefulWidget {
  const FilterBottomSheet({super.key});

  @override
  State<FilterBottomSheet> createState() => _FilterBottomSheetState();
}

class _FilterBottomSheetState extends State<FilterBottomSheet> {
  SecurityEventType? _selectedType;
  DateTime? _startDate;
  DateTime? _endDate;

  @override
  void initState() {
    super.initState();
    final provider = context.read<SecurityLogsProvider>();
    _selectedType = provider.filter.eventType;
    _startDate = provider.filter.startDate;
    _endDate = provider.filter.endDate;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Handle bar
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          
          // Title
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'تصفية الأحداث',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              TextButton(
                onPressed: _clearFilters,
                child: const Text('مسح الكل'),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Event type filter
          const Text(
            'نوع الحدث',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          _buildEventTypeDropdown(),
          const SizedBox(height: 16),

          // Date range filter
          const Text(
            'نطاق التاريخ',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _buildDateButton(
                  label: 'من',
                  date: _startDate,
                  onTap: () => _selectDate(isStart: true),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildDateButton(
                  label: 'إلى',
                  date: _endDate,
                  onTap: () => _selectDate(isStart: false),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Apply button
          ElevatedButton(
            onPressed: _applyFilters,
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text(
              'تطبيق',
              style: TextStyle(fontSize: 16),
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildEventTypeDropdown() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(12),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<SecurityEventType?>(
          value: _selectedType,
          isExpanded: true,
          hint: const Text('جميع الأنواع'),
          items: [
            const DropdownMenuItem<SecurityEventType?>(
              value: null,
              child: Text('جميع الأنواع'),
            ),
            ..._buildEventTypeItems(),
          ],
          onChanged: (value) {
            setState(() {
              _selectedType = value;
            });
          },
        ),
      ),
    );
  }

  List<DropdownMenuItem<SecurityEventType>> _buildEventTypeItems() {
    // Group event types by category for better UX
    final categories = {
      'محاولات الوصول': [
        SecurityEventType.failedLogin,
        SecurityEventType.screenUnlockFailed,
        SecurityEventType.settingsAccessed,
        SecurityEventType.fileManagerAccessed,
      ],
      'تغييرات النظام': [
        SecurityEventType.simCardChanged,
        SecurityEventType.airplaneModeChanged,
        SecurityEventType.usbDebuggingEnabled,
        SecurityEventType.usbConnectionDetected,
      ],
      'أوضاع الحماية': [
        SecurityEventType.protectedModeEnabled,
        SecurityEventType.protectedModeDisabled,
        SecurityEventType.kioskModeEnabled,
        SecurityEventType.kioskModeDisabled,
        SecurityEventType.panicModeActivated,
      ],
      'الأوامر عن بعد': [
        SecurityEventType.remoteCommandReceived,
        SecurityEventType.remoteCommandExecuted,
      ],
      'التتبع': [
        SecurityEventType.locationTracked,
        SecurityEventType.photoCapture,
        SecurityEventType.callLogged,
      ],
    };

    final items = <DropdownMenuItem<SecurityEventType>>[];

    for (final entry in categories.entries) {
      for (final type in entry.value) {
        items.add(
          DropdownMenuItem<SecurityEventType>(
            value: type,
            child: Text(_getEventTypeLabel(type)),
          ),
        );
      }
    }

    return items;
  }

  Widget _buildDateButton({
    required String label,
    required DateTime? date,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade300),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(Icons.calendar_today, size: 18, color: Colors.grey.shade600),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                date != null
                    ? DateFormat('yyyy/MM/dd', 'ar').format(date)
                    : label,
                style: TextStyle(
                  color: date != null ? Colors.black : Colors.grey.shade600,
                ),
              ),
            ),
            if (date != null)
              GestureDetector(
                onTap: () {
                  setState(() {
                    if (label == 'من') {
                      _startDate = null;
                    } else {
                      _endDate = null;
                    }
                  });
                },
                child: Icon(
                  Icons.close,
                  size: 18,
                  color: Colors.grey.shade600,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _selectDate({required bool isStart}) async {
    final initialDate = isStart
        ? (_startDate ?? DateTime.now())
        : (_endDate ?? DateTime.now());

    final pickedDate = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      locale: const Locale('ar'),
    );

    if (pickedDate != null) {
      setState(() {
        if (isStart) {
          _startDate = pickedDate;
          // Ensure end date is not before start date
          if (_endDate != null && _endDate!.isBefore(_startDate!)) {
            _endDate = _startDate;
          }
        } else {
          _endDate = pickedDate;
          // Ensure start date is not after end date
          if (_startDate != null && _startDate!.isAfter(_endDate!)) {
            _startDate = _endDate;
          }
        }
      });
    }
  }

  void _clearFilters() {
    setState(() {
      _selectedType = null;
      _startDate = null;
      _endDate = null;
    });
  }

  void _applyFilters() {
    final provider = context.read<SecurityLogsProvider>();
    provider.updateFilter(
      SecurityLogsFilter(
        eventType: _selectedType,
        startDate: _startDate,
        endDate: _endDate,
      ),
    );
    Navigator.pop(context);
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
}
