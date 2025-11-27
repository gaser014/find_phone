import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../services/authentication/i_authentication_service.dart';
import '../../../services/protection/i_protection_service.dart';

/// Fake "Device Locked by Administrator" screen for panic mode.
///
/// Displays a convincing administrator lock screen that appears to be
/// a system-level lock, making it difficult for a thief to realize
/// the device has anti-theft protection.
///
/// Requirements:
/// - 21.3: Display fake "Device Locked by Administrator" screen
/// - 21.5: Require Master Password entered twice to exit panic mode
class AdminLockScreen extends StatefulWidget {
  final IProtectionService protectionService;
  final IAuthenticationService authenticationService;
  final VoidCallback? onUnlocked;
  final String? organizationName;
  final String? contactInfo;

  const AdminLockScreen({
    super.key,
    required this.protectionService,
    required this.authenticationService,
    this.onUnlocked,
    this.organizationName,
    this.contactInfo,
  });

  @override
  State<AdminLockScreen> createState() => _AdminLockScreenState();
}

class _AdminLockScreenState extends State<AdminLockScreen>
    with SingleTickerProviderStateMixin {
  final TextEditingController _passwordController = TextEditingController();
  
  bool _isLoading = false;
  bool _showPasswordField = false;
  bool _firstPasswordConfirmed = false;
  String? _errorMessage;
  int _tapCount = 0;
  DateTime? _lastTapTime;
  
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  // Secret tap pattern to reveal password field (tap lock icon 5 times)
  static const int _secretTapCount = 5;
  static const Duration _tapWindow = Duration(seconds: 3);

  @override
  void initState() {
    super.initState();
    _setupPulseAnimation();
    _lockSystemUI();
  }

  void _setupPulseAnimation() {
    _pulseController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat(reverse: true);
    
    _pulseAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  void _lockSystemUI() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  @override
  void dispose() {
    _passwordController.dispose();
    _pulseController.dispose();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  void _handleLockIconTap() {
    final now = DateTime.now();
    
    // Reset tap count if too much time has passed
    if (_lastTapTime != null && now.difference(_lastTapTime!) > _tapWindow) {
      _tapCount = 0;
    }
    
    _lastTapTime = now;
    _tapCount++;
    
    if (_tapCount >= _secretTapCount) {
      HapticFeedback.mediumImpact();
      setState(() {
        _showPasswordField = true;
        _tapCount = 0;
      });
    }
  }

  Future<void> _handleUnlock() async {
    final password = _passwordController.text;
    
    if (password.isEmpty) {
      setState(() {
        _errorMessage = 'Enter administrator password';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Panic mode requires password twice (Requirement 21.5)
      final success = await widget.protectionService.disablePanicMode(password);
      
      if (success) {
        // Fully unlocked (both confirmations passed)
        widget.onUnlocked?.call();
        if (mounted) {
          Navigator.of(context).pop(true);
        }
      } else {
        if (!_firstPasswordConfirmed) {
          // First password was correct, need second confirmation
          setState(() {
            _firstPasswordConfirmed = true;
            _passwordController.clear();
            _errorMessage = null;
          });
        } else {
          // Password was incorrect
          setState(() {
            _errorMessage = 'Invalid administrator password';
            _passwordController.clear();
            _firstPasswordConfirmed = false;
          });
          await widget.authenticationService.recordFailedAttempt();
        }
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Authentication failed';
        _firstPasswordConfirmed = false;
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
      canPop: false,
      child: Scaffold(
        backgroundColor: const Color(0xFF0D1117),
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildAdminIcon(),
                  const SizedBox(height: 40),
                  _buildTitle(),
                  const SizedBox(height: 16),
                  _buildSubtitle(),
                  const SizedBox(height: 32),
                  _buildInfoCard(),
                  if (_showPasswordField) ...[
                    const SizedBox(height: 32),
                    _buildPasswordSection(),
                  ],
                  const SizedBox(height: 48),
                  _buildFooter(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAdminIcon() {
    return GestureDetector(
      onTap: _handleLockIconTap,
      child: AnimatedBuilder(
        animation: _pulseAnimation,
        builder: (context, child) {
          return Transform.scale(
            scale: _pulseAnimation.value,
            child: child,
          );
        },
        child: Container(
          width: 100,
          height: 100,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.red.shade900,
            boxShadow: [
              BoxShadow(
                color: Colors.red.withOpacity(0.3),
                blurRadius: 20,
                spreadRadius: 5,
              ),
            ],
          ),
          child: const Icon(
            Icons.admin_panel_settings,
            size: 50,
            color: Colors.white,
          ),
        ),
      ),
    );
  }

  Widget _buildTitle() {
    return const Text(
      'Device Locked',
      style: TextStyle(
        fontSize: 32,
        fontWeight: FontWeight.bold,
        color: Colors.white,
        letterSpacing: 1.2,
      ),
    );
  }

  Widget _buildSubtitle() {
    return Text(
      'This device has been locked by your administrator',
      textAlign: TextAlign.center,
      style: TextStyle(
        fontSize: 16,
        color: Colors.grey.shade400,
        height: 1.5,
      ),
    );
  }

  Widget _buildInfoCard() {
    final orgName = widget.organizationName ?? 'IT Security Department';
    final contact = widget.contactInfo ?? 'Contact your system administrator';
    
    return Container(
      constraints: const BoxConstraints(maxWidth: 400),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.grey.shade800,
          width: 1,
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(Icons.business, color: Colors.grey.shade500, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  orgName,
                  style: TextStyle(
                    color: Colors.grey.shade300,
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Icon(Icons.info_outline, color: Colors.grey.shade500, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  contact,
                  style: TextStyle(
                    color: Colors.grey.shade400,
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Icon(Icons.security, color: Colors.red.shade400, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Security policy violation detected',
                  style: TextStyle(
                    color: Colors.red.shade400,
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPasswordSection() {
    return Container(
      constraints: const BoxConstraints(maxWidth: 400),
      child: Column(
        children: [
          Text(
            _firstPasswordConfirmed
                ? 'Confirm administrator password'
                : 'Enter administrator password',
            style: TextStyle(
              color: Colors.grey.shade400,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _passwordController,
            obscureText: true,
            enabled: !_isLoading,
            style: const TextStyle(color: Colors.white, fontSize: 16),
            textAlign: TextAlign.center,
            decoration: InputDecoration(
              hintText: 'Password',
              hintStyle: TextStyle(color: Colors.grey.shade600),
              filled: true,
              fillColor: Colors.white.withOpacity(0.08),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.red.shade700, width: 2),
              ),
              prefixIcon: Icon(Icons.lock, color: Colors.grey.shade600),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 16,
              ),
            ),
            onSubmitted: (_) => _handleUnlock(),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _handleUnlock,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.shade800,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                disabledBackgroundColor: Colors.red.shade900.withOpacity(0.5),
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
                  : Text(
                      _firstPasswordConfirmed ? 'Confirm' : 'Unlock',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
            ),
          ),
          if (_errorMessage != null) ...[
            const SizedBox(height: 12),
            Text(
              _errorMessage!,
              style: TextStyle(
                color: Colors.red.shade400,
                fontSize: 14,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildFooter() {
    return Column(
      children: [
        Icon(
          Icons.shield,
          color: Colors.grey.shade700,
          size: 24,
        ),
        const SizedBox(height: 8),
        Text(
          'Protected by Enterprise Security',
          style: TextStyle(
            color: Colors.grey.shade600,
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Device Management System v2.1',
          style: TextStyle(
            color: Colors.grey.shade700,
            fontSize: 11,
          ),
        ),
      ],
    );
  }
}
