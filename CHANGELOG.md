# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [2.0.0-dev.2] - 2026-09-02

Phase 1: the parsing core is replaced. Every extraction path now runs through
`package:html` — a real HTML5 parser — instead of regular expressions.

### Fixed

- **Nested containers no longer truncate.** `<div>(.*?)</div>` stopped at the first
  closing tag, so querying any container returned a fragment and silently dropped the
  rest.
- **Class filters no longer leak across the document.** The regex lookahead ran with
  `dotAll`, so it scanned the whole remaining page — an element with no class at all
  matched a class filter because an unrelated later element carried it. *Wrong data,
  no error.*
- **Timeouts are caught.** The package declared its own `TimeoutException`, which
  shadowed `dart:async`'s inside the same library, so `on TimeoutException` never
  matched what `.timeout()` throws. Every timeout was mislabelled as an unexpected
  network error.
- **Backoff is exponential.** It computed `initialDelay × (multiplier × attempt)` —
  linear — while documenting exponential. Jitter added, so clients no longer retry a
  struggling host in lockstep.
- **Group-less regex patterns work.** `queryWithRegex` read group 1 unconditionally, so
  a pattern of only non-capturing `(?:…)` groups threw `RangeError`, relabelled as
  "Failed to parse HTML" — pointing the caller at their markup instead of the group index.
- **Regex is case-sensitive by default**, matching Dart's own `RegExp`. 1.x forced
  case-insensitivity with no opt-out, so `[A-Z][a-z]+` also matched lowercase.
- **Non-breaking spaces are folded.** `&nbsp;` decodes to U+00A0 and survived whitespace
  normalisation, so `text.contains('12 %')` failed against `12\u{00A0}%` invisibly.
- **The size limit works.** It was checked after the whole body had been buffered into
  memory; it now aborts mid-download.
- **The cache is durable.** It lived in `Directory.systemTemp`, which the OS may clear at
  any time, and rewrote every entry into one JSON file on each write.

### Added

- `HtmlDocument` / `HtmlNode` with CSS selectors, `blockText`, and URL resolution that
  honours `<base href>`.
- `SelectorGuard`, which **refuses** selectors `package:html` answers wrongly. Structural
  pseudo-classes like `li:nth-child(2)` return zero matches on markup that plainly
  contains them; a confidently empty result is worse than a refusal, so these raise
  `InvalidSelectorException` naming the workaround.
- `RegexTarget`, so a pattern can run against visible text instead of markup — the fix
  for URLs captured with a trailing `</p>`.
- `robots.txt` support, per-host rate limiting and a truthful `User-Agent`, all on by
  default.
- Conditional requests with `ETag`/`Last-Modified`, so an unchanged page costs a `304`.
- Charset detection: BOM, then `Content-Type`, then `<meta charset>`. 1.x read only the
  header, so pages declaring encoding in markup came back as mojibake.
- `CancellationToken`. 1.x's `cancel()` completed an error on a `Completer` nobody
  awaited, producing an unhandled async error rather than stopping the work.
- A 10-page golden fixture corpus and `tool/capture_fixture.dart`.

### Changed — breaking

- `TimeoutException` → `ScraperTimeoutException` (the old name shadowed `dart:async`'s).
- `ScraperException` is now `sealed`, with `InvalidUrlException`, `HttpStatusException`,
  `RobotsDisallowedException`, `CancelledException` and `InvalidSelectorException` split
  out. Every exception carries a `userMessage` safe to show a person.
- `ContentFormatter` and `SmartExtractor` take an `HtmlDocument`, not a `String`.
- `ContentFormatter.toCleanHtml`, `removeClutter` and `extractReadableText` removed.
- `CacheManager` replaced by `CacheStore`.
- `estimateReadingTime` reports seconds rather than rounding up to whole minutes.
- The platform gate no longer inspects `Platform.environment` for `FLUTTER_TEST`. Tests
  inject a `PlatformInfo` instead, so no test awareness ships in production code.

### Removed

- **Price extraction.** It stamped `$` on every match regardless of currency, so `€99`
  came back as `$99`. Fabricating currency is worse than returning nothing; real money
  parsing arrives with the structured-data work.
- **Phone extraction.** Its pattern matched dates, SKUs and IDs as freely as phone
  numbers. Returning when it can be done with region-aware parsing.

## [2.0.0-dev.1] - 2026-09-02

Phase 0 of the 2.0 rebuild: the package is renamed and correctly shaped. **No scraping
behaviour changed in this release** — the 7 inherited test failures fail identically before
and after, which is the evidence for that claim.

### Breaking

- **Renamed** `flutter_scrapper` → `flutter_ai_scrapper`.
- **Single entrypoint.** `lib/mobile_scraper.dart` and `lib/flutter_mobile_scraper.dart` are
  replaced by `package:flutter_ai_scrapper/flutter_ai_scrapper.dart`. Everything else moved
  under `lib/src/` and is no longer importable directly.
- **`ScraperViewModel` moved to the example app.** A package should not ship a `ChangeNotifier`
  bound to a particular state-management library. Purpose-built widgets arrive in a later phase.
- **`provider` is no longer a dependency**, so the package imposes no state-management choice.
- **Platform floors raised** to Android minSdk 24 (was API 21) and iOS 15.0 (was iOS 12), as
  required by `flutter_gemma` 1.7.0. The old floors were never achievable alongside on-device AI.
- **SDK floors raised** to Dart >=3.12.0 and Flutter >=3.44.0.
- **Android and iOS only**, now declared in `pubspec.yaml` so pub.dev states it rather than
  leaving consumers to hit it at runtime.

### Changed

- Default `User-Agent` is now truthful and carries a contact URL.
- Analyzer tightened (`strict-casts`, `strict-raw-types`, `strict-inference`, plus correctness
  lints). Issue count went from 194 to **0**.
- The demo app moved to `example/`, and the stale `example_app/` — whose own widget test never
  compiled — was removed.

### Known issues

7 inherited tests fail, all traced to the regex parsing engine that Phase 1 replaces. Three are
cases where the test is right and the library is wrong. See `test/KNOWN_FAILURES.md`.

## [1.1.0] - 2025-10-09

### Changed
- Upgraded package version to 1.1.0
- Updated dependencies to latest versions

## [0.1.0] - 2024-01-15

### Added
- Initial release of flutter_scrapper
- Basic HTML scraping functionality for mobile platforms
- Support for tag-based content extraction
- Support for regex-based content extraction
- Smart content extraction with auto-detection
- High-performance caching system
- Content formatting (plain text, markdown, clean HTML, readable)
- Comprehensive error handling
- Platform validation (Android/iOS only)
- Retry mechanism with exponential backoff
- Configurable timeout and headers
- Complete test coverage

### Features
- **Smart Content Extraction**: Auto-detect titles, descriptions, images, prices, and more
- **High-Performance Caching**: 50x faster repeated requests with intelligent caching
- **Professional Content Formatting**: Clean text, Markdown, readability mode
- **Production Ready**: Error handling, retry logic, resource management

### Platform Support
- ✅ Android
- ✅ iOS
- ❌ Web (by design)
- ❌ Desktop (by design)

### Documentation
- Comprehensive README with examples
- API documentation with dartdoc comments
- MVVM architecture explanation
- Usage examples and best practices 