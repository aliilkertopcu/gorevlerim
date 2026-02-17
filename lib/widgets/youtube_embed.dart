import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

// Conditional import for web platform
import 'youtube_embed_web.dart' if (dart.library.io) 'youtube_embed_stub.dart'
    as platform;

class YouTubeEmbed extends StatelessWidget {
  final String videoId;

  const YouTubeEmbed({super.key, required this.videoId});

  @override
  Widget build(BuildContext context) {
    if (kIsWeb) {
      return platform.buildWebEmbed(videoId);
    }

    // Mobile: thumbnail + play button
    return GestureDetector(
      onTap: () => _openYouTube(),
      child: AspectRatio(
        aspectRatio: 16 / 9,
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Thumbnail
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                image: DecorationImage(
                  image: NetworkImage(
                    'https://img.youtube.com/vi/$videoId/maxresdefault.jpg',
                  ),
                  fit: BoxFit.cover,
                ),
              ),
            ),
            // Dark overlay
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: Colors.black.withValues(alpha: 0.3),
              ),
            ),
            // Play button
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: Colors.red,
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(
                Icons.play_arrow,
                color: Colors.white,
                size: 40,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openYouTube() async {
    final url = Uri.parse('https://www.youtube.com/watch?v=$videoId');
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
  }
}
