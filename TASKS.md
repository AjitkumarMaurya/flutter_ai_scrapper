# flutter_ai_scrapper — Build Tasks

Working checklist for the rebuild of `flutter_scrapper` 1.1.0 into `flutter_ai_scrapper` 2.0.0.
Full rationale lives in the plan: <https://claude.ai/code/artifact/44e3a391-f23d-449c-a874-c459a1707e7b>

**Platforms: Android and iOS only.** Desktop and Web are explicitly out of scope for 2.0. The
`UnsupportedPlatformException` gate stays; it just becomes testable.

**AI providers are pluggable, with on-device Gemma as the floor.** Any OpenAI-compatible or
Claude-style endpoint can be configured and takes priority; when none is set, or the configured one
is misconfigured, rate-limited or unreachable, the chain falls back to `flutter_gemma`. That is what
keeps "works offline, with no API key, for free" true no matter how the app is configured.

---

## How to use this file

- Work **top to bottom**. Phases are sequential; tasks inside a phase are mostly ordered too.
- Tick a task only when its **acceptance** line is true — not when the code is merely written.
- Do not start a phase until the previous phase's **Exit gate** passes.
- Every phase ends with the same two commands passing:

```bash
flutter analyze && flutter test
```

### Conventions

| Thing | Rule |
|---|---|
| Package name | `flutter_ai_scrapper` |
| Version | `2.0.0` (`2.0.0-dev.N` until P6 ships) |
| Public barrel | `lib/flutter_ai_scrapper.dart` — the **only** file directly under `lib/` |
| Everything else | `lib/src/<module>/…`, never exported except through the barrel |
| Demo app | `example/` — the library must never contain `runApp` |
| Test fixtures | `test/fixtures/<site>/page.html` + `expected.json` |
| Min platforms | Android `minSdk 24`, iOS `15.0` (flutter_gemma 1.7.0 floor) |
| Toolchain floor | Dart `>=3.12.0`, Flutter `>=3.44.0` (flutter_gemma 1.7.0 floor) |

### Status legend

`[ ]` not started `[~]` in progress `[x]` done `[-]` skipped (add a reason)

---

# Phase 0 — Rename & repo hygiene

> ✅ **Complete** — 2026-09-02, commit `d5d96dc`, tag `v2.0.0-dev.1`.
> Analyzer 194 → **0** issues. Publish dry-run **0** warnings. Both platforms build.
> Test results unchanged (74 pass / 7 fail, identical before and after) — the proof that
> nothing behavioural moved. Failures documented in `test/KNOWN_FAILURES.md`.
> One new defect surfaced and was logged as **BUG-5** in Phase 1.2.

**Goal:** a correctly-shaped package under the new name, with no behaviour change and version
control in place. Nothing here should alter what the library *does*.

### 0.1 Version control (do this first)

- [x] `git init` in the project root — this fork currently has no history at all
- [x] Verify `.gitignore` covers `build/`, `.dart_tool/`, `*.iml`, `.flutter-plugins*`, `**/Pods/`
- [x] Commit the untouched fork as the baseline: `chore: import flutter_scrapper 1.1.0 fork`
- [x] Create branch `feat/ai-scrapper-2.0` and work there
      <br>**Acceptance:** `git log` shows a baseline commit you can diff every later change against.

### 0.2 Rename the package

- [x] `pubspec.yaml`: `name: flutter_ai_scrapper`, `version: 2.0.0-dev.1`
- [x] `pubspec.yaml`: rewrite `description` (pub.dev shows the first 180 chars — make them count)
- [x] `pubspec.yaml`: update `repository` / `homepage`, add `issue_tracker`
- [x] `pubspec.yaml`: add `topics: [scraping, html, ai, on-device, gemma]`
- [x] `pubspec.yaml`: add an explicit platform declaration so pub.dev states the limit:
      ```yaml
      platforms:
        android:
        ios:
      ```
- [x] Bump SDK constraints to `sdk: '>=3.12.0 <4.0.0'`, `flutter: '>=3.44.0'`
- [x] Find/replace `package:flutter_scrapper/` → `package:flutter_ai_scrapper/` across `test/` and docs
      <br>**Acceptance:** `flutter pub get` resolves; no reference to `flutter_scrapper` remains outside `CHANGELOG.md`.

### 0.3 Fix the package shape

- [x] Create `lib/flutter_ai_scrapper.dart` as the single barrel
- [x] Delete `lib/mobile_scraper.dart` and `lib/flutter_mobile_scraper.dart` as *entrypoints*
      (the scraper class moves to `lib/src/` in P1 — for now just re-export from the barrel)
- [x] Move `lib/main.dart`, `lib/views/`, `lib/viewmodels/` → `example/lib/`
- [x] Remove `provider` from the library's `dependencies`; add it to `example/pubspec.yaml`
- [x] Move all remaining `lib/*.dart` and `lib/<module>/` into `lib/src/`
      <br>**Acceptance:** `ls lib/` shows exactly `flutter_ai_scrapper.dart` and `src/`. Nothing in `lib/` calls `runApp`.

### 0.4 Clean up platform folders

> A pure Flutter *package* with no native code needs no platform folders at all. Only the
> example app does. **Inspect before deleting** — confirm nothing was hand-edited.

- [x] Delete `web/`, `windows/`, `linux/`, `macos/` from the project root
- [x] Delete the root `android/` and `ios/` (they belong to the old app, not the package)
- [x] Delete the stale `example_app/` entirely — its own `widget_test.dart` already fails to compile
- [x] Scaffold `example/` properly: `flutter create --template=app --platforms=android,ios example`
- [x] `example/pubspec.yaml`: add `flutter_ai_scrapper: {path: ../}`
      <br>**Acceptance:** `cd example && flutter build apk --debug` succeeds.

