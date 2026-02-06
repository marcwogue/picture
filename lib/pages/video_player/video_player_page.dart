import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';
import '../../core/theme.dart';
import '../../models/media_item.dart';
import '../../services/media_service.dart';
import '../../widgets/action_bottom_sheet.dart';
import 'widgets/video_controls.dart';

/// Full-screen video player with controls
class VideoPlayerPage extends StatefulWidget {
  final MediaItem media;

  const VideoPlayerPage({super.key, required this.media});

  @override
  State<VideoPlayerPage> createState() => _VideoPlayerPageState();
}

class _VideoPlayerPageState extends State<VideoPlayerPage> {
  final MediaService _mediaService = MediaService();
  VideoPlayerController? _controller;
  bool _isInitialized = false;
  bool _showControls = true;
  bool _isPlaying = false;

  @override
  void initState() {
    super.initState();
    _initializeVideo();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  @override
  void dispose() {
    _controller?.dispose();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  Future<void> _initializeVideo() async {
    final file = await widget.media.getFile();
    if (file == null) return;

    _controller = VideoPlayerController.file(file);
    await _controller!.initialize();

    _controller!.addListener(() {
      if (mounted) {
        setState(() => _isPlaying = _controller!.value.isPlaying);
      }
    });

    setState(() => _isInitialized = true);
    _controller!.play();
  }

  void _togglePlayPause() {
    if (_controller == null) return;
    if (_controller!.value.isPlaying) {
      _controller!.pause();
    } else {
      _controller!.play();
    }
  }

  void _toggleControls() {
    setState(() => _showControls = !_showControls);
  }

  void _seekTo(double value) {
    if (_controller == null) return;
    final duration = _controller!.value.duration;
    final position = Duration(
      milliseconds: (value * duration.inMilliseconds).toInt(),
    );
    _controller!.seekTo(position);
  }

  Future<void> _shareVideo() async {
    await _mediaService.shareSingleMedia(widget.media);
  }

  Future<void> _deleteVideo() async {
    DeleteConfirmationDialog.show(
      context,
      itemCount: 1,
      onConfirm: () async {
        final success = await _mediaService.deleteMedia([widget.media]);
        if (success && mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Vidéo supprimée'),
              backgroundColor: AppColors.success,
            ),
          );
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Video player
          if (_isInitialized && _controller != null)
            GestureDetector(
              onTap: _toggleControls,
              child: Center(
                child: AspectRatio(
                  aspectRatio: _controller!.value.aspectRatio,
                  child: VideoPlayer(_controller!),
                ),
              ),
            )
          else
            const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            ),

          // Controls overlay
          if (_isInitialized && _controller != null)
            VideoControls(
              controller: _controller!,
              visible: _showControls,
              isPlaying: _isPlaying,
              onBack: () => Navigator.pop(context),
              onShare: _shareVideo,
              onDelete: _deleteVideo,
              onPlayPause: _togglePlayPause,
              onSeek: _seekTo,
            ),
        ],
      ),
    );
  }
}
