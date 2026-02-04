import 'package:flutter/material.dart';
import 'package:photo_manager/photo_manager.dart';
import '../core/theme.dart';
import '../core/constants.dart';
import '../models/media_item.dart';
import '../services/media_service.dart';
import '../widgets/media_grid_item.dart';
import '../widgets/action_bottom_sheet.dart';
import 'image_viewer_page.dart';
import 'video_player_page.dart';

/// Gallery page showing all media from an album in a grid
class GalleryPage extends StatefulWidget {
  final AssetPathEntity? album;
  final MediaType? filterType;

  const GalleryPage({super.key, this.album, this.filterType});

  @override
  State<GalleryPage> createState() => _GalleryPageState();
}

class _GalleryPageState extends State<GalleryPage> {
  final MediaService _mediaService = MediaService();
  List<MediaItem> _media = [];
  bool _isLoading = true;
  bool _isSelectionMode = false;
  Set<String> _selectedIds = {};

  @override
  void initState() {
    super.initState();
    _loadMedia();
  }

  Future<void> _loadMedia() async {
    setState(() {
      _isLoading = true;
    });

    try {
      List<MediaItem> media;
      if (widget.album != null) {
        media = await _mediaService.getMediaFromAlbum(
          widget.album!,
          pageSize: 500,
        );
      } else if (widget.filterType == MediaType.image) {
        media = await _mediaService.getAllImages(pageSize: 100);
      } else if (widget.filterType == MediaType.video) {
        media = await _mediaService.getAllVideos(pageSize: 100);
      } else {
        media = await _mediaService.getRecentMedia(count: 100);
      }

      setState(() {
        _media = media;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _toggleSelection(MediaItem media) {
    setState(() {
      if (_selectedIds.contains(media.id)) {
        _selectedIds.remove(media.id);
        if (_selectedIds.isEmpty) {
          _isSelectionMode = false;
        }
      } else {
        _selectedIds.add(media.id);
      }
    });
  }

  void _enableSelectionMode(MediaItem media) {
    setState(() {
      _isSelectionMode = true;
      _selectedIds.add(media.id);
    });
  }

  void _cancelSelection() {
    setState(() {
      _isSelectionMode = false;
      _selectedIds.clear();
    });
  }

  void _selectAll() {
    setState(() {
      _selectedIds = _media.map((m) => m.id).toSet();
    });
  }

  List<MediaItem> get _selectedMedia {
    return _media.where((m) => _selectedIds.contains(m.id)).toList();
  }

  Future<void> _shareSelected() async {
    if (_selectedMedia.isEmpty) return;
    await _mediaService.shareMedia(_selectedMedia);
    _cancelSelection();
  }

  Future<void> _deleteSelected() async {
    if (_selectedMedia.isEmpty) return;

    DeleteConfirmationDialog.show(
      context,
      itemCount: _selectedMedia.length,
      onConfirm: () async {
        final success = await _mediaService.deleteMedia(_selectedMedia);
        if (success) {
          setState(() {
            _media.removeWhere((m) => _selectedIds.contains(m.id));
          });
          _cancelSelection();
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Fichiers supprimés'),
                backgroundColor: AppColors.success,
              ),
            );
          }
        }
      },
    );
  }

  void _openMedia(MediaItem media) {
    if (_isSelectionMode) {
      _toggleSelection(media);
      return;
    }

    if (media.isVideo) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => VideoPlayerPage(media: media)),
      );
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ImageViewerPage(
            media: media,
            mediaList: _media.where((m) => m.isImage).toList(),
          ),
        ),
      );
    }
  }

  String get _title {
    if (widget.album != null) {
      return widget.album!.name.isEmpty ? 'Album' : widget.album!.name;
    }
    switch (widget.filterType) {
      case MediaType.image:
        return 'Photos';
      case MediaType.video:
        return 'Vidéos';
      default:
        return 'Galerie';
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark
          ? AppColors.darkBackground
          : AppColors.lightBackground,
      appBar: _buildAppBar(isDark),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: AppColors.primary))
          : _media.isEmpty
          ? _buildEmptyState(isDark)
          : _buildGrid(),
      bottomNavigationBar: _isSelectionMode ? _buildSelectionBar(isDark) : null,
    );
  }

  PreferredSizeWidget _buildAppBar(bool isDark) {
    if (_isSelectionMode) {
      return AppBar(
        backgroundColor: isDark
            ? AppColors.darkSurface
            : AppColors.lightSurface,
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: _cancelSelection,
        ),
        title: Text(
          '${_selectedIds.length} sélectionné(s)',
          style: TextStyle(
            color: isDark
                ? AppColors.darkTextPrimary
                : AppColors.lightTextPrimary,
          ),
        ),
        actions: [
          TextButton(
            onPressed: _selectAll,
            child: const Text(
              'Tout sélectionner',
              style: TextStyle(color: AppColors.primary),
            ),
          ),
        ],
      );
    }

    return AppBar(
      backgroundColor: Colors.transparent,
      leading: IconButton(
        icon: Icon(
          Icons.arrow_back,
          color: isDark
              ? AppColors.darkTextPrimary
              : AppColors.lightTextPrimary,
        ),
        onPressed: () => Navigator.pop(context),
      ),
      title: Text(
        _title,
        style: TextStyle(
          color: isDark
              ? AppColors.darkTextPrimary
              : AppColors.lightTextPrimary,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildEmptyState(bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.photo_library_outlined,
            size: 64,
            color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
          ),
          const SizedBox(height: 16),
          Text(
            'Aucun fichier trouvé',
            style: TextStyle(
              color: isDark
                  ? AppColors.darkTextSecondary
                  : AppColors.lightTextSecondary,
              fontSize: 18,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGrid() {
    return RefreshIndicator(
      onRefresh: _loadMedia,
      color: AppColors.primary,
      child: GridView.builder(
        padding: const EdgeInsets.all(AppConstants.gridSpacing),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: AppConstants.gridCrossAxisCount,
          mainAxisSpacing: AppConstants.gridSpacing,
          crossAxisSpacing: AppConstants.gridSpacing,
        ),
        itemCount: _media.length,
        itemBuilder: (context, index) {
          final media = _media[index];
          return MediaGridItem(
            media: media,
            isSelected: _selectedIds.contains(media.id),
            onTap: () => _openMedia(media),
            onLongPress: () => _enableSelectionMode(media),
          );
        },
      ),
    );
  }

  Widget _buildSelectionBar(bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppConstants.paddingMedium,
        vertical: AppConstants.paddingSmall,
      ),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
        border: Border(
          top: BorderSide(
            color: isDark
                ? AppColors.darkSurfaceLight
                : AppColors.lightSurfaceLight,
          ),
        ),
      ),
      child: SafeArea(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildActionButton(
              icon: Icons.share,
              label: 'Partager',
              onTap: _shareSelected,
              isDark: isDark,
            ),
            _buildActionButton(
              icon: Icons.delete,
              label: 'Supprimer',
              onTap: _deleteSelected,
              color: AppColors.error,
              isDark: isDark,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    required bool isDark,
    Color? color,
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color:
                  color ??
                  (isDark
                      ? AppColors.darkTextPrimary
                      : AppColors.lightTextPrimary),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color:
                    color ??
                    (isDark
                        ? AppColors.darkTextSecondary
                        : AppColors.lightTextSecondary),
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
