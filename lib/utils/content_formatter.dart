/// Content formatting and cleaning utilities
library;

/// Content formatting options
enum ContentFormat {
  /// Clean text with minimal formatting
  plainText,

  /// Markdown formatted text
  markdown,

  /// HTML with cleaned structure
  cleanHtml,

  /// Readable content (like Readability.js)
  readable,
}

/// Content formatter that provides clean, formatted text from HTML
class ContentFormatter {
  /// Format content according to the specified format
  static String format(String html, ContentFormat format) {
    switch (format) {
      case ContentFormat.plainText:
        return toPlainText(html);
      case ContentFormat.markdown:
        return toMarkdown(html);
      case ContentFormat.cleanHtml:
        return toCleanHtml(html);
      case ContentFormat.readable:
        return toReadableContent(html);
    }
  }

  /// Convert HTML to clean plain text
  static String toPlainText(String html) {
    // Remove script and style tags completely
    String cleaned = html.replaceAll(
        RegExp(r'<(script|style)[^>]*>.*?</\1>',
            caseSensitive: false, dotAll: true),
        '');

    // Convert common HTML elements to plain text equivalents
    cleaned = cleaned
        // Line breaks for block elements
        .replaceAll(
            RegExp(r'</(div|p|h[1-6]|li|br)>', caseSensitive: false), '\n')
        .replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n')
        // Double line breaks for paragraphs and headers
        .replaceAll(RegExp(r'</(p|h[1-6])>', caseSensitive: false), '\n\n')
        // List items
        .replaceAll(RegExp(r'<li[^>]*>', caseSensitive: false), '• ')
        // Remove all remaining HTML tags
        .replaceAll(RegExp(r'<[^>]*>'), '');

    return _cleanText(cleaned);
  }

  /// Convert HTML to Markdown format
  static String toMarkdown(String html) {
    String markdown = html;

    // Remove script and style tags
    markdown = markdown.replaceAll(
        RegExp(r'<(script|style)[^>]*>.*?</\1>',
            caseSensitive: false, dotAll: true),
        '');

    // Convert headers
    markdown = markdown.replaceAllMapped(
      RegExp(r'<h1[^>]*>(.*?)</h1>', caseSensitive: false, dotAll: true),
      (match) => '# ${match.group(1)}\n\n',
    );
    markdown = markdown.replaceAllMapped(
      RegExp(r'<h2[^>]*>(.*?)</h2>', caseSensitive: false, dotAll: true),
      (match) => '## ${match.group(1)}\n\n',
    );
    markdown = markdown.replaceAllMapped(
      RegExp(r'<h3[^>]*>(.*?)</h3>', caseSensitive: false, dotAll: true),
      (match) => '### ${match.group(1)}\n\n',
    );
    markdown = markdown.replaceAllMapped(
      RegExp(r'<h4[^>]*>(.*?)</h4>', caseSensitive: false, dotAll: true),
      (match) => '#### ${match.group(1)}\n\n',
    );
    markdown = markdown.replaceAllMapped(
      RegExp(r'<h5[^>]*>(.*?)</h5>', caseSensitive: false, dotAll: true),
      (match) => '##### ${match.group(1)}\n\n',
    );
    markdown = markdown.replaceAllMapped(
      RegExp(r'<h6[^>]*>(.*?)</h6>', caseSensitive: false, dotAll: true),
      (match) => '###### ${match.group(1)}\n\n',
    );

    // Convert text formatting
    markdown = markdown.replaceAllMapped(
      RegExp(r'<strong[^>]*>(.*?)</strong>',
          caseSensitive: false, dotAll: true),
      (match) => '**${match.group(1)}**',
    );
    markdown = markdown.replaceAllMapped(
      RegExp(r'<b[^>]*>(.*?)</b>', caseSensitive: false, dotAll: true),
      (match) => '**${match.group(1)}**',
    );
    markdown = markdown.replaceAllMapped(
      RegExp(r'<em[^>]*>(.*?)</em>', caseSensitive: false, dotAll: true),
      (match) => '*${match.group(1)}*',
    );
    markdown = markdown.replaceAllMapped(
      RegExp(r'<i[^>]*>(.*?)</i>', caseSensitive: false, dotAll: true),
      (match) => '*${match.group(1)}*',
    );
    markdown = markdown.replaceAllMapped(
      RegExp(r'<code[^>]*>(.*?)</code>', caseSensitive: false, dotAll: true),
      (match) => '`${match.group(1)}`',
    );

    // Convert links
    markdown = markdown.replaceAllMapped(
      RegExp(r'<a[^>]*href=[\"\x27]([^\"\x27]*)[\"\x27][^>]*>(.*?)</a>',
          caseSensitive: false, dotAll: true),
      (match) => '[${match.group(2)}](${match.group(1)})',
    );

    // Convert images
    markdown = markdown.replaceAllMapped(
      RegExp(
          r'<img[^>]*src=[\"\x27]([^\"\x27]*)[\"\x27][^>]*alt=[\"\x27]([^\"\x27]*)[\"\x27][^>]*/?>',
          caseSensitive: false),
      (match) => '![${match.group(2)}](${match.group(1)})',
    );

    // Convert lists
    markdown = markdown
        .replaceAll(RegExp(r'<ul[^>]*>', caseSensitive: false), '')
        .replaceAll(RegExp(r'</ul>', caseSensitive: false), '\n')
        .replaceAll(RegExp(r'<ol[^>]*>', caseSensitive: false), '')
        .replaceAll(RegExp(r'</ol>', caseSensitive: false), '\n');
    markdown = markdown.replaceAllMapped(
      RegExp(r'<li[^>]*>(.*?)</li>', caseSensitive: false, dotAll: true),
      (match) => '- ${match.group(1)}\n',
    );

    // Convert paragraphs
    markdown = markdown.replaceAllMapped(
      RegExp(r'<p[^>]*>(.*?)</p>', caseSensitive: false, dotAll: true),
      (match) => '${match.group(1)}\n\n',
    );
    markdown =
        markdown.replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n');

    // Convert blockquotes
    markdown = markdown.replaceAllMapped(
      RegExp(r'<blockquote[^>]*>(.*?)</blockquote>',
          caseSensitive: false, dotAll: true),
      (match) => '> ${match.group(1)}\n\n',
    );

    // Remove remaining HTML tags
    markdown = markdown.replaceAll(RegExp(r'<[^>]*>'), '');

    return _cleanText(markdown);
  }

