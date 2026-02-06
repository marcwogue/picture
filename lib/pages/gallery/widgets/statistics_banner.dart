import 'package:flutter/material.dart';
import '../../../core/theme.dart';
import '../../../core/constants.dart';

/// Statistics banner showing file counts
class StatisticsBanner extends StatelessWidget {
  final int totalCount;
  final int imageCount;
  final int videoCount;

  const StatisticsBanner({
    super.key,
    required this.totalCount,
    required this.imageCount,
    required this.videoCount,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: AppConstants.paddingMedium,
        vertical: AppConstants.paddingSmall,
      ),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
        border: Border(
          bottom: BorderSide(
            color: isDark
                ? AppColors.darkSurfaceLight
                : AppColors.lightSurfaceLight,
          ),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _StatItem(
            icon: Icons.folder_outlined,
            label: 'Fichiers',
            count: totalCount,
          ),
          if (imageCount > 0)
            _StatItem(
              icon: Icons.image_outlined,
              label: 'Images',
              count: imageCount,
              iconColor: AppColors.primary,
            ),
          if (videoCount > 0)
            _StatItem(
              icon: Icons.videocam_outlined,
              label: 'Vidéos',
              count: videoCount,
              iconColor: AppColors.warning,
            ),
        ],
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final int count;
  final Color? iconColor;

  const _StatItem({
    required this.icon,
    required this.label,
    required this.count,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          icon,
          size: 20,
          color:
              iconColor ??
              (isDark
                  ? AppColors.darkTextSecondary
                  : AppColors.lightTextSecondary),
        ),
        const SizedBox(width: 6),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              count.toString(),
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: isDark
                    ? AppColors.darkTextPrimary
                    : AppColors.lightTextPrimary,
              ),
            ),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                color: isDark
                    ? AppColors.darkTextMuted
                    : AppColors.lightTextMuted,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
