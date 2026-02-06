import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:share_plus/share_plus.dart';
import '../models/media_item.dart';

/// Service for managing media files (images and videos)
class MediaService {
  static final MediaService _instance = MediaService._internal();
  factory MediaService() => _instance;
  MediaService._internal();

  List<AssetPathEntity> _albums = [];
  bool _hasPermission = false;

  /// Check and request permissions based on platform
  Future<bool> requestPermission() async {
    if (Platform.isAndroid || Platform.isIOS) {
      // Mobile platforms - use photo_manager permissions
      final PermissionState result =
          await PhotoManager.requestPermissionExtend();
      _hasPermission = result.isAuth;
      return _hasPermission;
    } else if (Platform.isLinux || Platform.isWindows || Platform.isMacOS) {
      // Desktop platforms - check storage permission or use file picker
      // On desktop, we typically have file system access
      _hasPermission = true;
      return true;
    }
    return false;
  }

  /// Check if we have permission
  bool get hasPermission => _hasPermission;

  /// Load all albums
  Future<List<AssetPathEntity>> loadAlbums({
    RequestType type = RequestType.common,
  }) async {
    if (!_hasPermission) {
      final granted = await requestPermission();
      if (!granted) return [];
    }

    try {
      _albums = await PhotoManager.getAssetPathList(
        type: type,
        hasAll: true,
        onlyAll: false,
      );
      return _albums;
    } catch (e) {
      debugPrint('Error loading albums: $e');
      return [];
    }
  }

  /// Get recent media items
  Future<List<MediaItem>> getRecentMedia({int count = 20}) async {
    if (!_hasPermission) {
      final granted = await requestPermission();
      if (!granted) return [];
    }

    try {
      // Get the "Recent" or "All" album
      final albums = await loadAlbums();
      if (albums.isEmpty) return [];

      // Usually the first album is "Recent" or "All Photos"
      final recentAlbum = albums.first;
      final assets = await recentAlbum.getAssetListRange(start: 0, end: count);

      return assets.map((asset) => MediaItem.fromAsset(asset)).toList();
    } catch (e) {
      debugPrint('Error getting recent media: $e');
      return [];
    }
  }

  /// Get media from a specific album
  Future<List<MediaItem>> getMediaFromAlbum(
    AssetPathEntity album, {
    int page = 0,
    int pageSize = 50,
  }) async {
    try {
      debugPrint(
        'DEBUG MediaService: Getting media from album "${album.name}", page: $page, pageSize: $pageSize',
      );
      final assets = await album.getAssetListPaged(page: page, size: pageSize);
      debugPrint(
        'DEBUG MediaService: Got ${assets.length} assets from getAssetListPaged',
      );
      final mediaItems = assets
          .map((asset) => MediaItem.fromAsset(asset))
          .toList();
      debugPrint(
        'DEBUG MediaService: Converted to ${mediaItems.length} MediaItem objects',
      );
      return mediaItems;
    } catch (e) {
      debugPrint('Error getting media from album: $e');
      return [];
    }
  }

  /// Get media from a specific album with range (start/end)
  Future<List<MediaItem>> getMediaFromAlbumRange(
    AssetPathEntity album, {
    required int start,
    required int end,
  }) async {
    try {
      final assets = await album.getAssetListRange(start: start, end: end);
      return assets.map((asset) => MediaItem.fromAsset(asset)).toList();
    } catch (e) {
      debugPrint('Error getting media from album range: $e');
      return [];
    }
  }

  /// Get all images
  Future<List<MediaItem>> getAllImages({
    int page = 0,
    int pageSize = 50,
  }) async {
    if (!_hasPermission) {
      final granted = await requestPermission();
      if (!granted) return [];
    }

    final albums = await loadAlbums(type: RequestType.image);
    if (albums.isEmpty) return [];

    final album = albums.first;
    final start = page * pageSize;
    final assets = await album.getAssetListRange(
      start: start,
      end: start + pageSize,
    );

    return assets.map((asset) => MediaItem.fromAsset(asset)).toList();
  }

  /// Get all videos
  Future<List<MediaItem>> getAllVideos({
    int page = 0,
    int pageSize = 50,
  }) async {
    if (!_hasPermission) {
      final granted = await requestPermission();
      if (!granted) return [];
    }

    final albums = await loadAlbums(type: RequestType.video);
    if (albums.isEmpty) return [];

    final album = albums.first;
    final start = page * pageSize;
    final assets = await album.getAssetListRange(
      start: start,
      end: start + pageSize,
    );

    return assets.map((asset) => MediaItem.fromAsset(asset)).toList();
  }

  /// Delete media items
  Future<bool> deleteMedia(List<MediaItem> items) async {
    try {
      final ids = items.map((item) => item.id).toList();
      final result = await PhotoManager.editor.deleteWithIds(ids);
      return result.isNotEmpty;
    } catch (e) {
      debugPrint('Error deleting media: $e');
      return false;
    }
  }

  /// Share media items
  Future<void> shareMedia(List<MediaItem> items) async {
    try {
      final files = <XFile>[];

      for (final item in items) {
        final file = await item.getFile();
        if (file != null) {
          files.add(XFile(file.path));
        }
      }

      if (files.isNotEmpty) {
        await Share.shareXFiles(files);
      }
    } catch (e) {
      debugPrint('Error sharing media: $e');
    }
  }

  /// Share a single media item
  Future<void> shareSingleMedia(MediaItem item) async {
    await shareMedia([item]);
  }

  /// Get total count of media in an album
  Future<int> getMediaCount({RequestType type = RequestType.common}) async {
    final albums = await loadAlbums(type: type);
    if (albums.isEmpty) return 0;
    return await albums.first.assetCountAsync;
  }

  /// Search media by date range
  Future<List<MediaItem>> getMediaByDateRange({
    required DateTime start,
    required DateTime end,
    RequestType type = RequestType.common,
  }) async {
    try {
      final albums = await loadAlbums(type: type);
      if (albums.isEmpty) return [];

      final album = albums.first;
      final count = await album.assetCountAsync;
      final assets = await album.getAssetListRange(start: 0, end: count);

      return assets
          .where(
            (asset) =>
                asset.createDateTime.isAfter(start) &&
                asset.createDateTime.isBefore(end),
          )
          .map((asset) => MediaItem.fromAsset(asset))
          .toList();
    } catch (e) {
      debugPrint('Error getting media by date range: $e');
      return [];
    }
  }

  /// Get media modified today
  Future<List<MediaItem>> getTodayMedia() async {
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));

    return getMediaByDateRange(start: startOfDay, end: endOfDay);
  }

  /// Get media from last 7 days
  Future<List<MediaItem>> getLastWeekMedia() async {
    final now = DateTime.now();
    final startOfWeek = now.subtract(const Duration(days: 7));

    return getMediaByDateRange(start: startOfWeek, end: now);
  }
}
