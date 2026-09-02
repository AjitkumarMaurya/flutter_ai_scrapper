import 'package:flutter_ai_scrapper/flutter_ai_scrapper.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('RecipeStore', () {
    test('stores and retrieves recipes by host and schemaHash', () {
      final store = RecipeStore();

      final recipe = Recipe(
        id: 'r1',
        host: 'shop.example',
        schemaHash: 'hash_123',
        fields: {'name': const FieldSelector(selector: 'h1')},
      );

      store.put(recipe);

      final retrieved = store.get('shop.example', 'hash_123');
      expect(retrieved, isNotNull);
      expect(retrieved!.id, 'r1');

      // Case-insensitive host lookup
      expect(store.get('SHOP.EXAMPLE', 'hash_123'), isNotNull);

      // Missing hash returns null
      expect(store.get('shop.example', 'other_hash'), isNull);
    });

    test('evicts expired recipes based on TTL', () {
      final store = RecipeStore();

      final expiredRecipe = Recipe(
        id: 'expired_r',
        host: 'shop.example',
        schemaHash: 'hash_expired',
        fields: {'name': const FieldSelector(selector: 'h1')},
        createdAt: DateTime.now().subtract(const Duration(days: 10)),
        ttl: const Duration(days: 7), // Expired 3 days ago
      );

      store.put(expiredRecipe);

      expect(store.get('shop.example', 'hash_expired'), isNull);
      expect(store.count, 0); // Evicted on access
    });
  });
}