  /// Clean HTML while preserving basic structure
  static String toCleanHtml(String html) {
    // Remove unwanted elements
    String cleaned = html.replaceAll(
        RegExp(r'<(script|style|nav|header|footer|aside|menu)[^>]*>.*?</\1>',
            caseSensitive: false, dotAll: true),
        '');

    // Remove comments
    cleaned = cleaned.replaceAll(RegExp(r'<!--.*?-->', dotAll: true), '');

    // Clean up attributes but keep essential ones
    cleaned = cleaned.replaceAllMapped(
        RegExp(r'<([a-z]+)[^>]*>', caseSensitive: false), (match) {
      final tag = match.group(1)!.toLowerCase();
      switch (tag) {
        case 'a':
          // Keep href attribute for links
          final hrefMatch =
              RegExp(r'href=[\"\x27]([^\"\x27]*)[\"\x27]', caseSensitive: false)
                  .firstMatch(match.group(0)!);
          return hrefMatch != null ? '<a href="${hrefMatch.group(1)}">' : '<a>';
        case 'img':
          // Keep src and alt for images
          final imgMatch = RegExp(
                  r'src=[\"\x27]([^\"\x27]*)[\"\x27].*?alt=[\"\x27]([^\"\x27]*)[\"\x27]',
                  caseSensitive: false)
              .firstMatch(match.group(0)!);
          return imgMatch != null
              ? '<img src="${imgMatch.group(1)}" alt="${imgMatch.group(2)}">'
              : '<img>';
        default:
          return '<$tag>';
      }
    });

    return cleaned;
  }

