import 'package:flutter/material.dart';
import 'package:photo_manager/photo_manager.dart';
import '../../core/theme.dart';
import '../../models/media_item.dart';
import '../../services/media_service.dart';
import '../../shared/widgets/empty_state.dart';
import '../../shared/widgets/loading_indicator.dart';
import '../image_viewer/image_viewer_page.dart';
import '../video_player/video_player_page.dart';
import '../../widgets/action_bottom_sheet.dart';
import 'widgets/statistics_banner.dart';
import 'widgets/grouped_media_list.dart';
import 'widgets/selection_bar.dart';
import 'utils/date_grouping.dart';

/// Gallery page showing all media from an album in a grid
class GalleryPage extends StatefulWidget {
  final AssetPathEntity? album;
  final MediaType? filterType;
  final List<MediaItem>? initialMedia;
  final String? albumName;
  final int? totalMediaCount;

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
    if (widget.initialMedia != null && widget.initialMedia!.isNotEmpty) {
      setState(() {
        _media = List.from(widget.initialMedia!);
        _totalMediaCount =
            widget.totalMediaCount ?? widget.initialMedia!.length;
        _isLoading = false;
      });
      return;
    }

    setState(() => _isLoading = true);

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
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadMoreMedia() async {
    if (_isLoadingMore || !_hasMoreMedia) return;

    setState(() => _isLoadingMore = true);

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
      setState(() => _isLoadingMore = false);
    }
  }

  bool get _hasMoreMedia => _media.length < _totalMediaCount;

  void _toggleSelection(MediaItem media) {
    setState(() {
      if (_selectedIds.contains(media.id)) {
        _selectedIds.remove(media.id);
        if (_selectedIds.isEmpty) _isSelectionMode = false;
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
        MaterialPageRoute(builder: (_) => VideoPlayerPage(media: media)),
      );
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ImageViewerPage(
            media: media,
            mediaList: _media.where((m) => m.isImage).toList(),
          ),
        ),
      );
    }
  }

  String get _title {
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
      body: _buildBody(),
      bottomNavigationBar: _isSelectionMode
          ? SelectionBar(onShare: _shareSelected, onDelete: _deleteSelected)
          : null,
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

  Widget _buildBody() {
    if (_isLoading) {
      return const LoadingIndicator();
    }

    if (_media.isEmpty) {
      return const EmptyState(
        icon: Icons.photo_library_outlined,
        message: 'Aucun fichier trouvé',
      );
    }

    return Column(
      children: [
        StatisticsBanner(
          totalCount: _media.length,
          imageCount: getImageCount(_media),
          videoCount: getVideoCount(_media),
        ),
        Expanded(
          child: GroupedMediaList(
            media: _media,
            selectedIds: _selectedIds,
            hasMoreMedia: _hasMoreMedia,
            isLoadingMore: _isLoadingMore,
            totalMediaCount: _totalMediaCount,
            onRefresh: _loadMedia,
            onLoadMore: _loadMoreMedia,
            onMediaTap: _openMedia,
            onMediaLongPress: _enableSelectionMode,
          ),
        ),
      ],
    );
  }
}
