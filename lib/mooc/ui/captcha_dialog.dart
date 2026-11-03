import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:webview_all/webview_all.dart';
import 'package:webview_all_android/webview_all_android.dart';

import '../../core/diagnostics.dart';
import '../../l10n/l10n.dart';
import '../../ui/app_dialog.dart';
import '../credentials.dart';
import '../login_client.dart';

const _captchaScriptUrl = 'https://cstaticdun.126.net/load.min.js';
const _captchaId = 'a3b396bb2f589bbc1151f0fa61d14747';
const _captchaLoadTimeout = Duration(seconds: 20);
const _captchaLogPrefix = '[BITREE_CAPTCHA]';

Future<MoocCaptchaSolution?> showMoocCaptchaDialog(
  BuildContext context, {
  required MoocLoginChallenge challenge,
  required String userAgent,
  Iterable<Cookie> cookies = const [],
}) {
  if (!context.mounted) return Future.value();
  return showAppDialog<MoocCaptchaSolution>(
    context: context,
    builder: (_) => _MoocCaptchaDialog(
      challenge: challenge,
      userAgent: userAgent,
      cookies: cookies.toList(growable: false),
    ),
  );
}

class _MoocCaptchaDialog extends StatefulWidget {
  const _MoocCaptchaDialog({
    required this.challenge,
    required this.userAgent,
    required this.cookies,
  });

  final MoocLoginChallenge challenge;
  final String userAgent;
  final List<Cookie> cookies;

  @override
  State<_MoocCaptchaDialog> createState() => _MoocCaptchaDialogState();
}

class _MoocCaptchaDialogState extends State<_MoocCaptchaDialog> {
  WebViewController? _browser;
  Timer? _poll;
  Timer? _loadTimeout;
  int _generation = 0;
  bool _loading = true;
  bool _checking = false;
  bool _loggedEvaluationFailure = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    final generation = ++_generation;
    _poll?.cancel();
    _poll = null;
    _loadTimeout?.cancel();
    _loggedEvaluationFailure = false;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final browser = WebViewController();
      await browser.setJavaScriptMode(JavaScriptMode.unrestricted);
      await browser.setUserAgent(widget.userAgent);
      await browser.setOnConsoleMessage((message) {
        if (message.message.startsWith(_captchaLogPrefix)) {
          AppDiagnostics.instance.info(message.message);
        }
      });
      await browser.setNavigationDelegate(
        NavigationDelegate(
          onNavigationRequest: (request) {
            final uri = Uri.tryParse(request.url);
            return uri != null && uri.scheme == 'https'
                ? NavigationDecision.navigate
                : NavigationDecision.prevent;
          },
          onPageFinished: (_) {
            if (!mounted || generation != _generation) return;
            _startPolling(generation);
          },
          onWebResourceError: (error) {
            if (!mounted || generation != _generation) return;
            final uri = Uri.tryParse(error.url ?? '');
            final captchaResource =
                uri?.host == 'cstaticdun.126.net' ||
                uri?.host == 'webzjcaptcha.reg.163.com' ||
                uri?.host == 'c.dun.163yun.com';
            if (error.isForMainFrame == true || captchaResource) _fail();
          },
        ),
      );
      final cookieManager = WebViewCookieManager();
      if (cookieManager.platform
          case final AndroidWebViewCookieManager manager) {
        await manager.setAcceptThirdPartyCookies(
          browser.platform as AndroidWebViewController,
          true,
        );
      }
      for (final cookie in widget.cookies) {
        await cookieManager
            .setCookie(
              WebViewCookie(
                name: cookie.name,
                value: cookie.value,
                domain: cookie.domain ?? MoocCredentials.origin.host,
                path: cookie.path ?? '/',
              ),
            )
            .timeout(const Duration(seconds: 10));
      }
      if (!mounted || generation != _generation) return;
      final screen = MediaQuery.sizeOf(context);
      final width = math.min(360.0, math.max(220.0, screen.width - 64));
      setState(() => _browser = browser);
      _loadTimeout = Timer(_captchaLoadTimeout, () {
        if (mounted && generation == _generation && _loading) _fail();
      });
      await browser.loadHtmlString(
        _captchaHtml(
          captchaType: widget.challenge.captchaType,
          width: width.round(),
        ),
        baseUrl: MoocCredentials.origin.resolve('/member/login.htm').toString(),
      );
      if (mounted && generation == _generation) {
        _startPolling(generation);
      }
    } on Exception catch (error, stack) {
      if (generation != _generation) return;
      AppDiagnostics.instance.error('打开 MOOC 人机验证', error, stack);
      _fail();
    }
  }

  void _startPolling(int generation) {
    if (!mounted || generation != _generation) return;
    _poll ??= Timer.periodic(
      const Duration(milliseconds: 200),
      (_) => unawaited(_check(generation)),
    );
    unawaited(_check(generation));
  }

  Future<void> _check(int generation) async {
    final browser = _browser;
    if (!mounted ||
        generation != _generation ||
        browser == null ||
        _checking ||
        _error != null) {
      return;
    }
    _checking = true;
    try {
      final value = await browser.callAsyncJavaScript('''
        return {
          ready: window.__bitreeCaptchaReady === true,
          error: window.__bitreeCaptchaError || null,
          solution: window.__bitreeCaptcha || null
        };
      ''', timeout: const Duration(seconds: 4));
      if (!mounted || generation != _generation) return;
      final result = _stringMap(value);
      final solution = _stringMap(result?['solution']);
      final validate = solution?['validate'];
      if (validate is String && validate.trim().isNotEmpty) {
        _poll?.cancel();
        _loadTimeout?.cancel();
        Navigator.pop(
          context,
          MoocCaptchaSolution(
            validate: validate,
            captchaType: switch (solution?['captchaType']) {
              final String value => value,
              final num value => '$value',
              _ => null,
            },
          ),
        );
        return;
      }
      if (result?['error'] != null) {
        _fail();
        return;
      }
      if (result?['ready'] == true && _loading) {
        _loadTimeout?.cancel();
        setState(() => _loading = false);
      }
    } on Exception catch (error, stack) {
      // A document replacement can briefly invalidate JavaScript calls.
      if (!_loggedEvaluationFailure) {
        _loggedEvaluationFailure = true;
        AppDiagnostics.instance.error('读取 MOOC 人机验证状态', error, stack);
      }
    } finally {
      _checking = false;
    }
  }

  void _fail() {
    if (!mounted) return;
    _poll?.cancel();
    _loadTimeout?.cancel();
    setState(() {
      _loading = false;
      _error = context.l10n.moocVerificationLoadFailed;
    });
  }

  @override
  void dispose() {
    _generation++;
    _poll?.cancel();
    _loadTimeout?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screen = MediaQuery.sizeOf(context);
    final width = math.min(360.0, math.max(220.0, screen.width - 64));
    final height = math.min(280.0, math.max(220.0, screen.height * 0.36));
    final l10n = context.l10n;
    return AlertDialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      contentPadding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      title: Text(l10n.moocVerificationTitle),
      content: SizedBox(
        width: width,
        height: height,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: ColoredBox(
            color: Theme.of(context).colorScheme.surface,
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (_browser case final browser?)
                  WebViewWidget(
                    key: const ValueKey('mooc-captcha-webview'),
                    controller: browser,
                  ),
                if (_loading) const Center(child: CircularProgressIndicator()),
                if (_error case final error?)
                  ColoredBox(
                    color: Theme.of(context).colorScheme.surface,
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(error, textAlign: TextAlign.center),
                          const SizedBox(height: 12),
                          FilledButton.tonal(
                            onPressed: _load,
                            child: Text(l10n.refresh),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.cancel),
        ),
      ],
    );
  }
}

