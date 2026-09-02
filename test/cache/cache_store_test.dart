import 'package:flutter_ai_scrapper/flutter_ai_scrapper.dart';
import 'package:flutter_test/flutter_test.dart';

CacheEntry _entry(
  String url, {
  String body = '<html>body</html>',
  Duration ttl = const Duration(hours: 1),
  String? etag,
  String? lastModified,
}) =>
    CacheEntry(
      url: url,
      body: body,
      cachedAt: DateTime.now(),
      expiresAt: DateTime.now().add(ttl),
      etag: etag,
      lastModified: lastModified,
    );

/// Memory-only, so these tests never touch the filesystem or need a plugin.
CacheStore _memoryStore({int maxEntries = 32}) => CacheStore(
      config: CacheConfig(
        persistToDisk: false,
        maxMemoryEntries: maxEntries,
      ),
    );

void main() {
  group('CacheEntry', () {
    test('is fresh before expiry and stale after', () {
      expect(_entry('u', ttl: const Duration(hours: 1)).isFresh, isTrue);
      expect(
        _entry('u', ttl: const Duration(seconds: -1)).isStale,
        isTrue,
      );
    });

    test('knows whether it can be revalidated', () {
      expect(_entry('u').canRevalidate, isFalse);
      expect(_entry('u', etag: '"abc"').canRevalidate, isTrue);
      expect(_entry('u', lastModified: 'Mon, 1 Jan 2024').canRevalidate, isTrue);
    });

    test('round-trips through JSON', () {
      final original = _entry('https://e.example', etag: '"v1"');
      final restored = CacheEntry.fromJson(original.toJson());

      expect(restored.url, original.url);
      expect(restored.body, original.body);
      expect(restored.etag, '"v1"');
      expect(
        restored.expiresAt.difference(original.expiresAt).inSeconds.abs(),
        lessThan(2),
      );
    });

    test('refreshed keeps the body and the validators', () {
      final stale = CacheEntry(
        url: 'u',
        body: 'kept',
        cachedAt: DateTime(2020),
        expiresAt: DateTime(2020, 1, 2),
        etag: '"v1"',
      );
      final refreshed = stale.refreshed(const Duration(hours: 1));

      expect(refreshed.body, 'kept', reason: 'a 304 transfers no new body');
      expect(refreshed.etag, '"v1"');
      expect(refreshed.isFresh, isTrue);
    });
  });

  group('store', () {
    test('returns what was put in', () async {
      final store = _memoryStore();
      await store.put('https://e.example', _entry('https://e.example'));

      final got = await store.get('https://e.example');
      expect(got?.body, '<html>body</html>');
    });

    test('is a miss for an unknown URL', () async {
      expect(await _memoryStore().get('https://unknown.example'), isNull);
    });

    test('distinguishes URLs that differ only in query', () async {
      final store = _memoryStore();
      await store.put('https://e.example?a=1', _entry('a', body: 'ONE'));
      await store.put('https://e.example?a=2', _entry('b', body: 'TWO'));

      expect((await store.get('https://e.example?a=1'))?.body, 'ONE');
      expect((await store.get('https://e.example?a=2'))?.body, 'TWO');
    });

    test('returns a stale entry so it can be revalidated', () async {
      final store = _memoryStore();
      await store.put(
        'https://e.example',
        _entry('https://e.example',
            ttl: const Duration(seconds: -1), etag: '"v1"'),
      );

      final got = await store.get('https://e.example');
      expect(got, isNotNull,
          reason: 'a stale entry with an ETag is still useful');
      expect(got!.isStale, isTrue);
      expect(got.canRevalidate, isTrue);
    });

    test('contains only reports fresh entries', () async {
      final store = _memoryStore();
      await store.put('https://fresh.example', _entry('f'));
      await store.put(
        'https://stale.example',
        _entry('s', ttl: const Duration(seconds: -1)),
      );

      expect(await store.contains('https://fresh.example'), isTrue);
      expect(await store.contains('https://stale.example'), isFalse);
    });

    test('remove drops an entry', () async {
      final store = _memoryStore();
      await store.put('https://e.example', _entry('e'));
      await store.remove('https://e.example');

      expect(await store.get('https://e.example'), isNull);
    });

    test('clear empties everything', () async {
      final store = _memoryStore();
      await store.put('https://a.example', _entry('a'));
      await store.put('https://b.example', _entry('b'));
      await store.clear();

      expect(await store.get('https://a.example'), isNull);
      expect(await store.get('https://b.example'), isNull);
    });
  });

  group('revalidate', () {
    test('extends life without a new body', () async {
      final store = _memoryStore();
      await store.put(
        'https://e.example',
        _entry('https://e.example',
            body: 'ORIGINAL', ttl: const Duration(seconds: -1), etag: '"v1"'),
      );

      final refreshed = await store.revalidate('https://e.example');

      expect(refreshed?.body, 'ORIGINAL');
      expect(refreshed?.isFresh, isTrue);
    });

    test('is null when nothing is cached', () async {
      expect(await _memoryStore().revalidate('https://nothing.example'), isNull);
    });
  });

  group('LRU eviction', () {
    test('evicts the least recently used entry past the limit', () async {
      final store = _memoryStore(maxEntries: 3);

      for (final key in ['a', 'b', 'c']) {
        await store.put('https://$key.example', _entry(key, body: key));
      }

      // Touch 'a' so 'b' becomes the least recently used.
      await store.get('https://a.example');
      await store.put('https://d.example', _entry('d', body: 'd'));

      expect(await store.get('https://b.example'), isNull,
          reason: 'b was least recently used');
      expect((await store.get('https://a.example'))?.body, 'a');
      expect((await store.get('https://c.example'))?.body, 'c');
      expect((await store.get('https://d.example'))?.body, 'd');
    });

    test('holds the limit under sustained writes', () async {
      final store = _memoryStore(maxEntries: 5);
      for (var i = 0; i < 50; i++) {
        await store.put('https://e$i.example', _entry('e$i'));
      }

      expect(store.stats().memoryEntries, lessThanOrEqualTo(5));
    });
  });

  group('stats', () {
    test('counts hits and misses', () async {
      final store = _memoryStore();
      await store.put('https://e.example', _entry('e'));

      await store.get('https://e.example'); // hit
      await store.get('https://nope.example'); // miss

      final stats = store.stats();
      expect(stats.hits, 1);
      expect(stats.misses, 1);
      expect(stats.hitRate, 0.5);
    });

    test('hit rate is zero with no reads', () {
      expect(_memoryStore().stats().hitRate, 0);
    });
  });
}
