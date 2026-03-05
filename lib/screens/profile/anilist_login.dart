import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:go_router/go_router.dart';
import 'package:namizo/core/config.dart';
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
  bool _isPreparingLogin = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _prepareLoginSession();
  }

  Future<void> _prepareLoginSession() async {
    try {
      // Start login in a clean WebView cookie context so users can pick account.
      await _cookieManager.deleteAllCookies();
    } catch (_) {
      // Continue even if cookie clearing fails on some platforms.
    }

    if (!mounted) return;
    setState(() => _isPreparingLogin = false);
  }

  Uri get _authorizationUri {
    final queryParameters = <String, String>{
      'client_id': AppConfigurations.anilistOauthClientId,
      'response_type': 'token',
    };

    final redirectUri = AppConfigurations.anilistOauthRedirectUri.trim();
    if (redirectUri.isNotEmpty) {
      queryParameters['redirect_uri'] = redirectUri;
    }

    return Uri.parse(AppConfigurations.anilistOauthAuthorizeUrl).replace(
      queryParameters: queryParameters,
    );
  }

  String? _extractAccessToken(Uri uri) {
    final fromQuery = uri.queryParameters['access_token'];
    if (fromQuery != null && fromQuery.trim().isNotEmpty) {
      return fromQuery.trim();
    }

    if (uri.fragment.isEmpty) return null;
    for (final segment in uri.fragment.split('&')) {
      final pair = segment.split('=');
      if (pair.length != 2) continue;
      if (pair.first != 'access_token') continue;

      final token = Uri.decodeComponent(pair.last).trim();
      if (token.isNotEmpty) return token;
    }

    return null;
  }

  Future<void> _tryCaptureToken(Uri? uri) async {
    if (uri == null) return;
    if (_isSaving) return;
    final accessToken = _extractAccessToken(uri);
    if (accessToken == null) return;

    setState(() => _isSaving = true);

    await _aniListService.saveAccessToken(accessToken);
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

  Future<void> _tryCaptureTokenFromString(String? rawUrl) async {
    if (rawUrl == null || rawUrl.trim().isEmpty) return;
    await _tryCaptureToken(Uri.tryParse(rawUrl));
  }

  @override
  Widget build(BuildContext context) {
    if (AppConfigurations.anilistOauthClientId.trim().isEmpty) {
      return Scaffold(
        backgroundColor: NamizoTheme.netflixBlack,
        appBar: AppBar(
          backgroundColor: NamizoTheme.netflixBlack,
          elevation: 0,
        ),
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(20),
            child: Text(
              'AniList OAuth client ID is not configured. Set --dart-define=ANILIST_CLIENT_ID=<your_client_id> and try again.',
              style: TextStyle(color: Colors.white70),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: NamizoTheme.netflixBlack,
      body: _isPreparingLogin
          ? const Center(
              child: CircularProgressIndicator(color: NamizoTheme.netflixRed),
            )
          : InAppWebView(
              initialUrlRequest: URLRequest(url: WebUri.uri(_authorizationUri)),
              onLoadStart: (controller, url) {
                _tryCaptureToken(
                  url == null ? null : Uri.tryParse(url.toString()),
                );
              },
              onLoadStop: (controller, url) async {
                await _tryCaptureToken(
                  url == null ? null : Uri.tryParse(url.toString()),
                );

                final href = await controller.evaluateJavascript(
                  source: 'window.location.href',
                );
                await _tryCaptureTokenFromString(href?.toString());
              },
              onUpdateVisitedHistory: (controller, url, _) {
                _tryCaptureToken(
                  url == null ? null : Uri.tryParse(url.toString()),
                );
              },
            ),
    );
  }
}
