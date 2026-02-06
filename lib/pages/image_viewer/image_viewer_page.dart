import 'dart:io';
import 'package:flutter/material.dart';
import '../../core/theme.dart';
import '../../models/media_item.dart';
import '../../services/media_service.dart';
import '../../widgets/action_bottom_sheet.dart';
import 'widgets/image_controls.dart';
import 'widgets/info_dialog.dart';

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
    setState(() => _currentFile = file);
  }

  void _onPageChanged(int index) {
    setState(() {
      _currentIndex = index;
      _currentFile = null;
    });
    _loadCurrentFile();
  }

  void _toggleControls() {
    setState(() => _showControls = !_showControls);
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
    InfoDialog.show(context, media: _currentMedia, file: _currentFile);
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
              itemBuilder: (_, index) =>
                  _ImageView(media: widget.mediaList[index]),
            ),
          ),

          // Controls overlay
          ImageControls(
            visible: _showControls,
            onBack: () => Navigator.pop(context),
            onInfo: _showInfo,
            onShare: _shareImage,
            onDelete: _deleteImage,
            currentIndex: _currentIndex,
            totalCount: widget.mediaList.length,
          ),
        ],
      ),
    );
  }
}

class _ImageView extends StatelessWidget {
  final MediaItem media;

  const _ImageView({required this.media});

  @override
  Widget build(BuildContext context) {
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
}
