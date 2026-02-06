import '../../../models/media_item.dart';

/// French month names for date grouping
const List<String> frenchMonths = [
  'Janvier',
  'Février',
  'Mars',
  'Avril',
  'Mai',
  'Juin',
  'Juillet',
  'Août',
  'Septembre',
  'Octobre',
  'Novembre',
  'Décembre',
];

/// Groups media items by month and year
/// Returns a map with keys like "Janvier 2026" and values as lists of MediaItem
Map<String, List<MediaItem>> groupMediaByMonth(List<MediaItem> media) {
  final Map<String, List<MediaItem>> groups = {};

  // Sort media by date (most recent first)
  final sortedMedia = List<MediaItem>.from(media)
    ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

  for (final item in sortedMedia) {
    final monthName = frenchMonths[item.createdAt.month - 1];
    final year = item.createdAt.year;
    final key = '$monthName $year';

    if (!groups.containsKey(key)) {
      groups[key] = [];
    }
    groups[key]!.add(item);
  }

  return groups;
}

/// Get count of images in media list
int getImageCount(List<MediaItem> media) {
  return media.where((m) => m.isImage).length;
}

/// Get count of videos in media list
int getVideoCount(List<MediaItem> media) {
  return media.where((m) => m.isVideo).length;
}
