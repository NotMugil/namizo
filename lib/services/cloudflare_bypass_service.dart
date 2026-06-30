import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import 'dart:convert';

void _log(String msg) {
  if (kDebugMode) {
    debugPrint('🛡️ CloudflareBypass: $msg');
  }
}

final cloudflareBypassProvider = ChangeNotifierProvider<CloudflareBypassService>((ref) {
  return CloudflareBypassService.instance;
});

class CloudflareBypassService extends ChangeNotifier {
  static final CloudflareBypassService instance = CloudflareBypassService._internal();
  factory CloudflareBypassService() => instance;
  CloudflareBypassService._internal();

  InAppWebViewController? Function()? _controllerGetter;
  
  String _userAgent = 'Mozilla/5.0 (Linux; Android 13; Mobile) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36';
  Map<String, String> _cookies = {};
  
  Map<String, String> get headers => {
    'User-Agent': _userAgent,
    'Cookie': cookieString,
  };
  
  bool _isBypassing = false;
  bool _isBypassed = false;
  String _bypassedUrl = 'https://animepahe.pw';
  Completer<void>? _bypassCompleter;
  
  String get userAgent => _userAgent;
  Map<String, String> get cookies => _cookies;
  bool get isReady => _isBypassed;
  bool get isBypassing => _isBypassing;
  String get bypassedUrl => _bypassedUrl;
  
  String get cookieString {
    return _cookies.entries.map((e) => '${e.key}=${e.value}').join('; ');
  }

  void registerWebViewController({required InAppWebViewController? Function() controllerGetter}) {
    _controllerGetter = controllerGetter;
  }

  /// Initialize the background bypass service. Should be called on app startup.
  Future<void> init() async {
    if (_isBypassed || _isBypassing) return;
    _log('Initializing CloudflareBypassService for Animepahe...');
    await _startBypass();
    
    // Schedule a refresh every 45 minutes to keep cookies warm
    Timer.periodic(const Duration(minutes: 45), (timer) {
      _log('Background refresh of Cloudflare cookies...');
      _startBypass(forceRefresh: true);
    });
  }
  
  /// Manually force a refresh of the bypass
  Future<void> forceRefresh() async {
    _log('Manual refresh of Cloudflare bypass requested...');
    await _startBypass(forceRefresh: true);
  }
  
  /// Wait until bypass is complete. Returns immediately if already bypassed.
  Future<void> waitForBypass() async {
    if (_isBypassed) return;
    if (_bypassCompleter != null) return _bypassCompleter!.future;
    
    if (!_isBypassing) {
      await _startBypass();
    }
    
    return _bypassCompleter?.future;
  }

  Future<void> _startBypass({bool forceRefresh = false}) async {
    if (_isBypassing && !forceRefresh) return;
    _isBypassing = true;
    _bypassCompleter = Completer<void>();
    Future.microtask(() => notifyListeners()); // Tell the Widget to render the WebView
    
    _log('Triggering visible WebView widget to bypass Cloudflare on animepahe.pw...');
    
    try {
      CookieManager cookieManager = CookieManager.instance();
      if (forceRefresh) {
        await cookieManager.deleteAllCookies();
        _isBypassed = false;
      }
      
      final controller = _controllerGetter?.call();
      if (controller != null) {
         await controller.loadUrl(urlRequest: URLRequest(url: WebUri('https://animepahe.pw/')));
      }
      
      // Safety timeout
      Future.delayed(const Duration(seconds: 30), () {
        if (_isBypassing && _bypassCompleter != null && !_bypassCompleter!.isCompleted) {
          _log('Bypass timed out after 30 seconds. Will retry later.');
          _isBypassing = false;
          Future.microtask(() => notifyListeners());
          
          final completer = _bypassCompleter;
          _bypassCompleter = null;
          completer?.completeError(Exception('Cloudflare bypass timed out'));
        }
      });
      
    } catch (e) {
      _log('Bypass error: $e');
      _isBypassing = false;
      Future.microtask(() => notifyListeners());
      
      if (_bypassCompleter != null && !_bypassCompleter!.isCompleted) {
        final completer = _bypassCompleter;
        _bypassCompleter = null;
        completer?.completeError(e);
      }
    }
  }

  Future<void> onBypassSuccess(String url) async {
    _log('Cloudflare bypassed successfully! Resolved URL: $url');
    
    try {
      final uri = Uri.parse(url);
      _bypassedUrl = '${uri.scheme}://${uri.host}';
    } catch (_) {
      _bypassedUrl = 'https://animepahe.pw';
    }
    
    await _extractCookies(url);
    
    _isBypassed = true;
    _isBypassing = false;
    Future.microtask(() => notifyListeners());
    
    if (_bypassCompleter != null && !_bypassCompleter!.isCompleted) {
      _bypassCompleter!.complete();
    }
  }

