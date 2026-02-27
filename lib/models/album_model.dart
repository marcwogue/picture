import 'dart:io';
import 'package:photo_manager/photo_manager.dart';

/// Generic album model that abstracts away the platform-specific representation
class AppAlbum {
  final String id;
  final String name;
  final AssetPathEntity? assetPath; // Null on Desktop
  final String? localPath; // Null on Mobile if not using direct files

  AppAlbum({
    required this.id,
    required this.name,
    this.assetPath,
    this.localPath,
  });

  /// Get total count of assets in this album
  Future<int> get assetCountAsync async {
    if (assetPath != null) {
      return await assetPath!.assetCountAsync;
    }
    if (localPath != null) {
      try {
        final dir = Directory(localPath!);
        if (!await dir.exists()) return 0;
        final files = dir.listSync(followLinks: false).whereType<File>().where((
          f,
        ) {
          final ext = f.path.toLowerCase().split('.').last;
          return [
            'jpg',
            'jpeg',
            'png',
            'webp',
            'gif',
            'mp4',
            'mov',
            'avi',
            'mkv',
          ].contains(ext);
        }).length;
        return files;
      } catch (_) {
        return 0;
      }
    }
    return 0;
  }

  bool get isLocal => localPath != null;
}
