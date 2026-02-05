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
  final List<MediaItem>? initialMedia; // Médias préchargés passés directement
  final String? albumName; // Nom de l'album pour l'affichage
  final int? totalMediaCount; // Nombre total de médias dans l'album

  const GalleryPage({
    super.key,
    this.album,
    this.filterType,
    this.initialMedia,
    this.albumName,
    this.totalMediaCount,
  });

  @override
  State<GalleryPage> createState() => _GalleryPageState();
}

class _GalleryPageState extends State<GalleryPage> {
  final MediaService _mediaService = MediaService();
  List<MediaItem> _media = [];
  bool _isLoading = true;
  bool _isSelectionMode = false;
  Set<String> _selectedIds = {};
  bool _isLoadingMore = false;
  int _totalMediaCount = 0;
  static const int _initialPageSize = 500;
  static const int _loadMoreSize = 100;

  @override
  void initState() {
    super.initState();
    _loadMedia();
  }

  Future<void> _loadMedia() async {
    // Si des médias préchargés sont fournis, les utiliser directement
    if (widget.initialMedia != null && widget.initialMedia!.isNotEmpty) {
      setState(() {
        _media = List.from(widget.initialMedia!);
        _totalMediaCount =
            widget.totalMediaCount ?? widget.initialMedia!.length;
        _isLoading = false;
      });
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      List<MediaItem> media;
      if (widget.album != null) {
        _totalMediaCount = await widget.album!.assetCountAsync;
        media = await _mediaService.getMediaFromAlbum(
          widget.album!,
          pageSize: _initialPageSize,
        );
      } else if (widget.filterType == MediaType.image) {
        media = await _mediaService.getAllImages(pageSize: 100);
        _totalMediaCount = media.length;
      } else if (widget.filterType == MediaType.video) {
        media = await _mediaService.getAllVideos(pageSize: 100);
        _totalMediaCount = media.length;
      } else {
        media = await _mediaService.getRecentMedia(count: 100);
        _totalMediaCount = media.length;
      }

      setState(() {
        _media = media;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading media: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  /// Charge plus de médias (pagination)
  Future<void> _loadMoreMedia() async {
    if (_isLoadingMore || !_hasMoreMedia) return;

    setState(() {
      _isLoadingMore = true;
    });

    try {
      if (widget.album != null) {
        final currentCount = _media.length;
        final moreMedia = await _mediaService.getMediaFromAlbumRange(
          widget.album!,
          start: currentCount,
          end: currentCount + _loadMoreSize,
        );

        setState(() {
          _media.addAll(moreMedia);
          _isLoadingMore = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading more media: $e');
      setState(() {
        _isLoadingMore = false;
      });
    }
  }

  /// Vérifie s'il y a plus de médias à charger
  bool get _hasMoreMedia => _media.length < _totalMediaCount;

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
    // Utiliser le nom d'album passé en paramètre si disponible
    if (widget.albumName != null && widget.albumName!.isNotEmpty) {
      return widget.albumName!;
    }
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    // +1 pour le bouton "Charger plus" si nécessaire
    final itemCount = _hasMoreMedia ? _media.length + 1 : _media.length;

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
        itemCount: itemCount,
        itemBuilder: (context, index) {
          // Dernier élément = bouton "Charger plus"
          if (_hasMoreMedia && index == _media.length) {
            return _buildLoadMoreButton(isDark);
          }

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

  Widget _buildLoadMoreButton(bool isDark) {
    final remaining = _totalMediaCount - _media.length;

    return GestureDetector(
      onTap: _isLoadingMore ? null : _loadMoreMedia,
      child: Container(
        decoration: BoxDecoration(
          color: isDark
              ? AppColors.darkSurfaceLight
              : AppColors.lightSurfaceLight,
          borderRadius: BorderRadius.circular(AppConstants.radiusSmall),
          border: Border.all(
            color: AppColors.primary.withOpacity(0.3),
            width: 2,
          ),
        ),
        child: _isLoadingMore
            ? const Center(
                child: CircularProgressIndicator(
                  color: AppColors.primary,
                  strokeWidth: 2,
                ),
              )
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.add,
                      color: AppColors.primary,
                      size: 32,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '+$remaining',
                    style: TextStyle(
                      color: isDark
                          ? AppColors.darkTextPrimary
                          : AppColors.lightTextPrimary,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  Text(
                    'Voir plus',
                    style: TextStyle(
                      color: isDark
                          ? AppColors.darkTextSecondary
                          : AppColors.lightTextSecondary,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
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
