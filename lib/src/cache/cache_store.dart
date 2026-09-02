import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:path_provider/path_provider.dart';

/// One cached response.
class CacheEntry {
  /// Creates a cache entry.
  const CacheEntry({
    required this.url,
    required this.body,
    required this.cachedAt,
    required this.expiresAt,
    this.etag,
    this.lastModified,
    this.contentType,
  });

  /// Rebuilds an entry from its JSON form.
  factory CacheEntry.fromJson(Map<String, dynamic> json) => CacheEntry(
        url: json['url'] as String,
        body: json['body'] as String,
        cachedAt: DateTime.parse(json['cachedAt'] as String),
        expiresAt: DateTime.parse(json['expiresAt'] as String),
        etag: json['etag'] as String?,
        lastModified: json['lastModified'] as String?,
        contentType: json['contentType'] as String?,
      );

  /// The URL this was fetched from.
  final String url;

  /// The cached body.
  final String body;

  /// When it was stored.
  final DateTime cachedAt;

  /// When it stops being served without revalidation.
  final DateTime expiresAt;

  /// The response `ETag`, for conditional requests.
  final String? etag;

  /// The response `Last-Modified`, for conditional requests.
  final String? lastModified;

  /// The response `Content-Type`.
  final String? contentType;

  /// Whether this can still be served directly.
  bool get isFresh => DateTime.now().isBefore(expiresAt);

  /// Whether this has passed its freshness window.
  ///
  /// A stale entry is not useless: if it carries an [etag] or [lastModified] it
  /// can still be revalidated with a conditional request, and a `304` refreshes
  /// it without transferring the body again.
  bool get isStale => !isFresh;

  /// Whether this entry can be revalidated rather than refetched.
  bool get canRevalidate => etag != null || lastModified != null;

  /// Approximate size in bytes.
  int get sizeBytes => body.length * 2; // Dart strings are UTF-16.

  /// This entry as JSON.
  Map<String, dynamic> toJson() => {
        'url': url,
        'body': body,
        'cachedAt': cachedAt.toIso8601String(),
        'expiresAt': expiresAt.toIso8601String(),
        if (etag != null) 'etag': etag,
        if (lastModified != null) 'lastModified': lastModified,
        if (contentType != null) 'contentType': contentType,
      };

  /// Copies this entry with a new expiry, keeping the body.
  ///
  /// What a `304 Not Modified` response calls for.
  CacheEntry refreshed(Duration ttl) => CacheEntry(
        url: url,
        body: body,
        cachedAt: DateTime.now(),
        expiresAt: DateTime.now().add(ttl),
        etag: etag,
        lastModified: lastModified,
        contentType: contentType,
      );
}

/// Cache sizing and location.
class CacheConfig {
  /// Creates a cache configuration.
  const CacheConfig({
    this.maxMemoryEntries = 32,
    this.maxDiskEntries = 500,
    this.maxDiskBytes = 50 * 1024 * 1024,
    this.defaultTtl = const Duration(hours: 1),
    this.persistToDisk = true,
    this.directoryName = 'flutter_ai_scrapper_cache',
  });

  /// Entries held in memory.
  final int maxMemoryEntries;

  /// Entries held on disk.
  final int maxDiskEntries;

  /// Disk budget in bytes.
  final int maxDiskBytes;

  /// Freshness window when a response does not specify one.
  final Duration defaultTtl;

  /// Whether entries survive process restart.
  final bool persistToDisk;

  /// Subdirectory name under the app's documents directory.
  final String directoryName;
}

/// Statistics for a [CacheStore].
class CacheStats {
  /// Creates a statistics snapshot.
  const CacheStats({
    required this.memoryEntries,
    required this.diskEntries,
    required this.diskBytes,
    required this.hits,
    required this.misses,
    required this.revalidations,
  });

  /// Entries currently in memory.
  final int memoryEntries;

  /// Entries currently on disk.
  final int diskEntries;

  /// Bytes currently on disk.
  final int diskBytes;

  /// Reads served from cache.
  final int hits;

  /// Reads that had to go to the network.
  final int misses;

  /// Stale entries confirmed still-current by a `304`.
  final int revalidations;

  /// Share of reads served from cache, from 0.0 to 1.0.
  double get hitRate {
    final total = hits + misses;
    return total == 0 ? 0 : hits / total;
  }

  @override
  String toString() => 'CacheStats(memory: $memoryEntries, disk: $diskEntries, '
      '${(diskBytes / 1024).toStringAsFixed(1)}KB, '
      'hitRate: ${(hitRate * 100).toStringAsFixed(1)}%)';
}

/// A two-tier LRU cache: hot entries in memory, the rest on disk.
///
/// The 1.x cache had three problems this replaces:
///
/// - It lived in `Directory.systemTemp`, which the OS may clear at any time —
///   so the "persistent" cache silently was not.
/// - It serialised **every** entry into one JSON file and rewrote the whole
///   file on each write, so cost grew with the size of the cache.
/// - It never sent `If-None-Match` or `If-Modified-Since`, so an expired entry
///   meant refetching the full body even when nothing had changed.
class CacheStore {
  /// Creates a cache store.
  CacheStore({CacheConfig? config}) : config = config ?? const CacheConfig();

  /// The active configuration.
  final CacheConfig config;

  /// LRU ordering comes from `LinkedHashMap` insertion order: a read
  /// re-inserts its key at the end, so the eviction candidate is always
  /// `keys.first`.
  final LinkedHashMap<String, CacheEntry> _memory =
      LinkedHashMap<String, CacheEntry>();

  Directory? _directory;
  bool _initialized = false;
  int _hits = 0;
  int _misses = 0;
  int _revalidations = 0;

