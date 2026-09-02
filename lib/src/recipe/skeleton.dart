/// Structural DOM skeletonizer for token-efficient selector synthesis.
library;

import 'package:html/dom.dart' as dom;

import '../dom/html_document.dart';
import '../reduce/token_estimator.dart';

/// Produces a compact, token-efficient structural representation of a document.
abstract final class StructuralSkeleton {
  static const _ignoredTags = {
    'script',
    'style',
    'svg',
    'noscript',
    'iframe',
    'head',
    'meta',
    'link',
  };

  /// Generates a structural skeleton from [document].
  ///
  /// Text is elided, repeated sibling elements are collapsed into representative
  /// nodes with counts (`[xN]`), and tag attributes are restricted to `id` and `class`.
  static String build(
    HtmlDocument document, {
    int maxDepth = 8,
    int maxTokens = 1500,
  }) {
    final body = document.raw.body;
    if (body == null) return '<body/>';

    final sb = StringBuffer();
    _renderNode(body, sb, 0, maxDepth);

    final skeleton = sb.toString();
    final tokens = TokenEstimator.estimate(skeleton);

    if (tokens > maxTokens && maxDepth > 4) {
      // Recursively trim depth if over budget
      return build(document, maxDepth: maxDepth - 2, maxTokens: maxTokens);
    }

    return skeleton;
  }

  static void _renderNode(
    dom.Element element,
    StringBuffer sb,
    int depth,
    int maxDepth,
  ) {
    if (depth > maxDepth) return;

    final tagName = element.localName?.toLowerCase() ?? '';
    if (tagName.isEmpty || _ignoredTags.contains(tagName)) return;

    final indent = '  ' * depth;
    final classes = element.classes.isNotEmpty
        ? ' class="${element.classes.join(' ')}"'
        : '';
    final id = element.id.isNotEmpty ? ' id="${element.id}"' : '';

    // Filter structural children
    final childElements = element.children
        .where((c) => !_ignoredTags.contains(c.localName?.toLowerCase()))
        .toList();

    if (childElements.isEmpty) {
      final hasText = element.text.trim().isNotEmpty;
      if (hasText) {
        sb.writeln('$indent<$tagName$id$classes>_text_</$tagName>');
      } else {
        sb.writeln('$indent<$tagName$id$classes/>');
      }
      return;
    }

    // Group and collapse consecutive identical siblings
    sb.writeln('$indent<$tagName$id$classes>');

    var i = 0;
    while (i < childElements.length) {
      final current = childElements[i];
      final currentKey = _nodeSignature(current);

      var repeatCount = 1;
      while (i + repeatCount < childElements.length &&
          _nodeSignature(childElements[i + repeatCount]) == currentKey) {
        repeatCount++;
      }

      if (repeatCount > 2) {
        // Collapsed repeated siblings annotated with count
        final childIndent = '  ' * (depth + 1);
        final tag = current.localName?.toLowerCase() ?? '';
        final childClasses = current.classes.isNotEmpty
            ? ' class="${current.classes.join(' ')}"'
            : '';
        final childId = current.id.isNotEmpty ? ' id="${current.id}"' : '';

        sb.writeln('$childIndent<!-- repeated $repeatCount times -->');
        sb.writeln('$childIndent<$tag$childId$childClasses count="$repeatCount">');
        for (final grandChild in current.children) {
          _renderNode(grandChild, sb, depth + 2, maxDepth);
        }
        sb.writeln('$childIndent</$tag>');

        i += repeatCount;
      } else {
        _renderNode(current, sb, depth + 1, maxDepth);
        i++;
      }
    }

    sb.writeln('$indent</$tagName>');
  }

  static String _nodeSignature(dom.Element el) {
    final tag = el.localName?.toLowerCase() ?? '';
    final classes = el.classes.join('.');
    return '$tag.$classes';
  }
}
