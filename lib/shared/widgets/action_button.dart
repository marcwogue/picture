import 'package:flutter/material.dart';
import '../../core/theme.dart';

/// Reusable action button with icon and label
class ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? color;

  const ActionButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final effectiveColor =
        color ??
        (isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary);
    final secondaryColor =
        color ??
        (isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary);

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: effectiveColor),
            const SizedBox(height: 4),
            Text(label, style: TextStyle(color: secondaryColor, fontSize: 12)),
          ],
        ),
      ),
    );
  }
}
