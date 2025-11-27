import 'package:flutter/material.dart';

import '../../../domain/entities/protection_config.dart';
import '../../../services/storage/i_storage_service.dart';

/// Storage keys for auto-protection schedule.
class AutoProtectionStorageKeys {
  static const String scheduleEnabled = 'auto_protection_enabled';
  static const String scheduleData = 'auto_protection_schedule';
}

/// Auto-protection schedule configuration screen.
///
/// Requirements:
/// - 14.1: Configure auto-protection schedule with time ranges and days
class AutoProtectionScheduleScreen extends StatefulWidget {
  final IStorageService storageService;
  final VoidCallback? onSaved;

  const AutoProtectionScheduleScreen({
    super.key,
    required this.storageService,
    this.onSaved,
  });

  @override
  State<AutoProtectionScheduleScreen> createState() =>
      _AutoProtectionScheduleScreenState();
}

class _AutoProtectionScheduleScreenState
    extends State<AutoProtectionScheduleScreen> {
  bool _isEnabled = false;
  List<TimeRange> _schedules = [];
  bool _isLoading = true;
  bool _isSaving = false;

  final List<String> _dayNames = [
    'الإثنين',
    'الثلاثاء',
    'الأربعاء',
    'الخميس',
    'الجمعة',
    'السبت',
    'الأحد',
  ];

  @override
  void initState() {
    super.initState();
    _loadSchedule();
  }

  Future<void> _loadSchedule() async {
    setState(() => _isLoading = true);

    try {
      final enabled = await widget.storageService.retrieve(
        AutoProtectionStorageKeys.scheduleEnabled,
      );
      _isEnabled = enabled == true || enabled == 'true';

      final scheduleJson = await widget.storageService.retrieve(
        AutoProtectionStorageKeys.scheduleData,
      );

      if (scheduleJson != null && scheduleJson is List) {
        _schedules = scheduleJson
            .map((e) => TimeRange.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList();
      }
    } catch (e) {
      // Use defaults on error
    }

    setState(() => _isLoading = false);
  }

  Future<void> _saveSchedule() async {
    setState(() => _isSaving = true);

    try {
      await widget.storageService.store(
        AutoProtectionStorageKeys.scheduleEnabled,
        _isEnabled,
      );

      await widget.storageService.store(
        AutoProtectionStorageKeys.scheduleData,
        _schedules.map((s) => s.toJson()).toList(),
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم حفظ الجدول بنجاح'),
            backgroundColor: Colors.green,
          ),
        );
      }

      widget.onSaved?.call();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('فشل في حفظ الجدول: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }

    setState(() => _isSaving = false);
  }

  void _addSchedule() {
    _showScheduleDialog(null);
  }

  void _editSchedule(int index) {
    _showScheduleDialog(index);
  }

  void _deleteSchedule(int index) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('حذف الجدول'),
        content: const Text('هل أنت متأكد من حذف هذا الجدول؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء'),
          ),
          TextButton(
            onPressed: () {
              setState(() {
                _schedules.removeAt(index);
              });
              Navigator.pop(context);
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('حذف'),
          ),
        ],
      ),
    );
  }

  void _showScheduleDialog(int? editIndex) {
    TimeOfDay startTime = const TimeOfDay(hour: 8, minute: 0);
    TimeOfDay endTime = const TimeOfDay(hour: 18, minute: 0);
    List<int> selectedDays = [1, 2, 3, 4, 5]; // Mon-Fri by default

    if (editIndex != null) {
      final schedule = _schedules[editIndex];
      startTime = schedule.startTime;
      endTime = schedule.endTime;
      selectedDays = List.from(schedule.daysOfWeek);
    }

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            title: Text(editIndex == null ? 'إضافة جدول' : 'تعديل الجدول'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Start time
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('وقت البدء'),
                    trailing: TextButton(
                      onPressed: () async {
                        final time = await showTimePicker(
                          context: context,
                          initialTime: startTime,
                        );
                        if (time != null) {
                          setDialogState(() => startTime = time);
                        }
                      },
                      child: Text(
                        '${startTime.hour.toString().padLeft(2, '0')}:'
                        '${startTime.minute.toString().padLeft(2, '0')}',
                        style: const TextStyle(fontSize: 16),
                      ),
                    ),
                  ),
                  // End time
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('وقت الانتهاء'),
                    trailing: TextButton(
                      onPressed: () async {
                        final time = await showTimePicker(
                          context: context,
                          initialTime: endTime,
                        );
                        if (time != null) {
                          setDialogState(() => endTime = time);
                        }
                      },
                      child: Text(
                        '${endTime.hour.toString().padLeft(2, '0')}:'
                        '${endTime.minute.toString().padLeft(2, '0')}',
                        style: const TextStyle(fontSize: 16),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'أيام الأسبوع:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  // Days selection
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: List.generate(7, (index) {
                      final dayNumber = index + 1;
                      final isSelected = selectedDays.contains(dayNumber);
                      return FilterChip(
                        label: Text(_dayNames[index]),
                        selected: isSelected,
                        onSelected: (selected) {
                          setDialogState(() {
                            if (selected) {
                              selectedDays.add(dayNumber);
                            } else {
                              selectedDays.remove(dayNumber);
                            }
                          });
                        },
                      );
                    }),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('إلغاء'),
              ),
              ElevatedButton(
                onPressed: selectedDays.isEmpty
                    ? null
                    : () {
                        final schedule = TimeRange(
                          startTime: startTime,
                          endTime: endTime,
                          daysOfWeek: selectedDays..sort(),
                        );

                        setState(() {
                          if (editIndex != null) {
                            _schedules[editIndex] = schedule;
                          } else {
                            _schedules.add(schedule);
                          }
                        });

                        Navigator.pop(context);
                      },
                child: const Text('حفظ'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatTimeRange(TimeRange schedule) {
    final start =
        '${schedule.startTime.hour.toString().padLeft(2, '0')}:'
        '${schedule.startTime.minute.toString().padLeft(2, '0')}';
    final end =
        '${schedule.endTime.hour.toString().padLeft(2, '0')}:'
        '${schedule.endTime.minute.toString().padLeft(2, '0')}';
    return '$start - $end';
  }

  String _formatDays(List<int> days) {
    if (days.length == 7) return 'كل يوم';
    if (days.length == 5 &&
        days.contains(1) &&
        days.contains(2) &&
        days.contains(3) &&
        days.contains(4) &&
        days.contains(5)) {
      return 'أيام العمل';
    }
    if (days.length == 2 && days.contains(6) && days.contains(7)) {
      return 'عطلة نهاية الأسبوع';
    }
    return days.map((d) => _dayNames[d - 1]).join('، ');
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('جدول الحماية التلقائية'),
          centerTitle: true,
          actions: [
            if (!_isLoading)
              IconButton(
                icon: _isSaving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.save),
                onPressed: _isSaving ? null : _saveSchedule,
                tooltip: 'حفظ',
              ),
          ],
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : Column(
                children: [
                  // Enable/disable switch
                  SwitchListTile(
                    title: const Text('تفعيل الحماية التلقائية'),
                    subtitle: const Text(
                      'تفعيل وضع الحماية تلقائياً في الأوقات المحددة',
                    ),
                    value: _isEnabled,
                    onChanged: (value) {
                      setState(() => _isEnabled = value);
                    },
                  ),
                  const Divider(),
                  // Schedules list
                  Expanded(
                    child: _schedules.isEmpty
                        ? _buildEmptyState()
                        : ListView.builder(
                            itemCount: _schedules.length,
                            itemBuilder: (context, index) {
                              final schedule = _schedules[index];
                              return Card(
                                margin: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 8,
                                ),
                                child: ListTile(
                                  leading: const CircleAvatar(
                                    child: Icon(Icons.schedule),
                                  ),
                                  title: Text(_formatTimeRange(schedule)),
                                  subtitle: Text(_formatDays(schedule.daysOfWeek)),
                                  trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        icon: const Icon(Icons.edit),
                                        onPressed: () => _editSchedule(index),
                                      ),
                                      IconButton(
                                        icon: const Icon(
                                          Icons.delete,
                                          color: Colors.red,
                                        ),
                                        onPressed: () => _deleteSchedule(index),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
        floatingActionButton: _isLoading
            ? null
            : FloatingActionButton.extended(
                onPressed: _addSchedule,
                icon: const Icon(Icons.add),
                label: const Text('إضافة جدول'),
              ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.schedule, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            'لا توجد جداول',
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'أضف جدولاً لتفعيل الحماية تلقائياً',
            style: TextStyle(color: Colors.grey[500]),
          ),
        ],
      ),
    );
  }
}
