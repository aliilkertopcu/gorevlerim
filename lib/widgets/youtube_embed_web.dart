import 'dart:ui_web' as ui_web;
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:web/web.dart' as web;

final Set<String> _registeredViewTypes = {};

bool get _isSafari {
  final ua = web.window.navigator.userAgent.toLowerCase();
  return ua.contains('safari') && !ua.contains('chrome') && !ua.contains('chromium');
}

Widget buildWebEmbed(String videoId) {
  // Safari has issues rendering HtmlElementView inside scrollable containers,
  // causing the entire page content to disappear. Use thumbnail fallback.
  if (_isSafari) {
    return _buildThumbnailFallback(videoId);
  }

  final viewType = 'youtube-$videoId';

  if (!_registeredViewTypes.contains(viewType)) {
    ui_web.platformViewRegistry.registerViewFactory(viewType, (int viewId) {
      final iframe =
          web.document.createElement('iframe') as web.HTMLIFrameElement;
      iframe.src = 'https://www.youtube.com/embed/$videoId';
      iframe.style.border = 'none';
      iframe.style.width = '100%';
      iframe.style.height = '100%';
      iframe.style.borderRadius = '12px';
      iframe.allow =
          'accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture';
      iframe.allowFullscreen = true;
      return iframe;
    });
    _registeredViewTypes.add(viewType);
  }

  return AspectRatio(
    aspectRatio: 16 / 9,
    child: ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: HtmlElementView(viewType: viewType),
    ),
  );
}

Widget _buildThumbnailFallback(String videoId) {
  return GestureDetector(
    onTap: () => launchUrl(
      Uri.parse('https://www.youtube.com/watch?v=$videoId'),
      mode: LaunchMode.externalApplication,
    ),
    child: AspectRatio(
      aspectRatio: 16 / 9,
      child: Stack(
        alignment: Alignment.center,
        children: [
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
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: Colors.black.withValues(alpha: 0.3),
            ),
          ),
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
