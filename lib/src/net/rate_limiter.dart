import 'dart:async';
import 'dart:collection';

/// Paces outbound requests so one host is never hammered.
///
/// A scraping library that ships without this makes it trivially easy for a
/// well-meaning app to look like a denial-of-service to a small site. Politeness
/// is a default here, not an option — see also `RobotsPolicy`.
///
/// Limits are per-host: two different sites proceed in parallel, two requests to
/// the same site are spaced by [minInterval] and capped at
/// [maxConcurrentPerHost].
class RateLimiter {
  /// Creates a rate limiter.
  RateLimiter({
    this.minInterval = const Duration(milliseconds: 500),
    this.maxConcurrentPerHost = 2,
  }) : assert(maxConcurrentPerHost >= 1, 'must allow at least one request');

  /// A limiter that imposes no delay. For tests and for local fixtures.
  factory RateLimiter.unlimited() => RateLimiter(
        minInterval: Duration.zero,
        maxConcurrentPerHost: 1 << 20,
      );

  /// Minimum gap between two requests to the same host.
  final Duration minInterval;

  /// How many requests to one host may be in flight at once.
  final int maxConcurrentPerHost;

  final Map<String, DateTime> _lastRequest = {};
  final Map<String, int> _inFlight = {};
  final Map<String, Queue<Completer<void>>> _waiting = {};
  final Map<String, Duration> _hostOverrides = {};

  /// Applies a host-specific interval, overriding [minInterval].
  ///
  /// Used to honour a `Crawl-delay` from the host's own `robots.txt`.
  void setHostInterval(String host, Duration interval) {
    _hostOverrides[host.toLowerCase()] = interval;
  }

  /// The interval currently in force for [host].
  Duration intervalFor(String host) =>
      _hostOverrides[host.toLowerCase()] ?? minInterval;

  /// Waits until a request to [url] may proceed.
  ///
  /// Always pair with [release] — a `try`/`finally` is the safe shape, since an
  /// exception between the two would otherwise leak a concurrency slot and
  /// eventually deadlock every request to that host.
  Future<void> acquire(Uri url) async {
    final host = url.host.toLowerCase();

    while ((_inFlight[host] ?? 0) >= maxConcurrentPerHost) {
      final completer = Completer<void>();
      (_waiting[host] ??= Queue<Completer<void>>()).add(completer);
      await completer.future;
    }

    _inFlight[host] = (_inFlight[host] ?? 0) + 1;

    final interval = intervalFor(host);
    if (interval > Duration.zero) {
      final last = _lastRequest[host];
      if (last != null) {
        final elapsed = DateTime.now().difference(last);
        if (elapsed < interval) {
          await Future<void>.delayed(interval - elapsed);
        }
      }
    }

    _lastRequest[host] = DateTime.now();
  }

  /// Releases the slot taken by [acquire] for [url].
  void release(Uri url) {
    final host = url.host.toLowerCase();

    final count = (_inFlight[host] ?? 1) - 1;
    if (count <= 0) {
      _inFlight.remove(host);
    } else {
      _inFlight[host] = count;
    }

    final queue = _waiting[host];
    if (queue != null && queue.isNotEmpty) {
      queue.removeFirst().complete();
      if (queue.isEmpty) _waiting.remove(host);
    }
  }

  /// Runs [action] while holding a slot for [url], releasing it either way.
  Future<T> run<T>(Uri url, Future<T> Function() action) async {
    await acquire(url);
    try {
      return await action();
    } finally {
      release(url);
    }
  }

  /// Forgets all timing state. Waiters are released so nothing hangs.
  void reset() {
    _lastRequest.clear();
    _inFlight.clear();
    _hostOverrides.clear();
    for (final queue in _waiting.values) {
      while (queue.isNotEmpty) {
        queue.removeFirst().complete();
      }
    }
    _waiting.clear();
  }
}