  /// Extract readable content (similar to Readability.js)
  static String toReadableContent(String html) {
    // Remove script, style, nav, header, footer, sidebar elements
    String content = html.replaceAll(
        RegExp(
            r'<(script|style|nav|header|footer|aside|sidebar|menu|form)[^>]*>.*?</\1>',
            caseSensitive: false,
            dotAll: true),
        '');

    // Remove elements commonly used for ads and navigation
    content = content.replaceAll(
        RegExp(
            r'<[^>]*class=[\"\x27][^\"\x27]*(?:ad|advertisement|banner|social|share|comment|sidebar|navigation|nav)[^\"\x27]*[\"\x27][^>]*>.*?</[^>]*>',
            caseSensitive: false,
            dotAll: true),
        '');

    // Focus on content-rich elements
    final contentSelectors = [
      r'<article[^>]*>(.*?)</article>',
      r'<main[^>]*>(.*?)</main>',
      r'<div[^>]*class=[\"\x27][^\"\x27]*(?:content|article|post|entry)[^\"\x27]*[\"\x27][^>]*>(.*?)</div>',
    ];

    String? bestContent;
    int maxLength = 0;

    for (final selector in contentSelectors) {
      final matches = RegExp(selector, caseSensitive: false, dotAll: true)
          .allMatches(content);
      for (final match in matches) {
        final extracted = match.group(1) ?? '';
        final textLength = toPlainText(extracted).length;
        if (textLength > maxLength) {
          maxLength = textLength;
          bestContent = extracted;
        }
      }
    }

    // If no specific content area found, try to extract paragraphs
    if (bestContent == null || maxLength < 200) {
      final paragraphs =
          RegExp(r'<p[^>]*>(.*?)</p>', caseSensitive: false, dotAll: true)
              .allMatches(content)
              .map((match) => match.group(1) ?? '')
              .where((p) => p.trim().length > 50)
              .join('\n\n');

      if (paragraphs.isNotEmpty) {
        bestContent = paragraphs;
      }
    }

    return bestContent != null
        ? toPlainText(bestContent)
        : toPlainText(content);
  }

  /// Remove clutter elements like ads, navigation, etc.
  static String removeClutter(String html) {
    String cleaned = html;

    // Remove script and style tags
    cleaned = cleaned.replaceAll(
        RegExp(r'<(script|style)[^>]*>.*?</\1>',
            caseSensitive: false, dotAll: true),
        '');

    // Remove navigation elements
    cleaned = cleaned.replaceAll(
        RegExp(r'<(nav|header|footer|aside|menu)[^>]*>.*?</\1>',
            caseSensitive: false, dotAll: true),
        '');

    // Remove elements with ad-related classes/ids
    final adPatterns = [
      r'ad',
      r'advertisement',
      r'banner',
      r'popup',
      r'modal',
      r'social',
      r'share',
      r'comment',
      r'sidebar',
      r'widget',
      r'navigation',
      r'nav',
      r'menu',
      r'breadcrumb'
    ];

    for (final pattern in adPatterns) {
      cleaned = cleaned.replaceAll(
          RegExp(
              r'<[^>]*(?:class|id)=[\"\x27][^\"\x27]*' +
                  pattern +
                  r'[^\"\x27]*[\"\x27][^>]*>.*?</[^>]*>',
              caseSensitive: false,
              dotAll: true),
          '');
    }

    return cleaned;
  }

  /// Extract readable text with smart paragraph detection
  static String extractReadableText(String html) {
    // First remove clutter
    String content = removeClutter(html);

    // Extract text from content-rich elements
    final contentElements = [
      'article',
      'main',
      'section',
      '[class*="content"]',
      '[class*="article"]',
      '[class*="post"]'
    ];

    String bestContent = '';
    int maxScore = 0;

    for (final element in contentElements) {
      final pattern = element.startsWith('[')
          ? r'<[^>]*' +
              element.replaceAll(RegExp(r'[\[\]*"]'), r'\$&') +
              r'[^>]*>(.*?)</[^>]*>'
          : '<$element[^>]*>(.*?)</$element>';

      final matches = RegExp(pattern, caseSensitive: false, dotAll: true)
          .allMatches(content);

      for (final match in matches) {
        final text = toPlainText(match.group(1) ?? '');
        final score = _calculateContentScore(text);

        if (score > maxScore) {
          maxScore = score;
          bestContent = text;
        }
      }
    }

    return bestContent.isNotEmpty ? bestContent : toPlainText(content);
  }

  /// Calculate content quality score
  static int _calculateContentScore(String text) {
    if (text.trim().isEmpty) return 0;

    int score = 0;

    // Length score (prefer longer content)
    score += (text.length / 10).round();

    // Sentence score (prefer content with proper sentences)
    final sentences = text.split(RegExp(r'[.!?]+'));
    score += sentences.length * 5;

    // Word score (prefer content with reasonable word count)
    final words = text.split(RegExp(r'\s+'));
    if (words.length > 50 && words.length < 2000) {
      score += 50;
    }

    // Penalize very short sentences (likely navigation/ads)
    final avgSentenceLength = words.length / sentences.length;
    if (avgSentenceLength < 3) {
      score -= 30;
    }

    return score;
  }

