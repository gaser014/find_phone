import 'package:flutter/material.dart';

import '../../../domain/entities/protection_config.dart';
import '../../../services/authentication/i_authentication_service.dart';
import '../../../services/protection/i_protection_service.dart';
import '../../widgets/password_confirmation_dialog.dart';
import '../../widgets/protection_status_card.dart';
import '../../widgets/protection_toggle_tile.dart';

/// Main Dashboard Screen displaying protection status and feature toggles.
///
/// Requirements:
/// - 9.1: Display main dashboard with protection status
/// - 9.2: Show toggle switches for all protection features
/// - 9.3: Require Master Password confirmation for setting changes
/// - 9.5: Provide clear Arabic labels and RTL support
class MainDashboardScreen extends StatefulWidget {
  final IProtectionService protectionService;
  final IAuthenticationService authenticationService;

  const MainDashboardScreen({
    super.key,
    required this.protectionService,
    required this.authenticationService,
  });

  @override
  State<MainDashboardScreen> createState() => _MainDashboardScreenState();
}

class _MainDashboardScreenState extends State<MainDashboardScreen> {
  bool _isLoading = true;
  ProtectionConfig _config = ProtectionConfig();
  bool _protectedModeActive = false;
  bool _kioskModeActive = false;
  bool _panicModeActive = false;
  bool _stealthModeActive = false;

  @override
  void initState() {
    super.initState();
    _loadProtectionStatus();
  }

  Future<void> _loadProtectionStatus() async {
    setState(() => _isLoading = true);

    try {
      final config = await widget.protectionService.getConfiguration();
      final protectedMode = await widget.protectionService.isProtectedModeActive();
      final kioskMode = await widget.protectionService.isKioskModeActive();
      final panicMode = await widget.protectionService.isPanicModeActive();
      final stealthMode = await widget.protectionService.isStealthModeActive();

      setState(() {
        _config = config;
        _protectedModeActive = protectedMode;
        _kioskModeActive = kioskMode;
        _panicModeActive = panicMode;
        _stealthModeActive = stealthMode;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        _showErrorSnackBar('فشل في تحميل حالة الحماية');
      }
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
      ),
    );
  }

