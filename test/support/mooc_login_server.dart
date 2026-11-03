import 'dart:convert';
import 'dart:io';

class MoocLoginServer {
  MoocLoginServer._(this._server);

  final HttpServer _server;
  final requests = <String>[];
  Map<String, dynamic> passwordResult = {'ret': 201};
  Map<String, dynamic> smsSendResult = {'ret': 201, 'cd': 2};
  Map<String, dynamic> smsLoginResult = {'ret': 201};
  bool requireProofOnFirstPassword = false;
  int passwordAttempts = 0;
  int smsSendAttempts = 0;
  int smsLoginAttempts = 0;
  var _proofCalls = 0;

  int get port => _server.port;

  static Future<MoocLoginServer> start() async {
    final socket = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final server = MoocLoginServer._(socket);
    socket.listen(server._handle);
    return server;
  }

  Future<void> close() => _server.close(force: true);

  Future<void> _handle(HttpRequest request) async {
    final path = request.uri.path;
    requests.add('${request.method} $path');
    await request.drain<void>();
    if (request.method == 'GET' && path.endsWith('/home.htm')) {
      final cookie = request.headers.value(HttpHeaders.cookieHeader) ?? '';
      if (!cookie.contains('NTESSTUDYSI=') || !cookie.contains('STUDY_SESS=')) {
        request.response.statusCode = HttpStatus.found;
        request.response.headers.set(
          HttpHeaders.locationHeader,
          'https://www.icourse163.org/passport/logingate/changeCookie.htm',
        );
      } else {
        request.response.headers.contentType = ContentType.html;
        request.response.write('''
          <html><script>
            window.webUser = {"id": 123, "nickName": "测试账号"};
          </script></html>
        ''');
      }
      await request.response.close();
      return;
    }
    if (request.method == 'GET') {
      request.response.headers.contentType = ContentType.html;
      request.response.write('<html></html>');
      await request.response.close();
      return;
    }
    if (!path.startsWith('/reg.icourse163.org/')) {
      await _json(request.response, {'ret': 404});
      return;
    }
    if (path.endsWith('/powGetP')) {
      _proofCalls++;
      final challenge = requireProofOnFirstPassword && _proofCalls == 2;
      await _json(request.response, {
        'ret': 201,
        'pVInfo': {
          'needCheck': challenge,
          if (challenge) ...{
            'hashFunc': 'VDF_FUNCTION',
            'sid': 'proof-session',
            'minTime': 0,
            'maxTime': 100,
            'args': {'mod': '0b', 'x': '02', 't': 2, 'puzzle': 'puzzle'},
          },
        },
      });
      return;
    }
    if (path.endsWith('/gt')) {
      await _json(request.response, {'ret': 201, 'tk': 'ticket'});
      return;
    }
    if (path.endsWith('/pwd/l')) {
      passwordAttempts++;
      if (requireProofOnFirstPassword && passwordAttempts == 1) {
        await _json(request.response, {'ret': 805});
        return;
      }
      if (passwordResult['ret'] == 201) _setSession(request.response);
      await _json(request.response, passwordResult);
      return;
    }
    if (path.endsWith('/sms/sm')) {
      smsSendAttempts++;
      await _json(request.response, smsSendResult);
      return;
    }
    if (path.endsWith('/sms/vfsms')) {
      smsLoginAttempts++;
      if (smsLoginResult['ret'] == 201) {
        _setSession(request.response);
      }
      await _json(request.response, smsLoginResult);
      return;
    }
    if (path.endsWith('/ini')) {
      await _json(request.response, {'ret': 201});
      return;
    }
    await _json(request.response, {'ret': 404});
  }

  void _setSession(HttpResponse response) {
    response.headers.add(
      HttpHeaders.setCookieHeader,
      'NTESSTUDYSI=csrf; Domain=.icourse163.org; Path=/; '
      'Secure; HttpOnly; SameSite=Lax',
    );
    response.headers.add(
      HttpHeaders.setCookieHeader,
      'STUDY_SESS=session; Domain=.icourse163.org; Path=/; '
      'Secure; HttpOnly; SameSite=Lax',
    );
  }

  Future<void> _json(HttpResponse response, Map<String, dynamic> value) async {
    response.headers.contentType = ContentType.json;
    response.write(jsonEncode(value));
    await response.close();
  }
}
