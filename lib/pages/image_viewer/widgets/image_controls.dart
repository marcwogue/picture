import 'package:flutter/material.dart';
import '../../../core/constants.dart';

/// Overlay controls for image viewer (top and bottom bars)
class ImageControls extends StatelessWidget {
  final bool visible;
  final VoidCallback onBack;
  final VoidCallback onInfo;
  final VoidCallback onShare;
  final VoidCallback onDelete;
  final int currentIndex;
  final int totalCount;

  const ImageControls({
    super.key,
    required this.visible,
    required this.onBack,
    required this.onInfo,
    required this.onShare,
    required this.onDelete,
    required this.currentIndex,
    required this.totalCount,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Top bar
        AnimatedOpacity(
          opacity: visible ? 1.0 : 0.0,
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
                  onPressed: visible ? onBack : null,
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.info_outline, color: Colors.white),
                  onPressed: visible ? onInfo : null,
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
            opacity: visible ? 1.0 : 0.0,
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
                  _ActionIcon(
                    icon: Icons.share,
                    label: 'Partager',
                    onTap: visible ? onShare : null,
                  ),
                  _ActionIcon(
                    icon: Icons.delete,
                    label: 'Supprimer',
                    onTap: visible ? onDelete : null,
                  ),
                ],
              ),
            ),
          ),
        ),

        // Page indicator
        if (totalCount > 1)
          Positioned(
            bottom: MediaQuery.of(context).padding.bottom + 80,
            left: 0,
            right: 0,
            child: AnimatedOpacity(
              opacity: visible ? 1.0 : 0.0,
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
                    '${currentIndex + 1} / $totalCount',
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _ActionIcon extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  const _ActionIcon({required this.icon, required this.label, this.onTap});

  @override
  Widget build(BuildContext context) {
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
