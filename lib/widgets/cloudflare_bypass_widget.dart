import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:namizo/services/cloudflare_bypass_service.dart';

void _log(String msg) {
  debugPrint('🛡️ CloudflareBypassWidget: $msg');
}

class CloudflareBypassWidget extends ConsumerStatefulWidget {
  const CloudflareBypassWidget({super.key});

  @override
  ConsumerState<CloudflareBypassWidget> createState() => _CloudflareBypassWidgetState();
}

class _CloudflareBypassWidgetState extends ConsumerState<CloudflareBypassWidget> {
  InAppWebViewController? _controller;
  bool _isDisposed = false;

  bool _showChallengeUI = false;
  bool _mountWebView = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_isDisposed) {
        ref.read(cloudflareBypassProvider).registerWebViewController(
          controllerGetter: () => _controller,
        );
      }
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        setState(() => _mountWebView = true);
      }
    });
  }

  @override
  void dispose() {
    _isDisposed = true;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bypassState = ref.watch(cloudflareBypassProvider);

    return Stack(
      children: [
        if (_mountWebView)
          SizedBox(
            width: _showChallengeUI ? MediaQuery.of(context).size.width : 1,
            height: _showChallengeUI ? MediaQuery.of(context).size.height : 1,
            child: IgnorePointer(
              ignoring: !_showChallengeUI,
              child: InAppWebView(
                initialUrlRequest: URLRequest(url: WebUri('https://animepahe.pw/')),
                initialSettings: InAppWebViewSettings(
                  userAgent: bypassState.userAgent,
                  javaScriptEnabled: true,
                  domStorageEnabled: true,
                  thirdPartyCookiesEnabled: true,
                  transparentBackground: true,
                  useWideViewPort: true,
                  loadWithOverviewMode: true,
                ),
                onWebViewCreated: (controller) {
                  _controller = controller;
                  bypassState.registerWebViewController(controllerGetter: () => _controller);
                  _log('Physical InAppWebView created');
                },
                onReceivedError: (controller, request, error) {
                  if (request.url.toString() == 'https://animepahe.pw/') {
                    _log('WebView Error: ${error.description}');
                    controller.evaluateJavascript(source: "window.webViewError = true;");
                  }
                },
                onLoadStart: (controller, url) async {
                  _log('Loading $url');
                  await controller.evaluateJavascript(source: """
                    window.webViewError = false;
                    Object.defineProperty(navigator, 'webdriver', {
                      get: () => undefined
                    });
                    window.chrome = {
                      runtime: {}
                    };
                    
                    var meta = document.createElement('meta');
                    meta.name = 'viewport';
                    meta.content = 'width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no';
                    var head = document.getElementsByTagName('head')[0];
                    if (head) {
                        head.appendChild(meta);
                    }
                  """);
                },
                onLoadStop: (controller, url) async {
                  _log('Load stopped for $url');
                  
                  if (url?.toString().startsWith('chrome-error://') == true) {
                    _log('WebView encountered a chrome-error. Retrying in 5s...');
                    Future.delayed(const Duration(seconds: 5), () {
                      controller.loadUrl(urlRequest: URLRequest(url: WebUri('https://animepahe.pw/')));
                    });
                    return;
                  }
                  
                  final hasError = await controller.evaluateJavascript(source: "window.webViewError === true");
                  if (hasError == true) {
                     _log('WebView had a network error. Retrying in 5s...');
                     Future.delayed(const Duration(seconds: 5), () {
                       controller.loadUrl(urlRequest: URLRequest(url: WebUri('https://animepahe.pw/')));
                     });
                     return;
                  }
                  
                  // Check if we bypassed the challenge
                  Future<void> checkBypassStatus() async {
                    if (!mounted) return;
                    
                    final html = await controller.evaluateJavascript(source: "document.documentElement.outerHTML");
                    if (html == null) return;
                    
                    final isChallenge = html.contains('cf-browser-verification') || html.contains('cf-turnstile') || html.contains('Just a moment...');
                    
                    if (!isChallenge) {
                      if (_showChallengeUI) setState(() => _showChallengeUI = false);
                      bypassState.onBypassSuccess(url?.toString() ?? 'https://animepahe.pw/');
                    } else {
                      _log('Still waiting on Cloudflare challenge...');
                      
                      if (!_showChallengeUI) {
                        if (mounted && ref.read(cloudflareBypassProvider).isBypassing) {
                          _log('Showing challenge to user');
                          setState(() => _showChallengeUI = true);
                        }
                      }
                      
                      if (bypassState.isBypassing) {
                        Future.delayed(const Duration(seconds: 2), checkBypassStatus);
                      }
                    }
                  }
                  
                  await checkBypassStatus();
                },
              ),
            ),
          ),
        if (_showChallengeUI)
          Positioned(
            top: 100,
            left: 20,
            right: 20,
            child: Material(
              color: Colors.transparent,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.black87,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFFF5722), width: 1),
                ),
                child: const Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Please verify you are human below to bypass protection. This will only happen once.',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}
