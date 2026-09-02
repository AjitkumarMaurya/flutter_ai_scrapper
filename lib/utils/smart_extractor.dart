/// Smart content extraction utilities for common web content patterns
library;

/// Represents extracted content from a webpage
class SmartContent {
  /// Page title
  final String? title;

  /// Meta description or excerpt
  final String? description;

  /// Main article/content text
  final String? content;

  /// Author information
  final String? author;

  /// Publication date
  final String? publishDate;

  /// All images found on the page
  final List<String> images;

  /// All links found on the page
  final List<String> links;

  /// Email addresses found
  final List<String> emails;

  /// Phone numbers found
  final List<String> phoneNumbers;

  /// Prices found (for e-commerce)
  final List<String> prices;

  /// Open Graph data
  final OpenGraphData? openGraph;

  const SmartContent({
    this.title,
    this.description,
    this.content,
    this.author,
    this.publishDate,
    this.images = const [],
    this.links = const [],
    this.emails = const [],
    this.phoneNumbers = const [],
    this.prices = const [],
    this.openGraph,
  });

  @override
  String toString() {
    return 'SmartContent(title: $title, description: $description, '
        'images: ${images.length}, links: ${links.length})';
  }
}

/// Open Graph metadata
class OpenGraphData {
  final String? title;
  final String? description;
  final String? image;
  final String? url;
  final String? type;
  final String? siteName;

  const OpenGraphData({
    this.title,
    this.description,
    this.image,
    this.url,
    this.type,
    this.siteName,
  });
}

/// Smart content extractor that uses multiple fallback strategies
class SmartExtractor {
  /// Extract all common content types from HTML
  static SmartContent extractAll(String html) {
    return SmartContent(
      title: extractTitle(html),
      description: extractDescription(html),
      content: extractMainContent(html),
      author: extractAuthor(html),
      publishDate: extractPublishDate(html),
      images: extractImages(html),
      links: extractLinks(html),
      emails: extractEmails(html),
      phoneNumbers: extractPhoneNumbers(html),
      prices: extractPrices(html),
      openGraph: extractOpenGraph(html),
    );
  }

  /// Extract page title using multiple fallback strategies
  static String? extractTitle(String html) {
    // Priority order: OG title, title tag, h1 tags
    final strategies = [
      // Open Graph title
      r'<meta[^>]*property=[\"\x27]og:title[\"\x27][^>]*content=[\"\x27]([^\"\x27]*)[\"\x27]',
      // Title tag
      r'<title[^>]*>([^<]*)</title>',
      // H1 tags
      r'<h1[^>]*>([^<]*)</h1>',
      // Article title patterns
      r'<[^>]*class=[\"\x27][^\"\x27]*title[^\"\x27]*[\"\x27][^>]*>([^<]*)<',
      r'<[^>]*class=[\"\x27][^\"\x27]*headline[^\"\x27]*[\"\x27][^>]*>([^<]*)<',
    ];

    for (final pattern in strategies) {
      final match = RegExp(pattern, caseSensitive: false).firstMatch(html);
      if (match != null) {
        final title = _cleanText(match.group(1) ?? '');
        if (title.isNotEmpty) return title;
      }
    }
    return null;
  }

  /// Extract meta description
  static String? extractDescription(String html) {
    final strategies = [
      // Open Graph description
      r'<meta[^>]*property=[\"\x27]og:description[\"\x27][^>]*content=[\"\x27]([^\"\x27]*)[\"\x27]',
      // Meta description
      r'<meta[^>]*name=[\"\x27]description[\"\x27][^>]*content=[\"\x27]([^\"\x27]*)[\"\x27]',
      // Twitter description
      r'<meta[^>]*name=[\"\x27]twitter:description[\"\x27][^>]*content=[\"\x27]([^\"\x27]*)[\"\x27]',
      // First paragraph
      r'<p[^>]*>([^<]{50,200})</p>',
    ];

    for (final pattern in strategies) {
      final match = RegExp(pattern, caseSensitive: false).firstMatch(html);
      if (match != null) {
        final desc = _cleanText(match.group(1) ?? '');
        if (desc.length > 20) return desc;
      }
    }
    return null;
  }

  /// Extract main article content
  static String? extractMainContent(String html) {
    final strategies = [
      // Common article selectors
      r'<article[^>]*>(.*?)</article>',
      r'<div[^>]*class=[\"\x27][^\"\x27]*content[^\"\x27]*[\"\x27][^>]*>(.*?)</div>',
      r'<div[^>]*class=[\"\x27][^\"\x27]*article[^\"\x27]*[\"\x27][^>]*>(.*?)</div>',
      r'<div[^>]*class=[\"\x27][^\"\x27]*post[^\"\x27]*[\"\x27][^>]*>(.*?)</div>',
      r'<main[^>]*>(.*?)</main>',
    ];

    for (final pattern in strategies) {
      final match =
          RegExp(pattern, caseSensitive: false, dotAll: true).firstMatch(html);
      if (match != null) {
        final content = _cleanText(match.group(1) ?? '');
        if (content.length > 100) return content;
      }
    }
    return null;
  }

  /// Extract author information
  static String? extractAuthor(String html) {
    final strategies = [
      r'<meta[^>]*name=[\"\x27]author[\"\x27][^>]*content=[\"\x27]([^\"\x27]*)[\"\x27]',
      r'<[^>]*class=[\"\x27][^\"\x27]*author[^\"\x27]*[\"\x27][^>]*>([^<]*)<',
      r'<[^>]*class=[\"\x27][^\"\x27]*byline[^\"\x27]*[\"\x27][^>]*>([^<]*)<',
      r'[Bb]y\s+([A-Z][a-z]+\s+[A-Z][a-z]+)',
    ];

    for (final pattern in strategies) {
      final match = RegExp(pattern, caseSensitive: false).firstMatch(html);
      if (match != null) {
        final author = _cleanText(match.group(1) ?? '');
        if (author.isNotEmpty) return author;
      }
    }
    return null;
  }

