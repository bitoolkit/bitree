import 'source.dart';

class SourceError implements Exception {
  const SourceError(this.code, this.message, [this.details]);

  final String code;
  final String message;
  final Object? details;

  @override
  String toString() => '$code: $message';
}

class SourceCancelled implements Exception {
  const SourceCancelled();
}

typedef SourceHttpHandler = Future<Object?> Function(
  Map<String, Object?> request,
);

typedef SourceSessionCookie = Future<String?> Function(String name, String url);

typedef SourceProgressHandler = void Function(Map<String, Object?> progress);

abstract interface class SourceSecretStore {
  Future<Object?> read(String namespace, String key);

  Future<void> write(String namespace, String key, Object? value);

  Future<void> remove(String namespace, String key);
}

/// Host callbacks available to one source operation. Callbacks are synchronous
/// so the Lua stack never crosses an async Dart callback boundary.
class SourceOperationContext {
  SourceOperationContext({
    this.config = const {},
    this.scope = const {},
    this.source = const {},
    this.locale = 'zh',
    this.baseSteps = const {},
    this.data = const {},
    Map<String, dynamic>? storage,
    this.isCancelled,
    this.logSink,
    this.httpRequest,
    this.baseOperationHandler,
    this.secrets,
    this.secretNamespace,
    this.sessionCookie,
    this.progressSink,
  }) : storage = storage ?? <String, dynamic>{};

  final Map<String, Object?> config;
  final Map<String, Object?> scope;
  final Map<String, Object?> source;
  final String locale;

  /// Calls an operation on the source implementation this definition extends.
  final Future<Object?> Function(String name, Object? query)?
  baseOperationHandler;

  /// Original built-in steps exposed as `ctx.base.steps`.
  final Map<String, Object? Function(List<Object?> args)> baseSteps;

  /// Data access exposed through `require("bitree.data")`.
  final Map<String, Object? Function(Map<String, Object?> query)> data;

  final Map<String, dynamic> storage;
  final bool Function()? isCancelled;
  final void Function(String level, String message)? logSink;
  final SourceHttpHandler? httpRequest;

  /// Persistent values scoped to one package and source instance.
  final SourceSecretStore? secrets;
  final String? secretNamespace;

  /// Reads a declared cookie from the current source session.
  final SourceSessionCookie? sessionCookie;

  /// Reports bounded operation progress to the current UI task.
  final SourceProgressHandler? progressSink;

  /// Set by LuaSourceModule.callOperation so a Dart base operation can call
  /// the merged (possibly overridden) step.
  Object? Function(String name, List<Object?> args)? stepDispatcher;

  SourceOperationContext withHttpRequest(SourceHttpHandler? handler) {
    final context = SourceOperationContext(
      config: config,
      scope: scope,
      source: source,
      locale: locale,
      baseSteps: baseSteps,
      data: data,
      storage: storage,
      isCancelled: isCancelled,
      logSink: logSink,
      httpRequest: handler,
      baseOperationHandler: baseOperationHandler,
      secrets: secrets,
      secretNamespace: secretNamespace,
      sessionCookie: sessionCookie,
      progressSink: progressSink,
    );
    context.stepDispatcher = stepDispatcher;
    return context;
  }

  SourceOperationContext withSource(Map<String, Object?> values) {
    final context = SourceOperationContext(
      config: config,
      scope: scope,
      source: {...source, ...values},
      locale: locale,
      baseSteps: baseSteps,
      data: data,
      storage: storage,
      isCancelled: isCancelled,
      logSink: logSink,
      httpRequest: httpRequest,
      baseOperationHandler: baseOperationHandler,
      secrets: secrets,
      secretNamespace: secretNamespace,
      sessionCookie: sessionCookie,
      progressSink: progressSink,
    );
    context.stepDispatcher = stepDispatcher;
    return context;
  }

  SourceOperationContext withBaseOperationHandler(
    Future<Object?> Function(String name, Object? query)? handler,
  ) {
    final context = SourceOperationContext(
      config: config,
      scope: scope,
      source: source,
      locale: locale,
      baseSteps: baseSteps,
      data: data,
      storage: storage,
      isCancelled: isCancelled,
      logSink: logSink,
      httpRequest: httpRequest,
      baseOperationHandler: handler,
      secrets: secrets,
      secretNamespace: secretNamespace,
      sessionCookie: sessionCookie,
      progressSink: progressSink,
    );
    context.stepDispatcher = stepDispatcher;
    return context;
  }

  SourceOperationContext withHostServices({
    SourceSecretStore? secrets,
    String? secretNamespace,
    SourceSessionCookie? sessionCookie,
    SourceProgressHandler? progressSink,
  }) {
    final context = SourceOperationContext(
      config: config,
      scope: scope,
      source: source,
      locale: locale,
      baseSteps: baseSteps,
      data: data,
      storage: storage,
      isCancelled: isCancelled,
      logSink: logSink,
      httpRequest: httpRequest,
      baseOperationHandler: baseOperationHandler,
      secrets: secrets ?? this.secrets,
      secretNamespace: secretNamespace ?? this.secretNamespace,
      sessionCookie: sessionCookie ?? this.sessionCookie,
      progressSink: progressSink ?? this.progressSink,
    );
    context.stepDispatcher = stepDispatcher;
    return context;
  }

  SourceOperationContext withData(
    Map<String, Object? Function(Map<String, Object?> query)> values,
  ) {
    final context = SourceOperationContext(
      config: config,
      scope: scope,
      source: source,
      locale: locale,
      baseSteps: baseSteps,
      data: {...data, ...values},
      storage: storage,
      isCancelled: isCancelled,
      logSink: logSink,
      httpRequest: httpRequest,
      baseOperationHandler: baseOperationHandler,
      secrets: secrets,
      secretNamespace: secretNamespace,
      sessionCookie: sessionCookie,
      progressSink: progressSink,
    );
    context.stepDispatcher = stepDispatcher;
    return context;
  }
}

/// Uniform boundary for built-in Dart and Lua source implementations.
abstract interface class SourceRuntime {
  Future<Object?> call(
    SourceDefinition definition,
    SourceOperation operation,
    Map<String, Object?> query,
    SourceOperationContext context,
  );
}

typedef SourceRuntimeResolver = Future<SourceRuntime?> Function(
  SourceDefinition definition,
);
