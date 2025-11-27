import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../services/authentication/i_authentication_service.dart';
import '../../../services/protection/i_protection_service.dart';

/// Password entry widget for Kiosk Mode.
///
/// Provides a secure password entry interface with:
/// - PIN-style numeric keypad option
/// - Full keyboard password entry
/// - Visual feedback for input
/// - Failed attempt tracking
///
/// Requirements:
/// - 3.4: Exit Kiosk Mode with correct password
class KioskPasswordEntry extends StatefulWidget {
  final IProtectionService protectionService;
  final IAuthenticationService authenticationService;
  final Function(bool success) onPasswordVerified;
  final bool usePinStyle;
  final int pinLength;

  const KioskPasswordEntry({
    super.key,
    required this.protectionService,
    required this.authenticationService,
    required this.onPasswordVerified,
    this.usePinStyle = false,
    this.pinLength = 6,
  });

  @override
  State<KioskPasswordEntry> createState() => _KioskPasswordEntryState();
}

class _KioskPasswordEntryState extends State<KioskPasswordEntry>
    with SingleTickerProviderStateMixin {
  final TextEditingController _passwordController = TextEditingController();
  String _enteredPin = '';
  bool _isLoading = false;
  String? _errorMessage;
  int _failedAttempts = 0;
  
  late AnimationController _shakeController;
  late Animation<double> _shakeAnimation;

  @override
  void initState() {
    super.initState();
    _setupShakeAnimation();
  }

  void _setupShakeAnimation() {
    _shakeController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
    _shakeAnimation = Tween<double>(begin: 0, end: 8).animate(
      CurvedAnimation(parent: _shakeController, curve: Curves.elasticIn),
    );
  }

  @override
  void dispose() {
    _passwordController.dispose();
    _shakeController.dispose();
    super.dispose();
  }

  void _onPinDigitPressed(String digit) {
    if (_enteredPin.length < widget.pinLength && !_isLoading) {
      HapticFeedback.lightImpact();
      setState(() {
        _enteredPin += digit;
        _errorMessage = null;
      });
      
      // Auto-submit when PIN is complete
      if (_enteredPin.length == widget.pinLength) {
        _verifyPassword(_enteredPin);
      }
    }
  }

  void _onBackspacePressed() {
    if (_enteredPin.isNotEmpty && !_isLoading) {
      HapticFeedback.lightImpact();
      setState(() {
        _enteredPin = _enteredPin.substring(0, _enteredPin.length - 1);
        _errorMessage = null;
      });
    }
  }

  void _onClearPressed() {
    if (!_isLoading) {
      HapticFeedback.lightImpact();
      setState(() {
        _enteredPin = '';
        _errorMessage = null;
      });
    }
  }

  Future<void> _verifyPassword(String password) async {
    if (password.isEmpty) {
      setState(() {
        _errorMessage = 'الرجاء إدخال كلمة المرور';
      });
      _triggerShake();
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final isValid = await widget.authenticationService.verifyPassword(password);
      
      if (isValid) {
        widget.onPasswordVerified(true);
      } else {
        _failedAttempts++;
        await widget.authenticationService.recordFailedAttempt();
        
        setState(() {
          _errorMessage = 'كلمة المرور غير صحيحة';
          _enteredPin = '';
          _passwordController.clear();
        });
        _triggerShake();
        widget.onPasswordVerified(false);
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'حدث خطأ. حاول مرة أخرى.';
        _enteredPin = '';
      });
      _triggerShake();
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _triggerShake() {
    _shakeController.forward().then((_) => _shakeController.reset());
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: AnimatedBuilder(
        animation: _shakeAnimation,
        builder: (context, child) {
          return Transform.translate(
            offset: Offset(_shakeAnimation.value, 0),
            child: child,
          );
        },
        child: widget.usePinStyle ? _buildPinEntry() : _buildPasswordEntry(),
      ),
    );
  }

  Widget _buildPasswordEntry() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          constraints: const BoxConstraints(maxWidth: 350),
          child: TextField(
            controller: _passwordController,
            obscureText: true,
            enabled: !_isLoading,
            style: const TextStyle(color: Colors.white, fontSize: 18),
            textAlign: TextAlign.center,
            decoration: InputDecoration(
              hintText: 'كلمة المرور',
              hintStyle: TextStyle(color: Colors.grey.shade600),
              filled: true,
              fillColor: Colors.white.withValues(alpha: 0.1),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Colors.blue, width: 2),
              ),
              prefixIcon: const Icon(Icons.lock_outline, color: Colors.grey),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 16,
              ),
            ),
            onSubmitted: _verifyPassword,
          ),
        ),
        const SizedBox(height: 20),
        SizedBox(
          width: 200,
          height: 48,
          child: ElevatedButton(
            onPressed: _isLoading
                ? null
                : () => _verifyPassword(_passwordController.text),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue.shade700,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: _isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : const Text('تأكيد', style: TextStyle(fontSize: 16)),
          ),
        ),
        if (_errorMessage != null) ...[
          const SizedBox(height: 16),
          _buildErrorMessage(),
        ],
      ],
    );
  }

  Widget _buildPinEntry() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildPinDots(),
        const SizedBox(height: 32),
        _buildNumericKeypad(),
        if (_errorMessage != null) ...[
          const SizedBox(height: 16),
          _buildErrorMessage(),
        ],
        if (_failedAttempts > 0) ...[
          const SizedBox(height: 8),
          Text(
            'محاولات فاشلة: $_failedAttempts',
            style: TextStyle(color: Colors.orange.shade400, fontSize: 14),
          ),
        ],
      ],
    );
  }

  Widget _buildPinDots() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(widget.pinLength, (index) {
        final isFilled = index < _enteredPin.length;
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 8),
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isFilled ? Colors.blue : Colors.transparent,
            border: Border.all(
              color: isFilled ? Colors.blue : Colors.grey.shade600,
              width: 2,
            ),
          ),
        );
      }),
    );
  }

  Widget _buildNumericKeypad() {
    return Container(
      constraints: const BoxConstraints(maxWidth: 300),
      child: Column(
        children: [
          _buildKeypadRow(['1', '2', '3']),
          const SizedBox(height: 12),
          _buildKeypadRow(['4', '5', '6']),
          const SizedBox(height: 12),
          _buildKeypadRow(['7', '8', '9']),
          const SizedBox(height: 12),
          _buildKeypadRow(['C', '0', '⌫']),
        ],
      ),
    );
  }

  Widget _buildKeypadRow(List<String> keys) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: keys.map((key) => _buildKeypadButton(key)).toList(),
    );
  }

  Widget _buildKeypadButton(String key) {
    final isSpecial = key == 'C' || key == '⌫';
    
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: _isLoading
            ? null
            : () {
                if (key == 'C') {
                  _onClearPressed();
                } else if (key == '⌫') {
                  _onBackspacePressed();
                } else {
                  _onPinDigitPressed(key);
                }
              },
        borderRadius: BorderRadius.circular(40),
        child: Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isSpecial
                ? Colors.grey.shade800.withValues(alpha: 0.5)
                : Colors.white.withValues(alpha: 0.1),
            border: Border.all(
              color: Colors.grey.shade700,
              width: 1,
            ),
          ),
          child: Center(
            child: key == '⌫'
                ? Icon(
                    Icons.backspace_outlined,
                    color: Colors.grey.shade400,
                    size: 24,
                  )
                : Text(
                    key,
                    style: TextStyle(
                      fontSize: isSpecial ? 18 : 28,
                      fontWeight: FontWeight.w500,
                      color: isSpecial ? Colors.grey.shade400 : Colors.white,
                    ),
                  ),
          ),
        ),
      ),
    );
  }

  Widget _buildErrorMessage() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.red.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline, color: Colors.red, size: 18),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              _errorMessage!,
              style: const TextStyle(color: Colors.red, fontSize: 14),
              overflow: TextOverflow.ellipsis,
              maxLines: 2,
            ),
          ),
        ],
      ),
    );
  }
}
