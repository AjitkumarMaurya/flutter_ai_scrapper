/// Readability DOM node scoring engine and article extractor.
library;

import 'dart:math' as math;

import 'package:html/dom.dart' as dom;

import '../dom/html_document.dart';
import '../dom/url_resolver.dart';
import '../utils/content_formatter.dart';
import '../utils/smart_extractor.dart';

/// An article extracted from a page via the readability engine.
class Article {
  /// Creates an [Article].
  const Article({
    required this.markdown,
    required this.text,
    this.title,
    this.byline,
    this.publishDate,
    this.images = const [],
    required this.readingTime,
  });

  /// The article body rendered as Markdown.
  final String markdown;

  /// The plain text content of the article body.
  final String text;

  /// The title of the article.
  final String? title;

  /// The author or byline.
  final String? byline;

  /// The publication date string.
  final String? publishDate;

  /// Image URLs found within the article body.
  final List<String> images;

  /// Estimated reading time.
  final Duration readingTime;

  @override
  String toString() =>
      'Article(title: $title, byline: $byline, words: ${ContentFormatter.wordCount(text)})';
}

/// Scores DOM nodes to identify the main article container, eliminating chrome.
abstract final class ReadabilityScorer {
  static final RegExp _negativePattern = RegExp(
    r'comment|sidebar|footer|nav|ad|promo|social|share|related|widget|banner|sponsor|disqus|cookie|popup|modal',
    caseSensitive: false,
  );

  static final RegExp _positivePattern = RegExp(
    r'article|content|post|entry|main|body|story|prose|text',
    caseSensitive: false,
  );

  /// Extracts the main article from [document].
  static Article extractArticle(HtmlDocument document) {
    // 1. Work on a sanitized clone without scripts, styles, etc.
    final clone = HtmlDocument.parse(document.raw.outerHtml, url: document.url)
        .sanitize();

    final body = clone.body?.raw;
    if (body == null) {
      return Article(
        markdown: '',
        text: '',
        readingTime: Duration.zero,
      );
    }

    // 2. Score candidates
    final candidateScores = <dom.Element, double>{};
    _scoreTree(body, candidateScores);

    // 3. Find top candidate
    dom.Element? topCandidate;
    var maxScore = -1.0;

    for (final entry in candidateScores.entries) {
      if (entry.value > maxScore) {
        maxScore = entry.value;
        topCandidate = entry.key;
      }
    }

    // If no candidate scored well, fall back to body or semantic tags
    topCandidate ??= clone.selectFirst('article')?.raw ??
        clone.selectFirst('main')?.raw ??
        clone.selectFirst('[role=main]')?.raw ??
        body;

    // 4. Sibling inclusion
    final selectedElements = _collectSiblings(topCandidate, candidateScores, maxScore);

    // 5. Extract images within selected elements
    final articleImages = <String>[];
    for (final elem in selectedElements) {
      for (final img in elem.querySelectorAll('img')) {
        final src = img.attributes['src'] ?? img.attributes['data-src'];
        if (src != null && src.isNotEmpty) {
          final resolved = UrlResolver.resolve(src, document.baseUrl) ?? src;
          articleImages.add(resolved);
        }
      }
    }

    // 6. Convert selected elements to clean Markdown & Text
    final container = dom.Element.tag('div');
    for (final elem in selectedElements) {
      container.append(elem.clone(true));
    }

    final containerDoc = HtmlDocument.parse(container.outerHtml, url: document.url);
    final markdown = ContentFormatter.toMarkdown(containerDoc);
    final text = ContentFormatter.toPlainText(containerDoc);

    final title = SmartExtractor.extractTitle(document);
    final byline = SmartExtractor.extractAuthor(document);
    final publishDate = SmartExtractor.extractPublishDate(document);
    final readingTime = ContentFormatter.estimateReadingTime(text);

    return Article(
      title: title,
      byline: byline,
      publishDate: publishDate,
      markdown: markdown,
      text: text,
      images: articleImages,
      readingTime: readingTime,
    );
  }

  static void _scoreTree(
    dom.Element root,
    Map<dom.Element, double> scores,
  ) {
    for (final element in root.querySelectorAll('*')) {
      final tag = element.localName?.toLowerCase();
      if (tag == null) continue;

      // Skip elements that are navigation/footer/aside directly
      if (tag == 'nav' || tag == 'footer' || tag == 'aside' || tag == 'header') {
        continue;
      }

      // Check class/id weight
      final weight = _classIdWeight(element);
      if (weight < -15) continue;

      // Score content in paragraph-like elements
      if (tag == 'p' || tag == 'blockquote' || tag == 'pre') {
        final text = element.text.trim();
        if (text.length < 25) continue;

        var contentScore = 1.0;

        // Comma / punctuation count
        final commaCount = ','.allMatches(text).length;
        contentScore += math.min(commaCount, 15);

        // Character length bonus (up to 30)
        contentScore += math.min(text.length / 50.0, 30.0);

        // Link density penalty
        final linkDensity = _getLinkDensity(element);
        contentScore *= (1.0 - linkDensity);

        // Add to parent and grandparent
        final parent = element.parent;
        if (parent != null && parent != root) {
          scores[parent] = (scores[parent] ?? _baseScoreFor(parent)) + contentScore;

          final grandparent = parent.parent;
          if (grandparent != null && grandparent != root) {
            scores[grandparent] =
                (scores[grandparent] ?? _baseScoreFor(grandparent)) + (contentScore / 2.0);
          }
        }
      }
    }
  }

  static double _baseScoreFor(dom.Element element) {
    var score = 0.0;
    final tag = element.localName?.toLowerCase();

    switch (tag) {
      case 'article':
        score += 30;
      case 'main' || '[role=main]':
        score += 25;
      case 'section':
        score += 15;
      case 'div':
        score += 5;
      case 'nav' || 'footer' || 'aside' || 'header':
        score -= 30;
    }

    score += _classIdWeight(element);
    return score;
  }

  static double _classIdWeight(dom.Element element) {
    var weight = 0.0;
    final className = element.attributes['class'] ?? '';
    final id = element.attributes['id'] ?? '';
    final combined = '$className $id';

    if (_positivePattern.hasMatch(combined)) {
      weight += 25;
    }
    if (_negativePattern.hasMatch(combined)) {
      weight -= 30;
    }

    return weight;
  }

  static double _getLinkDensity(dom.Element element) {
    final linkTextLength = element
        .querySelectorAll('a')
        .fold(0, (sum, a) => sum + a.text.trim().length);
    final totalTextLength = element.text.trim().length;

    if (totalTextLength == 0) return 0.0;
    return linkTextLength / totalTextLength;
  }

  static List<dom.Element> _collectSiblings(
    dom.Element topCandidate,
    Map<dom.Element, double> scores,
    double topScore,
  ) {
    final parent = topCandidate.parent;
    if (parent == null) return [topCandidate];

    final siblings = <dom.Element>[];
    final threshold = math.max(10.0, topScore * 0.2);

    for (final sibling in parent.children) {
      if (sibling == topCandidate) {
        siblings.add(sibling);
        continue;
      }

      final score = scores[sibling] ?? 0.0;
      if (score >= threshold) {
        siblings.add(sibling);
        continue;
      }

      // Check if it is a substantial paragraph or heading
      if (sibling.localName == 'p') {
        final text = sibling.text.trim();
        final linkDensity = _getLinkDensity(sibling);
        if (text.length >= 60 && linkDensity < 0.3) {
          siblings.add(sibling);
        }
      }
    }

    return siblings.isNotEmpty ? siblings : [topCandidate];
  }
}
