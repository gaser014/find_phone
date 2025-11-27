import 'package:flutter/material.dart';

/// Extension to create colors with opacity without deprecation warnings.
extension _ColorWithAlpha on Color {
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

/// A list tile widget with a toggle switch for protection features.
///
/// Displays a feature name, description, icon, and toggle switch.
/// Used for enabling/disabling protection features in the dashboard.
///
/// Requirements:
/// - 9.2: Show toggle switches for all protection features
/// - 9.5: Provide clear Arabic labels
class ProtectionToggleTile extends StatelessWidget {
  /// The title/name of the protection feature.
  final String title;

  /// A brief description of what the feature does.
  final String subtitle;

  /// Icon representing the feature.
  final IconData icon;

  /// Current toggle state.
  final bool value;

  /// Callback when toggle is changed.
  final ValueChanged<bool> onChanged;

  /// Color when the toggle is active (defaults to theme primary).
  final Color? activeColor;

  /// Whether the toggle is enabled.
  final bool enabled;

  const ProtectionToggleTile({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.value,
    required this.onChanged,
    this.activeColor,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveActiveColor = activeColor ?? Theme.of(context).primaryColor;

    return ListTile(
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: value
              ? effectiveActiveColor.withAlpha255(0.2)
              : Colors.grey[200],
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(
          icon,
          color: value ? effectiveActiveColor : Colors.grey[600],
          size: 24,
        ),
      ),
      title: Text(
        title,
        style: TextStyle(
          fontWeight: FontWeight.w600,
          color: enabled ? null : Colors.grey,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(
          fontSize: 12,
          color: enabled ? Colors.grey[600] : Colors.grey[400],
        ),
      ),
      trailing: Switch(
        value: value,
        onChanged: enabled ? onChanged : null,
        activeTrackColor: effectiveActiveColor.withAlpha255(0.5),
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return effectiveActiveColor;
          }
          return null;
        }),
      ),
      onTap: enabled ? () => onChanged(!value) : null,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
    );
  }
}
