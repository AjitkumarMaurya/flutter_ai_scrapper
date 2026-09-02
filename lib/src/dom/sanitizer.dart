import 'package:html/dom.dart' as dom;

/// Strips non-content nodes from a parsed document.
///
/// This is not optional cleanup. `Element.text` concatenates the text of every
/// descendant, and that includes `<script>` bodies — so the JavaScript source
/// of a page ends up inside its "text" unless the scripts are removed first.
/// Verified against `package:html` 0.15.7: a document containing
/// `<script>var x = "<div>fake</div>";</script>` yields a `body.text`
/// containing `fake`.
abstract final class Sanitizer {
  /// Elements removed entirely, along with their subtrees.
  ///
  /// These carry no readable content, and several of them (`script`, `style`,
  /// `template`) contain source code that would otherwise pollute text
  /// extraction.
  static const Set<String> defaultRemovedTags = {
    'script',
    'style',
    'noscript',
    'template',
    'svg',
    'canvas',
    'object',
    'embed',
    'applet',
    'link',
    'base',
    'param',
  };

  /// Additionally removed when extracting readable content.
  ///
  /// Kept separate from [defaultRemovedTags] because these *do* contain real
  /// text — a caller scraping a site's navigation legitimately wants `<nav>`.
  /// Only the readability path discards them.
  static const Set<String> chromeTags = {
    'nav',
    'header',
    'footer',
    'aside',
    'form',
    'button',
    'dialog',
    'menu',
  };

  /// Removes non-content nodes from [document], in place.
  ///
  /// Returns the same document for chaining. Pass [removeChrome] to also drop
  /// [chromeTags], and [additionalTags] to remove more.
  static dom.Document sanitize(
    dom.Document document, {
    bool removeChrome = false,
    Set<String> additionalTags = const {},
    bool removeComments = true,
    bool removeHiddenElements = true,
  }) {
    final tags = <String>{
      ...defaultRemovedTags,
      if (removeChrome) ...chromeTags,
      ...additionalTags,
    };

    for (final tag in tags) {
      for (final element in document.querySelectorAll(tag).toList()) {
        element.remove();
      }
    }

    if (removeComments) _removeComments(document);
    if (removeHiddenElements) _removeHidden(document);

    return document;
  }

  static void _removeComments(dom.Node node) {
    for (final child in node.nodes.toList()) {
      if (child.nodeType == dom.Node.COMMENT_NODE) {
        child.remove();
      } else {
        _removeComments(child);
      }
    }
  }

  /// Drops elements the page itself has hidden.
  ///
  /// Anything behind `hidden`, `aria-hidden="true"`, `display:none` or
  /// `visibility:hidden` is invisible to a reader, so counting it as content
  /// pulls in tracking pixels, offscreen SEO text and collapsed menus.
  static void _removeHidden(dom.Document document) {
    for (final element in document.querySelectorAll('[hidden]').toList()) {
      element.remove();
    }

    for (final element
        in document.querySelectorAll('[aria-hidden]').toList()) {
      if (element.attributes['aria-hidden']?.toLowerCase() == 'true') {
        element.remove();
      }
    }

    for (final element in document.querySelectorAll('[style]').toList()) {
      final style =
          element.attributes['style']?.toLowerCase().replaceAll(' ', '') ?? '';
      if (style.contains('display:none') ||
          style.contains('visibility:hidden')) {
        element.remove();
      }
    }
  }
}
