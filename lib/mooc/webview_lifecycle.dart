import 'package:webview_all/webview_all.dart';

import '../core/diagnostics.dart';

Future<void> disposeMoocWebView(WebViewController? browser) async {
  if (browser == null) return;
  try {
    await browser.platform.closeWebViewSession();
  } on UnsupportedError {
    // Some embedded platforms leave widget lifetime to the WebView widget.
  } catch (error, stack) {
    AppDiagnostics.instance.error('释放 MOOC 网页控件', error, stack);
  }
}
