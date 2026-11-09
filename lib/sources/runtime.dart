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

/// Host callbacks available to one source operation. Callbacks are synchronous
/// so the Lua stack never crosses an async Dart callback boundary.
class SourceOperationContext {
  SourceOperationContext({
    this.config = const {},
    this.scope = const {},
    this.source = const {},
    this.locale = 'zh',
    this.baseOperations = const {},
    this.baseSteps = const {},
    this.data = const {},
    Map<String, dynamic>? storage,
    this.isCancelled,
    this.logSink,
    this.httpRequest,
  }) : storage = storage ?? <String, dynamic>{};

  final Map<String, Object?> config;
  final Map<String, Object?> scope;
  final Map<String, Object?> source;
  final String locale;

  /// Base operation name to callback. The callback receives the converted
  /// query table and returns a JSON-compatible Dart value.
  final Map<String, Object? Function(Object? query)> baseOperations;

  /// Original built-in steps exposed as `ctx.base.steps`.
  final Map<String, Object? Function(List<Object?> args)> baseSteps;

  /// Data access exposed as `ctx.data.*`.
  final Map<String, Object? Function(Map<String, Object?> query)> data;

  final Map<String, dynamic> storage;
  final bool Function()? isCancelled;
  final void Function(String level, String message)? logSink;
  final SourceHttpHandler? httpRequest;

  /// Set by LuaSourceModule.callOperation so a Dart base operation can call
  /// the merged (possibly overridden) step.
  Object? Function(String name, List<Object?> args)? stepDispatcher;

  SourceOperationContext withHttpRequest(SourceHttpHandler? handler) {
    final context = SourceOperationContext(
      config: config,
      scope: scope,
      source: source,
      locale: locale,
      baseOperations: baseOperations,
      baseSteps: baseSteps,
      data: data,
      storage: storage,
      isCancelled: isCancelled,
      logSink: logSink,
      httpRequest: handler,
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
      baseOperations: baseOperations,
      baseSteps: baseSteps,
      data: data,
      storage: storage,
      isCancelled: isCancelled,
      logSink: logSink,
      httpRequest: httpRequest,
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
