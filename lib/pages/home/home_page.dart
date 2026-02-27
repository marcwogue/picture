import 'package:flutter/material.dart';
import '../../core/theme.dart';
import '../../core/theme_provider.dart';
import '../../core/constants.dart';
import '../../services/media_service.dart';
import '../../models/album_model.dart';
import '../../widgets/album_card.dart';
import '../../shared/widgets/empty_state.dart';
import '../../shared/widgets/loading_indicator.dart';
import '../gallery/gallery_page.dart';
import 'widgets/permission_request.dart';

/// Home page showing albums organized by folders
class HomePage extends StatefulWidget {
  final ThemeProvider themeProvider;

  const HomePage({super.key, required this.themeProvider});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final MediaService _mediaService = MediaService();
  List<AppAlbum> _albums = [];
  bool _isLoading = true;
  bool _hasPermission = false;

  @override
  void initState() {
    super.initState();
    _initializeMedia();
  }

  Future<void> _initializeMedia() async {
    final hasPermission = await _mediaService.requestPermission();
    setState(() => _hasPermission = hasPermission);

    if (hasPermission) {
      await _loadAlbums();
    } else {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadAlbums() async {
    setState(() => _isLoading = true);

    try {
      final albums = await _mediaService.loadAlbums();
      final nonEmptyAlbums = <AppAlbum>[];

      for (final album in albums) {
        final count = await album.assetCountAsync;
        if (count > 0) nonEmptyAlbums.add(album);
      }

      setState(() {
        _albums = nonEmptyAlbums;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  void _openAlbum(AppAlbum album) {
    final albumName = album.name.isEmpty ? 'Album' : album.name;

    debugPrint('DEBUG: Navigating to GalleryPage for album: "$albumName"');

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => GalleryPage(album: album, albumName: albumName),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark
          ? AppColors.darkBackground
          : AppColors.lightBackground,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: Text(
          'Galerie',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: isDark
                ? AppColors.darkTextPrimary
                : AppColors.lightTextPrimary,
          ),
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 8),
            decoration: BoxDecoration(
              color: isDark
                  ? AppColors.darkSurfaceLight
                  : AppColors.lightSurfaceLight,
              borderRadius: BorderRadius.circular(12),
            ),
            child: IconButton(
              icon: Icon(
                isDark ? Icons.light_mode : Icons.dark_mode,
                color: isDark
                    ? AppColors.darkTextPrimary
                    : AppColors.lightTextPrimary,
              ),
              onPressed: widget.themeProvider.toggleTheme,
            ),
          ),
        ],
      ),
      body: SafeArea(child: _buildBody()),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const LoadingIndicator(message: 'Chargement des albums...');
    }

    if (!_hasPermission) {
      return PermissionRequest(onRequestPermission: _initializeMedia);
    }

    if (_albums.isEmpty) {
      return EmptyState(
        icon: Icons.photo_library_outlined,
        message: 'Aucun album trouvé',
        action: ElevatedButton.icon(
          onPressed: _loadAlbums,
          icon: const Icon(Icons.refresh),
          label: const Text('Actualiser'),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadAlbums,
      color: AppColors.primary,
      child: GridView.builder(
        padding: const EdgeInsets.all(AppConstants.paddingMedium),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisSpacing: 16,
          crossAxisSpacing: 16,
          childAspectRatio: 0.85,
        ),
        itemCount: _albums.length,
        itemBuilder: (context, index) {
          final album = _albums[index];
          return AlbumCard(album: album, onTap: () => _openAlbum(album));
        },
      ),
    );
  }
}
