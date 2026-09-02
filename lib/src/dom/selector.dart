import '../core/scraper_exceptions.dart';

/// Guards CSS selectors against the parser's real capabilities.
///
/// `package:html` implements a subset of CSS, and its failure modes are
/// uneven: `:has()` throws [UnimplementedError], while `li:nth-child(2)` and
/// `p:first-child` return **zero matches** on markup that plainly contains
/// them. A silently empty result is the worse of the two — it looks like "this
/// page has no such element" and sends the caller hunting through their HTML
/// for a problem that is really in the parser.
///
/// So unsupported constructs are rejected up front with a message that says
/// what to do instead. Wrong answers are worse than refusals.
abstract final class SelectorGuard {
  /// Pseudo-classes and combinators the parser cannot evaluate reliably.
  ///
  /// Each entry pairs the token with the workaround suggested to the caller.
  static const Map<String, String> _unsupported = {
    ':has': 'select the child, then walk up with .parent',
    ':not': 'select broadly, then filter the results in Dart',
    ':nth-child': 'select all matches, then index the returned list',
    ':nth-of-type': 'select all matches, then index the returned list',
    ':nth-last-child': 'select all matches, then index from the end in Dart',
    ':first-child': 'select all matches and take .first',
    ':last-child': 'select all matches and take .last',
    ':first-of-type': 'select all matches and take .first',
    ':last-of-type': 'select all matches and take .last',
    ':only-child': 'select all matches, then check the parent in Dart',
    ':empty': 'select all matches, then check .text in Dart',
    ':contains': 'select all matches, then filter on .text in Dart',
  };

  /// Sibling combinators, which `package:html` does not implement.
  static const Map<String, String> _unsupportedCombinators = {
    '~': 'select the shared parent, then walk .children in Dart',
    '+': 'select the shared parent, then walk .children in Dart',
  };

  /// Throws [InvalidSelectorException] if [selector] cannot be evaluated.
  ///
  /// Call this before handing a selector to the parser.
  static void validate(String selector) {
    final trimmed = selector.trim();
    if (trimmed.isEmpty) {
      throw const InvalidSelectorException('', 'selector is empty');
    }

    final lower = trimmed.toLowerCase();

    for (final entry in _unsupported.entries) {
      if (lower.contains(entry.key)) {
        throw InvalidSelectorException(
          selector,
          'the "${entry.key}" pseudo-class is not supported by the HTML '
          'parser. Instead, ${entry.value}. '
          '${InvalidSelectorException.unsupportedSelectorHelp}',
        );
      }
    }

    for (final entry in _unsupportedCombinators.entries) {
      // Only flag a real combinator: `a ~ b`, not an attribute match like
      // `[title~=foo]`, where the character sits inside brackets.
      if (_containsCombinator(trimmed, entry.key)) {
        throw InvalidSelectorException(
          selector,
          'the "${entry.key}" sibling combinator is not supported by the HTML '
          'parser. Instead, ${entry.value}. '
          '${InvalidSelectorException.unsupportedSelectorHelp}',
        );
      }
    }
  }

  /// Whether [selector] uses [combinator] outside of an attribute clause.
  static bool _containsCombinator(String selector, String combinator) {
    var depth = 0;
    for (var i = 0; i < selector.length; i++) {
      final char = selector[i];
      if (char == '[') {
        depth++;
      } else if (char == ']') {
        if (depth > 0) depth--;
      } else if (depth == 0 && char == combinator) {
        return true;
      }
    }
    return false;
  }
}
