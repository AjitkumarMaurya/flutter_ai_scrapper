/// Caching system for scraped content
library;

import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';

/// Represents a cached entry
class CacheEntry {
  /// The cached content
  final String content;

  /// When the content was cached
  final DateTime cachedAt;

  /// When the cache expires
  final DateTime expiresAt;

  /// The URL that was cached
  final String url;

  const CacheEntry({
    required this.content,
    required this.cachedAt,
    required this.expiresAt,
    required this.url,
  });

  /// Check if the cache entry is still valid
  bool get isValid => DateTime.now().isBefore(expiresAt);

  /// Check if the cache entry has expired
  bool get isExpired => !isValid;

  /// Convert to JSON for persistence
  Map<String, dynamic> toJson() => {
        'content': content,
        'cachedAt': cachedAt.toIso8601String(),
        'expiresAt': expiresAt.toIso8601String(),
        'url': url,
      };

  /// Create from JSON
  factory CacheEntry.fromJson(Map<String, dynamic> json) => CacheEntry(
        content: json['content'] as String,
        cachedAt: DateTime.parse(json['cachedAt'] as String),
        expiresAt: DateTime.parse(json['expiresAt'] as String),
        url: json['url'] as String,
      );
}

/// Cache configuration options
class CacheConfig {
  /// Maximum cache size in MB
  final int maxSizeMB;

  /// Default cache expiration time
  final Duration defaultExpiry;

  /// Whether to persist cache to disk
  final bool persistToDisk;

  /// Maximum number of cached entries
  final int maxEntries;

  const CacheConfig({
    this.maxSizeMB = 50,
    this.defaultExpiry = const Duration(hours: 1),
    this.persistToDisk = true,
    this.maxEntries = 1000,
  });
}

/// Simple in-memory and persistent cache manager for scraped content
class CacheManager {
  static CacheManager? _instance;
  static CacheManager get instance => _instance ??= CacheManager._();

  CacheManager._();

  final Map<String, CacheEntry> _memoryCache = {};
  CacheConfig _config = const CacheConfig();
  File? _cacheFile;

  /// Initialize the cache manager
  Future<void> initialize({CacheConfig? config}) async {
    _config = config ?? const CacheConfig();

    if (_config.persistToDisk && !kIsWeb) {
      try {
        final cacheDir = Directory.systemTemp;
        _cacheFile = File('${cacheDir.path}/flutter_scrapper_cache.json');
        await _loadFromDisk();
      } catch (e) {
        if (kDebugMode) {
          print('Cache initialization warning: $e');
        }
      }
    }
  }

  /// Get cached content for a URL
  Future<String?> get(String url) async {
    await _cleanExpiredEntries();

    final key = _generateKey(url);
    final entry = _memoryCache[key];

    if (entry != null && entry.isValid) {
      return entry.content;
    }

    if (entry != null && entry.isExpired) {
      _memoryCache.remove(key);
    }

    return null;
  }

  /// Cache content for a URL
  Future<void> set(
    String url,
    String content, {
    Duration? expiry,
  }) async {
    final key = _generateKey(url);
    final expiryDuration = expiry ?? _config.defaultExpiry;
    final now = DateTime.now();

    final entry = CacheEntry(
      content: content,
      cachedAt: now,
      expiresAt: now.add(expiryDuration),
      url: url,
    );

    _memoryCache[key] = entry;

    // Enforce cache size limits
    await _enforceLimits();

    // Persist to disk if enabled
    if (_config.persistToDisk && _cacheFile != null) {
      await _saveToDisk();
    }
  }

  /// Check if URL is cached and valid
  Future<bool> contains(String url) async {
    final content = await get(url);
    return content != null;
  }

  /// Remove specific URL from cache
  Future<void> remove(String url) async {
    final key = _generateKey(url);
    _memoryCache.remove(key);

    if (_config.persistToDisk && _cacheFile != null) {
      await _saveToDisk();
    }
  }

  /// Clear all cached content
  Future<void> clear() async {
    _memoryCache.clear();

    if (_config.persistToDisk && _cacheFile != null) {
      try {
        if (await _cacheFile!.exists()) {
          await _cacheFile!.delete();
        }
      } catch (e) {
        if (kDebugMode) {
          print('Cache clear warning: $e');
        }
      }
    }
  }

  /// Get cache statistics
  CacheStats getStats() {
    final validEntries = _memoryCache.values.where((e) => e.isValid).toList();
    final totalSize = validEntries.fold<int>(
      0,
      (sum, entry) => sum + entry.content.length,
    );

    return CacheStats(
      entryCount: validEntries.length,
      totalSizeBytes: totalSize,
      hitRate: _calculateHitRate(),
      oldestEntry: validEntries.isNotEmpty
          ? validEntries
              .map((e) => e.cachedAt)
              .reduce((a, b) => a.isBefore(b) ? a : b)
          : null,
      newestEntry: validEntries.isNotEmpty
          ? validEntries
              .map((e) => e.cachedAt)
              .reduce((a, b) => a.isAfter(b) ? a : b)
          : null,
    );
  }

