import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:go_router/go_router.dart';
import 'package:namizo/theme/theme.dart';
import 'package:namizo/services/anilist.dart';

class AniListLoginScreen extends StatefulWidget {
  const AniListLoginScreen({super.key});

  @override
  State<AniListLoginScreen> createState() => _AniListLoginScreenState();
}

class _AniListLoginScreenState extends State<AniListLoginScreen> {
  final AniListService _aniListService = AniListService();
  final CookieManager _cookieManager = CookieManager.instance();
  bool _isSaving = false;

  Future<void> _tryCaptureSession(Uri? uri) async {
    if (uri == null) return;
    if (_isSaving) return;
    if (!uri.host.contains('anilist.co')) return;

    final cookies = await _cookieManager.getCookies(
      url: WebUri('https://anilist.co'),
    );
    if (cookies.isEmpty) return;

    final cookieHeader = cookies
        .where((cookie) => cookie.name.isNotEmpty)
        .map((cookie) => '${cookie.name}=${cookie.value}')
        .join('; ');
    if (cookieHeader.isEmpty) return;

    setState(() => _isSaving = true);

    await _aniListService.saveSessionCookie(cookieHeader);
    final viewer = await _aniListService.getViewerProfile();

    if (viewer == null) {
      if (mounted) {
        setState(() => _isSaving = false);
      }
      return;
    }

    if (!mounted) return;
    context.pop(true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: NamizoTheme.netflixBlack,
      appBar: AppBar(
        backgroundColor: NamizoTheme.netflixBlack,
        title: const Text('AniList Login'),
      ),
      body: InAppWebView(
        initialUrlRequest: URLRequest(url: WebUri('https://anilist.co/login')),
        onLoadStart: (controller, url) {
          _tryCaptureSession(url == null ? null : Uri.tryParse(url.toString()));
        },
        onLoadStop: (controller, url) async {
          await _tryCaptureSession(
            url == null ? null : Uri.tryParse(url.toString()),
          );
        },
        onUpdateVisitedHistory: (controller, url, _) {
          _tryCaptureSession(url == null ? null : Uri.tryParse(url.toString()));
        },
      ),
    );
  }
}
