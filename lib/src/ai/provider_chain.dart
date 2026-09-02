/// Fallback engine orchestrating ordered provider execution, error escalation,
/// egress privacy gating, and key redaction.
library;

import 'dart:async';
import 'dart:developer' as developer;

import '../schema/schema.dart';
import 'ai_provider.dart';
import 'cost_tracker.dart';
import 'providers/openai_provider.dart';

/// Exception thrown when every provider in the chain failed or was skipped.
class NoProviderAvailableException implements Exception {
  /// Creates a [NoProviderAvailableException].
  const NoProviderAvailableException(this.message, {this.attemptLog = const []});

  /// Detailed explanation of why the chain exhausted.
  final String message;

  /// Chronological log of provider attempts and error reasons.
  final List<String> attemptLog;

  @override
  String toString() => 'NoProviderAvailableException: $message\nAttempts:\n${attemptLog.join("\n")}';
}

/// Helper utility for redacting sensitive secrets from error messages and logs.
abstract final class KeySanitizer {
  static final _apiKeyPattern = RegExp(r'(?:sk-[a-zA-Z0-9_-]{8,}|[a-zA-Z0-9_-]{24,})');
  static final _bearerPattern = RegExp(r'Bearer\s+[^\s"\}]+', caseSensitive: false);

  /// Redacts sensitive keys and bearer tokens from [text].
  static String redact(String text) {
    var sanitized = text.replaceAllMapped(_bearerPattern, (m) => 'Bearer [REDACTED]');
    sanitized = sanitized.replaceAllMapped(_apiKeyPattern, (m) {
      final key = m.group(0)!;
      if (key.length <= 8) return '[REDACTED]';
      return '${key.substring(0, 4)}...[REDACTED]';
    });
    return sanitized;
  }
}

/// Circuit breaker tracking consecutive failures for a specific provider.
class _CircuitBreaker {
  int consecutiveFailures = 0;
  DateTime? trippedUntil;

  bool get isOpen {
    if (trippedUntil == null) return false;
    if (DateTime.now().isAfter(trippedUntil!)) {
      trippedUntil = null; // Reset on cooldown expiry
      consecutiveFailures = 0;
      return false;
    }
    return true;
  }

  void recordFailure() {
    consecutiveFailures++;
    if (consecutiveFailures >= 3) {
      trippedUntil = DateTime.now().add(const Duration(seconds: 30));
    }
  }

  void recordSuccess() {
    consecutiveFailures = 0;
    trippedUntil = null;
  }
}

/// Fallback provider chain executing candidate [AiProvider]s in sequence according
/// to specific resilience and error-handling rules.
class ProviderChain implements AiProvider {
  /// Creates a [ProviderChain].
  ProviderChain({
    required List<AiProvider> providers,
    this.allowCloudEgress = false,
    this.preferLocal = false,
    this.providerTimeout = const Duration(seconds: 25),
    this.session,
    String? id,
  })  : id = id ?? 'provider-chain',
        _providers = List.of(providers) {
    // Check whether the chain has a local offline floor
    final hasLocal = _providers.any((p) => p.capabilities.isLocal);
    if (!hasLocal) {
      developer.log(
        'Warning: ProviderChain has no local on-device provider (like GemmaProvider). '
        'Extraction will fail if device is offline or without cloud credentials.',
        name: 'flutter_ai_scrapper.ProviderChain',
      );
    }
  }

  @override
  final String id;

  /// Ordered list of candidate providers.
  final List<AiProvider> _providers;

  /// Whether sending scraped content off-device to cloud providers is allowed.
  ///
  /// Defaults to `false` for privacy. Non-local providers are skipped when `false`.
  final bool allowCloudEgress;

  /// Whether local providers are prioritized over remote cloud endpoints.
  final bool preferLocal;

  /// Timeout per provider attempt.
  final Duration providerTimeout;

  /// Optional session tracker for token usage and savings accounting.
  final UsageSession? session;

  final Map<String, _CircuitBreaker> _breakers = {};

  @override
  bool get isReady => _providers.any((p) => p.isReady);

  @override
  AiCapabilities get capabilities {
    // Aggregate capabilities from the best available provider
    return const AiCapabilities(
      supportsJsonSchema: true,
      supportsTools: true,
      maxContextTokens: 128000,
      maxOutputTokens: 4096,
      supportsStreaming: true,
      isLocal: false,
    );
  }

  List<AiProvider> get _effectiveProviders {
    final list = List<AiProvider>.from(_providers);
    if (preferLocal) {
      // Sort local providers to the front
      list.sort((a, b) {
        if (a.capabilities.isLocal && !b.capabilities.isLocal) return -1;
        if (!a.capabilities.isLocal && b.capabilities.isLocal) return 1;
        return 0;
      });
    }
    return list;
  }

