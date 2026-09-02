/// Persistence and lifecycle management for site selector recipes.
library;

import 'recipe.dart';

/// Strategy for handling recipes when structural site drift is detected.
enum RepairPolicy {
  /// Re-synthesize a new recipe using the structural skeleton and an AI provider.
  resynthesize,

  /// Fall back to normal per-page LLM extraction.
  fallbackToAi,

  /// Cease execution and return partial or empty results.
  fail,
}

/// Store caching site extraction recipes per host and schema signature.
class RecipeStore {
  /// Creates an in-memory [RecipeStore].
  RecipeStore({
    this.defaultPolicy = RepairPolicy.resynthesize,
  });

  /// Default policy when a recipe experiences drift.
  final RepairPolicy defaultPolicy;

  final Map<String, Recipe> _cache = {};

  static String _key(String host, String schemaHash) =>
      '${host.toLowerCase()}:$schemaHash';

  /// Retrieves a valid, unexpired recipe for [host] and [schemaHash].
  Recipe? get(String host, String schemaHash) {
    final key = _key(host, schemaHash);
    final recipe = _cache[key];
    if (recipe == null) return null;

    if (recipe.isExpired) {
      _cache.remove(key);
      return null;
    }

    return recipe;
  }

  /// Stores or updates a [recipe].
  void put(Recipe recipe) {
    final key = _key(recipe.host, recipe.schemaHash);
    _cache[key] = recipe;
  }

  /// Deletes a recipe for [host] and [schemaHash].
  void delete(String host, String schemaHash) {
    _cache.remove(_key(host, schemaHash));
  }

  /// Clears all cached recipes.
  void clear() => _cache.clear();

  /// Total number of stored recipes.
  int get count => _cache.length;
}
