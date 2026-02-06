import 'package:flutter/material.dart';
import '../../../core/theme.dart';
import '../../../core/constants.dart';
import '../../../shared/widgets/action_button.dart';

/// Selection bar at bottom of gallery page
class SelectionBar extends StatelessWidget {
  final VoidCallback onShare;
  final VoidCallback onDelete;

  const SelectionBar({
    super.key,
    required this.onShare,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppConstants.paddingMedium,
        vertical: AppConstants.paddingSmall,
      ),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
        border: Border(
          top: BorderSide(
            color: isDark
                ? AppColors.darkSurfaceLight
                : AppColors.lightSurfaceLight,
          ),
        ),
      ),
      child: SafeArea(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            ActionButton(icon: Icons.share, label: 'Partager', onTap: onShare),
            ActionButton(
              icon: Icons.delete,
              label: 'Supprimer',
              onTap: onDelete,
              color: AppColors.error,
            ),
          ],
        ),
      ),
    );
  }
}
