import 'package:flutter/material.dart';
import '../../../services/kiosk/kiosk_on_lock_service.dart';

/// Settings screen for Kiosk on Lock feature.
///
/// Allows users to configure:
/// - Enable/disable Kiosk Mode on screen lock
/// - Auto-enable mobile data
/// - USB blocking
/// - Photo capture on failed attempts
/// - Alarm on multiple failures
class KioskOnLockSettingsScreen extends StatefulWidget {
  const KioskOnLockSettingsScreen({super.key});

  @override
  State<KioskOnLockSettingsScreen> createState() => _KioskOnLockSettingsScreenState();
}

class _KioskOnLockSettingsScreenState extends State<KioskOnLockSettingsScreen> {
  final KioskOnLockService _service = KioskOnLockService.instance;
  KioskOnLockConfig _config = KioskOnLockConfig();
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadConfiguration();
  }

  Future<void> _loadConfiguration() async {
    await _service.initialize();
    final config = await _service.getConfiguration();
    setState(() {
      _config = config;
      _isLoading = false;
    });
  }

  Future<void> _updateConfiguration(KioskOnLockConfig newConfig) async {
    setState(() => _config = newConfig);
    await _service.updateConfiguration(newConfig);
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFF1A1A2E),
        appBar: AppBar(
          title: const Text('إعدادات Kiosk عند القفل'),
          backgroundColor: const Color(0xFF16213E),
          foregroundColor: Colors.white,
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildWarningCard(),
                    const SizedBox(height: 24),
                    _buildMainToggle(),
                    const SizedBox(height: 24),
                    _buildTestButton(),
                    const SizedBox(height: 24),
                    _buildEmergencyContactsSection(),
                    const SizedBox(height: 24),
                    _buildSettingsSection(),
                    const SizedBox(height: 24),
                    _buildSecuritySection(),
                    const SizedBox(height: 24),
                    _buildInfoSection(),
                    const SizedBox(height: 24),
                    _buildUninstallSection(),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildWarningCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.orange.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orange.withValues(alpha: 0.5)),
      ),
      child: Row(
        children: [
          const Icon(Icons.warning_amber, color: Colors.orange, size: 32),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'تنبيه مهم',
                  style: TextStyle(
                    color: Colors.orange,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'هذا التطبيق للحماية من السرقة. عند تفعيل هذه الميزة:\n'
                  '• سيتم قفل الجهاز بشاشة كلمة المرور عند كل فتح\n'
                  '• سيتم تتبع الموقع وتسجيل المحاولات الفاشلة\n'
                  '• لن يمكن استخدام الجهاز بدون كلمة المرور',
                  style: TextStyle(
                    color: Colors.orange.shade200,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMainToggle() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: _config.kioskOnLockEnabled
              ? [Colors.green.shade700, Colors.green.shade900]
              : [Colors.grey.shade700, Colors.grey.shade900],
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(
            _config.kioskOnLockEnabled ? Icons.lock : Icons.lock_open,
            color: Colors.white,
            size: 40,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Kiosk عند قفل الشاشة',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _config.kioskOnLockEnabled
                      ? 'مفعل - الجهاز محمي'
                      : 'معطل - الجهاز غير محمي',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.8),
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: _config.kioskOnLockEnabled,
            onChanged: (value) async {
              if (value) {
                // Show confirmation dialog
                final confirmed = await _showEnableConfirmation();
                if (confirmed == true) {
                  await _service.enableKioskOnLock();
                  _updateConfiguration(_config.copyWith(kioskOnLockEnabled: true));
                }
              } else {
                await _service.disableKioskOnLock();
                _updateConfiguration(_config.copyWith(kioskOnLockEnabled: false));
              }
            },
            activeThumbColor: Colors.white,
            activeTrackColor: Colors.green.shade400,
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'إعدادات التفعيل',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        _buildSettingTile(
          icon: Icons.signal_cellular_alt,
          title: 'تفعيل بيانات الهاتف تلقائياً',
          subtitle: 'تفعيل الإنترنت عند تشغيل Kiosk للتتبع',
          value: _config.autoEnableMobileData,
          onChanged: (value) {
            _updateConfiguration(_config.copyWith(autoEnableMobileData: value));
          },
        ),
        _buildSettingTile(
          icon: Icons.usb_off,
          title: 'منع USB',
          subtitle: 'حظر نقل البيانات عبر USB في وضع Kiosk',
          value: _config.blockUsbOnKiosk,
          onChanged: (value) {
            _updateConfiguration(_config.copyWith(blockUsbOnKiosk: value));
          },
        ),
      ],
    );
  }

  Widget _buildSecuritySection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'إعدادات الأمان',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        _buildSettingTile(
          icon: Icons.camera_alt,
          title: 'التقاط صورة عند الفشل',
          subtitle: 'التقاط صورة بالكاميرا الأمامية عند إدخال كلمة مرور خاطئة',
          value: _config.capturePhotoOnFailedAttempt,
          onChanged: (value) {
            _updateConfiguration(_config.copyWith(capturePhotoOnFailedAttempt: value));
          },
        ),
        _buildSettingTile(
          icon: Icons.alarm,
          title: 'تشغيل الإنذار',
          subtitle: 'تشغيل صوت إنذار بعد ${_config.alarmTriggerThreshold} محاولات فاشلة',
          value: _config.triggerAlarmOnMultipleFailures,
          onChanged: (value) {
            _updateConfiguration(_config.copyWith(triggerAlarmOnMultipleFailures: value));
          },
        ),
        if (_config.triggerAlarmOnMultipleFailures)
          _buildThresholdSlider(),
      ],
    );
  }

  Widget _buildSettingTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        leading: Icon(icon, color: Colors.blue.shade400),
        title: Text(
          title,
          style: const TextStyle(color: Colors.white, fontSize: 15),
        ),
        subtitle: Text(
          subtitle,
          style: TextStyle(color: Colors.grey.shade400, fontSize: 12),
        ),
        trailing: Switch(
          value: value,
          onChanged: _config.kioskOnLockEnabled ? onChanged : null,
          activeTrackColor: Colors.blue,
        ),
      ),
    );
  }

  Widget _buildThresholdSlider() {
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'عدد المحاولات قبل الإنذار: ${_config.alarmTriggerThreshold}',
            style: const TextStyle(color: Colors.white, fontSize: 14),
          ),
          Slider(
            value: _config.alarmTriggerThreshold.toDouble(),
            min: 1,
            max: 10,
            divisions: 9,
            label: _config.alarmTriggerThreshold.toString(),
            onChanged: _config.kioskOnLockEnabled
                ? (value) {
                    _updateConfiguration(
                      _config.copyWith(alarmTriggerThreshold: value.toInt()),
                    );
                  }
                : null,
          ),
        ],
      ),
    );
  }

  Widget _buildTestButton() {
    return Container(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: () async {
          // Test the kiosk lock screen
          final result = await _service.showKioskLockScreen();
          if (!result && mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('فشل في عرض شاشة القفل'),
                backgroundColor: Colors.red,
              ),
            );
          }
        },
        icon: const Icon(Icons.play_arrow),
        label: const Text('اختبار شاشة القفل'),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.purple.shade700,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }

  Widget _buildEmergencyContactsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'إعدادات التيليجرام',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.blue.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.blue.withValues(alpha: 0.3)),
          ),
          child: Column(
            children: [
              _buildTextField(
                icon: Icons.key,
                iconColor: Colors.orange.shade400,
                label: 'Bot Token',
                hint: 'Bot Token',
                value: _config.telegramBotToken,
                onChanged: (value) {
                  _updateConfiguration(_config.copyWith(telegramBotToken: value));
                },
              ),
              const SizedBox(height: 16),
              _buildTextField(
                icon: Icons.chat,
                iconColor: Colors.blue.shade400,
                label: 'Chat ID',
                hint: 'Chat ID',
                value: _config.telegramChatId,
                onChanged: (value) {
                  _updateConfiguration(_config.copyWith(telegramChatId: value));
                },
              ),
              const SizedBox(height: 16),
              _buildPhoneNumberField(
                icon: Icons.phone,
                iconColor: Colors.green.shade400,
                label: 'رقم الطوارئ (للعرض للسارق)',
                hint: '+201027888372',
                value: _config.emergencyNumber1,
                onChanged: (value) {
                  _updateConfiguration(_config.copyWith(emergencyNumber1: value));
                },
              ),
              const SizedBox(height: 16),
              _buildTextField(
                icon: Icons.lock,
                iconColor: Colors.red.shade400,
                label: 'كلمة مرور Kiosk',
                hint: '123456',
                value: _config.kioskPassword,
                onChanged: (value) {
                  _updateConfiguration(_config.copyWith(kioskPassword: value));
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'سيتم إرسال الصور والموقع للتيليجرام فوراً عند فتح شاشة القفل',
          style: TextStyle(color: Colors.grey.shade400, fontSize: 12),
        ),
        const SizedBox(height: 8),
        _buildTelegramTestButton(),
      ],
    );
  }
  
  Widget _buildTelegramTestButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: () async {
          if (_config.telegramBotToken.isEmpty || _config.telegramChatId.isEmpty) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('يرجى إدخال Bot Token و Chat ID أولاً'),
                backgroundColor: Colors.orange,
              ),
            );
            return;
          }
          
          // Test Telegram connection
          final result = await _service.testTelegramConnection(
            _config.telegramBotToken,
            _config.telegramChatId,
          );
          
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(result ? '✅ تم الاتصال بنجاح!' : '❌ فشل الاتصال'),
                backgroundColor: result ? Colors.green : Colors.red,
              ),
            );
          }
        },
        icon: const Icon(Icons.send),
        label: const Text('اختبار اتصال التيليجرام'),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.blue.shade700,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      ),
    );
  }
  
  Widget _buildTextField({
    required IconData icon,
    required Color iconColor,
    required String label,
    required String hint,
    required String value,
    required ValueChanged<String> onChanged,
  }) {
    return Row(
      children: [
        Icon(icon, color: iconColor),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              TextField(
                controller: TextEditingController(text: value.isEmpty ? '' : value),
                style: const TextStyle(color: Colors.white, fontSize: 13),
                decoration: InputDecoration(
                  hintText: hint,
                  hintStyle: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                  filled: true,
                  fillColor: Colors.white.withValues(alpha: 0.1),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
                onChanged: onChanged,
              ),
            ],
          ),
        ),
      ],
    );
  }
  
  Widget _buildPhoneNumberField({
    required IconData icon,
    required Color iconColor,
    required String label,
    required String hint,
    required String value,
    required ValueChanged<String> onChanged,
  }) {
    return Row(
      children: [
        Icon(icon, color: iconColor),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              TextField(
                controller: TextEditingController(text: value.isEmpty ? hint : value),
                style: const TextStyle(color: Colors.white),
                keyboardType: TextInputType.phone,
                decoration: InputDecoration(
                  hintText: hint,
                  hintStyle: TextStyle(color: Colors.grey.shade600),
                  filled: true,
                  fillColor: Colors.white.withValues(alpha: 0.1),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
                onChanged: onChanged,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildInfoSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.info_outline, color: Colors.blue.shade400),
              const SizedBox(width: 8),
              const Text(
                'كيف يعمل؟',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildInfoItem('1', 'عند قفل الشاشة، يتم تفعيل وضع Kiosk'),
          _buildInfoItem('2', 'عند فتح الجهاز، تظهر شاشة إدخال كلمة المرور'),
          _buildInfoItem('3', 'لا يمكن الوصول لأي شيء آخر بدون كلمة المرور'),
          _buildInfoItem('4', 'يتم تفعيل بيانات الهاتف للتتبع'),
          _buildInfoItem('5', 'يتم حظر USB لمنع نقل البيانات'),
        ],
      ),
    );
  }

  Widget _buildInfoItem(String number, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: Colors.blue.shade700,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                number,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: TextStyle(color: Colors.grey.shade300, fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUninstallSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.red.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.delete_forever, color: Colors.red.shade400),
              const SizedBox(width: 8),
              const Text(
                'إزالة التطبيق',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'سيتم إيقاف جميع الخدمات وإزالة التطبيق من الجهاز',
            style: TextStyle(color: Colors.grey.shade400, fontSize: 13),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => _showUninstallConfirmation(),
              icon: const Icon(Icons.delete_outline),
              label: const Text('مسح التطبيق'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.shade700,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showUninstallConfirmation() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          backgroundColor: const Color(0xFF1A1A2E),
          title: Row(
            children: [
              Icon(Icons.warning, color: Colors.red.shade400),
              const SizedBox(width: 8),
              const Text(
                'تأكيد المسح',
                style: TextStyle(color: Colors.white),
              ),
            ],
          ),
          content: const Text(
            'هل أنت متأكد من مسح التطبيق؟\n\n'
            'سيتم:\n'
            '• إيقاف جميع خدمات الحماية\n'
            '• إزالة التطبيق نهائياً\n\n'
            'لا يمكن التراجع عن هذا الإجراء!',
            style: TextStyle(color: Colors.white70),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('إلغاء'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
              ),
              child: const Text('مسح'),
            ),
          ],
        ),
      ),
    );

    if (confirmed == true) {
      await _uninstallApp();
    }
  }

  Future<void> _uninstallApp() async {
    try {
      // Disable kiosk mode first
      if (_config.kioskOnLockEnabled) {
        await _service.disableKioskOnLock();
      }
      
      // Request uninstall
      await _service.uninstallApp();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('فشل في مسح التطبيق: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<bool?> _showEnableConfirmation() {
    return showDialog<bool>(
      context: context,
      builder: (context) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          backgroundColor: const Color(0xFF1A1A2E),
          title: const Text(
            'تأكيد التفعيل',
            style: TextStyle(color: Colors.white),
          ),
          content: const Text(
            'هل أنت متأكد من تفعيل وضع Kiosk عند قفل الشاشة؟\n\n'
            'سيتم:\n'
            '• قفل الجهاز بشاشة كلمة المرور عند كل فتح\n'
            '• تتبع الموقع وتسجيل المحاولات\n'
            '• منع الوصول للجهاز بدون كلمة المرور\n\n'
            'تأكد من تذكر كلمة المرور!',
            style: TextStyle(color: Colors.white70),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('إلغاء'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
              ),
              child: const Text('تفعيل'),
            ),
          ],
        ),
      ),
    );
  }
}
