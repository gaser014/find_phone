import 'package:flutter/material.dart';

/// Extension to create colors with opacity without deprecation warnings.
extension ColorWithAlpha on Color {
  /// Creates a new color with the specified opacity (0.0 to 1.0).
  Color withAlpha255(double opacity) {
    return Color.fromARGB(
      (opacity * 255).round(),
      (r * 255).round(),
      (g * 255).round(),
      (b * 255).round(),
    );
  }
}

/// A card widget displaying the current protection status.
///
/// Shows the overall protection state with visual indicators for each
/// protection mode (Protected, Kiosk, Panic, Stealth).
///
/// Requirements:
/// - 9.1: Display main dashboard with protection status
/// - 9.5: Provide clear Arabic labels
class ProtectionStatusCard extends StatelessWidget {
  final bool isProtectedModeActive;
  final bool isKioskModeActive;
  final bool isPanicModeActive;
  final bool isStealthModeActive;
  final String? emergencyContact;

  const ProtectionStatusCard({
    super.key,
    required this.isProtectedModeActive,
    required this.isKioskModeActive,
    required this.isPanicModeActive,
    required this.isStealthModeActive,
    this.emergencyContact,
  });

  /// Determines the overall protection level based on active modes.
  _ProtectionLevel get _protectionLevel {
    if (isPanicModeActive) return _ProtectionLevel.panic;
    if (isKioskModeActive) return _ProtectionLevel.maximum;
    if (isProtectedModeActive) return _ProtectionLevel.active;
    return _ProtectionLevel.inactive;
  }

  @override
  Widget build(BuildContext context) {
    final level = _protectionLevel;

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: level.color.withAlpha255(0.5),
          width: 2,
        ),
      ),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              level.color.withAlpha255(0.1),
              level.color.withAlpha255(0.05),
            ],
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              // Status Icon
              _buildStatusIcon(level),
              const SizedBox(height: 16),

              // Status Title
              Text(
                level.title,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: level.color,
                    ),
              ),
              const SizedBox(height: 8),

              // Status Description
              Text(
                level.description,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.grey[600],
                    ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),

              // Active Modes Indicators
              _buildActiveModeIndicators(context),

              // Emergency Contact Info
              if (emergencyContact != null) ...[
                const SizedBox(height: 16),
                _buildEmergencyContactInfo(context),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusIcon(_ProtectionLevel level) {
    return Container(
      width: 80,
      height: 80,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: level.color.withAlpha255(0.2),
        border: Border.all(
          color: level.color,
          width: 3,
        ),
      ),
      child: Icon(
        level.icon,
        size: 40,
        color: level.color,
      ),
    );
  }

  Widget _buildActiveModeIndicators(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      alignment: WrapAlignment.center,
      children: [
        _buildModeChip(
          context,
          'الحماية',
          Icons.shield,
          isProtectedModeActive,
          Colors.green,
        ),
        _buildModeChip(
          context,
          'Kiosk',
          Icons.lock,
          isKioskModeActive,
          Colors.orange,
        ),
        _buildModeChip(
          context,
          'الذعر',
          Icons.warning,
          isPanicModeActive,
          Colors.red,
        ),
        _buildModeChip(
          context,
          'التخفي',
          Icons.visibility_off,
          isStealthModeActive,
          Colors.purple,
        ),
      ],
    );
  }

  Widget _buildModeChip(
    BuildContext context,
    String label,
    IconData icon,
    bool isActive,
    Color activeColor,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: isActive ? activeColor.withAlpha255(0.2) : Colors.grey[200],
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isActive ? activeColor : Colors.grey[400]!,
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 16,
            color: isActive ? activeColor : Colors.grey[600],
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
              color: isActive ? activeColor : Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmergencyContactInfo(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.blue[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.blue[200]!),
      ),
      child: Row(
        children: [
          Icon(Icons.contact_phone, color: Colors.blue[700], size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'جهة اتصال الطوارئ',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.blue[700],
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  emergencyContact!,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.blue[900],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Represents the overall protection level.
enum _ProtectionLevel {
  inactive(
    title: 'الحماية غير مفعلة',
    description: 'جهازك غير محمي حالياً. قم بتفعيل وضع الحماية لتأمين جهازك.',
    icon: Icons.shield_outlined,
    color: Colors.grey,
  ),
  active(
    title: 'الحماية مفعلة',
    description: 'جهازك محمي. جميع ميزات الحماية الأساسية تعمل.',
    icon: Icons.shield,
    color: Colors.green,
  ),
  maximum(
    title: 'الحماية القصوى',
    description: 'وضع Kiosk مفعل. الجهاز مقفل على التطبيق فقط.',
    icon: Icons.lock,
    color: Colors.orange,
  ),
  panic(
    title: 'وضع الذعر',
    description: 'تم تفعيل وضع الطوارئ. يتم إرسال التنبيهات والموقع.',
    icon: Icons.warning,
    color: Colors.red,
  );

  final String title;
  final String description;
  final IconData icon;
  final Color color;

  const _ProtectionLevel({
    required this.title,
    required this.description,
    required this.icon,
    required this.color,
  });
}
