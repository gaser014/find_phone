import 'package:flutter/material.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:provider/provider.dart';

import '../providers/location_history_provider.dart';

/// Dialog for filtering location history by date range.
/// 
/// Requirements:
/// - 5.4: Display all tracked locations on a map (with filtering)
class LocationFilterDialog extends StatefulWidget {
  const LocationFilterDialog({super.key});

  @override
  State<LocationFilterDialog> createState() => _LocationFilterDialogState();
}

class _LocationFilterDialogState extends State<LocationFilterDialog> {
  DateTime? _startDate;
  DateTime? _endDate;

  @override
  void initState() {
    super.initState();
    final provider = context.read<LocationHistoryProvider>();
    _startDate = provider.filter.startDate;
    _endDate = provider.filter.endDate;
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.filter_list, color: Colors.blue),
            const SizedBox(width: 8),
            const Text('تصفية المواقع'),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'تصفية حسب التاريخ',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 16),
              // Start date
              _buildDateField(
                label: 'من تاريخ',
                value: _startDate,
                onTap: () => _selectDate(isStart: true),
                onClear: () => setState(() => _startDate = null),
              ),
              const SizedBox(height: 12),
              // End date
              _buildDateField(
                label: 'إلى تاريخ',
                value: _endDate,
                onTap: () => _selectDate(isStart: false),
                onClear: () => setState(() => _endDate = null),
              ),
              const SizedBox(height: 16),
              // Quick filters
              const Text(
                'تصفية سريعة',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _buildQuickFilterChip('اليوم', _setToday),
                  _buildQuickFilterChip('أمس', _setYesterday),
                  _buildQuickFilterChip('آخر 7 أيام', _setLastWeek),
                  _buildQuickFilterChip('آخر 30 يوم', _setLastMonth),
                ],
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              setState(() {
                _startDate = null;
                _endDate = null;
              });
            },
            child: const Text('مسح الكل'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: _applyFilter,
            child: const Text('تطبيق'),
          ),
        ],
      ),
    );
  }

  Widget _buildDateField({
    required String label,
    required DateTime? value,
    required VoidCallback onTap,
    required VoidCallback onClear,
  }) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade300),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            const Icon(Icons.calendar_today, size: 20, color: Colors.grey),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey.shade600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    value != null
                        ? DateFormat('yyyy/MM/dd', 'ar').format(value)
                        : 'اختر تاريخ',
                    style: TextStyle(
                      fontSize: 14,
                      color: value != null ? Colors.black : Colors.grey,
                    ),
                  ),
                ],
              ),
            ),
            if (value != null)
              IconButton(
                icon: const Icon(Icons.clear, size: 18),
                onPressed: onClear,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickFilterChip(String label, VoidCallback onTap) {
    return ActionChip(
      label: Text(label, style: const TextStyle(fontSize: 12)),
      onPressed: onTap,
    );
  }

  Future<void> _selectDate({required bool isStart}) async {
    final initialDate = isStart
        ? (_startDate ?? DateTime.now())
        : (_endDate ?? DateTime.now());

    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      locale: const Locale('ar'),
    );

    if (picked != null) {
      setState(() {
        if (isStart) {
          _startDate = picked;
          // Ensure end date is not before start date
          if (_endDate != null && _endDate!.isBefore(picked)) {
            _endDate = picked;
          }
        } else {
          _endDate = picked;
          // Ensure start date is not after end date
          if (_startDate != null && _startDate!.isAfter(picked)) {
            _startDate = picked;
          }
        }
      });
    }
  }

  void _setToday() {
    final now = DateTime.now();
    setState(() {
      _startDate = DateTime(now.year, now.month, now.day);
      _endDate = now;
    });
  }

  void _setYesterday() {
    final now = DateTime.now();
    final yesterday = now.subtract(const Duration(days: 1));
    setState(() {
      _startDate = DateTime(yesterday.year, yesterday.month, yesterday.day);
      _endDate = DateTime(yesterday.year, yesterday.month, yesterday.day, 23, 59, 59);
    });
  }

  void _setLastWeek() {
    final now = DateTime.now();
    setState(() {
      _startDate = now.subtract(const Duration(days: 7));
      _endDate = now;
    });
  }

  void _setLastMonth() {
    final now = DateTime.now();
    setState(() {
      _startDate = now.subtract(const Duration(days: 30));
      _endDate = now;
    });
  }

  void _applyFilter() {
    context.read<LocationHistoryProvider>().setDateRangeFilter(
      _startDate,
      _endDate,
    );
    Navigator.pop(context);
  }
}
