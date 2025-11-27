import 'package:flutter/material.dart';

import '../../../services/sms/i_sms_service.dart';

/// Emergency Contact setup screen with phone number validation.
///
/// Requirements:
/// - 16.1: Require user to enter an Emergency Contact phone number
/// - 16.2: Validate phone number format and store it encrypted
class EmergencyContactScreen extends StatefulWidget {
  final ISmsService smsService;
  final VoidCallback onContactSet;
  final bool isInitialSetup;
  final String? currentContact;

  const EmergencyContactScreen({
    super.key,
    required this.smsService,
    required this.onContactSet,
    this.isInitialSetup = true,
    this.currentContact,
  });

  @override
  State<EmergencyContactScreen> createState() => _EmergencyContactScreenState();
}

class _EmergencyContactScreenState extends State<EmergencyContactScreen> {
  final _formKey = GlobalKey<FormState>();
  final _phoneController = TextEditingController();
  
  bool _isLoading = false;
  String? _errorMessage;
  bool _sendTestSms = true;

  @override
  void initState() {
    super.initState();
    if (widget.currentContact != null) {
      _phoneController.text = widget.currentContact!;
    }
  }

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  /// Validates phone number format.
  /// Supports international format (+XX...) and local formats.
  String? _validatePhoneNumber(String? value) {
    if (value == null || value.isEmpty) {
      return 'الرجاء إدخال رقم الهاتف';
    }
    
    if (!widget.smsService.validatePhoneNumber(value)) {
      return 'رقم الهاتف غير صالح. يجب أن يكون بين 7-15 رقم';
    }
    
    return null;
  }

  Future<void> _saveEmergencyContact() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final phoneNumber = _phoneController.text.trim();
      
      // Store the emergency contact
      await widget.smsService.setEmergencyContact(phoneNumber);
      
      // Send test SMS if enabled
      if (_sendTestSms) {
        final testSent = await widget.smsService.sendSms(
          phoneNumber,
          'Anti-Theft: تم إعداد رقم الطوارئ بنجاح. '
          'ستتلقى تنبيهات الأمان على هذا الرقم.',
        );
        
        if (!testSent && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('تم حفظ الرقم لكن فشل إرسال رسالة الاختبار'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      }
      
      widget.onContactSet();
    } catch (e) {
      setState(() {
        _errorMessage = 'حدث خطأ: ${e.toString()}';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: widget.isInitialSetup
            ? null
            : AppBar(
                title: const Text('رقم الطوارئ'),
                centerTitle: true,
              ),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (widget.isInitialSetup) ...[
                    const SizedBox(height: 48),
                    const Icon(
                      Icons.contact_phone,
                      size: 80,
                      color: Colors.green,
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'إعداد رقم الطوارئ',
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                  ],
                  Text(
                    'أدخل رقم هاتف موثوق لاستقبال تنبيهات الأمان '
                    'والتحكم في الجهاز عن بعد.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.grey[600],
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 32),
                  // Phone number field
                  TextFormField(
                    controller: _phoneController,
                    keyboardType: TextInputType.phone,
                    decoration: InputDecoration(
                      labelText: 'رقم الهاتف',
                      hintText: '+201234567890',
                      prefixIcon: const Icon(Icons.phone),
                      border: const OutlineInputBorder(),
                      helperText: 'يمكن استخدام الصيغة الدولية (+20...)',
                    ),
                    validator: _validatePhoneNumber,
                    textInputAction: TextInputAction.done,
                    onFieldSubmitted: (_) => _saveEmergencyContact(),
                  ),
                  const SizedBox(height: 24),
                  // Features info
                  _buildFeaturesInfo(),
                  const SizedBox(height: 24),
                  // Send test SMS checkbox
                  CheckboxListTile(
                    value: _sendTestSms,
                    onChanged: (value) {
                      setState(() {
                        _sendTestSms = value ?? true;
                      });
                    },
                    title: const Text('إرسال رسالة اختبار'),
                    subtitle: const Text('للتأكد من صحة الرقم'),
                    controlAffinity: ListTileControlAffinity.leading,
                    contentPadding: EdgeInsets.zero,
                  ),
                  const SizedBox(height: 16),
                  // Error message
                  if (_errorMessage != null)
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.red[50],
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.red[200]!),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.error_outline, color: Colors.red),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _errorMessage!,
                              style: const TextStyle(color: Colors.red),
                            ),
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 24),
                  // Submit button
                  ElevatedButton(
                    onPressed: _isLoading ? null : _saveEmergencyContact,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(
                            widget.isInitialSetup ? 'متابعة' : 'حفظ',
                            style: const TextStyle(fontSize: 16),
                          ),
                  ),
                  if (widget.isInitialSetup) ...[
                    const SizedBox(height: 16),
                    TextButton(
                      onPressed: widget.onContactSet,
                      child: const Text('تخطي الآن'),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFeaturesInfo() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.blue[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.info_outline, color: Colors.blue[700]),
              const SizedBox(width: 8),
              Text(
                'ما يمكنك فعله برقم الطوارئ:',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.blue[700],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildFeatureItem(Icons.lock, 'قفل الجهاز عن بعد'),
          _buildFeatureItem(Icons.location_on, 'تتبع موقع الجهاز'),
          _buildFeatureItem(Icons.volume_up, 'تشغيل إنذار عالي'),
          _buildFeatureItem(Icons.notifications, 'استقبال تنبيهات الأمان'),
        ],
      ),
    );
  }

  Widget _buildFeatureItem(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 18, color: Colors.blue[600]),
          const SizedBox(width: 8),
          Text(text, style: TextStyle(color: Colors.blue[800])),
        ],
      ),
    );
  }
}
