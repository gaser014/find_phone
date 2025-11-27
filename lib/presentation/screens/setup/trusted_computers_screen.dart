import 'package:flutter/material.dart';
import 'package:intl/intl.dart' hide TextDirection;

import '../../../services/usb/i_usb_service.dart';
import '../../../services/authentication/i_authentication_service.dart';

/// Trusted computers management screen.
///
/// Requirements:
/// - 28.4: Add trusted computer with Master Password
/// - 29.4: Remove trusted device with Master Password confirmation
class TrustedComputersScreen extends StatefulWidget {
  final IUsbService usbService;
  final IAuthenticationService authenticationService;

  const TrustedComputersScreen({
    super.key,
    required this.usbService,
    required this.authenticationService,
  });

  @override
  State<TrustedComputersScreen> createState() => _TrustedComputersScreenState();
}

class _TrustedComputersScreenState extends State<TrustedComputersScreen> {
  List<TrustedDevice> _trustedDevices = [];
  bool _isLoading = true;
  bool _isUsbConnected = false;
  String? _connectedDeviceId;

  @override
  void initState() {
    super.initState();
    _loadTrustedDevices();
    _checkUsbConnection();
  }

  Future<void> _loadTrustedDevices() async {
    setState(() => _isLoading = true);

    try {
      final devices = await widget.usbService.getTrustedDevices();
      setState(() {
        _trustedDevices = devices;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('فشل في تحميل الأجهزة: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }

    setState(() => _isLoading = false);
  }

  Future<void> _checkUsbConnection() async {
    try {
      final isConnected = await widget.usbService.isUsbConnected();
      final deviceId = await widget.usbService.getConnectedDeviceId();

      setState(() {
        _isUsbConnected = isConnected;
        _connectedDeviceId = deviceId;
      });
    } catch (e) {
      // Ignore errors
    }
  }

  Future<void> _addCurrentDevice() async {
    if (_connectedDeviceId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('لا يوجد جهاز متصل'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // Check if already trusted
    final isTrusted = await widget.usbService.isDeviceTrusted(_connectedDeviceId!);
    if (isTrusted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('هذا الجهاز موثوق بالفعل'),
          backgroundColor: Colors.blue,
        ),
      );
      return;
    }

    // Request password confirmation
    final password = await _showPasswordDialog('إضافة جهاز موثوق');
    if (password == null) return;

    // Verify password
    final isValid = await widget.authenticationService.verifyPassword(password);
    if (!isValid) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('كلمة المرور غير صحيحة'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    // Show device name dialog
    final deviceName = await _showDeviceNameDialog();
    if (deviceName == null) return;

    // Add the device
    final device = TrustedDevice(
      deviceId: _connectedDeviceId!,
      deviceName: deviceName,
      addedAt: DateTime.now(),
    );

    final success = await widget.usbService.addTrustedDevice(device);

    if (success) {
      await _loadTrustedDevices();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تمت إضافة الجهاز بنجاح'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('فشل في إضافة الجهاز'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _removeDevice(TrustedDevice device) async {
    // Request password confirmation
    final password = await _showPasswordDialog('إزالة جهاز موثوق');
    if (password == null) return;

    // Verify password
    final isValid = await widget.authenticationService.verifyPassword(password);
    if (!isValid) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('كلمة المرور غير صحيحة'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    // Confirm removal
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('إزالة الجهاز'),
        content: Text('هل أنت متأكد من إزالة "${device.deviceName}"؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('إلغاء'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('إزالة'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    // Remove the device
    final success = await widget.usbService.removeTrustedDevice(device.deviceId);

    if (success) {
      await _loadTrustedDevices();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تمت إزالة الجهاز بنجاح'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('فشل في إزالة الجهاز'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<String?> _showPasswordDialog(String title) async {
    final controller = TextEditingController();
    bool obscureText = true;

    return showDialog<String>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            title: Text(title),
            content: TextField(
              controller: controller,
              obscureText: obscureText,
              decoration: InputDecoration(
                labelText: 'كلمة المرور',
                prefixIcon: const Icon(Icons.lock),
                suffixIcon: IconButton(
                  icon: Icon(
                    obscureText ? Icons.visibility_off : Icons.visibility,
                  ),
                  onPressed: () {
                    setDialogState(() => obscureText = !obscureText);
                  },
                ),
                border: const OutlineInputBorder(),
              ),
              autofocus: true,
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('إلغاء'),
              ),
              ElevatedButton(
                onPressed: () {
                  if (controller.text.isNotEmpty) {
                    Navigator.pop(context, controller.text);
                  }
                },
                child: const Text('تأكيد'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<String?> _showDeviceNameDialog() async {
    final controller = TextEditingController();

    return showDialog<String>(
      context: context,
      builder: (context) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: const Text('اسم الجهاز'),
          content: TextField(
            controller: controller,
            decoration: const InputDecoration(
              labelText: 'أدخل اسماً للجهاز',
              hintText: 'مثال: كمبيوتر المنزل',
              prefixIcon: Icon(Icons.computer),
              border: OutlineInputBorder(),
            ),
            autofocus: true,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('إلغاء'),
            ),
            ElevatedButton(
              onPressed: () {
                final name = controller.text.trim();
                if (name.isNotEmpty) {
                  Navigator.pop(context, name);
                }
              },
              child: const Text('إضافة'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('الأجهزة الموثوقة'),
          centerTitle: true,
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: () {
                _loadTrustedDevices();
                _checkUsbConnection();
              },
              tooltip: 'تحديث',
            ),
          ],
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : Column(
                children: [
                  // USB connection status
                  _buildUsbStatusCard(),
                  const Divider(),
                  // Trusted devices list
                  Expanded(
                    child: _trustedDevices.isEmpty
                        ? _buildEmptyState()
                        : ListView.builder(
                            itemCount: _trustedDevices.length,
                            itemBuilder: (context, index) {
                              final device = _trustedDevices[index];
                              return _buildDeviceCard(device);
                            },
                          ),
                  ),
                ],
              ),
        floatingActionButton: _isUsbConnected && _connectedDeviceId != null
            ? FloatingActionButton.extended(
                onPressed: _addCurrentDevice,
                icon: const Icon(Icons.add),
                label: const Text('إضافة الجهاز المتصل'),
              )
            : null,
      ),
    );
  }

  Widget _buildUsbStatusCard() {
    return Card(
      margin: const EdgeInsets.all(16),
      color: _isUsbConnected ? Colors.green[50] : Colors.grey[100],
      child: ListTile(
        leading: Icon(
          Icons.usb,
          color: _isUsbConnected ? Colors.green : Colors.grey,
          size: 32,
        ),
        title: Text(
          _isUsbConnected ? 'جهاز USB متصل' : 'لا يوجد جهاز متصل',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: _isUsbConnected ? Colors.green[800] : Colors.grey[700],
          ),
        ),
        subtitle: _isUsbConnected && _connectedDeviceId != null
            ? Text(
                'معرف الجهاز: ${_connectedDeviceId!.substring(0, _connectedDeviceId!.length.clamp(0, 16))}...',
                style: TextStyle(color: Colors.grey[600]),
              )
            : const Text('قم بتوصيل كمبيوتر لإضافته كجهاز موثوق'),
      ),
    );
  }

  Widget _buildDeviceCard(TrustedDevice device) {
    final isCurrentDevice = device.deviceId == _connectedDeviceId;
    final dateFormat = DateFormat('yyyy/MM/dd HH:mm', 'ar');

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: isCurrentDevice ? Colors.green : Colors.blue,
          child: const Icon(Icons.computer, color: Colors.white),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                device.deviceName ?? 'جهاز غير معروف',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (isCurrentDevice)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.green,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  'متصل',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                  ),
                ),
              ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'تمت الإضافة: ${dateFormat.format(device.addedAt)}',
              style: TextStyle(color: Colors.grey[600], fontSize: 12),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              'المعرف: ${device.deviceId.substring(0, device.deviceId.length.clamp(0, 20))}...',
              style: TextStyle(color: Colors.grey[500], fontSize: 11),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
        trailing: IconButton(
          icon: const Icon(Icons.delete, color: Colors.red),
          onPressed: () => _removeDevice(device),
          tooltip: 'إزالة',
        ),
        isThreeLine: true,
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.computer, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            'لا توجد أجهزة موثوقة',
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'قم بتوصيل كمبيوتر وإضافته كجهاز موثوق',
            style: TextStyle(color: Colors.grey[500]),
          ),
          const SizedBox(height: 24),
          // Info card
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Card(
              color: Colors.blue[50],
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Icon(Icons.info_outline, color: Colors.blue[700]),
                    const SizedBox(height: 8),
                    Text(
                      'الأجهزة الموثوقة فقط يمكنها نقل البيانات عبر USB',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.blue[800]),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
