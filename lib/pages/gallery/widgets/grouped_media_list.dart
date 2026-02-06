import 'package:flutter/material.dart';
import '../../../core/theme.dart';
import '../../../core/constants.dart';
import '../../../models/media_item.dart';
import '../../../widgets/media_grid_item.dart';
import '../utils/date_grouping.dart';
import 'load_more_button.dart';

/// Grouped list of media items by month
class GroupedMediaList extends StatelessWidget {
  final List<MediaItem> media;
  final Set<String> selectedIds;
  final bool hasMoreMedia;
  final bool isLoadingMore;
  final int totalMediaCount;
  final VoidCallback onRefresh;
  final VoidCallback onLoadMore;
  final void Function(MediaItem) onMediaTap;
  final void Function(MediaItem) onMediaLongPress;

  const GroupedMediaList({
    super.key,
    required this.media,
    required this.selectedIds,
    required this.hasMoreMedia,
    required this.isLoadingMore,
    required this.totalMediaCount,
    required this.onRefresh,
    required this.onLoadMore,
    required this.onMediaTap,
    required this.onMediaLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final groups = groupMediaByMonth(media);
    final groupKeys = groups.keys.toList();

    return RefreshIndicator(
      onRefresh: () async => onRefresh(),
      color: AppColors.primary,
      child: ListView.builder(
        padding: const EdgeInsets.all(AppConstants.gridSpacing),
        itemCount: groupKeys.length + (hasMoreMedia ? 1 : 0),
        itemBuilder: (context, groupIndex) {
          // "Load more" button at the end
          if (hasMoreMedia && groupIndex == groupKeys.length) {
            return Padding(
              padding: const EdgeInsets.only(top: 16),
              child: SizedBox(
                height: 100,
                child: LoadMoreButton(
                  remainingCount: totalMediaCount - media.length,
                  isLoading: isLoadingMore,
                  onTap: onLoadMore,
                ),
              ),
            );
          }

          final groupKey = groupKeys[groupIndex];
          final mediaList = groups[groupKey]!;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Month/Year section header
              Padding(
                padding: const EdgeInsets.only(top: 16, bottom: 8),
                child: Text(
                  groupKey,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: isDark
                        ? AppColors.darkTextPrimary
                        : AppColors.lightTextPrimary,
                  ),
                ),
              ),
              // Grid for this month
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: AppConstants.gridCrossAxisCount,
                  mainAxisSpacing: AppConstants.gridSpacing,
                  crossAxisSpacing: AppConstants.gridSpacing,
                ),
                itemCount: mediaList.length,
                itemBuilder: (context, index) {
                  final item = mediaList[index];
                  return MediaGridItem(
                    media: item,
                    isSelected: selectedIds.contains(item.id),
                    onTap: () => onMediaTap(item),
                    onLongPress: () => onMediaLongPress(item),
                  );
                },
              ),
            ],
          );
        },
      ),
    );
  }
}
