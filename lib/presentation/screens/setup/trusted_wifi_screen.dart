import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../services/storage/i_storage_service.dart';

/// Storage keys for trusted WiFi configuration.
class TrustedWifiStorageKeys {
  static const String trustedWifiSsid = 'trusted_wifi_ssid';
  static const String disableProtectionOnTrustedWifi = 'disable_protection_on_trusted_wifi';
}

/// Trusted WiFi (home) configuration screen.
///
/// Requirements:
/// - 14.3: Optionally disable auto-protection when in trusted location (home WiFi)
class TrustedWifiScreen extends StatefulWidget {
  final IStorageService storageService;
  final VoidCallback? onSaved;

  const TrustedWifiScreen({
    super.key,
    required this.storageService,
    this.onSaved,
  });

  @override
  State<TrustedWifiScreen> createState() => _TrustedWifiScreenState();
}

class _TrustedWifiScreenState extends State<TrustedWifiScreen> {
  final _ssidController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  bool _isLoading = true;
  bool _isSaving = false;
  bool _disableProtectionOnTrustedWifi = true;
  String? _currentWifiSsid;

  static const MethodChannel _wifiChannel =
      MethodChannel('com.example.find_phone/wifi');

  @override
  void initState() {
    super.initState();
    _loadSettings();
    _getCurrentWifi();
  }

  @override
  void dispose() {
    _ssidController.dispose();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    setState(() => _isLoading = true);

    try {
      final ssid = await widget.storageService.retrieve(
        TrustedWifiStorageKeys.trustedWifiSsid,
      );
      if (ssid != null) {
        _ssidController.text = ssid.toString();
      }

      final disableProtection = await widget.storageService.retrieve(
        TrustedWifiStorageKeys.disableProtectionOnTrustedWifi,
      );
      _disableProtectionOnTrustedWifi =
          disableProtection == true || disableProtection == 'true';
    } catch (e) {
      // Use defaults on error
    }

    setState(() => _isLoading = false);
  }

  Future<void> _getCurrentWifi() async {
    try {
      final ssid = await _wifiChannel.invokeMethod<String>('getCurrentWifiSsid');
      setState(() {
        _currentWifiSsid = ssid;
      });
    } on PlatformException {
      // WiFi info not available
    }
  }

  Future<void> _saveSettings() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _isSaving = true);

    try {
      final ssid = _ssidController.text.trim();

      if (ssid.isNotEmpty) {
        await widget.storageService.store(
          TrustedWifiStorageKeys.trustedWifiSsid,
          ssid,
        );
      } else {
        await widget.storageService.delete(
          TrustedWifiStorageKeys.trustedWifiSsid,
        );
      }

      await widget.storageService.store(
        TrustedWifiStorageKeys.disableProtectionOnTrustedWifi,
        _disableProtectionOnTrustedWifi,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم حفظ الإعدادات بنجاح'),
            backgroundColor: Colors.green,
          ),
        );
      }

      widget.onSaved?.call();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('فشل في حفظ الإعدادات: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }

    setState(() => _isSaving = false);
  }

  void _useCurrentWifi() {
    if (_currentWifiSsid != null && _currentWifiSsid!.isNotEmpty) {
      setState(() {
        _ssidController.text = _currentWifiSsid!;
      });
    }
  }

  void _clearTrustedWifi() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('إزالة شبكة WiFi الموثوقة'),
        content: const Text('هل أنت متأكد من إزالة شبكة WiFi الموثوقة؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء'),
          ),
          TextButton(
            onPressed: () {
              setState(() {
                _ssidController.clear();
              });
              Navigator.pop(context);
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('إزالة'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('شبكة WiFi الموثوقة'),
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
                onPressed: _isSaving ? null : _saveSettings,
                tooltip: 'حفظ',
              ),
          ],
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Info card
                      Card(
                        color: Colors.blue[50],
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            children: [
                              Icon(Icons.info_outline, color: Colors.blue[700]),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  'عند الاتصال بشبكة WiFi الموثوقة (مثل المنزل)، '
                                  'يمكن تعطيل الحماية التلقائية.',
                                  style: TextStyle(color: Colors.blue[800]),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      // Current WiFi info
                      if (_currentWifiSsid != null) ...[
                        Card(
                          child: ListTile(
                            leading: const Icon(Icons.wifi, color: Colors.green),
                            title: const Text('الشبكة الحالية'),
                            subtitle: Text(_currentWifiSsid!),
                            trailing: TextButton(
                              onPressed: _useCurrentWifi,
                              child: const Text('استخدام'),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],
                      // SSID input field
                      TextFormField(
                        controller: _ssidController,
                        decoration: InputDecoration(
                          labelText: 'اسم شبكة WiFi (SSID)',
                          hintText: 'أدخل اسم الشبكة الموثوقة',
                          prefixIcon: const Icon(Icons.wifi),
                          border: const OutlineInputBorder(),
                          suffixIcon: _ssidController.text.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear),
                                  onPressed: _clearTrustedWifi,
                                )
                              : null,
                        ),
                        validator: (value) {
                          // SSID is optional
                          return null;
                        },
                        onChanged: (_) => setState(() {}),
                      ),
                      const SizedBox(height: 24),
                      // Disable protection switch
                      SwitchListTile(
                        title: const Text('تعطيل الحماية التلقائية'),
                        subtitle: const Text(
                          'تعطيل وضع الحماية عند الاتصال بالشبكة الموثوقة',
                        ),
                        value: _disableProtectionOnTrustedWifi,
                        onChanged: (value) {
                          setState(() {
                            _disableProtectionOnTrustedWifi = value;
                          });
                        },
                      ),
                      const SizedBox(height: 24),
                      // How it works section
                      _buildHowItWorksSection(),
                    ],
                  ),
                ),
              ),
      ),
    );
  }

  Widget _buildHowItWorksSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.help_outline, color: Colors.grey[700]),
                const SizedBox(width: 8),
                Text(
                  'كيف يعمل؟',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[700],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _buildStepItem(
              '1',
              'أدخل اسم شبكة WiFi المنزلية',
            ),
            _buildStepItem(
              '2',
              'عند الاتصال بهذه الشبكة، يتم تعطيل الحماية التلقائية',
            ),
            _buildStepItem(
              '3',
              'عند مغادرة الشبكة، يتم تفعيل الحماية مرة أخرى',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStepItem(String number, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 12,
            backgroundColor: Colors.blue,
            child: Text(
              number,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(text),
          ),
        ],
      ),
    );
  }
}