  Future<String?> fetchViaWebView(String url, {bool retry = true}) async {
    final controller = _controllerGetter?.call();
    if (controller == null) {
      _log('WebView controller not ready yet for fetching');
      return null;
    }
    
    try {
      _log('Executing Fetch via WebView for: $url');
      final result = await controller.callAsyncJavaScript(functionBody: """
        return fetch(url, {
          headers: {
            'Accept': 'application/json, text/javascript, */*; q=0.01',
            'X-Requested-With': 'XMLHttpRequest'
          }
        })
        .then(response => {
          if (!response.ok) {
            return response.text().then(text => 'ERROR: HTTP ' + response.status + ' - ' + text).catch(e => 'ERROR: HTTP ' + response.status);
          }
          return response.text();
        })
        .catch(err => {
          return 'ERROR: Fetch failed - ' + err.toString();
        });
      """, arguments: {'url': url}).timeout(const Duration(seconds: 20));
      
      final val = result?.value as String?;
      _log('Fetch completed.');
      
      if (val != null && val.startsWith('ERROR: HTTP 403') && retry) {
         _log('Got 403. Likely Cloudflare challenge. Forcing refresh...');
         await forceRefresh();
         await waitForBypass();
         return fetchViaWebView(url, retry: false);
      }
      
      return val;
    } catch (e) {
      _log('fetchViaWebView threw an exception: $e');
      return null;
    }
  }

  Future<String?> getFinalUrlViaWebView(String url) async {
    final controller = _controllerGetter?.call();
    if (controller == null) return null;
    
    try {
      final result = await controller.callAsyncJavaScript(functionBody: """
        return fetch(url, {
          method: 'GET'
        })
        .then(response => {
          return response.url;
        })
        .catch(err => {
          return null;
        });
      """, arguments: {'url': url}).timeout(const Duration(seconds: 15));
      
      return result?.value as String?;
    } catch (e) {
      _log('getFinalUrlViaWebView threw an exception: $e');
      return null;
    }
  }

  /// Load kwik player and extract the direct video link
  Future<String?> extractKwikVideoUrl(String kwikUrl) async {
    final controller = _controllerGetter?.call();
    if (controller == null) return null;
    
    _log('Extracting direct video link from Kwik embed: $kwikUrl');
    
    try {
      final dio = Dio(BaseOptions(
        headers: {
          'Referer': 'https://animepahe.pw/',
          'User-Agent': userAgent,
        },
        validateStatus: (status) => true,
      ));
      
      final response = await dio.get(kwikUrl);
      final text = response.data.toString();
      
      if (text.contains('p,a,c,k,e,d')) {
        _log('Found packed script via Dio!');
        
        final result = await controller.evaluateJavascript(source: """
          (function() {
            try {
              var text = ${jsonEncode(text)};
              var unpacked = "";
              var originalEval = window.eval;
              window.eval = function(str) {
                  unpacked = str;
              };
              
              var scriptMatch = text.match(/<script>(eval\\(function\\(p,a,c,k,e,d\\)[\\s\\S]*?)<\\/script>/);
              if (scriptMatch) {
                 var scriptContent = scriptMatch[1].replace('<\\/script>', '');
                 try {
                     originalEval(scriptContent);
                 } catch(e) {
                     return "DEBUG_DUMP:Error evaling: " + e.message;
                 }
                 window.eval = originalEval;
                 
                 if (unpacked) {
                    var urlMatch = unpacked.match(/(https:\\/\\/[^"']*?\\.(m3u8|mp4)[^"']*)/);
                    if (urlMatch) {
                        return urlMatch[1];
                    }
                 }
              }
              return "DEBUG_DUMP:No match or unpack failed";
            } catch(e) {
              return "DEBUG_DUMP:Catch " + e.message;
            }
          })();
        """);
        
        if (result != null && result is String && result.isNotEmpty && result != 'null') {
          if (result.startsWith('http')) {
            _log('Extracted video URL: $result');
            return result;
          } else {
            _log('DEBUG JS: $result');
          }
        }
      } else {
        _log('Dio response did not contain p,a,c,k,e,d script');
      }
      
      return null;
    } catch (e) {
      _log('Bypass error extracting Kwik URL: $e');
      return null;
    }
  }

  Future<void> _extractCookies(String url) async {
    try {
      await Future.delayed(const Duration(seconds: 2));
      
      CookieManager cookieManager = CookieManager.instance();
      final uri = WebUri(url);
      List<Cookie> cookies = await cookieManager.getCookies(url: uri);
      
      if (cookies.isEmpty) {
        final domainUri = WebUri('https://animepahe.pw/');
        cookies = await cookieManager.getCookies(url: domainUri);
      }
      
      final Map<String, String> newCookies = {};
      for (final cookie in cookies) {
        newCookies[cookie.name] = cookie.value.toString();
      }
      
      if (newCookies.isNotEmpty) {
        _cookies = newCookies;
        _log('Extracted cookies: ${_cookies.keys.join(", ")}');
      }
    } catch (e) {
      _log('Error extracting cookies: $e');
    }
  }
}
