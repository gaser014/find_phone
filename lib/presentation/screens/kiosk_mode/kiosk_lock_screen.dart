import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../services/authentication/i_authentication_service.dart';
import '../../../services/protection/i_protection_service.dart';

/// Custom lock screen for Kiosk Mode.
///
/// Displays a full-screen lock interface that requires the Master Password
/// to exit Kiosk Mode and restore normal device operation.
///
/// Requirements:
/// - 3.5: Show custom lock screen requiring Master Password
/// - 3.4: Exit Kiosk Mode with correct password
class KioskLockScreen extends StatefulWidget {
  final IProtectionService protectionService;
  final IAuthenticationService authenticationService;
  final String? customMessage;
  final VoidCallback? onUnlocked;

  const KioskLockScreen({
    super.key,
    required this.protectionService,
    required this.authenticationService,
    this.customMessage,
    this.onUnlocked,
  });

  @override
  State<KioskLockScreen> createState() => _KioskLockScreenState();
}

class _KioskLockScreenState extends State<KioskLockScreen>
    with SingleTickerProviderStateMixin {
  final TextEditingController _passwordController = TextEditingController();
  final FocusNode _passwordFocusNode = FocusNode();
  
  bool _isLoading = false;
  bool _obscurePassword = true;
  String? _errorMessage;
  int _failedAttempts = 0;
  
  late AnimationController _shakeController;
  late Animation<double> _shakeAnimation;

  @override
  void initState() {
    super.initState();
    _setupShakeAnimation();
    _lockSystemUI();
  }

  void _setupShakeAnimation() {
    _shakeController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _shakeAnimation = Tween<double>(begin: 0, end: 10).animate(
      CurvedAnimation(parent: _shakeController, curve: Curves.elasticIn),
    );
  }

  /// Lock system UI to prevent navigation
  void _lockSystemUI() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }


  @override
  void dispose() {
    _passwordController.dispose();
    _passwordFocusNode.dispose();
    _shakeController.dispose();
    // Restore system UI when disposed
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  Future<void> _handleUnlock() async {
    final password = _passwordController.text;
    
    if (password.isEmpty) {
      setState(() {
        _errorMessage = 'الرجاء إدخال كلمة المرور';
      });
      _shakeController.forward().then((_) => _shakeController.reset());
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final success = await widget.protectionService.disableKioskMode(password);
      
      if (success) {
        // Successfully unlocked
        widget.onUnlocked?.call();
        if (mounted) {
          Navigator.of(context).pop(true);
        }
      } else {
        // Failed to unlock
        setState(() {
          _failedAttempts++;
          _errorMessage = 'كلمة المرور غير صحيحة';
          _passwordController.clear();
        });
        _shakeController.forward().then((_) => _shakeController.reset());
        
        // Record failed attempt for security logging
        await widget.authenticationService.recordFailedAttempt();
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'حدث خطأ. حاول مرة أخرى.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false, // Prevent back button
      child: Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(
          backgroundColor: const Color(0xFF1A1A2E),
          body: SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(32),
                child: AnimatedBuilder(
                  animation: _shakeAnimation,
                  builder: (context, child) {
                    return Transform.translate(
                      offset: Offset(_shakeAnimation.value, 0),
                      child: child,
                    );
                  },
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _buildLockIcon(),
                      const SizedBox(height: 32),
                      _buildTitle(),
                      const SizedBox(height: 16),
                      _buildMessage(),
                      const SizedBox(height: 48),
                      _buildPasswordField(),
                      const SizedBox(height: 24),
                      _buildUnlockButton(),
                      if (_errorMessage != null) ...[
                        const SizedBox(height: 16),
                        _buildErrorMessage(),
                      ],
                      if (_failedAttempts > 0) ...[
                        const SizedBox(height: 8),
                        _buildFailedAttemptsWarning(),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLockIcon() {
    return Container(
      width: 120,
      height: 120,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.blue.shade700,
            Colors.blue.shade900,
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.blue.withOpacity(0.3),
            blurRadius: 20,
            spreadRadius: 5,
          ),
        ],
      ),
      child: const Icon(
        Icons.lock,
        size: 60,
        color: Colors.white,
      ),
    );
  }

  Widget _buildTitle() {
    return const Text(
      'الجهاز مقفل',
      style: TextStyle(
        fontSize: 28,
        fontWeight: FontWeight.bold,
        color: Colors.white,
      ),
    );
  }

  Widget _buildMessage() {
    final message = widget.customMessage ?? 'أدخل كلمة المرور الرئيسية لفتح الجهاز';
    return Text(
      message,
      textAlign: TextAlign.center,
      style: TextStyle(
        fontSize: 16,
        color: Colors.grey.shade400,
      ),
    );
  }

  Widget _buildPasswordField() {
    return Container(
      constraints: const BoxConstraints(maxWidth: 400),
      child: TextField(
        controller: _passwordController,
        focusNode: _passwordFocusNode,
        obscureText: _obscurePassword,
        enabled: !_isLoading,
        style: const TextStyle(color: Colors.white, fontSize: 18),
        textAlign: TextAlign.center,
        decoration: InputDecoration(
          hintText: 'كلمة المرور',
          hintStyle: TextStyle(color: Colors.grey.shade600),
          filled: true,
          fillColor: Colors.white.withOpacity(0.1),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: Colors.blue, width: 2),
          ),
          prefixIcon: const Icon(Icons.lock_outline, color: Colors.grey),
          suffixIcon: IconButton(
            icon: Icon(
              _obscurePassword ? Icons.visibility_off : Icons.visibility,
              color: Colors.grey,
            ),
            onPressed: () {
              setState(() {
                _obscurePassword = !_obscurePassword;
              });
            },
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 24,
            vertical: 20,
          ),
        ),
        onSubmitted: (_) => _handleUnlock(),
      ),
    );
  }

  Widget _buildUnlockButton() {
    return Container(
      constraints: const BoxConstraints(maxWidth: 400),
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: _isLoading ? null : _handleUnlock,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.blue.shade700,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: 4,
        ),
        child: _isLoading
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : const Text(
                'فتح القفل',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
      ),
    );
  }

  Widget _buildErrorMessage() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.red.withOpacity(0.2),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline, color: Colors.red, size: 20),
          const SizedBox(width: 8),
          Text(
            _errorMessage!,
            style: const TextStyle(color: Colors.red),
          ),
        ],
      ),
    );
  }

  Widget _buildFailedAttemptsWarning() {
    return Text(
      'محاولات فاشلة: $_failedAttempts',
      style: TextStyle(
        color: Colors.orange.shade400,
        fontSize: 14,
      ),
    );
  }
}