String _captchaHtml({required int? captchaType, required int width}) {
  final type = captchaType == null ? '' : 'captchaType: $captchaType,';
  return '''
<!doctype html>
<html lang="zh-CN">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <style>
    html, body {
      margin: 0;
      width: 100%;
      height: 100%;
      overflow: hidden;
      background: #fff;
    }
    body {
      display: flex;
      align-items: center;
      justify-content: center;
      font-family: sans-serif;
    }
    #captcha {
      width: ${width}px;
      max-width: calc(100% - 16px);
      min-height: 40px;
      box-sizing: border-box;
    }
  </style>
</head>
<body>
  <div id="captcha"></div>
  <script>
    (function () {
      window.__bitreeCaptchaReady = false;
      window.__bitreeCaptchaError = null;
      window.__bitreeCaptcha = null;

      function fail(code) {
        if (window.__bitreeCaptchaError) return;
        window.__bitreeCaptchaError = code;
        console.error('$_captchaLogPrefix ' + code);
      }

      function ready() {
        if (window.__bitreeCaptchaError) return;
        window.__bitreeCaptchaReady = true;
      }

      function initialize() {
        try {
          if (typeof window.initNECaptcha !== 'function') {
            fail('sdk');
            return;
          }
          window.initNECaptcha({
            element: document.getElementById('captcha'),
            captchaId: '$_captchaId',
            $type
            mode: 'embed',
            width: $width,
            lang: 'zh-CN',
            onReady: ready,
            onVerify: function (error, data) {
              if (error) {
                fail('verify');
                return;
              }
              if (!data || !data.validate) {
                fail('validation');
                return;
              }
              window.__bitreeCaptcha = {
                validate: String(data.validate),
                captchaType: data.captchaType == null
                  ? null
                  : String(data.captchaType)
              };
            }
          }, ready, function () {
            fail('init');
          });
        } catch (error) {
          fail('init');
        }
      }

      var script = document.createElement('script');
      script.src = '$_captchaScriptUrl';
      script.async = true;
      script.onload = initialize;
      script.onerror = function () {
        fail('script');
      };
      document.head.appendChild(script);

      window.setTimeout(function () {
        if (window.__bitreeCaptchaReady || window.__bitreeCaptchaError) return;
        fail('timeout');
      }, 18000);
    })();
  </script>
</body>
</html>
''';
}

Map<String, dynamic>? _stringMap(Object? value) {
  if (value is! Map) return null;
  return {
    for (final MapEntry(:key, :value) in value.entries)
      if (key is String) key: value,
  };
}
