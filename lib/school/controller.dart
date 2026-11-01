import 'dart:async';

import 'package:flutter/foundation.dart';

import '../academics/controller.dart';
import '../agenda/controller.dart';
import '../agenda/deadline_source.dart';
import '../core/async/cancelable_request.dart';
import '../core/diagnostics.dart';
import '../core/error_message.dart';
import '../schedule/controller.dart';
import 'academics.dart';
import 'access.dart';
import 'errors.dart';
import 'learning/eclass_deadlines.dart';
import 'learning/lexue_deadlines.dart';
import 'network.dart';
import 'service.dart';
import 'session.dart';
import 'storage.dart';
import 'verification.dart';

enum AccountStatus {
  unverified,
  signedIn,
  signedOut,
  expired,
  smsRequired,
  imageRequired,
}

/// Runs school operations through one authenticated, cancellable session owner.
class SchoolController extends ChangeNotifier {
  SchoolController({
    required this._service,
    required SchoolStorage storage,
    required this._timetable,
    required this._agenda,
    required this._academics,
  }) : _storage = storage,
       _access = SchoolAccess(storage);

  final SchoolService _service;
  final SchoolStorage _storage;
  final SchoolAccess _access;
  final TimetableController _timetable;
  final AgendaController _agenda;
  final AcademicController _academics;
  AccountStatus _status = AccountStatus.unverified;
  String? _username;
  Future<void>? _finished;
  bool _disposed = false;
  String? _error;
  int _accountRevision = 0;

  AccountStatus get accountStatus => _status;
  String? get username => _username;
  bool get loginExpired => _status == AccountStatus.expired;
  bool get verificationRequired =>
      _status == AccountStatus.smsRequired ||
      _status == AccountStatus.imageRequired;
  bool get busy => _finished != null;
  Future<void> get idle => _finished ?? Future<void>.value();
  String? get error => _error;

  Future<void> loadAccount() async {
    final active = _finished;
    if (active != null) await active;
    if (_disposed) return;

    final revision = _accountRevision;
    try {
      final username = (await _storage.readCredentials())?.username;
      if (revision != _accountRevision) return;
      _username = username;
      if (_username == null) _status = AccountStatus.signedOut;
    } on Exception catch (failure, stack) {
      AppDiagnostics.instance.report('读取学校账号', failure, stack);
    }
    _notify();
  }

  void requireLogin() {
    final next = _username == null
        ? AccountStatus.signedOut
        : AccountStatus.expired;
    if (next == _status) return;
    _status = next;
    _notify();
  }

  void _requireVerification(SchoolVerificationKind kind) {
    _status = switch (kind) {
      SchoolVerificationKind.sms => AccountStatus.smsRequired,
      SchoolVerificationKind.image => AccountStatus.imageRequired,
    };
    _notify();
  }

  VerifySchoolLogin? _verification(VerifySchoolLogin? verify) =>
      verify == null ? null : _requiredVerification(verify);

  VerifySchoolLogin _requiredVerification(VerifySchoolLogin verify) =>
      (request) {
        _requireVerification(switch (request) {
          SchoolSmsVerification() => SchoolVerificationKind.sms,
          SchoolImageVerification() => SchoolVerificationKind.image,
        });
        return verify(request);
      };

  Future<bool> _run(
    String label,
    Future<bool> Function() operation, {
    bool notifyErrors = true,
  }) async {
    if (busy) {
      AppDiagnostics.instance.notice('正在处理学校请求，请稍后再试。');
      return false;
    }
    final finished = Completer<void>();
    _finished = finished.future;
    _error = null;
    _notify();
    AppDiagnostics.instance.info('开始$label');
    try {
      final success = await operation();
      if (success) {
        _status = _username == null
            ? AccountStatus.signedOut
            : AccountStatus.signedIn;
        AppDiagnostics.instance.info('$label完成');
      }
      return success;
    } on SchoolVerificationRequired catch (request) {
      _requireVerification(request.kind);
      _error = '学校登录验证未完成，请完成验证后继续同步。';
      if (notifyErrors) {
        AppDiagnostics.instance.notice('学校登录验证未完成，请在设置中完成验证。');
      }
      return false;
    } on RequestCancelled {
      return false;
    } on Exception catch (failure, stack) {
      if (failure is SessionExpired || failure is SchoolCredentialsRequired) {
        requireLogin();
      }
      _error = errorMessage(failure);
      AppDiagnostics.instance.error(label, failure, stack);
      if (notifyErrors) AppDiagnostics.instance.notice(_error!);
      return false;
    } finally {
      _finished = null;
      finished.complete();
      _notify();
    }
  }

