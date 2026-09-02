import 'package:http/http.dart' as http;

/// The rules one `robots.txt` declares for one user agent.
class RobotsRules {
  /// Creates a rule set.
  const RobotsRules({
    this.allow = const [],
    this.disallow = const [],
    this.crawlDelay,
    this.sitemaps = const [],
  });

  /// Rules permitting everything — used when a site has no `robots.txt`.
  ///
  /// A missing file means "no restrictions stated", not "stay out". A 5xx,
  /// by contrast, means the site's wishes are unknown; see
  /// [RobotsPolicy.failOpen].
  static const RobotsRules permissive = RobotsRules();

  /// `Allow:` path prefixes.
  final List<String> allow;

  /// `Disallow:` path prefixes.
  final List<String> disallow;

  /// The host's requested gap between requests, if it stated one.
  final Duration? crawlDelay;

  /// Sitemap URLs advertised by the file.
  final List<String> sitemaps;

  /// Whether [path] may be fetched.
  ///
  /// Longest match wins, and an equally specific `Allow` beats `Disallow` —
  /// the behaviour Google's parser documents.
  bool isAllowed(String path) {
    final target = path.isEmpty ? '/' : path;

    var longestAllow = -1;
    for (final rule in allow) {
      if (_matches(target, rule) && rule.length > longestAllow) {
        longestAllow = rule.length;
      }
    }

    var longestDisallow = -1;
    for (final rule in disallow) {
      if (_matches(target, rule) && rule.length > longestDisallow) {
        longestDisallow = rule.length;
      }
    }

    if (longestDisallow < 0) return true;
    return longestAllow >= longestDisallow;
  }

  /// Whether [path] is covered by [rule], honouring `*` and `$`.
  static bool _matches(String path, String rule) {
    if (rule.isEmpty) return false;
    if (!rule.contains('*') && !rule.endsWith(r'$')) {
      return path.startsWith(rule);
    }

    final anchored = rule.endsWith(r'$');
    final body = anchored ? rule.substring(0, rule.length - 1) : rule;
    final pattern = body.split('*').map(RegExp.escape).join('.*');

    return RegExp('^$pattern${anchored ? r'$' : ''}').hasMatch(path);
  }
}

/// Fetches and applies `robots.txt`.
///
/// Shipping this by default is a deliberate choice. A scraping library makes it
/// easy to ignore what a site has asked for, and the people who bear the cost
/// are never the library's users. Consumers can still opt out per-scrape, but
/// they have to say so.
class RobotsPolicy {
  /// Creates a robots policy.
  RobotsPolicy({
    http.Client? client,
    this.cacheDuration = const Duration(hours: 12),
    this.timeout = const Duration(seconds: 10),
    this.failOpen = true,
  }) : _client = client ?? http.Client();

  final http.Client _client;

  /// How long a fetched `robots.txt` stays valid.
  final Duration cacheDuration;

  /// Time allowed to fetch `robots.txt` itself.
  final Duration timeout;

  /// What to do when `robots.txt` cannot be read.
  ///
  /// `true` (the default) allows the request: an unreachable file is a network
  /// problem, and blocking every scrape because a site's `robots.txt` 500s
  /// would be its own kind of wrong. Set `false` for strict operation.
  final bool failOpen;

  final Map<String, _CachedRules> _cache = {};

  /// Whether [url] may be fetched by [userAgent].
  Future<bool> isAllowed(Uri url, String userAgent) async {
    final rules = await rulesFor(url, userAgent);
    return rules.isAllowed(url.path);
  }

  /// The rules that apply to [userAgent] on [url]'s host.
  Future<RobotsRules> rulesFor(Uri url, String userAgent) async {
    final host = '${url.scheme}://${url.authority}';
    final agentKey = _agentToken(userAgent);
    final cacheKey = '$host|$agentKey';

    final cached = _cache[cacheKey];
    if (cached != null && cached.isValid) return cached.rules;

    final rules = await _fetch(host, agentKey);
    _cache[cacheKey] = _CachedRules(rules, DateTime.now().add(cacheDuration));
    return rules;
  }

