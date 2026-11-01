import 'package:flutter/material.dart';
import 'package:webview_platform_interface/webview_platform_interface.dart';

/// Only the system WebView is replaced. Account capture, storage and navigation
/// still run through the production login screen.
class TestMoocBrowser extends WebViewPlatform {
  late TestMoocWebView controller;
  final cookies = <WebViewCookie>[];

  @override
  PlatformWebViewController createPlatformWebViewController(
    PlatformWebViewControllerCreationParams params,
  ) => controller = TestMoocWebView(params);

  @override
  PlatformWebViewCookieManager createPlatformCookieManager(
    PlatformWebViewCookieManagerCreationParams params,
  ) => _Cookies(params, cookies);

  @override
  PlatformNavigationDelegate createPlatformNavigationDelegate(
    PlatformNavigationDelegateCreationParams params,
  ) => _Navigation(params);

  @override
  PlatformWebViewWidget createPlatformWebViewWidget(
    PlatformWebViewWidgetCreationParams params,
  ) => _View(params);
}

class TestMoocWebView extends PlatformWebViewController {
  TestMoocWebView(super.params) : super.implementation();
  late _Navigation _navigation;
  Uri? url;
  Object snapshot = false;

  void finishLoading() {
    _navigation.progress?.call(100);
    _navigation.finished?.call(url.toString());
  }

  @override
  Future<void> setJavaScriptMode(JavaScriptMode mode) async {}
  @override
  Future<void> setPlatformNavigationDelegate(
    PlatformNavigationDelegate handler,
  ) async => _navigation = handler as _Navigation;
  @override
  Future<void> loadRequest(LoadRequestParams params) async {
    url = params.uri;
    finishLoading();
  }

  @override
  Future<void> reload() async => finishLoading();
  @override
  Future<Object?> callAsyncJavaScript(
    JavaScriptInvocationParams params,
  ) async => snapshot;
}

class _Navigation extends PlatformNavigationDelegate {
  _Navigation(super.params) : super.implementation();
  PageEventCallback? finished;
  ProgressCallback? progress;
  @override
  Future<void> setOnNavigationRequest(
    NavigationRequestCallback callback,
  ) async {}
  @override
  Future<void> setOnPageFinished(PageEventCallback callback) async =>
      finished = callback;
  @override
  Future<void> setOnProgress(ProgressCallback callback) async =>
      progress = callback;
  @override
  Future<void> setOnWebResourceError(WebResourceErrorCallback callback) async {}
}

class _Cookies extends PlatformWebViewCookieManager {
  _Cookies(super.params, this.cookies) : super.implementation();
  final List<WebViewCookie> cookies;
  @override
  Future<bool> clearCookies() async {
    final hadCookies = cookies.isNotEmpty;
    cookies.clear();
    return hadCookies;
  }

  @override
  Future<void> setCookie(WebViewCookie cookie) async => cookies.add(cookie);
  @override
  Future<List<WebViewCookie>> getCookies(Uri url) async => List.of(cookies);
}

class _View extends PlatformWebViewWidget {
  _View(super.params) : super.implementation();
  @override
  Widget build(BuildContext context) => const ColoredBox(
    color: Colors.white,
    child: Center(child: Text('MOOC 网页（系统控件替身）')),
  );
}