  /// Failed or cancelled reads return null; diagnostics are reported once here.
  Future<T?> read<T>(
    String label,
    Future<T> Function(SchoolSession) operation, {
    required VerifySchoolLogin verify,
    CancellationToken? cancellation,
  }) async {
    T? result;
    final success = await _run(label, () async {
      result = await _access.read(
        _verification(verify),
        operation,
        cancellation: cancellation,
      );
      return true;
    });
    return success ? result : null;
  }

  Future<bool> signIn(
    SchoolCredentials credentials,
    VerifySchoolLogin verify, {
    DeadlineSource? source,
  }) => _run('登录学校账号', () async {
    _accountRevision++;
    await _access.signIn(
      credentials,
      _requiredVerification(verify),
      source: source,
    );
    if (_username != credentials.username) _service.clearCache();
    _username = credentials.username;
    await _academics.load(_username);
    return true;
  });

  Future<bool> restoreAccount({VerifySchoolLogin? verify}) async {
    if (_username == null) return false;
    return _run('恢复学校登录', () async {
      await _access.read(
        verify == null ? null : _verification(verify),
        (session) => session.checkLogin(),
        // A manual check must reach SSO even if a service cookie still works.
        service: verify == null ? null : SchoolNetwork.campus.accountPage,
      );
      return true;
    });
  }

  Future<bool> synchronize({String? term, VerifySchoolLogin? verify}) => _run(
    '同步课表',
    () => _access.read(_verification(verify), (session) async {
      final result = await _service.synchronize(
        session,
        account: _username!,
        term: term,
      );
      session.checkActive();
      return _timetable.importSchedule(
        result.schedule,
        result.terms,
        checkActive: session.checkActive,
      );
    }),
    notifyErrors: false,
  );

  Future<bool> importExams({String? term, VerifySchoolLogin? verify}) => _run(
    '同步考试安排',
    () => _access.read(_verification(verify), (session) async {
      final result = await _service.exams(
        session,
        account: _username!,
        term: term ?? _timetable.schedule?.term,
      );
      session.checkActive();
      return _agenda.replaceExams(
        result.term,
        result.exams,
        checkActive: session.checkActive,
      );
    }),
    notifyErrors: false,
  );

  Future<bool> importGrades({VerifySchoolLogin? verify}) =>
      _run('同步成绩', () async {
        final grades = await _access.read(
          _verification(verify),
          fetchSchoolGrades,
          service: SchoolNetwork.recordsService,
        );
        return _academics.save(
          _academics.record.copyWith(
            grades: grades,
            gradesUpdatedAt: DateTime.now(),
          ),
        );
      }, notifyErrors: false);

  Future<bool> importStudyPlan({VerifySchoolLogin? verify}) =>
      _run('同步学分进度', () async {
        final plan = await _access.read(_verification(verify), fetchStudyPlan);
        return _academics.save(
          _academics.record.copyWith(plan: plan, planUpdatedAt: DateTime.now()),
        );
      }, notifyErrors: false);

  Future<bool> importDeadlines({
    required DeadlineSource source,
    VerifySchoolLogin? verify,
  }) => _run(
    '同步${source.label} DDL',
    () => _access.readLearningPlatform(source, _verification(verify), (
      session,
      page,
    ) async {
      final deadlines = await switch (source) {
        DeadlineSource.lexue => fetchLexueDeadlines(session, page),
        DeadlineSource.eclass => fetchEclassDeadlines(session),
        DeadlineSource.mooc => throw ArgumentError('MOOC 使用独立账号同步'),
      };
      session.checkActive();
      return _agenda.mergeDeadlines(
        deadlines,
        checkActive: session.checkActive,
      );
    }),
    notifyErrors: false,
  );

  void cancel() => _access.cancel();

  Future<bool> signOut() async {
    final finished = _finished;
    cancel();
    await finished;
    return _run('退出学校账号', () async {
      _accountRevision++;
      await _storage.clear();
      _service.clearCache();
      _username = null;
      await _academics.load(null);
      return true;
    });
  }

  @override
  void dispose() {
    _disposed = true;
    cancel();
    super.dispose();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }
}