  /// Extract publication date
  static String? extractPublishDate(String html) {
    final strategies = [
      r'<time[^>]*datetime=[\"\x27]([^\"\x27]*)[\"\x27]',
      r'<meta[^>]*property=[\"\x27]article:published_time[\"\x27][^>]*content=[\"\x27]([^\"\x27]*)[\"\x27]',
      r'<[^>]*class=[\"\x27][^\"\x27]*date[^\"\x27]*[\"\x27][^>]*>([^<]*)<',
      r'(\d{4}-\d{2}-\d{2})',
    ];

    for (final pattern in strategies) {
      final match = RegExp(pattern, caseSensitive: false).firstMatch(html);
      if (match != null) {
        final date = _cleanText(match.group(1) ?? '');
        if (date.isNotEmpty) return date;
      }
    }
    return null;
  }

  /// Extract all images with their URLs
  static List<String> extractImages(String html) {
    final images = <String>[];
    final strategies = [
      r'<img[^>]*src=[\"\x27]([^\"\x27]*)[\"\x27]',
      r'<meta[^>]*property=[\"\x27]og:image[\"\x27][^>]*content=[\"\x27]([^\"\x27]*)[\"\x27]',
    ];

    for (final pattern in strategies) {
      final matches = RegExp(pattern, caseSensitive: false).allMatches(html);
      for (final match in matches) {
        final imageUrl = match.group(1);
        if (imageUrl != null && imageUrl.isNotEmpty) {
          images.add(imageUrl);
        }
      }
    }

    return images.toSet().toList(); // Remove duplicates
  }

  /// Extract all links
  static List<String> extractLinks(String html) {
    final links = <String>[];
    final pattern = r'<a[^>]*href=[\"\x27]([^\"\x27]*)[\"\x27]';

    final matches = RegExp(pattern, caseSensitive: false).allMatches(html);
    for (final match in matches) {
      final link = match.group(1);
      if (link != null && link.isNotEmpty && link.startsWith('http')) {
        links.add(link);
      }
    }

    return links.toSet().toList();
  }

  /// Extract email addresses
  static List<String> extractEmails(String html) {
    final emails = <String>[];
    final pattern = r'\b[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Z|a-z]{2,}\b';

    final matches = RegExp(pattern).allMatches(html);
    for (final match in matches) {
      final email = match.group(0);
      if (email != null) emails.add(email);
    }

    return emails.toSet().toList();
  }

  /// Extract phone numbers
  static List<String> extractPhoneNumbers(String html) {
    final phones = <String>[];
    final patterns = [
      r'\+?1?[-.\s]?\(?(\d{3})\)?[-.\s]?(\d{3})[-.\s]?(\d{4})', // US format
      r'\+?(\d{1,4})[-.\s]?(\d{1,4})[-.\s]?(\d{1,4})[-.\s]?(\d{1,4})', // International
    ];

    for (final pattern in patterns) {
      final matches = RegExp(pattern).allMatches(html);
      for (final match in matches) {
        final phone = match.group(0);
        if (phone != null && phone.length >= 10) {
          phones.add(phone);
        }
      }
    }

    return phones.toSet().toList();
  }

  /// Extract prices (for e-commerce sites)
  static List<String> extractPrices(String html) {
    final prices = <String>[];
    final patterns = [
      r'\$\s*(\d+(?:,\d{3})*(?:\.\d{2})?)', // $123.45, $1,234.56
      r'(\d+(?:,\d{3})*(?:\.\d{2})?)\s*USD', // 123.45 USD
      r'Price:\s*\$?(\d+(?:,\d{3})*(?:\.\d{2})?)', // Price: $123.45
      r'<[^>]*class=[\"\x27][^\"\x27]*price[^\"\x27]*[\"\x27][^>]*>[^\\$]*\\\$([^<]*)<', // Class-based price
    ];

    for (final pattern in patterns) {
      final matches = RegExp(pattern, caseSensitive: false).allMatches(html);
      for (final match in matches) {
        final price = match.group(1);
        if (price != null && price.isNotEmpty) {
          prices.add('\$${price.trim()}');
        }
      }
    }

    return prices.toSet().toList();
  }

  /// Extract Open Graph metadata
  static OpenGraphData? extractOpenGraph(String html) {
    String? getOgContent(String property) {
      final pattern =
          '<meta[^>]*property=[\"\x27]og:$property[\"\x27][^>]*content=[\"\x27]([^\"\x27]*)[\"\x27]';
      final match = RegExp(pattern, caseSensitive: false).firstMatch(html);
      return match?.group(1);
    }

    final title = getOgContent('title');
    final description = getOgContent('description');
    final image = getOgContent('image');
    final url = getOgContent('url');
    final type = getOgContent('type');
    final siteName = getOgContent('site_name');

    if (title != null || description != null || image != null) {
      return OpenGraphData(
        title: title,
        description: description,
        image: image,
        url: url,
        type: type,
        siteName: siteName,
      );
    }

    return null;
  }

  /// Clean and normalize extracted text
  static String _cleanText(String text) {
    // Remove HTML tags
    String cleaned = text.replaceAll(RegExp(r'<[^>]*>'), '');

    // Decode HTML entities
    cleaned = cleaned
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'")
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&copy;', '©')
        .replaceAll('&reg;', '®')
        .replaceAll('&trade;', '™');

    // Clean up whitespace
    cleaned = cleaned.replaceAll(RegExp(r'\s+'), ' ').trim();

    return cleaned;
  }
}