  @override
  Future<AiResult> extract(Schema schema, String content) async {
    final attemptLog = <String>[];
    final warnings = <String>[];
    AiResult? bestPartialResult;

    for (final provider in _effectiveProviders) {
      final pid = provider.id;

      // 1. Egress privacy check
      if (!provider.capabilities.isLocal && !allowCloudEgress) {
        attemptLog.add('$pid: Skipped (allowCloudEgress is false)');
        continue;
      }

      // 2. Configuration check
      if (!provider.isReady) {
        attemptLog.add('$pid: Skipped (provider not configured or ready)');
        continue;
      }

      // 3. Circuit breaker check
      final breaker = _breakers.putIfAbsent(pid, _CircuitBreaker.new);
      if (breaker.isOpen) {
        attemptLog.add('$pid: Skipped (circuit breaker tripped)');
        continue;
      }

      try {
        final result = await _attemptExtractWithRetry(
          provider,
          schema,
          content,
          warnings,
        );

        if (result.isSuccessful) {
          breaker.recordSuccess();
          if (result.usage != null) {
            session?.recordUsage(
              result.usage!,
              pricing: ModelPricing.forModel(pid, capabilities: provider.capabilities),
            );
          }
          return result;
        } else {
          // Keep best partial result in case all fail
          bestPartialResult = result;
          attemptLog.add('$pid: Failed schema validation (${result.error})');
        }
      } on HttpException catch (e) {
        breaker.recordFailure();
        final safeMsg = KeySanitizer.redact(e.message);

        if (e.statusCode == 401 || e.statusCode == 403) {
          // Loud warning for bad/missing key, recorded in warnings
          final warnText =
              'Authentication failed for $pid (HTTP ${e.statusCode}). Check API key or token.';
          developer.log(warnText, name: 'flutter_ai_scrapper.ProviderChain', level: 900);
          warnings.add(warnText);
          attemptLog.add('$pid: Auth failure (HTTP ${e.statusCode})');
        } else if (e.statusCode == 429) {
          warnings.add('Rate limited on $pid (HTTP 429)');
          attemptLog.add('$pid: Rate limited (HTTP 429)');
        } else {
          attemptLog.add('$pid: HTTP error ${e.statusCode}: $safeMsg');
        }
      } catch (e) {
        breaker.recordFailure();
        final safeMsg = KeySanitizer.redact(e.toString());
        attemptLog.add('$pid: Error: $safeMsg');
      }
    }

    if (bestPartialResult != null) {
      return bestPartialResult;
    }

    throw NoProviderAvailableException(
      'All AI providers in chain were exhausted without completing extraction.',
      attemptLog: attemptLog,
    );
  }

  Future<AiResult> _attemptExtractWithRetry(
    AiProvider provider,
    Schema schema,
    String content,
    List<String> warnings,
  ) async {
    try {
      return await provider
          .extract(schema, content)
          .timeout(providerTimeout);
    } on HttpException catch (e) {
      // 429: rate limited - retry with backoff once
      if (e.statusCode == 429) {
        await Future<void>.delayed(const Duration(milliseconds: 500));
        return await provider
            .extract(schema, content)
            .timeout(providerTimeout);
      }
      // 5xx: server error - retry once
      if (e.statusCode != null && e.statusCode! >= 500) {
        await Future<void>.delayed(const Duration(milliseconds: 200));
        return await provider
            .extract(schema, content)
            .timeout(providerTimeout);
      }
      rethrow;
    }
  }

  @override
  Future<String> complete(String prompt) async {
    for (final provider in _effectiveProviders) {
      if (!provider.capabilities.isLocal && !allowCloudEgress) continue;
      if (!provider.isReady) continue;

      try {
        return await provider.complete(prompt).timeout(providerTimeout);
      } catch (_) {
        continue;
      }
    }

    throw const NoProviderAvailableException('All providers exhausted for completion.');
  }

  @override
  Stream<String> stream(String prompt) async* {
    for (final provider in _effectiveProviders) {
      if (!provider.capabilities.isLocal && !allowCloudEgress) continue;
      if (!provider.isReady) continue;

      try {
        yield* provider.stream(prompt);
        return;
      } catch (_) {
        continue;
      }
    }

    throw const NoProviderAvailableException('All providers exhausted for streaming.');
  }

  @override
  Future<void> dispose() async {
    for (final provider in _providers) {
      await provider.dispose();
    }
  }
}