  /// Prepares the on-disk cache directory.
  ///
  /// Safe to call repeatedly; only the first call does work. Disk failures are
  /// swallowed deliberately — a cache that cannot write is a slow cache, not a
  /// broken scraper — and the store falls back to memory only.
  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;

    if (!config.persistToDisk) return;

    try {
      final documents = await getApplicationDocumentsDirectory();
      final directory = Directory('${documents.path}/${config.directoryName}');
      if (!directory.existsSync()) {
        directory.createSync(recursive: true);
      }
      _directory = directory;
    } on Object {
      _directory = null;
    }
  }

  /// The entry for [url], fresh or stale, or `null` if there is none.
  ///
  /// A stale entry is still returned so the caller can revalidate it with a
  /// conditional request. Check [CacheEntry.isFresh] before serving it.
  Future<CacheEntry?> get(String url) async {
    await initialize();
    final key = _keyFor(url);

    final cached = _memory.remove(key);
    if (cached != null) {
      _memory[key] = cached; // re-insert: most recently used
      cached.isFresh ? _hits++ : _misses++;
      return cached;
    }

    final fromDisk = await _readFromDisk(key);
    if (fromDisk != null) {
      _putInMemory(key, fromDisk);
      fromDisk.isFresh ? _hits++ : _misses++;
      return fromDisk;
    }

    _misses++;
    return null;
  }

  /// Stores [entry] against [url].
  Future<void> put(String url, CacheEntry entry) async {
    await initialize();
    final key = _keyFor(url);

    _putInMemory(key, entry);
    await _writeToDisk(key, entry);
    await _enforceDiskLimits();
  }

  /// Extends an existing entry's life after a `304 Not Modified`.
  ///
  /// Returns the refreshed entry, or `null` when nothing was cached.
  Future<CacheEntry?> revalidate(String url, {Duration? ttl}) async {
    final existing = await get(url);
    if (existing == null) return null;

    _revalidations++;
    final refreshed = existing.refreshed(ttl ?? config.defaultTtl);
    await put(url, refreshed);
    return refreshed;
  }

  /// Whether a fresh entry exists for [url].
  Future<bool> contains(String url) async =>
      (await get(url))?.isFresh ?? false;

  /// Removes the entry for [url].
  Future<void> remove(String url) async {
    await initialize();
    final key = _keyFor(url);
    _memory.remove(key);

    final file = _fileFor(key);
    if (file != null && file.existsSync()) {
      try {
        file.deleteSync();
      } on FileSystemException {
        // A file we cannot delete is not worth failing the caller over.
      }
    }
  }

  /// Empties the cache, in memory and on disk.
  Future<void> clear() async {
    await initialize();
    _memory.clear();

    final directory = _directory;
    if (directory != null && directory.existsSync()) {
      try {
        for (final entity in directory.listSync()) {
          if (entity is File) entity.deleteSync();
        }
      } on FileSystemException {
        // Best effort.
      }
    }
  }

  /// A snapshot of cache statistics.
  CacheStats stats() {
    var diskEntries = 0;
    var diskBytes = 0;

    final directory = _directory;
    if (directory != null && directory.existsSync()) {
      try {
        for (final entity in directory.listSync()) {
          if (entity is File) {
            diskEntries++;
            diskBytes += entity.lengthSync();
          }
        }
      } on FileSystemException {
        // Report what we have.
      }
    }

    return CacheStats(
      memoryEntries: _memory.length,
      diskEntries: diskEntries,
      diskBytes: diskBytes,
      hits: _hits,
      misses: _misses,
      revalidations: _revalidations,
    );
  }

  void _putInMemory(String key, CacheEntry entry) {
    _memory
      ..remove(key)
      ..[key] = entry;

    while (_memory.length > config.maxMemoryEntries) {
      _memory.remove(_memory.keys.first); // evict least recently used
    }
  }

  Future<CacheEntry?> _readFromDisk(String key) async {
    final file = _fileFor(key);
    if (file == null || !file.existsSync()) return null;

    try {
      final json = jsonDecode(await file.readAsString());
      if (json is! Map<String, dynamic>) return null;
      return CacheEntry.fromJson(json);
    } on Object {
      // Corrupt entry: drop it rather than let it fail every future read.
      try {
        file.deleteSync();
      } on FileSystemException {
        // Ignore.
      }
      return null;
    }
  }

  Future<void> _writeToDisk(String key, CacheEntry entry) async {
    final file = _fileFor(key);
    if (file == null) return;

    try {
      await file.writeAsString(jsonEncode(entry.toJson()));
    } on Object {
      // A cache that cannot write is a slow cache, not a broken scraper.
    }
  }

  /// Evicts oldest-first until the entry and byte budgets are met.
  Future<void> _enforceDiskLimits() async {
    final directory = _directory;
    if (directory == null || !directory.existsSync()) return;

    try {
      final files = directory
          .listSync()
          .whereType<File>()
          .map((f) => (file: f, modified: f.lastModifiedSync()))
          .toList()
        ..sort((a, b) => a.modified.compareTo(b.modified));

      var totalBytes = 0;
      for (final entry in files) {
        totalBytes += entry.file.lengthSync();
      }

      var count = files.length;
      for (final entry in files) {
        if (count <= config.maxDiskEntries &&
            totalBytes <= config.maxDiskBytes) {
          break;
        }
        final size = entry.file.lengthSync();
        entry.file.deleteSync();
        totalBytes -= size;
        count--;
      }
    } on FileSystemException {
      // Best effort.
    }
  }

  File? _fileFor(String key) {
    final directory = _directory;
    return directory == null ? null : File('${directory.path}/$key.json');
  }

  /// A filesystem-safe, collision-resistant key for [url].
  static String _keyFor(String url) =>
      sha256.convert(utf8.encode(url)).toString();
}
