import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../core/theme.dart';
import '../core/constants.dart';
import '../models/media_item.dart';
import '../services/media_service.dart';
import '../widgets/action_bottom_sheet.dart';

/// Full-screen image viewer with zoom and swipe
class ImageViewerPage extends StatefulWidget {
  final MediaItem media;
  final List<MediaItem> mediaList;

  const ImageViewerPage({
    super.key,
    required this.media,
    required this.mediaList,
  });

  @override
  State<ImageViewerPage> createState() => _ImageViewerPageState();
}

class _ImageViewerPageState extends State<ImageViewerPage> {
  final MediaService _mediaService = MediaService();
  late PageController _pageController;
  late int _currentIndex;
  bool _showControls = true;
  File? _currentFile;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.mediaList.indexWhere((m) => m.id == widget.media.id);
    if (_currentIndex == -1) _currentIndex = 0;
    _pageController = PageController(initialPage: _currentIndex);
    _loadCurrentFile();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _loadCurrentFile() async {
    final file = await widget.mediaList[_currentIndex].getFile();
    setState(() {
      _currentFile = file;
    });
  }

  void _onPageChanged(int index) {
    setState(() {
      _currentIndex = index;
      _currentFile = null;
    });
    _loadCurrentFile();
  }

  void _toggleControls() {
    setState(() {
      _showControls = !_showControls;
    });
  }

  MediaItem get _currentMedia => widget.mediaList[_currentIndex];

  Future<void> _shareImage() async {
    await _mediaService.shareSingleMedia(_currentMedia);
  }

  Future<void> _deleteImage() async {
    DeleteConfirmationDialog.show(
      context,
      itemCount: 1,
      onConfirm: () async {
        final success = await _mediaService.deleteMedia([_currentMedia]);
        if (success && mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Image supprimée'),
              backgroundColor: AppColors.success,
            ),
          );
        }
      },
    );
  }

  void _showInfo() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDark
            ? AppColors.darkSurface
            : AppColors.lightSurface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppConstants.radiusLarge),
        ),
        title: Text(
          'Informations',
          style: TextStyle(
            color: isDark
                ? AppColors.darkTextPrimary
                : AppColors.lightTextPrimary,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildInfoRow(
              'Date',
              DateFormat('dd/MM/yyyy à HH:mm').format(_currentMedia.createdAt),
              isDark,
            ),
            _buildInfoRow(
              'Dimensions',
              '${_currentMedia.width} × ${_currentMedia.height}',
              isDark,
            ),
            if (_currentFile != null)
              _buildInfoRow(
                'Taille',
                _formatFileSize(_currentFile!.lengthSync()),
                isDark,
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Fermer',
              style: TextStyle(color: AppColors.primary),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$label: ',
            style: TextStyle(
              color: isDark
                  ? AppColors.darkTextSecondary
                  : AppColors.lightTextSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                color: isDark
                    ? AppColors.darkTextPrimary
                    : AppColors.lightTextPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Image viewer with swipe
          GestureDetector(
            onTap: _toggleControls,
            child: PageView.builder(
              controller: _pageController,
              onPageChanged: _onPageChanged,
              itemCount: widget.mediaList.length,
              itemBuilder: (context, index) {
                return _buildImageView(widget.mediaList[index]);
              },
            ),
          ),

          // Top bar
          AnimatedOpacity(
            opacity: _showControls ? 1.0 : 0.0,
            duration: AppConstants.animationFast,
            child: Container(
              padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.7),
                    Colors.transparent,
                  ],
                ),
              ),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.info_outline, color: Colors.white),
                    onPressed: _showInfo,
                  ),
                ],
              ),
            ),
          ),

          // Bottom bar with actions
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: AnimatedOpacity(
              opacity: _showControls ? 1.0 : 0.0,
              duration: AppConstants.animationFast,
              child: Container(
                padding: EdgeInsets.only(
                  bottom: MediaQuery.of(context).padding.bottom + 16,
                  top: 16,
                ),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.7),
                      Colors.transparent,
                    ],
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildActionIcon(Icons.share, 'Partager', _shareImage),
                    _buildActionIcon(Icons.delete, 'Supprimer', _deleteImage),
                  ],
                ),
              ),
            ),
          ),

          // Page indicator
          if (widget.mediaList.length > 1)
            Positioned(
              bottom: MediaQuery.of(context).padding.bottom + 80,
              left: 0,
              right: 0,
              child: AnimatedOpacity(
                opacity: _showControls ? 1.0 : 0.0,
                duration: AppConstants.animationFast,
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '${_currentIndex + 1} / ${widget.mediaList.length}',
                      style: const TextStyle(color: Colors.white, fontSize: 14),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildImageView(MediaItem media) {
    return FutureBuilder<File?>(
      future: media.getFile(),
      builder: (context, snapshot) {
        if (snapshot.hasData && snapshot.data != null) {
          return InteractiveViewer(
            minScale: 1.0,
            maxScale: 4.0,
            child: Center(
              child: Image.file(snapshot.data!, fit: BoxFit.contain),
            ),
          );
        }
        return const Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        );
      },
    );
  }

  Widget _buildActionIcon(IconData icon, String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 28),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(color: Colors.white70, fontSize: 12),
          ),
        ],
      ),
    );
  }
}
