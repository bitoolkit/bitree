import '../agenda/deadline_source.dart';
import '../core/async/cancelable_request.dart';
import 'connection.dart';
import 'errors.dart';
import 'login.dart';
import 'network.dart';
import 'session.dart';
import 'storage.dart';
import 'verification.dart';

/// Authenticates school operations through one cancellable route selection.
class SchoolAccess {
  SchoolAccess(this._storage);

  final SchoolStorage _storage;
  SchoolConnection? _connection;

  Future<T> read<T>(
    VerifySchoolLogin? verify,
    Future<T> Function(SchoolSession) operation, {
    CancellationToken? cancellation,
    Uri? service,
  }) => _run(service ?? SchoolNetwork.campus.accountPage, (session) async {
    if (service != null) {
      await SchoolLogin(session, verify).signInTo(service);
    }
    try {
      return await operation(session);
    } on SessionExpired {
      final login = SchoolLogin(session, verify);
      if (service == null) {
        await login.signIn();
      } else {
        await login.signInTo(service);
      }
      return operation(session);
    }
  }, cancellation: cancellation);

  Future<T> readLearningPlatform<T>(
    DeadlineSource source,
    VerifySchoolLogin? verify,
    Future<T> Function(SchoolSession, SchoolResponse) operation,
  ) => _run(source.loginPage, (session) async {
    final login = SchoolLogin(session, verify);
    Future<T> read() async =>
        operation(session, await login.openService(source.loginPage));
    try {
      return await read();
    } on SessionExpired {
      return read();
    }
  });

  Future<void> signIn(
    SchoolCredentials credentials,
    VerifySchoolLogin verify, {
    DeadlineSource? source,
  }) {
    Future<void> authenticate(SchoolSession session) async {
      await _storage.clearSession(session.network);
      session.checkActive();
      final login = SchoolLogin(session, verify);
      if (source == null) {
        await login.signIn(credentials);
      } else {
        await login.openService(source.loginPage, credentials: credentials);
      }
      session.checkActive();
      await _storage.saveCredentials(credentials);
    }

    return _run(
      source?.loginPage ?? SchoolNetwork.campus.accountPage,
      authenticate,
    );
  }

  Future<T> _run<T>(
    Uri service,
    Future<T> Function(SchoolSession) operation, {
    CancellationToken? cancellation,
  }) async {
    cancellation?.check();
    final connection = SchoolConnection(_storage);
    _connection = connection;
    final detach = cancellation?.onCancel(connection.close);
    try {
      return await connection.run(service, operation);
    } finally {
      detach?.call();
      if (identical(_connection, connection)) _connection = null;
    }
  }

  void cancel() => _connection?.close();
}
