import 'dart:async';

class RequestCancelled implements Exception {
  const RequestCancelled();
}

/// A request can bind its transport's abort method to this signal.
class CancellationToken {
  bool _cancelled = false;
  final _listeners = <void Function()>{};

  bool get isCancelled => _cancelled;

  void check() {
    if (_cancelled) throw const RequestCancelled();
  }

  /// Returns a function that detaches the listener when the request finishes.
  void Function() onCancel(void Function() listener) {
    if (_cancelled) {
      listener();
      return () {};
    }
    _listeners.add(listener);
    return () => _listeners.remove(listener);
  }

  void cancel() {
    if (_cancelled) return;
    _cancelled = true;
    final listeners = _listeners.toList();
    _listeners.clear();
    for (final listener in listeners) {
      listener();
    }
  }
}

/// Replaces the previous request, waiting for its resources to close first.
class LatestRequest {
  CancellationToken? _current;
  Future<void>? _finished;

  /// A superseded run throws [RequestCancelled]; other errors propagate.
  Future<T> run<T>(
    Future<T> Function(CancellationToken cancellation) operation,
  ) async {
    final previous = _finished;
    cancel();
    final cancellation = CancellationToken();
    final finished = Completer<void>();
    _current = cancellation;
    _finished = finished.future;

    try {
      await previous;
      cancellation.check();
      final result = await operation(cancellation);
      cancellation.check();
      return result;
    } finally {
      if (identical(_current, cancellation)) {
        _current = null;
        _finished = null;
      }
      finished.complete();
    }
  }

  void cancel() => _current?.cancel();
}