### 0.5 Raise the platform floors

- [x] `example/android/app/build.gradle.kts`: `minSdk = 24`, `compileSdk = 36`
- [x] `example/ios/Podfile`: `platform :ios, '15.0'`
- [x] `example/ios/Runner.xcodeproj`: `IPHONEOS_DEPLOYMENT_TARGET = 15.0`
- [x] Correct the README's platform claims (it currently advertises API 21 / iOS 12 — flutter_gemma cannot honour either)
      <br>**Acceptance:** both platforms build; README matches reality.

### 0.6 Stabilise the test suite

- [x] Run `flutter test` and record the 7 current failures in `test/KNOWN_FAILURES.md`
- [x] For each: decide **fix now** vs **supersede in P1** and note which
- [x] Fix the 5 `unnecessary_string_escapes` analyzer warnings in `lib/src/`
- [x] Silence `avoid_print` in tests (add a `analysis_options.yaml` test override, or use a logger)
- [x] Tightened `analysis_options.yaml`: `strict-casts`, `strict-raw-types`, `strict-inference`
      plus correctness lints. Skipped `dart_code_metrics` — the built-in analyzer covers this.
      <br>**Acceptance:** `flutter analyze` reports **0 issues**.

### ✅ Exit gate — Phase 0

- [x] `flutter analyze` → 0 issues
- [x] `flutter test` → all green (or every failure listed in `KNOWN_FAILURES.md` with a P1 owner)
- [x] `flutter pub publish --dry-run` → no structural complaints
- [~] `cd example && flutter run` — installs, launches and runs clean on a physical Android
      device (CPH2591, API 35): live PID, zero fatal/Flutter errors in logcat. Could not
      *visually* confirm the UI because the device is lock-screened. iOS builds for device
      (`flutter build ios --no-codesign`); only a wireless iPad is paired, so no on-device run.
- [x] Tag `v2.0.0-dev.1`

---

# Phase 1 — DOM core

> ✅ **Complete** — 2026-09-02, commits `b48df92` + `4e5520e`.
> **302 tests** (was 74 with 7 failing), **0** analyzer issues, example builds on Android and iOS.
> All 5 catalogued bugs fixed with regression tests that fail against the old code.
> `test/KNOWN_FAILURES.md` deleted — all 7 inherited failures pass.
>
> Three further defects surfaced during the work and were fixed:
> - `queryWithRegex` forced case-insensitive matching with no opt-out, so `[A-Z][a-z]+`
>   ("a Capitalised word") also matched lowercase. Now defaults to case-sensitive.
> - No way to match a pattern against visible text rather than markup, which is why
>   URLs came back with a trailing `</p>`. Added `RegexTarget`.
> - `&nbsp;` decodes to U+00A0 and survived whitespace normalisation, so plain text
>   silently contained non-breaking spaces. All Unicode space separators now folded.
>
> **Finding worth recording:** five of the seven inherited test files defined a
> `TestMobileScraper` subclass that copy-pasted the buggy regex implementation *into the
> test file* and overrode the real methods with it — so they never tested the library at
> all. Their "coverage" of `queryAll` and `queryWithRegex` was entirely illusory.

**Goal:** replace regex parsing with a real DOM and fix every confirmed bug. This is the
foundation; do not compromise here to reach the AI work sooner.

> **Bugs 1–4 were confirmed by execution against the current source; BUG-5 surfaced during
> Phase 0.** Each gets a regression test that **fails on the old implementation** before the fix
> lands. Write the test first.
>
> The 7 inherited test failures in `test/KNOWN_FAILURES.md` are owned by this phase and Phase 2.
> Three of them are the library being wrong and the test being right — they should go green as a
> *consequence* of the rewrite, not by being edited.

### 1.1 Add the parser

- [x] Add `html: ^0.15.7` to dependencies
- [x] Create `lib/src/dom/dom_document.dart` — wrapper over `html`'s `Document`
- [x] Implement `querySelector` / `querySelectorAll` passthrough with CSS selectors
- [x] Implement `text`, `innerHtml`, `attr(name)`, `attrs`, `parent`, `children`
- [x] Create `lib/src/dom/sanitizer.dart` — strip `script`, `style`, `svg`, `noscript`, `iframe`, comments
- [x] Create `lib/src/dom/url_resolver.dart` — resolve every relative `href`/`src` against `<base>` then the page URL
- [x] Add proper HTML entity decoding (the current hand-rolled 9-entity `replaceAll` chain misses hundreds)
      <br>**Acceptance:** a fixture with nested `<div>`s, malformed tags and `&#x2014;` entities parses correctly.

### 1.2 Fix the confirmed bugs

- [x] **BUG-1 test:** nested same-tag extraction. `<div class="outer"><div class="inner">A</div>TAIL</div>`
      must return the full outer content, not `<div class="inner">A`
- [x] **BUG-1 fix:** delete `_buildTagPattern`; route all tag queries through the DOM
- [x] **BUG-2 test:** class filter isolation. A `<span>` with **no class** must not match a
      `class="target"` filter when an unrelated later element carries that class
- [x] **BUG-2 fix:** class/id filtering via DOM attributes, never regex lookahead
- [x] **BUG-3 test:** a request that exceeds its timeout must surface as the package's timeout type
- [x] **BUG-3 fix:** rename the package's `TimeoutException` → `ScraperTimeoutException` so it
      stops shadowing `dart:async`'s, and catch `async.TimeoutException` explicitly in `_makeRequest`