  /// Shows password confirmation dialog and returns true if password is correct.
  /// Requirements: 9.3 - Require Master Password confirmation for setting changes
  Future<bool> _confirmPassword() async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => PasswordConfirmationDialog(
        authenticationService: widget.authenticationService,
      ),
    );
    return result ?? false;
  }

  /// Handles Protected Mode toggle
  Future<void> _onProtectedModeChanged(bool value) async {
    if (value) {
      // Enabling protected mode
      final success = await widget.protectionService.enableProtectedMode();
      if (success) {
        setState(() => _protectedModeActive = true);
        _showSuccessSnackBar('تم تفعيل وضع الحماية');
      } else {
        _showErrorSnackBar('فشل في تفعيل وضع الحماية. تأكد من منح الصلاحيات المطلوبة.');
      }
    } else {
      // Disabling protected mode - requires password
      final confirmed = await _confirmPassword();
      if (confirmed) {
        // Password dialog already verified, now disable
        final password = await _getPasswordFromDialog();
        if (password != null) {
          final success = await widget.protectionService.disableProtectedMode(password);
          if (success) {
            setState(() => _protectedModeActive = false);
            _showSuccessSnackBar('تم إلغاء وضع الحماية');
          } else {
            _showErrorSnackBar('فشل في إلغاء وضع الحماية');
          }
        }
      }
    }
  }

  /// Handles Kiosk Mode toggle
  Future<void> _onKioskModeChanged(bool value) async {
    if (value) {
      final success = await widget.protectionService.enableKioskMode();
      if (success) {
        setState(() => _kioskModeActive = true);
        _showSuccessSnackBar('تم تفعيل وضع Kiosk');
      } else {
        _showErrorSnackBar('فشل في تفعيل وضع Kiosk');
      }
    } else {
      final password = await _getPasswordFromDialog();
      if (password != null) {
        final success = await widget.protectionService.disableKioskMode(password);
        if (success) {
          setState(() => _kioskModeActive = false);
          _showSuccessSnackBar('تم إلغاء وضع Kiosk');
        } else {
          _showErrorSnackBar('كلمة المرور غير صحيحة');
        }
      }
    }
  }

  /// Handles Panic Mode toggle
  Future<void> _onPanicModeChanged(bool value) async {
    if (value) {
      await widget.protectionService.enablePanicMode();
      setState(() => _panicModeActive = true);
      _showSuccessSnackBar('تم تفعيل وضع الذعر');
    } else {
      // Panic mode requires password twice
      final password = await _getPasswordFromDialog(
        title: 'تأكيد إلغاء وضع الذعر',
        message: 'أدخل كلمة المرور مرتين للتأكيد',
      );
      if (password != null) {
        final success = await widget.protectionService.disablePanicMode(password);
        if (success) {
          setState(() => _panicModeActive = false);
          _showSuccessSnackBar('تم إلغاء وضع الذعر');
        } else {
          // May need second confirmation
          final secondPassword = await _getPasswordFromDialog(
            title: 'التأكيد الثاني',
            message: 'أدخل كلمة المرور مرة أخرى للتأكيد',
          );
          if (secondPassword != null) {
            final secondSuccess = await widget.protectionService.disablePanicMode(secondPassword);
            if (secondSuccess) {
              setState(() => _panicModeActive = false);
              _showSuccessSnackBar('تم إلغاء وضع الذعر');
            } else {
              _showErrorSnackBar('كلمة المرور غير صحيحة');
            }
          }
        }
      }
    }
  }

  /// Handles Stealth Mode toggle
  Future<void> _onStealthModeChanged(bool value) async {
    final password = await _getPasswordFromDialog();
    if (password == null) return;

    final isValid = await widget.authenticationService.verifyPassword(password);
    if (!isValid) {
      _showErrorSnackBar('كلمة المرور غير صحيحة');
      return;
    }

    if (value) {
      await widget.protectionService.enableStealthMode();
      setState(() => _stealthModeActive = true);
      _showSuccessSnackBar('تم تفعيل وضع التخفي');
    } else {
      await widget.protectionService.disableStealthMode();
      setState(() => _stealthModeActive = false);
      _showSuccessSnackBar('تم إلغاء وضع التخفي');
    }
  }

  /// Shows password input dialog and returns the entered password
  Future<String?> _getPasswordFromDialog({
    String title = 'تأكيد كلمة المرور',
    String message = 'أدخل كلمة المرور الرئيسية للمتابعة',
  }) async {
    String? enteredPassword;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => _PasswordInputDialog(
        title: title,
        message: message,
        onSubmit: (password) {
          enteredPassword = password;
          Navigator.pop(dialogContext);
        },
        onCancel: () => Navigator.pop(dialogContext),
      ),
    );
    return enteredPassword;
  }

  /// Handles configuration toggle changes
  /// Requirements: 9.3 - Require Master Password confirmation for setting changes
  Future<void> _onConfigToggleChanged(
    String configKey,
    bool value,
    ProtectionConfig Function(ProtectionConfig, bool) updateConfig,
  ) async {
    final password = await _getPasswordFromDialog();
    if (password == null) return;

    final newConfig = updateConfig(_config, value);
    final success = await widget.protectionService.updateConfiguration(newConfig, password);

    if (success) {
      setState(() => _config = newConfig);
      _showSuccessSnackBar('تم تحديث الإعدادات');
    } else {
      _showErrorSnackBar('كلمة المرور غير صحيحة');
    }
  }

  @override
  Widget build(BuildContext context) {
    // Requirements: 9.5 - Arabic labels and RTL support
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('لوحة التحكم'),
          centerTitle: true,
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _loadProtectionStatus,
              tooltip: 'تحديث',
            ),
            IconButton(
              icon: const Icon(Icons.history),
              onPressed: () {
                // Navigate to security logs
                Navigator.pushNamed(context, '/security-logs');
              },
              tooltip: 'سجلات الأمان',
            ),
            IconButton(
              icon: const Icon(Icons.settings),
              onPressed: () {
                // Navigate to settings
                Navigator.pushNamed(context, '/settings');
              },
              tooltip: 'الإعدادات',
            ),
          ],
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: _loadProtectionStatus,
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Protection Status Card
                      // Requirements: 9.1 - Display main dashboard with protection status
                      ProtectionStatusCard(
                        isProtectedModeActive: _protectedModeActive,
                        isKioskModeActive: _kioskModeActive,
                        isPanicModeActive: _panicModeActive,
                        isStealthModeActive: _stealthModeActive,
                        emergencyContact: _config.emergencyContact,
                      ),
                      const SizedBox(height: 24),

                      // Main Protection Toggles Section
                      // Requirements: 9.2 - Show toggle switches for all protection features
                      _buildSectionHeader('أوضاع الحماية الرئيسية'),
                      const SizedBox(height: 8),
                      _buildMainProtectionToggles(),
                      const SizedBox(height: 24),

                      // Monitoring Options Section
                      _buildSectionHeader('خيارات المراقبة'),
                      const SizedBox(height: 8),
                      _buildMonitoringToggles(),
                      const SizedBox(height: 24),

                      // Blocking Options Section
                      _buildSectionHeader('خيارات الحظر'),
                      const SizedBox(height: 8),
                      _buildBlockingToggles(),
                      const SizedBox(height: 24),

                      // Additional Features Section
                      _buildSectionHeader('ميزات إضافية'),
                      const SizedBox(height: 8),
                      _buildAdditionalFeatureToggles(),
                      const SizedBox(height: 32),
                    ],
                  ),
                ),
              ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: Theme.of(context).primaryColor,
          ),
    );
  }

  /// Builds main protection mode toggles
  Widget _buildMainProtectionToggles() {
    return Card(
      child: Column(
        children: [
          ProtectionToggleTile(
            title: 'وضع الحماية',
            subtitle: 'تفعيل جميع ميزات الحماية',
            icon: Icons.shield,
            value: _protectedModeActive,
            onChanged: _onProtectedModeChanged,
            activeColor: Colors.green,
          ),
          const Divider(height: 1),
          ProtectionToggleTile(
            title: 'وضع Kiosk',
            subtitle: 'قفل الجهاز على التطبيق فقط',
            icon: Icons.lock,
            value: _kioskModeActive,
            onChanged: _onKioskModeChanged,
            activeColor: Colors.orange,
          ),
          const Divider(height: 1),
          ProtectionToggleTile(
            title: 'وضع الذعر',
            subtitle: 'تفعيل الحماية القصوى والإنذار',
            icon: Icons.warning,
            value: _panicModeActive,
            onChanged: _onPanicModeChanged,
            activeColor: Colors.red,
          ),
          const Divider(height: 1),
          ProtectionToggleTile(
            title: 'وضع التخفي',
            subtitle: 'إخفاء التطبيق من القوائم',
            icon: Icons.visibility_off,
            value: _stealthModeActive,
            onChanged: _onStealthModeChanged,
            activeColor: Colors.purple,
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.screen_lock_portrait, color: Colors.teal),
            title: const Text('Kiosk عند قفل الشاشة'),
            subtitle: const Text('قفل الجهاز بكلمة المرور عند كل فتح'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.pushNamed(context, '/kiosk-on-lock-settings');
            },
          ),
        ],
      ),
    );
  }

  /// Builds monitoring option toggles
  Widget _buildMonitoringToggles() {
    return Card(
      child: Column(
        children: [
          ProtectionToggleTile(
            title: 'مراقبة المكالمات',
            subtitle: 'تسجيل جميع المكالمات الواردة والصادرة',
            icon: Icons.phone,
            value: _config.monitorCalls,
            onChanged: (value) => _onConfigToggleChanged(
              'monitorCalls',
              value,
              (config, v) => config.copyWith(monitorCalls: v),
            ),
          ),
          const Divider(height: 1),
          ProtectionToggleTile(
            title: 'مراقبة وضع الطيران',
            subtitle: 'اكتشاف تغييرات وضع الطيران',
            icon: Icons.airplanemode_active,
            value: _config.monitorAirplaneMode,
            onChanged: (value) => _onConfigToggleChanged(
              'monitorAirplaneMode',
              value,
              (config, v) => config.copyWith(monitorAirplaneMode: v),
            ),
          ),
          const Divider(height: 1),
          ProtectionToggleTile(
            title: 'مراقبة شريحة SIM',
            subtitle: 'اكتشاف تغيير أو إزالة الشريحة',
            icon: Icons.sim_card,
            value: _config.monitorSimCard,
            onChanged: (value) => _onConfigToggleChanged(
              'monitorSimCard',
              value,
              (config, v) => config.copyWith(monitorSimCard: v),
            ),
          ),
        ],
      ),
    );
  }

  /// Builds blocking option toggles
  Widget _buildBlockingToggles() {
    return Card(
      child: Column(
        children: [
          ProtectionToggleTile(
            title: 'حظر الإعدادات',
            subtitle: 'منع الوصول لتطبيق الإعدادات',
            icon: Icons.settings_applications,
            value: _config.blockSettings,
            onChanged: (value) => _onConfigToggleChanged(
              'blockSettings',
              value,
              (config, v) => config.copyWith(blockSettings: v),
            ),
          ),
          const Divider(height: 1),
          ProtectionToggleTile(
            title: 'حظر قائمة الطاقة',
            subtitle: 'منع الوصول لقائمة إيقاف التشغيل',
            icon: Icons.power_settings_new,
            value: _config.blockPowerMenu,
            onChanged: (value) => _onConfigToggleChanged(
              'blockPowerMenu',
              value,
              (config, v) => config.copyWith(blockPowerMenu: v),
            ),
          ),
          const Divider(height: 1),
          ProtectionToggleTile(
            title: 'حظر مدير الملفات',
            subtitle: 'طلب كلمة المرور للوصول للملفات',
            icon: Icons.folder,
            value: _config.blockFileManagers,
            onChanged: (value) => _onConfigToggleChanged(
              'blockFileManagers',
              value,
              (config, v) => config.copyWith(blockFileManagers: v),
            ),
          ),
        ],
      ),
    );
  }

  /// Builds additional feature toggles
  Widget _buildAdditionalFeatureToggles() {
    return Card(
      child: Column(
        children: [
          ProtectionToggleTile(
            title: 'الحماية التلقائية',
            subtitle: 'تفعيل الحماية حسب الجدول الزمني',
            icon: Icons.schedule,
            value: _config.autoProtectionEnabled,
            onChanged: (value) => _onConfigToggleChanged(
              'autoProtectionEnabled',
              value,
              (config, v) => config.copyWith(autoProtectionEnabled: v),
            ),
          ),
          const Divider(height: 1),
          ProtectionToggleTile(
            title: 'التقرير اليومي',
            subtitle: 'إرسال تقرير حالة يومي',
            icon: Icons.summarize,
            value: _config.dailyReportEnabled,
            onChanged: (value) => _onConfigToggleChanged(
              'dailyReportEnabled',
              value,
              (config, v) => config.copyWith(dailyReportEnabled: v),
            ),
          ),
          const Divider(height: 1),
          ProtectionToggleTile(
            title: 'تسجيل الصوت',
            subtitle: 'تسجيل صوتي عند النشاط المشبوه',
            icon: Icons.mic,
            value: _config.audioRecordingEnabled,
            onChanged: (value) => _onConfigToggleChanged(
              'audioRecordingEnabled',
              value,
              (config, v) => config.copyWith(audioRecordingEnabled: v),
            ),
          ),
        ],
      ),
    );
  }
}

/// Separate stateful widget for password input dialog to properly manage TextEditingController
class _PasswordInputDialog extends StatefulWidget {
  final String title;
  final String message;
  final void Function(String password) onSubmit;
  final VoidCallback onCancel;

  const _PasswordInputDialog({
    required this.title,
    required this.message,
    required this.onSubmit,
    required this.onCancel,
  });

  @override
  State<_PasswordInputDialog> createState() => _PasswordInputDialogState();
}

class _PasswordInputDialogState extends State<_PasswordInputDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: AlertDialog(
        title: Text(widget.title),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(widget.message),
            const SizedBox(height: 16),
            TextField(
              controller: _controller,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'كلمة المرور',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.lock),
              ),
              autofocus: true,
              onSubmitted: (_) => widget.onSubmit(_controller.text),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: widget.onCancel,
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () => widget.onSubmit(_controller.text),
            child: const Text('تأكيد'),
          ),
        ],
      ),
    );
  }
}
