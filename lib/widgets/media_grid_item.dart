import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../core/theme.dart';
import '../core/constants.dart';
import '../models/media_item.dart';

/// Grid item widget for displaying media in a grid
class MediaGridItem extends StatelessWidget {
  final MediaItem media;
  final bool isSelected;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const MediaGridItem({
    super.key,
    required this.media,
    this.isSelected = false,
    required this.onTap,
    required this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppConstants.radiusSmall),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Thumbnail
            FutureBuilder<Uint8List?>(
              future: media.getThumbnail(),
              builder: (context, snapshot) {
                if (snapshot.hasData && snapshot.data != null) {
                  return Image.memory(snapshot.data!, fit: BoxFit.cover);
                }

                // Show placeholder for error or completed with null
                if (snapshot.connectionState == ConnectionState.done ||
                    snapshot.hasError) {
                  return Container(
                    color: isDark
                        ? AppColors.darkSurfaceLight
                        : AppColors.lightSurfaceLight,
                    child: Center(
                      child: Icon(
                        media.isVideo
                            ? Icons.videocam_outlined
                            : Icons.image_outlined,
                        size: 32,
                        color: isDark
                            ? AppColors.darkTextMuted
                            : AppColors.lightTextMuted,
                      ),
                    ),
                  );
                }

                // Still loading
                return Container(
                  color: isDark
                      ? AppColors.darkSurfaceLight
                      : AppColors.lightSurfaceLight,
                  child: const Center(
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.primary,
                    ),
                  ),
                );
              },
            ),

            // Video duration badge
            if (media.isVideo)
              Positioned(
                bottom: 4,
                right: 4,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 4,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.7),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    media.formattedDuration,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),

            // Selection overlay
            if (isSelected)
              Container(
                color: AppColors.primary.withValues(alpha: 0.4),
                child: const Center(
                  child: Icon(
                    Icons.check_circle,
                    color: Colors.white,
                    size: 32,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
