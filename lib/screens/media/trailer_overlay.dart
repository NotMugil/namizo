import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:namizo/theme/theme.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart' as yt;

/// Dialog overlay that resolves a YouTube URL to a direct stream and plays it
/// in an InAppWebView.
class TrailerOverlay extends StatefulWidget {
  final String youtubeUrl;

  const TrailerOverlay({super.key, required this.youtubeUrl});

  @override
  State<TrailerOverlay> createState() => _TrailerOverlayState();
}

class _TrailerOverlayState extends State<TrailerOverlay> {
  bool _isLoading = true;
  String? _streamUrl;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchStreamUrl();
  }

  String? _extractYoutubeVideoId(String url) {
    final regExp = RegExp(
      r'(?:youtube\.com\/watch\?v=|youtu\.be\/)([a-zA-Z0-9_-]{11})',
      caseSensitive: false,
    );
    return regExp.firstMatch(url)?.group(1);
  }

  Future<void> _fetchStreamUrl() async {
    final videoId = _extractYoutubeVideoId(widget.youtubeUrl);
    if (videoId == null) {
      if (!mounted) return;
      setState(() {
        _error = 'Invalid YouTube URL';
        _isLoading = false;
      });
      return;
    }

    try {
      final ytClient = yt.YoutubeExplode();
      final manifest =
          await ytClient.videos.streamsClient.getManifest(videoId);
      ytClient.close();

      final muxed = manifest.muxed.sortByVideoQuality();
      if (muxed.isNotEmpty) {
        if (!mounted) return;
        setState(() {
          _streamUrl = muxed.last.url.toString();
          _isLoading = false;
        });
        return;
      }

      final videoOnly = manifest.videoOnly.sortByVideoQuality();
      if (videoOnly.isNotEmpty) {
        if (!mounted) return;
        setState(() {
          _streamUrl = videoOnly.last.url.toString();
          _isLoading = false;
        });
        return;
      }

      if (!mounted) return;
      setState(() {
        _error = 'No streams available';
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Failed to load trailer';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Container(
        constraints: const BoxConstraints(maxWidth: 700, maxHeight: 450),
        decoration: BoxDecoration(
          color: Colors.black,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const AspectRatio(
          aspectRatio: 16 / 9,
          child: Center(
            child: CircularProgressIndicator(
              color: NamizoTheme.netflixRed,
              strokeWidth: 3,
            ),
          ),
        ),
      );
    }

    if (_error != null || _streamUrl == null) {
      return Container(
        constraints: const BoxConstraints(maxWidth: 700, maxHeight: 450),
        decoration: BoxDecoration(
          color: Colors.black,
          borderRadius: BorderRadius.circular(12),
        ),
        child: AspectRatio(
          aspectRatio: 16 / 9,
          child: Center(
            child: Text(
              _error ?? 'Unable to play trailer',
              style: const TextStyle(color: Colors.white70),
            ),
          ),
        ),
      );
    }

    final videoHtml = '''
<!DOCTYPE html>
<html><head>
<meta name="viewport" content="width=device-width,initial-scale=1,maximum-scale=1,user-scalable=no">
<style>*{margin:0;padding:0;background:#000}html,body{height:100%;width:100%;overflow:hidden}video{width:100%;height:100%;object-fit:contain}</style>
</head><body>
<video src="${_streamUrl!}" autoplay playsinline controls></video>
</body></html>
''';

    return Container(
      constraints: const BoxConstraints(maxWidth: 700, maxHeight: 450),
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: AspectRatio(
              aspectRatio: 16 / 9,
              child: InAppWebView(
                initialData: InAppWebViewInitialData(
                  data: videoHtml,
                  mimeType: 'text/html',
                  encoding: 'utf-8',
                ),
                initialSettings: InAppWebViewSettings(
                  mediaPlaybackRequiresUserGesture: false,
                  allowsInlineMediaPlayback: true,
                  transparentBackground: true,
                  javaScriptEnabled: true,
                ),
              ),
            ),
          ),
          Positioned(
            top: 8,
            right: 8,
            child: GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.6),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.close, color: Colors.white, size: 20),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
