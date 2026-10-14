import 'dart:collection';

class CacheStore<T> {
  final int maxEntries;
  final Duration defaultTtl;
  final LinkedHashMap<String, _CacheItem<T>> _map = LinkedHashMap();

  CacheStore({
    this.maxEntries = 100,
    this.defaultTtl = const Duration(minutes: 30),
  });

  T? get(String key) {
    final item = _map.remove(key);
    if (item == null) return null;

    if (DateTime.now().isAfter(item.expiresAt)) {
      return null;
    }

    // Re-insert to mark as most recently used (LRU)
    _map[key] = item;
    return item.value;
  }

  void set(String key, T value, {Duration? ttl}) {
    if (_map.length >= maxEntries && !_map.containsKey(key)) {
      _map.remove(_map.keys.first);
    }
    _map.remove(key);
    _map[key] = _CacheItem<T>(
      value: value,
      expiresAt: DateTime.now().add(ttl ?? defaultTtl),
    );
  }

  void invalidate(String key) => _map.remove(key);

  void clear() => _map.clear();

  int get length => _map.length;
}

class _CacheItem<T> {
  final T value;
  final DateTime expiresAt;

  const _CacheItem({required this.value, required this.expiresAt});
}
