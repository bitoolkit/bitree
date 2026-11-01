import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Routes real requests to a local server, keeping the original host in the path.
class LocalHttpOverrides extends HttpOverrides {
  LocalHttpOverrides(this.port);

  final int port;
  final clients = <LocalHttpClient>[];

  @override
  HttpClient createHttpClient(SecurityContext? context) {
    final client = LocalHttpClient(super.createHttpClient(context), port);
    clients.add(client);
    return client;
  }
}

class LocalHttpClient extends Fake implements HttpClient {
  LocalHttpClient(this.delegate, this.port);

  final HttpClient delegate;
  final int port;
  Uri? firstUrl;
  bool closed = false;

  @override
  set connectionTimeout(Duration? timeout) =>
      delegate.connectionTimeout = timeout;

  @override
  Future<HttpClientRequest> getUrl(Uri url) => openUrl('GET', url);

  @override
  Future<HttpClientRequest> postUrl(Uri url) => openUrl('POST', url);

  @override
  Future<HttpClientRequest> openUrl(String method, Uri url) {
    firstUrl ??= url;
    return delegate.openUrl(
      method,
      Uri(
        scheme: 'http',
        host: '127.0.0.1',
        port: port,
        path: '/${url.host}${url.path}',
        query: url.hasQuery ? url.query : null,
      ),
    );
  }

  @override
  void close({bool force = false}) {
    closed = true;
    delegate.close(force: force);
  }
}
