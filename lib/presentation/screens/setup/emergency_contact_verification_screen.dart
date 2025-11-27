import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import '../../../services/sms/i_sms_service.dart';
import '../../../services/storage/i_storage_service.dart';

/// Storage keys for verification data.
class VerificationStorageKeys {
  static const String verificationCode = 'emergency_verification_code';
  static const String verificationExpiry = 'emergency_verification_expiry';
  static const String pendingEmergencyContact = 'pending_emergency_contact';
}

/// Emergency Contact verification screen with SMS verification flow.
///
/// Requirements:
/// - 16.3: Require Master Password and send verification SMS to new number
/// - 16.4: Require user to enter verification code within 5 minutes
class EmergencyContactVerificationScreen extends StatefulWidget {
  final ISmsService smsService;
  final IStorageService storageService;
  final String newPhoneNumber;
  final VoidCallback onVerificationComplete;
  final VoidCallback onCancel;

  const EmergencyContactVerificationScreen({
    super.key,
    required this.smsService,
    required this.storageService,
    required this.newPhoneNumber,
    required this.onVerificationComplete,
    required this.onCancel,
  });

  @override
  State<EmergencyContactVerificationScreen> createState() =>
      _EmergencyContactVerificationScreenState();
}

class _EmergencyContactVerificationScreenState
    extends State<EmergencyContactVerificationScreen> {
  final _codeController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  bool _isLoading = false;
  bool _isSendingCode = false;
  String? _errorMessage;
  String? _verificationCode;
  DateTime? _codeExpiry;
  Timer? _countdownTimer;
  int _remainingSeconds = 0;

  @override
  void initState() {
    super.initState();
    _sendVerificationCode();
  }

  @override
  void dispose() {
    _codeController.dispose();
    _countdownTimer?.cancel();
    super.dispose();
  }

  /// Generates a 6-digit verification code.
  String _generateVerificationCode() {
    final random = Random.secure();
    return (100000 + random.nextInt(900000)).toString();
  }

  /// Sends verification SMS to the new phone number.
  Future<void> _sendVerificationCode() async {
    setState(() {
      _isSendingCode = true;
      _errorMessage = null;
    });

    try {
      // Generate new verification code
      _verificationCode = _generateVerificationCode();
      _codeExpiry = DateTime.now().add(const Duration(minutes: 5));

      // Store verification data
      await widget.storageService.storeSecure(
        VerificationStorageKeys.verificationCode,
        _verificationCode!,
      );
      await widget.storageService.store(
        VerificationStorageKeys.verificationExpiry,
        _codeExpiry!.toIso8601String(),
      );
      await widget.storageService.storeSecure(
        VerificationStorageKeys.pendingEmergencyContact,
        widget.newPhoneNumber,
      );

      // Send SMS with verification code
      final sent = await widget.smsService.sendSms(
        widget.newPhoneNumber,
        'Anti-Theft: رمز التحقق الخاص بك هو: $_verificationCode\n'
        'صالح لمدة 5 دقائق.',
      );

      if (!sent) {
        setState(() {
          _errorMessage = 'فشل إرسال رسالة التحقق. الرجاء المحاولة مرة أخرى.';
        });
        return;
      }

      // Start countdown timer
      _startCountdown();
    } catch (e) {
      setState(() {
        _errorMessage = 'حدث خطأ: ${e.toString()}';
      });
    } finally {
      setState(() {
        _isSendingCode = false;
      });
    }
  }

  void _startCountdown() {
    _remainingSeconds = 300; // 5 minutes
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        if (_remainingSeconds > 0) {
          _remainingSeconds--;
        } else {
          timer.cancel();
        }
      });
    });
  }

  String _formatRemainingTime() {
    final minutes = _remainingSeconds ~/ 60;
    final seconds = _remainingSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  Future<void> _verifyCode() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final enteredCode = _codeController.text.trim();

      // Check if code has expired
      if (_codeExpiry != null && DateTime.now().isAfter(_codeExpiry!)) {
        setState(() {
          _errorMessage = 'انتهت صلاحية رمز التحقق. الرجاء طلب رمز جديد.';
        });
        return;
      }

      // Verify the code
      if (enteredCode != _verificationCode) {
        setState(() {
          _errorMessage = 'رمز التحقق غير صحيح';
        });
        return;
      }

      // Code is valid, update emergency contact
      await widget.smsService.setEmergencyContact(widget.newPhoneNumber);

      // Clear verification data
      await widget.storageService.deleteSecure(
        VerificationStorageKeys.verificationCode,
      );
      await widget.storageService.delete(
        VerificationStorageKeys.verificationExpiry,
      );
      await widget.storageService.deleteSecure(
        VerificationStorageKeys.pendingEmergencyContact,
      );

      // Send confirmation SMS
      await widget.smsService.sendSms(
        widget.newPhoneNumber,
        'Anti-Theft: تم تأكيد رقم الطوارئ بنجاح.',
      );

      widget.onVerificationComplete();
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
        appBar: AppBar(
          title: const Text('التحقق من الرقم'),
          centerTitle: true,
          leading: IconButton(
            icon: const Icon(Icons.close),
            onPressed: widget.onCancel,
          ),
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 24),
                  const Icon(
                    Icons.sms,
                    size: 64,
                    color: Colors.blue,
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'أدخل رمز التحقق',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'تم إرسال رمز التحقق إلى:\n${widget.newPhoneNumber}',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.grey[600],
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 32),
                  // Countdown timer
                  if (_remainingSeconds > 0)
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: _remainingSeconds < 60
                            ? Colors.orange[50]
                            : Colors.green[50],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.timer,
                            color: _remainingSeconds < 60
                                ? Colors.orange
                                : Colors.green,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'صالح لمدة: ${_formatRemainingTime()}',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: _remainingSeconds < 60
                                  ? Colors.orange[700]
                                  : Colors.green[700],
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.red[50],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.timer_off, color: Colors.red),
                          const SizedBox(width: 8),
                          Text(
                            'انتهت صلاحية الرمز',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.red[700],
                            ),
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 24),
                  // Verification code field
                  TextFormField(
                    controller: _codeController,
                    keyboardType: TextInputType.number,
                    maxLength: 6,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 24,
                      letterSpacing: 8,
                      fontWeight: FontWeight.bold,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'رمز التحقق',
                      hintText: '000000',
                      border: OutlineInputBorder(),
                      counterText: '',
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'الرجاء إدخال رمز التحقق';
                      }
                      if (value.length != 6) {
                        return 'رمز التحقق يجب أن يكون 6 أرقام';
                      }
                      if (!RegExp(r'^\d{6}$').hasMatch(value)) {
                        return 'رمز التحقق يجب أن يحتوي على أرقام فقط';
                      }
                      return null;
                    },
                    onFieldSubmitted: (_) => _verifyCode(),
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
                  // Verify button
                  ElevatedButton(
                    onPressed: _isLoading || _remainingSeconds == 0
                        ? null
                        : _verifyCode,
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
                        : const Text(
                            'تحقق',
                            style: TextStyle(fontSize: 16),
                          ),
                  ),
                  const SizedBox(height: 16),
                  // Resend code button
                  TextButton(
                    onPressed: _isSendingCode ? null : _sendVerificationCode,
                    child: _isSendingCode
                        ? const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              SizedBox(
                                height: 16,
                                width: 16,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              ),
                              SizedBox(width: 8),
                              Text('جاري الإرسال...'),
                            ],
                          )
                        : const Text('إعادة إرسال الرمز'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