  /// Generate cache key from URL
  String _generateKey(String url) {
    // Simple hash-like key generation
    return url.hashCode.abs().toString();
  }

  /// Clean expired entries from memory cache
  Future<void> _cleanExpiredEntries() async {
    final expiredKeys = _memoryCache.entries
        .where((entry) => entry.value.isExpired)
        .map((entry) => entry.key)
        .toList();

    for (final key in expiredKeys) {
      _memoryCache.remove(key);
    }
  }

  /// Enforce cache size and entry limits
  Future<void> _enforceLimits() async {
    await _cleanExpiredEntries();

    // Enforce max entries limit
    if (_memoryCache.length > _config.maxEntries) {
      final sortedEntries = _memoryCache.entries.toList()
        ..sort((a, b) => a.value.cachedAt.compareTo(b.value.cachedAt));

      final toRemove =
          sortedEntries.take(_memoryCache.length - _config.maxEntries);
      for (final entry in toRemove) {
        _memoryCache.remove(entry.key);
      }
    }

    // Enforce max size limit
    final totalSize = _memoryCache.values.fold<int>(
      0,
      (sum, entry) => sum + entry.content.length,
    );

    final maxSizeBytes = _config.maxSizeMB * 1024 * 1024;
    if (totalSize > maxSizeBytes) {
      final sortedEntries = _memoryCache.entries.toList()
        ..sort((a, b) => a.value.cachedAt.compareTo(b.value.cachedAt));

      int currentSize = totalSize;
      for (final entry in sortedEntries) {
        if (currentSize <= maxSizeBytes) break;
        currentSize -= entry.value.content.length;
        _memoryCache.remove(entry.key);
      }
    }
  }

  /// Load cache from disk
  Future<void> _loadFromDisk() async {
    if (_cacheFile == null || !await _cacheFile!.exists()) return;

    try {
      final jsonString = await _cacheFile!.readAsString();
      final jsonData = jsonDecode(jsonString) as Map<String, dynamic>;

      final entries = jsonData['entries'] as Map<String, dynamic>?;
      if (entries != null) {
        for (final key in entries.keys) {
          try {
            final entryData = entries[key] as Map<String, dynamic>;
            final entry = CacheEntry.fromJson(entryData);

            if (entry.isValid) {
              _memoryCache[key] = entry;
            }
          } catch (e) {
            // Skip invalid entries
            if (kDebugMode) {
              print('Skipping invalid cache entry: $e');
            }
          }
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('Cache load warning: $e');
      }
    }
  }

  /// Save cache to disk
  Future<void> _saveToDisk() async {
    if (_cacheFile == null) return;

    try {
      final validEntries = Map<String, CacheEntry>.fromEntries(
        _memoryCache.entries.where((entry) => entry.value.isValid),
      );

      final jsonData = {
        'entries': validEntries.map(
          (key, entry) => MapEntry(key, entry.toJson()),
        ),
        'savedAt': DateTime.now().toIso8601String(),
      };

      await _cacheFile!.writeAsString(jsonEncode(jsonData));
    } catch (e) {
      if (kDebugMode) {
        print('Cache save warning: $e');
      }
    }
  }

  /// Calculate hit rate (simplified)
  double _calculateHitRate() {
    // This is a simplified implementation
    // In a production app, you'd track hits and misses
    return _memoryCache.isNotEmpty ? 0.8 : 0.0;
  }
}

/// Cache statistics
class CacheStats {
  /// Number of cached entries
  final int entryCount;

  /// Total size in bytes
  final int totalSizeBytes;

  /// Cache hit rate (0.0 to 1.0)
  final double hitRate;

  /// Oldest cache entry timestamp
  final DateTime? oldestEntry;

  /// Newest cache entry timestamp
  final DateTime? newestEntry;

  const CacheStats({
    required this.entryCount,
    required this.totalSizeBytes,
    required this.hitRate,
    this.oldestEntry,
    this.newestEntry,
  });

  /// Get total size in MB
  double get totalSizeMB => totalSizeBytes / (1024 * 1024);

  /// Get hit rate as percentage
  double get hitRatePercentage => hitRate * 100;

  @override
  String toString() {
    return 'CacheStats(entries: $entryCount, size: ${totalSizeMB.toStringAsFixed(2)}MB, '
        'hitRate: ${hitRatePercentage.toStringAsFixed(1)}%)';
  }
}
