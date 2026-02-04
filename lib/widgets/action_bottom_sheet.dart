import 'package:flutter/material.dart';
import '../core/theme.dart';
import '../core/constants.dart';
import '../models/media_item.dart';

/// Bottom sheet with media actions
class ActionBottomSheet extends StatelessWidget {
  final MediaItem media;
  final VoidCallback onShare;
  final VoidCallback onDelete;
  final VoidCallback? onInfo;
  final VoidCallback? onFavorite;

  const ActionBottomSheet({
    super.key,
    required this.media,
    required this.onShare,
    required this.onDelete,
    this.onInfo,
    this.onFavorite,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(AppConstants.radiusXLarge),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle bar
            Container(
              width: 48,
              height: 5,
              margin: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                color: Colors.grey.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(3),
              ),
            ),

            // Actions
            _ActionTile(
              icon: Icons.share_outlined,
              label: 'Partager',
              onTap: () {
                Navigator.pop(context);
                onShare();
              },
              isDark: isDark,
            ),

            if (onInfo != null)
              _ActionTile(
                icon: Icons.info_outline,
                label: 'Informations',
                onTap: () {
                  Navigator.pop(context);
                  onInfo!();
                },
                isDark: isDark,
              ),

            if (onFavorite != null)
              _ActionTile(
                icon: Icons.favorite_border,
                label: 'Ajouter aux favoris',
                onTap: () {
                  Navigator.pop(context);
                  onFavorite!();
                },
                isDark: isDark,
              ),

            const Divider(color: Colors.grey),

            _ActionTile(
              icon: Icons.delete_outline,
              label: 'Supprimer',
              color: AppColors.error,
              onTap: () {
                Navigator.pop(context);
                onDelete();
              },
              isDark: isDark,
            ),

            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? color;
  final bool isDark;

  const _ActionTile({
    required this.icon,
    required this.label,
    required this.onTap,
    required this.isDark,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveColor =
        color ??
        (isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary);

    return ListTile(
      leading: Icon(icon, color: effectiveColor),
      title: Text(
        label,
        style: TextStyle(color: effectiveColor, fontWeight: FontWeight.w500),
      ),
      onTap: onTap,
    );
  }
}

/// Dialog to confirm deletion
class DeleteConfirmationDialog extends StatelessWidget {
  final int itemCount;
  final VoidCallback onConfirm;

  const DeleteConfirmationDialog({
    super.key,
    required this.itemCount,
    required this.onConfirm,
  });

  static void show(
    BuildContext context, {
    required int itemCount,
    required VoidCallback onConfirm,
  }) {
    showDialog(
      context: context,
      builder: (context) =>
          DeleteConfirmationDialog(itemCount: itemCount, onConfirm: onConfirm),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final itemText = itemCount == 1 ? 'cet élément' : 'ces $itemCount éléments';

    return AlertDialog(
      backgroundColor: isDark ? AppColors.darkSurface : AppColors.lightSurface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppConstants.radiusLarge),
      ),
      title: Text(
        'Supprimer',
        style: TextStyle(
          color: isDark
              ? AppColors.darkTextPrimary
              : AppColors.lightTextPrimary,
          fontWeight: FontWeight.bold,
        ),
      ),
      content: Text(
        'Voulez-vous vraiment supprimer $itemText ? Cette action est irréversible.',
        style: TextStyle(
          color: isDark
              ? AppColors.darkTextSecondary
              : AppColors.lightTextSecondary,
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(
            'Annuler',
            style: TextStyle(
              color: isDark
                  ? AppColors.darkTextSecondary
                  : AppColors.lightTextSecondary,
            ),
          ),
        ),
        TextButton(
          onPressed: () {
            Navigator.pop(context);
            onConfirm();
          },
          child: const Text(
            'Supprimer',
            style: TextStyle(
              color: AppColors.error,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}