  Future<RobotsRules> _fetch(String host, String agentToken) async {
    try {
      final response = await _client
          .get(Uri.parse('$host/robots.txt'))
          .timeout(timeout);

      // 404 and friends: no rules stated, so nothing is forbidden.
      if (response.statusCode == 404 || response.statusCode == 410) {
        return RobotsRules.permissive;
      }
      if (response.statusCode >= 400) {
        return failOpen ? RobotsRules.permissive : const RobotsRules(disallow: ['/']);
      }

      return parse(response.body, agentToken);
    } on Object {
      return failOpen
          ? RobotsRules.permissive
          : const RobotsRules(disallow: ['/']);
    }
  }

  /// Parses [content] for the agent named [agentToken].
  ///
  /// Group selection follows the standard: rules for the most specific matching
  /// `User-agent` win, and `*` is the fallback when no named group matches.
  static RobotsRules parse(String content, String agentToken) {
    final groups = <String, _Group>{};
    var currentAgents = <String>[];
    var expectingAgents = false;
    final sitemaps = <String>[];

    for (final rawLine in content.split('\n')) {
      final withoutComment = rawLine.split('#').first.trim();
      if (withoutComment.isEmpty) continue;

      final separator = withoutComment.indexOf(':');
      if (separator < 0) continue;

      final field = withoutComment.substring(0, separator).trim().toLowerCase();
      final value = withoutComment.substring(separator + 1).trim();

      switch (field) {
        case 'user-agent':
          // Consecutive User-agent lines share one rule block.
          if (!expectingAgents) currentAgents = <String>[];
          currentAgents.add(value.toLowerCase());
          expectingAgents = true;
          groups.putIfAbsent(value.toLowerCase(), _Group.new);

        case 'allow':
        case 'disallow':
          expectingAgents = false;
          if (value.isEmpty && field == 'disallow') continue; // means "allow all"
          for (final agent in currentAgents) {
            final group = groups.putIfAbsent(agent, _Group.new);
            if (field == 'allow') {
              group.allow.add(value);
            } else {
              group.disallow.add(value);
            }
          }

        case 'crawl-delay':
          expectingAgents = false;
          final seconds = double.tryParse(value);
          if (seconds != null && seconds > 0) {
            for (final agent in currentAgents) {
              groups.putIfAbsent(agent, _Group.new).crawlDelay =
                  Duration(milliseconds: (seconds * 1000).round());
            }
          }

        case 'sitemap':
          if (value.isNotEmpty) sitemaps.add(value);
      }
    }

    final group = _selectGroup(groups, agentToken);
    if (group == null) return RobotsRules(sitemaps: sitemaps);

    return RobotsRules(
      allow: group.allow,
      disallow: group.disallow,
      crawlDelay: group.crawlDelay,
      sitemaps: sitemaps,
    );
  }

  /// Picks the most specific group matching [agentToken], else `*`.
  static _Group? _selectGroup(Map<String, _Group> groups, String agentToken) {
    _Group? best;
    var bestLength = -1;

    for (final entry in groups.entries) {
      final name = entry.key;
      if (name == '*') continue;
      if (agentToken.contains(name) && name.length > bestLength) {
        best = entry.value;
        bestLength = name.length;
      }
    }

    return best ?? groups['*'];
  }

  /// Reduces a full User-Agent header to the token robots.txt matches on.
  ///
  /// `flutter_ai_scrapper/2.0.0 (+https://…)` becomes `flutter_ai_scrapper`.
  static String _agentToken(String userAgent) {
    final token = userAgent.split('/').first.split(' ').first.trim();
    return token.isEmpty ? userAgent.toLowerCase() : token.toLowerCase();
  }

  /// Clears cached rules.
  void clearCache() => _cache.clear();

  /// Releases the HTTP client. Safe to call more than once.
  void dispose() => _client.close();
}

class _Group {
  final List<String> allow = [];
  final List<String> disallow = [];
  Duration? crawlDelay;
}

class _CachedRules {
  _CachedRules(this.rules, this.expiresAt);

  final RobotsRules rules;
  final DateTime expiresAt;

  bool get isValid => DateTime.now().isBefore(expiresAt);
}