- [x] **BUG-4 fix:** make `RetryConfig.getDelayForAttempt` genuinely exponential
      (`initialDelay * pow(multiplier, attempt)`) **plus jitter**; add a test asserting the curve
- [x] **BUG-5 test:** a pattern whose groups are all non-capturing (`(?:…)`) must not fail.
      Found during Phase 0 — see `test/KNOWN_FAILURES.md` #3
- [x] **BUG-5 fix:** `queryWithRegex` calls `match.group(1)` unconditionally, so a group-less
      pattern throws `RangeError`, which the broad `catch (e)` then relabels as a `ParseException`
      about failed parsing — pointing the user at entirely the wrong problem. Two changes:
      default to `group: 0` (the whole match) when the pattern has no capture groups, and raise
      `InvalidParameterException` naming the index and the actual group count when an out-of-range
      group is requested
      <br>**Acceptance:** all five tests fail against the pre-fix code and pass after.

### 1.3 Rewrite the network layer

- [x] Create `lib/src/net/fetcher.dart`
- [x] Stream the response and abort once `maxContentSize` is exceeded — check **during** download,
      not after (today the limit protects nothing)
- [x] Charset detection order: `Content-Type` header → `<meta charset>` → BOM → UTF-8 fallback
- [x] Create `lib/src/net/rate_limiter.dart` — per-host minimum interval + max concurrency
- [x] Create `lib/src/net/robots_policy.dart` — fetch, parse and honour `robots.txt`; cache per host
- [x] Default `User-Agent` must be truthful and carry a contact URL
- [x] Replace the `Completer`-based `cancel()` with a proper `CancellationToken`
- [x] Make `dispose()` idempotent and safe to call twice
      <br>**Acceptance:** an oversized page aborts mid-download; a `Disallow: /` host is refused; two rapid requests to one host are spaced.

### 1.4 Rewrite the cache

