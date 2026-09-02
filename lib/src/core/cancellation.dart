import 'dart:async';

import 'scraper_exceptions.dart';

/// Cooperative cancellation for in-flight scrapes.
///
/// Replaces the 1.x `cancel()`, which completed an error on a `Completer` that
/// nothing awaited — producing an unhandled async error rather than actually
/// stopping the work.
///
/// ```dart
/// final token = CancellationToken();
/// final future = scraper.load(cancellationToken: token);
/// token.cancel(); // load() throws CancelledException
/// ```
class CancellationToken {
  final _completer = Completer<void>();

  /// Whether [cancel] has been called.
  bool get isCancelled => _completer.isCompleted;

  /// Completes when this token is cancelled; never completes otherwise.
  ///
  /// Useful with [Future.any] to race an operation against cancellation.
  Future<void> get whenCancelled => _completer.future;

  /// Requests cancellation. Calling this more than once is harmless.
  void cancel() {
    if (!_completer.isCompleted) _completer.complete();
  }

  /// Throws [CancelledException] if cancellation has been requested.
  ///
  /// Call between steps of a long operation to make it interruptible.
  void throwIfCancelled({String? url}) {
    if (isCancelled) throw CancelledException(url: url);
  }
}
