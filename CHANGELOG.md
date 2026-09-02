# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

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