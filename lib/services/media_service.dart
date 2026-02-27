import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:share_plus/share_plus.dart';
import '../models/media_item.dart';
import '../models/album_model.dart';

/// Service for managing media files (images and videos)
class MediaService {
  static final MediaService _instance = MediaService._internal();
  factory MediaService() => _instance;
  MediaService._internal();

  List<AppAlbum> _albums = [];
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
  Future<List<AppAlbum>> loadAlbums({
    RequestType type = RequestType.common,
  }) async {
    if (!_hasPermission) {
      final granted = await requestPermission();
      if (!granted) return [];
    }

    try {
      if (Platform.isLinux || Platform.isWindows) {
        return await _loadDesktopAlbums();
      }

      final List<AssetPathEntity> photoAlbums =
          await PhotoManager.getAssetPathList(
            type: type,
            hasAll: true,
            onlyAll: false,
          );

      _albums = photoAlbums
          .map(
            (album) =>
                AppAlbum(id: album.id, name: album.name, assetPath: album),
          )
          .toList();

      return _albums;
    } catch (e) {
      debugPrint('Error loading albums: $e');
      return [];
    }
  }

  Future<List<AppAlbum>> _loadDesktopAlbums() async {
    final List<AppAlbum> desktopAlbums = [];

    // Add standard Linux/Windows folders
    final directories = <String, String>{};

    try {
      // For desktop, usually we want standard paths. path_provider has some, but we can also use env or home
      final home =
          Platform.environment['HOME'] ?? Platform.environment['USERPROFILE'];

      if (home != null) {
        directories['Images'] = '$home/Pictures';
        directories['Vidéos'] = '$home/Videos';
        directories['Téléchargements'] = '$home/Downloads';
      }
    } catch (e) {
      debugPrint('Error getting directories: $e');
    }

    for (var entry in directories.entries) {
      final dir = Directory(entry.value);
      if (await dir.exists()) {
        desktopAlbums.add(
          AppAlbum(id: entry.value, name: entry.key, localPath: entry.value),
        );
      }
    }

    _albums = desktopAlbums;
    return desktopAlbums;
  }

  /// Get recent media items
  Future<List<MediaItem>> getRecentMedia({int count = 20}) async {
    if (!_hasPermission) {
      final granted = await requestPermission();
      if (!granted) return [];
    }

    try {
      final albums = await loadAlbums();
      if (albums.isEmpty) return [];

      final firstAlbum = albums.first;
      return await getMediaFromAlbum(firstAlbum, pageSize: count);
    } catch (e) {
      debugPrint('Error getting recent media: $e');
      return [];
    }
  }

  /// Get media from a specific album
  Future<List<MediaItem>> getMediaFromAlbum(
    AppAlbum album, {
    int page = 0,
    int pageSize = 50,
  }) async {
    try {
      if (album.isLocal) {
        return await _getMediaFromLocalDirectory(album.localPath!);
      }

      final totalCount = await album.assetPath!.assetCountAsync;
      debugPrint(
        'DEBUG MediaService: Getting media from album "${album.name}", page: $page, pageSize: $pageSize, totalCount: $totalCount',
      );

      var assets = await album.assetPath!.getAssetListPaged(
        page: page,
        size: pageSize,
      );
      debugPrint(
        'DEBUG MediaService: Got ${assets.length} assets from getAssetListPaged',
      );

      // Robustness fallback: if we got 0 assets but totalCount > 0 and we are on page 0
      if (assets.isEmpty && totalCount > 0 && page == 0) {
        debugPrint(
          'DEBUG MediaService: Fallback triggered using getAssetListRange',
        );
        assets = await album.assetPath!.getAssetListRange(
          start: 0,
          end: totalCount < pageSize ? totalCount : pageSize,
        );
        debugPrint('DEBUG MediaService: Fallback got ${assets.length} assets');
      }

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

  Future<List<MediaItem>> _getMediaFromLocalDirectory(String path) async {
    final dir = Directory(path);
    if (!await dir.exists()) return [];

    final List<MediaItem> items = [];
    final files = dir.listSync();

    for (var file in files) {
      if (file is File) {
        final ext = file.path.toLowerCase().split('.').last;
        if (['jpg', 'jpeg', 'png', 'webp', 'gif'].contains(ext)) {
          items.add(MediaItem.fromFile(file, MediaType.image));
        } else if (['mp4', 'mov', 'avi', 'mkv'].contains(ext)) {
          items.add(MediaItem.fromFile(file, MediaType.video));
        }
      }
    }

    // Sort by date descending
    items.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return items;
  }

  /// Get media from a specific album with range (start/end)
  Future<List<MediaItem>> getMediaFromAlbumRange(
    AppAlbum album, {
    required int start,
    required int end,
  }) async {
    try {
      if (album.isLocal) {
        final all = await _getMediaFromLocalDirectory(album.localPath!);
        if (start >= all.length) return [];
        return all.sublist(start, end > all.length ? all.length : end);
      }
      final assets = await album.assetPath!.getAssetListRange(
        start: start,
        end: end,
      );
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

    if (Platform.isLinux || Platform.isWindows) {
      final albums = await loadAlbums();
      final List<MediaItem> allImages = [];
      for (var album in albums) {
        final media = await getMediaFromAlbum(album);
        allImages.addAll(media.where((m) => m.type == MediaType.image));
      }
      return allImages;
    }

    final List<AssetPathEntity> albums = await PhotoManager.getAssetPathList(
      type: RequestType.image,
    );
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

    if (Platform.isLinux || Platform.isWindows) {
      final albums = await loadAlbums();
      final List<MediaItem> allVideos = [];
      for (var album in albums) {
        final media = await getMediaFromAlbum(album);
        allVideos.addAll(media.where((m) => m.type == MediaType.video));
      }
      return allVideos;
    }

    final List<AssetPathEntity> albums = await PhotoManager.getAssetPathList(
      type: RequestType.video,
    );
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

      List<MediaItem> allMedia;
      if (album.isLocal) {
        allMedia = await _getMediaFromLocalDirectory(album.localPath!);
      } else {
        final count = await album.assetPath!.assetCountAsync;
        final assets = await album.assetPath!.getAssetListRange(
          start: 0,
          end: count,
        );
        allMedia = assets.map((asset) => MediaItem.fromAsset(asset)).toList();
      }

      return allMedia
          .where(
            (item) =>
                item.createdAt.isAfter(start) && item.createdAt.isBefore(end),
          )
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