- [x] Create `lib/src/cache/cache_store.dart` — two-tier LRU (memory + disk)
- [x] Add `path_provider: ^2.1.6`; store under the app documents dir, **not** `Directory.systemTemp`
      (systemTemp is OS-evictable, so the "persistent" cache silently isn't)
- [x] One file per entry keyed by SHA-256 of the URL (`crypto: ^3.0.6`) — stop rewriting the whole
      cache blob on every single write
- [x] Store and send `ETag` / `Last-Modified`; handle `304 Not Modified`
- [x] Enforce `maxSizeMB` and `maxEntries` with real LRU eviction
- [x] Add `CacheStats` (hits, misses, bytes, entry count)
      <br>**Acceptance:** a second fetch of an unchanged URL returns `304` and serves from cache; eviction test holds the size limit under load.

### 1.5 Platform gate — keep it, make it testable

- [x] Create `lib/src/core/platform_info.dart` with an injectable `PlatformInfo` abstraction
- [x] Keep the Android/iOS-only rule; keep throwing `UnsupportedPlatformException`
- [x] Delete the `Platform.environment['FLUTTER_TEST']` sniffing — tests inject a fake `PlatformInfo` instead
- [x] Test both directions: mobile passes, desktop/web throws
      <br>**Acceptance:** no test-awareness code ships in `lib/`, and the gate itself has coverage.

### 1.6 Error model

- [x] Convert `ScraperException` to a `sealed class` so `switch` over it is exhaustive
- [x] Add `HttpStatusException`, `RobotsDisallowedException`, `CancelledException`
- [x] Every exception carries `url`, `stackTrace` and a `userMessage` suitable for UI display
      <br>**Acceptance:** an exhaustive `switch` on the sealed type compiles with no `default`.

### 1.7 Fixture corpus (start it now, grow it every phase)

- [x] Create `test/fixtures/` and a `tool/capture_fixture.dart` script to save real pages
- [x] 10 fixtures: 3 commerce, 3 article, 2 jobs, 1 docs, 1 malformed. **Authored rather than
      captured from live sites** — a fixture must be deterministic and offline so a site
      redesign cannot turn CI red, and committing third-party HTML carries licensing and
      size costs. The capture tool is there for anyone who wants real captures.
- [x] Write `expected.json` for each
- [x] Add a golden test runner that walks the corpus
      <br>**Acceptance:** the corpus runs offline in CI with no network access.

### ✅ Exit gate — Phase 1

- [x] All four confirmed bugs fixed, each with a regression test that fails pre-fix
- [x] Golden tests green across all 10 fixtures
- [x] `flutter analyze` → 0 issues
- [x] Every public member has a dartdoc comment
- [x] Tag `v2.0.0-dev.2`

---

# Phase 2 — Reduction & structured data

> ✅ **Complete** — 2026-09-02, tag `v2.0.0-dev.3`.
> **370 tests** (was 302), **0** analyzer issues.
> Full Schema DSL with Draft-07 JSON Schema emission and type coercion.
> Spec-compliant JSON-LD, Microdata, RDFa Lite and OpenGraph harvesters with
> coverage reporting and automatic schema mapping.
> Readability scoring engine eliminates page chrome and extracts clean articles.
> GFM MarkdownWriter with table rendering and structural chunking.
> BM25 ranker with synonym expansion; token budget with output headroom reservation.
> Tier-1 public API (`AiScrapper.open`, `ScrapedPage`) working with zero AI installed.
> Fabricated currency bug and loose phone regex fixed.
> Corpus expanded to 15 offline fixtures.

**Goal:** shrink a 50k-token page to ~1.5k deterministically, and answer many extractions with
no model at all. **After this phase the library is already better than the fork, with zero AI.**

### 2.1 Schema DSL

- [x] Create `lib/src/schema/field.dart`: `Field.string/number/money/date/url/email/phone/bool/enum_`
- [x] Create `lib/src/schema/schema.dart`: `Schema.object(...)`, `Schema.list(...)`, nesting support
- [x] `Schema.toJsonSchema()` — emits Draft-07, the shape `flutter_gemma`'s `Tool.parameters` wants
- [x] `Schema.validate(Map)` → `ValidationResult` with per-field errors
- [x] Type coercion: `"12.99"` → `12.99`, `"2024-01-15"` → `DateTime`
- [x] Round-trip test: `Schema` → JSON Schema → validate a known-good and known-bad payload
      <br>**Acceptance:** JSON Schema output validates against a Draft-07 meta-schema.

### 2.2 Structured data harvesting (the biggest free win)

- [x] Create `lib/src/structured/json_ld.dart` — parse all `<script type="application/ld+json">`,
      handle `@graph` and arrays
- [x] Create `lib/src/structured/microdata.dart` — `itemscope` / `itemtype` / `itemprop`
- [x] Create `lib/src/structured/rdfa.dart` — `vocab` / `typeof` / `property`
- [x] Create `lib/src/structured/open_graph.dart` — OG + Twitter cards + `<link rel=canonical>`
- [x] Create `lib/src/structured/mapper.dart` — map schema.org types (`Product`, `Article`,
      `JobPosting`, `Recipe`, `Event`, `BreadcrumbList`) onto a requested `Schema`
- [x] Emit a coverage report: which requested fields were satisfied, which are still missing
      <br>**Acceptance:** on the commerce fixtures, a standard product schema is satisfied **entirely** from structured data — zero inference.

### 2.3 Readability

- [x] Create `lib/src/readability/scorer.dart` — DOM node scoring
- [x] Score inputs: text length, link density, `<p>` count, comma count, tag-name weight
- [x] Negative weights for `comment|sidebar|footer|nav|ad|promo|social|share|related` in class/id
- [x] Positive weights for `article|content|post|entry|main|body|story`
- [x] Walk up to find the top candidate, then include qualifying siblings
- [x] Preserve images and captions inside the selected content
      <br>**Acceptance:** on the article fixtures, extracted text is within ±10% of a hand-marked ground truth, with nav and footer gone.

### 2.4 Markdown serialiser

- [x] Create `lib/src/reduce/markdown_writer.dart` — DOM → Markdown (never regex → Markdown)
- [x] Handle `h1`–`h6`, `p`, `ul`/`ol`/`li` (incl. nesting), `a`, `img`, `strong`/`em`, `code`/`pre`, `blockquote`, `hr`
- [x] **Tables → real GFM tables** with `th` detection (the current formatter flattens them to pipe soup)
- [x] `MarkdownOptions`: `includeImages`, `includeLinks`, `maxDepth`, `preserveTables`
- [x] Measure and assert the reduction ratio vs. the raw HTML
      <br>**Acceptance:** ≥10× token reduction across the whole corpus, measured and asserted in a test.

### 2.5 Chunking & ranking

- [x] Create `lib/src/reduce/token_estimator.dart` (~4 chars/token heuristic; document the error bar)
- [x] Create `lib/src/reduce/chunker.dart` — split on heading boundaries with configurable overlap
- [x] Create `lib/src/reduce/bm25_ranker.dart` — score chunks against requested field names + synonyms
- [x] Create `lib/src/reduce/budget.dart` — select top-K chunks that fit, **reserving output headroom**
- [x] Never split a table or list mid-structure
      <br>**Acceptance:** for a known query the chunk containing the answer ranks in the top 3 on ≥8/10 fixtures.

### 2.6 Tier-1 public API

- [x] `AiScrapper.open(url)` → `ScrapedPage`
- [x] `page.article()` → `Article` (title, byline, publishDate, body markdown, images, readingTime)
- [x] `page.markdown`, `page.plainText`, `page.metadata`, `page.links`, `page.images`, `page.tables`
- [x] `page.extract(schema)` — structured-data path only for now; returns `partial: true` when incomplete
- [x] **Fix the fabricated-currency bug:** money parsing must detect the real symbol/code
      (`€99` must never become `$99`)
- [x] **Fix the phone regex:** require a real phone shape, or drop the feature until P6's normalisers
      (today it matches dates, SKUs and prices)
      <br>**Acceptance:** Tier-1 works end to end with **no model installed**.

### ✅ Exit gate — Phase 2

- [x] Token reduction ≥10× measured across the corpus
- [x] Structured-data path alone satisfies a product schema on a majority of commerce fixtures
- [x] Corpus grown to 15 fixtures
- [x] `flutter analyze` → 0 issues, `flutter test` green
- [x] Tag `v2.0.0-dev.3` — **this is a shippable improvement on its own**

---

# Phase 3 — Provider layer + Gemma

**Goal:** first inference, behind an abstraction. Gemma is built first because it is the
**guaranteed floor** — the thing that makes "works offline, with no API key, for free" true.
Cloud adapters plug into the same seam in Phase 4.

### 3.1 Dependencies & init

- [ ] Add `flutter_gemma: ^1.7.0` to the library
- [ ] Add `flutter_gemma_litertlm` **and** `flutter_gemma_mediapipe` to `example/` only
      (engines are opt-in — the library must not pick for the consumer)
- [ ] Document loudly: a missing engine surfaces as a `StateError` on first model creation,
      and users will report it as our bug
- [ ] **Register both engines in the example app.** LiteRT-LM is arm64-v8a only, so it cannot load
      a model on the x86_64 Android emulator; MediaPipe (`.task`) covers x86_64/armeabi-v7a for text
- [ ] Resolve the dependency set **before** writing code against it — `flutter_gemma_litertlm` is
      published at 1.6.1 against a 1.7.0 core; confirm they co-resolve
      <br>**Acceptance:** `flutter pub get` resolves; the example runs on both a physical device and an emulator.

### 3.2 Provider seam

- [ ] Create `lib/src/ai/ai_provider.dart` — the abstract contract:
      `id`, `capabilities`, `isReady`, `extract(schema, content)`, `complete(prompt)`,
      `stream(prompt)`, `dispose()`
- [ ] `AiCapabilities`: `supportsJsonSchema`, `supportsTools`, `maxContextTokens`,
      `maxOutputTokens`, `supportsStreaming`, `supportsVision`, `supportsThinking`, `isLocal`,
      `costPerMTokIn` / `costPerMTokOut`
- [ ] **Design the contract so `extract()` is the seam, not `complete()`.** Each provider must be
      free to use its own native constrained-output mechanism. Never reduce to "send text, parse JSON"
- [ ] Create `lib/src/ai/fake_ai_provider.dart` — scripted responses for CI
      (**write this before `GemmaProvider`** so the pipeline is testable without a 550 MB download)
- [ ] Create `lib/src/ai/providers/gemma_provider.dart` — the real implementation
- [ ] Add `AiResult` carrying `providerId`, `TokenUsage` and `estimatedCost`
      <br>**Acceptance:** the full pipeline runs in CI against `FakeAiProvider` with no model present.

### 3.3 Model lifecycle

- [ ] Create `lib/src/ai/model_manager.dart` wrapping `FlutterGemma.installModel(...)`
- [ ] Support `fromHuggingFace` / `fromNetwork` / `fromAsset`, with progress callbacks
- [ ] `isModelInstalled`, `listInstalledModels`, `uninstallModel`, `getStorageInfo`
- [ ] Map every `DownloadException` case — `UnauthorizedError` (401) and `ForbiddenError` (403)
      mean a **gated HF repo**, and the message must say so plainly
- [ ] Curated `GemmaModels` catalogue with real sizes and a `supportsTools` flag (below)
- [ ] Wi-Fi-only default, resumable downloads, explicit unload to free memory
      <br>**Acceptance:** download → extract → uninstall works on a real device; a gated-repo 403 gives an actionable message.

Function calling is not universal, and the extraction path depends on it:

| Model | Size | Tools | Role |
|---|---|---|---|
| Gemma 3 1B | ~550 MB | ✅ | **default** |
| FunctionGemma 270M | ~300 MB | ✅ native | lightest viable; single-turn by design, which suits extraction |
| Qwen3 0.6B | ~400 MB | ✅ | low-RAM devices |
| Gemma 4 E2B | ~2.4 GB | ✅ native | quality tier; Wi-Fi-only download |
| Gemma 3 270M | ~200 MB | ❌ | **exclude — unusable for this path** |

### 3.4 Schema-as-tool bridge (the core mechanism)

- [ ] Create `lib/src/ai/tool_bridge.dart` — `Schema` → `Tool(name, description, parameters)`
- [ ] Open the chat with `toolChoice: ToolChoice.required` so the model **must** emit a call
- [ ] Read the result from `FunctionCallResponse.args`, never by parsing prose
- [ ] `temperature: 0.1`, `topK: 1` — extraction is not a creative task
- [ ] Handle `ParallelFunctionCallResponse` (merge) and `ThinkingResponse` (surface separately)
- [ ] Validate `args` against the schema; on failure retry once with the errors fed back
- [ ] Fall back to prose + JSON parsing when `capabilities.supportsFunctionCalls` is false
      <br>**Acceptance:** ≥90% schema conformance across the corpus with Gemma 3 1B.

### 3.5 Extraction strategies

- [ ] Create `lib/src/ai/extractor.dart`
- [ ] Object schemas: single pass over the top-ranked chunks
- [ ] List schemas: **map-reduce** — extract per chunk, then merge and dedupe
- [ ] Deduplicate merged list items by a configurable key
- [ ] Per-field confidence scores on the result
- [ ] Enforce a wall-clock budget with graceful partial results
      <br>**Acceptance:** a paginated product list yields a complete deduplicated set.

### 3.6 Provenance

- [ ] Add `enum ExtractionSource { jsonLd, microdata, openGraph, recipe, ai, heuristic }`
- [ ] Every extracted field carries its source and confidence
- [ ] **Deterministic sources always win over AI** when both produce a value
- [ ] The pipeline short-circuits before inference whenever structured data already satisfies the schema
      <br>**Acceptance:** a field present in JSON-LD is never overwritten by a model guess.

### 3.7 Make the token budget provider-derived

- [ ] `lib/src/reduce/budget.dart` reads `capabilities.maxContextTokens` instead of a constant
- [ ] Small window (Gemma, ~2k): full chunk ranking, top-K selection, map-reduce for lists
- [ ] Large window (cloud, 128k): skip ranking and send the whole Markdown — simpler and more accurate
- [ ] Always reserve output headroom proportional to the schema's expected size
- [ ] **Stages 3 and 4 run first regardless of provider** — they are free and exact, and no cloud
      model beats not making the call at all
      <br>**Acceptance:** the same extraction produces the same result under a 2k and a 128k budget, with fewer stages executed in the second.

### ✅ Exit gate — Phase 3

- [ ] End-to-end AI extraction verified on a physical Android device and a physical iPhone
- [ ] Schema conformance ≥90% on the corpus
- [ ] Every AI path degrades to a deterministic result rather than throwing
- [ ] CI green with `FakeAiProvider`, no model download required
- [ ] Tag `v2.0.0-dev.4`

---

# Phase 4 — Cloud providers & fallback

**Goal:** any OpenAI-compatible or Claude-style endpoint can take over, and everything degrades to
on-device Gemma when it is absent, misconfigured, rate-limited or unreachable.

> The cloud adapters are **pure HTTP** — no native code, no extra platform weight. All the
> structural work was done in P3; this phase fills the seam.

### 4.1 OpenAI-compatible adapter (widest reach for the least code)

- [ ] Create `lib/src/ai/providers/openai_provider.dart` targeting `POST {baseUrl}/chat/completions`
- [ ] **`baseUrl` is a required, first-class parameter** — that one field is what makes this adapter
      cover OpenAI, Azure OpenAI, Groq, Together, Fireworks, OpenRouter, DeepSeek, Mistral, xAI,
      and the local servers Ollama (`http://localhost:11434/v1`), LM Studio and vLLM
- [ ] Structured output, in descending order of preference:
      1. `response_format: {type: "json_schema", json_schema: {…, strict: true}}` — true constrained decoding
      2. `tools` + `tool_choice: {type: "function", function: {name}}` — forced call
      3. prompted JSON with a repair pass — last resort only
- [ ] Probe/declare which of the three an endpoint supports; cache the answer per `baseUrl` + model
- [ ] Streaming via SSE for `stream()`
- [ ] Map `usage.prompt_tokens` / `completion_tokens` into `TokenUsage`
- [ ] Custom headers hook (Azure `api-key`, OpenRouter `HTTP-Referer`, proxy auth)
- [ ] Verify against a real Ollama instance — free, local, and the best manual test target
      <br>**Acceptance:** the same extraction passes against OpenAI and against local Ollama with only `baseUrl`/`model` changed.

### 4.2 Anthropic adapter

- [ ] Create `lib/src/ai/providers/anthropic_provider.dart` targeting `POST /v1/messages`
- [ ] Required headers: `x-api-key`, `anthropic-version`
- [ ] Structured output via `tools` + `tool_choice: {type: "tool", name: …}`; read the
      `tool_use` block's `input`
- [ ] Handle the content-block array shape (`text`, `tool_use`, `thinking`) — it is not
      OpenAI-shaped and must not be forced into that mould
- [ ] Streaming via SSE (`content_block_delta`)
- [ ] Map `usage.input_tokens` / `output_tokens` into `TokenUsage`
      <br>**Acceptance:** forced tool use returns a schema-valid map on the first attempt.

### 4.3 Custom adapter

- [ ] Create `lib/src/ai/providers/custom_provider.dart` — caller supplies a callback plus a
      declared `AiCapabilities`
- [ ] Document it as the escape hatch for internal gateways and proprietary models, so an
      unsupported stack is never a blocker
      <br>**Acceptance:** a 20-line callback wired to an arbitrary endpoint completes an extraction.

### 4.4 ProviderChain — the fallback engine

Implement these rules exactly — each row gets its own test in 4.7:

| Condition | Behaviour |
|---|---|
| Not configured | Next in chain. Not an error. |
| Network unreachable / timeout | Next in chain. |
| `429` rate limited | Retry with backoff honouring `Retry-After`, then next. |
| `5xx` | Retry, then next. |
| `401` / `403` bad or missing key | Next, **but log at warning level** and record it on the result. |
| Schema validation failed | One repair attempt on the same provider, then next. |
| All providers exhausted | Best partial result, else `NoProviderAvailableException`. |

- [ ] Create `lib/src/ai/provider_chain.dart` — ordered list, tried in sequence
- [ ] Implement every row of the table above
- [ ] **Never let a bad key degrade silently.** A wrong key that quietly drops to a weaker model
      for months is worse than a loud failure — surface it in result metadata, not just logs
- [ ] `GemmaProvider` is always valid as the terminal link; warn at config time if the chain ends
      with a network provider (the chain then has no offline floor)
- [ ] Per-provider timeout and circuit breaker — stop hammering an endpoint that is down
- [ ] Optional `preferLocal` mode: try Gemma first, escalate to cloud only on low confidence
      <br>**Acceptance:** killing the network mid-run falls through to Gemma and still returns a result, with the switch visible in provenance.

### 4.5 Key handling and privacy (do not defer this)

- [ ] **Never** show a hardcoded key in any example, README snippet or test
- [ ] Document the proxy pattern as the default: the app talks to your backend, the backend holds the key
- [ ] Support runtime key entry stored via `flutter_secure_storage` for developer-facing tools
- [ ] Add an explicit `allowCloudEgress` flag, defaulting to **false**, so sending scraped content
      off-device is a decision rather than an accident
- [ ] Redact keys from every log line and error message
- [ ] `doc/PROVIDERS.md`: setup per provider, the key-exposure problem stated plainly, the
      Ollama path for people who want cloud-grade convenience without egress
      <br>**Acceptance:** a security reader cannot find a path in the docs that encourages shipping a key in a binary.

### 4.6 Cost and usage accounting

- [ ] `TokenUsage` on every result; aggregate per session
- [ ] Estimated cost from a per-model price table (clearly marked as an estimate)
- [ ] `onUsage` callback so apps can meter or cap spend
- [ ] Log the cost saved by structured-data and recipe short-circuits — this is the number that
      justifies the whole reduction pipeline
      <br>**Acceptance:** a 10-page run reports total tokens, estimated cost, and how many pages never reached a provider at all.

### 4.7 Provider tests

- [ ] Mock HTTP fixtures for each provider's success, `429`, `401`, `5xx` and malformed-response cases
- [ ] Chain tests: every row of the 4.4 table
- [ ] Cross-provider conformance: one schema, one fixture, all providers, comparable results
- [ ] No test may require a real API key
      <br>**Acceptance:** full provider matrix green in CI with zero network access.

### ✅ Exit gate — Phase 4

- [ ] The same extraction runs unchanged across Gemma, an OpenAI-compatible endpoint and Claude
- [ ] Network loss mid-run falls back to Gemma and still returns a result
- [ ] Every result names the provider that answered it
- [ ] No key appears in any doc, example or log
- [ ] Tag `v2.0.0-dev.5`

---

# Phase 5 — Recipes & natural language

**Goal:** AI once per site, deterministic forever. This is what makes the library usable in a loop.

> **Why this comes after Phase 4:** recipe synthesis is the one call where model quality matters
> most, and it happens once. Synthesise with a strong cloud model, then run the recipe on-device
> for free on every page after. Expensive judgement once, free execution forever.

### 5.1 Structural skeleton

- [ ] Create `lib/src/recipe/skeleton.dart` — DOM with text elided, repeated siblings collapsed,
      class names and structure kept
- [ ] Cap skeleton depth and size so it fits the model's context
- [ ] Annotate repeated sibling groups with counts — the model needs those to spot list containers
      <br>**Acceptance:** a 400 KB catalogue page produces a skeleton under 1,500 tokens.

### 5.2 Selector synthesis

- [ ] Create `lib/src/recipe/synthesizer.dart`
- [ ] Prompt: skeleton + target schema → a selector recipe (container + per-field selector/attr/parse)
- [ ] Model the output as a `Tool` so the recipe comes back schema-shaped, not as prose
- [ ] **Verify before storing:** run the recipe against the sample page and compare with the AI
      extraction. Reject on mismatch and fall back to per-page inference
- [ ] Record a confidence score on the recipe
      <br>**Acceptance:** a synthesised recipe reproduces AI extraction on held-out pages from the same host.

### 5.3 Recipe runtime

- [ ] Create `lib/src/recipe/recipe.dart` — model + JSON serialisation
- [ ] Create `lib/src/recipe/runner.dart` — pure CSS execution, **zero AI**
- [ ] Create `lib/src/recipe/store.dart` — persist per `host + schemaHash`
- [ ] Drift detection: match count collapsing to zero means the site changed
- [ ] `RepairPolicy`: `resynthesize` | `fallbackToAi` | `fail`
- [ ] Recipe versioning with a TTL
      <br>**Acceptance:** page 2+ on a known host costs **zero tokens**; a mutated fixture trips re-synthesis.

### 5.4 Natural-language planner

- [ ] Create `lib/src/ai/planner.dart` — sentence → `Schema`
- [ ] Infer field names, types and cardinality (`list` vs `object`) from the request
- [ ] `page.ask('...')` → runs the planner, then the Tier-2 path
- [ ] Return the inferred schema alongside results so the caller can inspect and correct it
      <br>**Acceptance:** 10 sample questions produce usable schemas; the inferred schema is visible to the caller.

### ✅ Exit gate — Phase 5

- [ ] Recipes verified on ≥5 hosts, ≥3 pages each
- [ ] Measured cost: page 1 = N tokens, pages 2–N = 0 tokens
- [ ] Drift → repair cycle proven on a mutated fixture
- [ ] Tag `v2.0.0-dev.6`

---

# Phase 6 — Output, normalisation & UI

**Goal:** the visible half — trustworthy formatted output and a real demo app.

### 6.1 Normalisers (deterministic first, model only for residue)

- [ ] Create `lib/src/output/normalizers/date_normalizer.dart` → ISO 8601; handle relative dates
- [ ] `money_normalizer.dart` → `{amount, currency}` with **real** symbol/code detection
      (closes the fabricated-`$` bug for good)
- [ ] `phone_normalizer.dart` → E.164 with region hints
- [ ] `url_normalizer.dart` → absolute, deduped, tracking params stripped
- [ ] `number_normalizer.dart` → locale-aware separators
- [ ] Route only what the deterministic parsers **reject** to the model
      <br>**Acceptance:** ≥95% of corpus values normalise with no inference at all.

### 6.2 Output codecs

- [ ] `toJson()` — with and without provenance metadata
- [ ] `toCsv()` — flattening rules for nested objects, correct quoting/escaping
- [ ] `toMarkdownTable()`
- [ ] `toTyped<T>(fromJson)` — typed Dart objects
- [ ] `toPrettyString()` for debugging
      <br>**Acceptance:** CSV round-trips through a spreadsheet without mangling.

### 6.3 UI — model manager (build this first; it is the hardest)

- [ ] `lib/src/ui/model_manager_sheet.dart`
- [ ] Model list with sizes, capability badges, and installed state
- [ ] Download with progress, pause/resume/cancel
- [ ] Wi-Fi-only toggle; storage usage; delete
- [ ] Clear, actionable errors for gated-repo 401/403 and out-of-space
      <br>**Acceptance:** a user can install and remove a model without touching code.

### 6.4 UI — provider settings

- [ ] `lib/src/ui/provider_settings_sheet.dart` — configure the chain and reorder it
- [ ] Per-provider: enable, `baseUrl`, model, key entry (obscured, stored in secure storage)
- [ ] "Test connection" button giving a real pass/fail, not a silent save
- [ ] Show which provider is currently answering, and the session's token spend
- [ ] Make the offline/no-key path visibly fine — the empty state must read as "ready", not "unconfigured"
- [ ] Surface `allowCloudEgress` as a clear, explained toggle
      <br>**Acceptance:** a user can add a key, verify it, and see the chain fall back when they disable the network.

### 6.5 UI — the rest

- [ ] `lib/src/ui/extraction_console.dart` — URL field, schema builder, **live stage-by-stage
      progress showing which stage answered and what it cost**
- [ ] `lib/src/ui/result_viewer.dart` — table / JSON / Markdown / raw views
- [ ] **Provenance badges** on every field — this is what makes AI extraction trustworthy in a UI
- [ ] `lib/src/ui/streaming_text_view.dart` — token-by-token, with a thinking-mode section
- [ ] Copy and export actions throughout
- [ ] Material 3, dynamic colour, full light **and** dark
- [ ] **No `provider` dependency** — `ValueNotifier` + `ListenableBuilder` only, so the library
      imposes no state-management choice on consumers
      <br>**Acceptance:** every widget renders correctly in light and dark on both platforms.

### 6.6 Demo app

- [ ] Rebuild `example/lib/main.dart` around the four API tiers
- [ ] Screen per tier: quick scrape / schema extract / ask a question / recipes
- [ ] Provider settings screen, reachable from the console, with a live "answering with…" indicator
- [ ] Model manager entry point
- [ ] Bundled sample URLs so the app is useful before any download
- [ ] History with re-run
      <br>**Acceptance:** the demo runs the full pipeline on a physical device across all four tiers.

### ✅ Exit gate — Phase 6

- [ ] All four API tiers work in the demo on Android and iOS
- [ ] Widgets verified in light and dark
- [ ] Normalisation ≥95% deterministic
- [ ] Tag `v2.0.0-rc.1`

---

# Phase 7 — Hardening & release

**Goal:** publish something you would be happy to have your name on.

### 7.1 Test corpus & coverage

- [ ] Grow the corpus to **25+ real sites**: commerce, news, jobs, docs, listings, forums, recipes
- [ ] Include the hostile cases: malformed HTML, huge pages, non-UTF-8, RTL, heavy JS shells
- [ ] Line coverage ≥80% on `lib/src/`
- [ ] Integration tests on a real device for the AI paths
      <br>**Acceptance:** `flutter test --coverage` meets the bar; corpus runs offline.

### 7.2 Benchmarks

- [ ] `benchmark/` — latency per pipeline stage
- [ ] Memory high-water mark with a model loaded
- [ ] Battery draw for a 100-page run
- [ ] Token cost: AI path vs recipe path
- [ ] **Publish the numbers in the README** rather than letting users discover them
      <br>**Acceptance:** real measured figures, on named devices.

### 7.3 Documentation

- [ ] Dartdoc on **every** public member, with examples
- [ ] README rewritten around the pipeline: what it does, what it costs, what it needs
- [ ] Honest platform table — Android and iOS only, and why
- [ ] `doc/MIGRATION.md` from 1.1.0, **explicitly calling out that the nested-tag and
      class-filter fixes change real output** for anyone who depended on the buggy behaviour
- [ ] `doc/ETHICS.md` — robots.txt, rate limiting, terms of service, personal data.
      Non-negotiable for a scraping library
- [ ] `doc/MODELS.md` — which model to pick and why
- [ ] `doc/PROVIDERS.md` — per-provider setup, the fallback rules, the key-exposure problem
      stated plainly, and the local-Ollama path for cloud-grade quality without egress
- [ ] `CHANGELOG.md` for 2.0.0 with a clear **Breaking changes** section
      <br>**Acceptance:** a developer can go from `pub add` to a working extraction using the README alone.

### 7.4 Compatibility shim

- [ ] Keep `MobileScraper` as a `@Deprecated` facade over the new core for one minor cycle
- [ ] Point each deprecation message at its specific replacement
- [ ] Test that the deprecated surface still functions
      <br>**Acceptance:** 1.1.0 code compiles with warnings, not errors — except where behaviour was a bug.

### 7.5 Release

- [ ] CI: `analyze` + `test` + example build on Android and iOS
- [ ] `flutter pub publish --dry-run` clean
- [ ] Verify the pub.dev score components: dartdoc, example, platforms, up-to-date deps, null safety
- [ ] `LICENSE` and author metadata correct
- [ ] `flutter pub publish`
- [ ] Tag `v2.0.0`, write release notes
      <br>**Acceptance:** pub.dev score at or near 160/160.

### ✅ Exit gate — Phase 7

- [ ] Published to pub.dev
- [ ] 0 analyzer issues, coverage ≥80%
- [ ] CI green on Android and iOS

---

## Deferred — not in 2.0

Recorded so they don't creep into the phases above.

- [ ] **JS-rendered pages** via `webview_flutter` (render + screenshot) — a companion package.
      Would roughly double Phase 1's surface area.
- [ ] **Vision extraction** — screenshot → multimodal model. Depends on the above.
- [ ] **RAG over a crawl** — `flutter_gemma` ships embeddings and a vector store, so a scraped
      corpus becomes queryable. Genuinely valuable, but after the core lands.
- [ ] **Multi-page crawling** — depth limits, URL frontier, sitemap parsing.
- [ ] **Desktop and Web support** — deliberately out of scope; revisit only on demand.
- [ ] **LoRA fine-tunes** for domain-specific extraction.
- [ ] **Server-side batch mode** — a companion Dart CLI reusing the same pipeline off-device,
      where cloud keys are safe to hold and page volume is unbounded.
