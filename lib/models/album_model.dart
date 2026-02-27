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
    // For local files, we'll need to handle this in the service or keep a count
    return 0;
  }

  bool get isLocal => localPath != null;
}