  /// Clean and normalize text
  static String _cleanText(String text) {
    // Decode HTML entities
    String cleaned = text
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'")
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&copy;', '©')
        .replaceAll('&reg;', '®')
        .replaceAll('&trade;', '™')
        .replaceAll('&ndash;', '–')
        .replaceAll('&mdash;', '—')
        .replaceAll('&hellip;', '…');

    // Clean up whitespace
    cleaned = cleaned
        .replaceAll(
            RegExp(r'\n\s*\n\s*\n+'), '\n\n') // Remove excessive line breaks
        .replaceAll(RegExp(r'[ \t]+'), ' ') // Normalize spaces
        .replaceAll(RegExp(r'\n '), '\n') // Remove leading spaces on new lines
        .trim();

    return cleaned;
  }

  /// Word count for text
  static int wordCount(String text) {
    return text
        .trim()
        .split(RegExp(r'\s+'))
        .where((word) => word.isNotEmpty)
        .length;
  }

  /// Reading time estimation (average 200 words per minute)
  static Duration estimateReadingTime(String text, {int wordsPerMinute = 200}) {
    final words = wordCount(text);
    final minutes = (words / wordsPerMinute).ceil();
    return Duration(minutes: minutes);
  }

  /// Extract specific content types
  static Map<String, List<String>> extractSpecificContent(String html) {
    return {
      'headings': _extractHeadings(html),
      'links': _extractLinks(html),
      'images': _extractImages(html),
      'lists': _extractLists(html),
      'quotes': _extractQuotes(html),
      'tables': _extractTables(html),
    };
  }

  static List<String> _extractHeadings(String html) {
    final headings = <String>[];
    for (int i = 1; i <= 6; i++) {
      final matches =
          RegExp('<h$i[^>]*>(.*?)</h$i>', caseSensitive: false, dotAll: true)
              .allMatches(html);
      headings.addAll(matches.map((m) => _cleanText(m.group(1) ?? '')));
    }
    return headings;
  }

  static List<String> _extractLinks(String html) {
    return RegExp(r'<a[^>]*href=[\"\x27]([^\"\x27]*)[\"\x27][^>]*>(.*?)</a>',
            caseSensitive: false, dotAll: true)
        .allMatches(html)
        .map((m) => '${_cleanText(m.group(2) ?? '')}: ${m.group(1)}')
        .toList();
  }

  static List<String> _extractImages(String html) {
    return RegExp(
            r'<img[^>]*src=[\"\x27]([^\"\x27]*)[\"\x27][^>]*alt=[\"\x27]([^\"\x27]*)[\"\x27][^>]*/?>',
            caseSensitive: false)
        .allMatches(html)
        .map((m) => '${m.group(2)}: ${m.group(1)}')
        .toList();
  }

  static List<String> _extractLists(String html) {
    final lists = <String>[];
    final listMatches =
        RegExp(r'<[ou]l[^>]*>(.*?)</[ou]l>', caseSensitive: false, dotAll: true)
            .allMatches(html);

    for (final match in listMatches) {
      final items =
          RegExp(r'<li[^>]*>(.*?)</li>', caseSensitive: false, dotAll: true)
              .allMatches(match.group(1) ?? '')
              .map((m) => _cleanText(m.group(1) ?? ''))
              .join('\n• ');
      if (items.isNotEmpty) lists.add('• $items');
    }

    return lists;
  }

  static List<String> _extractQuotes(String html) {
    return RegExp(r'<blockquote[^>]*>(.*?)</blockquote>',
            caseSensitive: false, dotAll: true)
        .allMatches(html)
        .map((m) => _cleanText(m.group(1) ?? ''))
        .toList();
  }

  static List<String> _extractTables(String html) {
    final tables = <String>[];
    final tableMatches =
        RegExp(r'<table[^>]*>(.*?)</table>', caseSensitive: false, dotAll: true)
            .allMatches(html);

    for (final match in tableMatches) {
      final tableContent = match.group(1) ?? '';
      final rows =
          RegExp(r'<tr[^>]*>(.*?)</tr>', caseSensitive: false, dotAll: true)
              .allMatches(tableContent)
              .map((rowMatch) {
                final cells = RegExp(r'<t[hd][^>]*>(.*?)</t[hd]>',
                        caseSensitive: false, dotAll: true)
                    .allMatches(rowMatch.group(1) ?? '')
                    .map((cellMatch) => _cleanText(cellMatch.group(1) ?? ''))
                    .join(' | ');
                return cells;
              })
              .where((row) => row.isNotEmpty)
              .join('\n');

      if (rows.isNotEmpty) tables.add(rows);
    }

    return tables;
  }
}
