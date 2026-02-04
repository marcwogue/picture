import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:photo_manager/photo_manager.dart';

/// Enum representing media types
enum MediaType { image, video }

/// Model class representing a media item (image or video)
class MediaItem {
  final String id;
  final AssetEntity asset;
  final MediaType type;
  final DateTime createdAt;
  final int? duration; // Duration in seconds for videos
  final int width;
  final int height;

  MediaItem({
    required this.id,
    required this.asset,
    required this.type,
    required this.createdAt,
    this.duration,
    required this.width,
    required this.height,
  });

  /// Create MediaItem from AssetEntity
  factory MediaItem.fromAsset(AssetEntity asset) {
    return MediaItem(
      id: asset.id,
      asset: asset,
      type: asset.type == AssetType.video ? MediaType.video : MediaType.image,
      createdAt: asset.createDateTime,
      duration: asset.type == AssetType.video ? asset.duration : null,
      width: asset.width,
      height: asset.height,
    );
  }

  /// Get thumbnail as bytes
  Future<Uint8List?> getThumbnail({int width = 300, int height = 300}) async {
    try {
      return await asset.thumbnailDataWithSize(
        ThumbnailSize(width, height),
        quality: 80,
      );
    } catch (e) {
      debugPrint('Error getting thumbnail: $e');
      return null;
    }
  }

  /// Get the full file
  Future<File?> getFile() async {
    return await asset.file;
  }

  /// Get file path
  Future<String?> getFilePath() async {
    final file = await getFile();
    return file?.path;
  }

  /// Check if this is a video
  bool get isVideo => type == MediaType.video;

  /// Check if this is an image
  bool get isImage => type == MediaType.image;

  /// Get formatted duration for videos (MM:SS)
  String get formattedDuration {
    if (duration == null) return '';
    final minutes = duration! ~/ 60;
    final seconds = duration! % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  /// Get aspect ratio
  double get aspectRatio => width / height;
}
