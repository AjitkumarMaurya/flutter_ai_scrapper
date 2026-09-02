# Ethics, Privacy & Responsible Mobile Scraping

Web scraping on mobile devices carries distinct responsibilities. Mobile scrapers run on decentralized client IP addresses, share cellular bandwidth with users, and handle raw web content directly on user devices.

`flutter_ai_scrapper` is built on a "polite by default, private by design" philosophy.

---

## 1. Zero-Egress Privacy Default

Mobile scraping should never silently leak user browsing history or scraped page contents to third-party cloud APIs.

- **`allowCloudEgress: false` by default:** In `ProviderChain`, all cloud-based providers (OpenAI, Claude, external proxies) are skipped by default.
- **Local First:** Scraped HTML, readability prose, and JSON-LD stay on-device. Extraction is performed either deterministically or using local on-device models (`GemmaProvider`).
- **Secret Redaction:** `KeySanitizer` automatically scrubs API keys and bearer tokens from logs, error messages, and exception diagnostics to prevent accidental leakage in telemetry or crash reports.

```dart
// To explicitly allow off-device egress, callers must opt-in:
final chain = ProviderChain(
  providers: [localGemma, cloudOpenAi],
  allowCloudEgress: true, // Requires explicit developer consent
);
```

---

## 2. Robots.txt Compliance

Respecting `robots.txt` is standard practice for respectful crawlers:

- `RobotsPolicy.strict`: Prohibits accessing paths disallowed for your User-Agent or `*`.
- `RobotsPolicy.lenient` (default): Checks `robots.txt`, respects `Crawl-delay` directives, and logs warnings on disallow rules.
- `RobotsPolicy.disabled`: Ignores `robots.txt` (only appropriate for closed testing or personal domains).

Always pass an identifiable `User-Agent` with contact information when conducting automated indexing.

---

## 3. Rate Limiting & Network Courtesy

Do not hammer target web servers. In `flutter_ai_scrapper`:

- Every host domain is bounded by a per-host `RateLimiter` (default 2.0 requests/second).
- 429 Too Many Requests responses automatically enforce exponential backoff and honor standard `Retry-After` headers.
- If a server responds with `5xx` or `429`, the built-in circuit breaker trips after 3 consecutive failures to prevent hammering unresponsive hosts.

---

## 4. Personal Identifiable Information (PII) & GDPR

- Do not scrape personal data (names, phone numbers, private addresses, emails) without a valid legal basis or user consent.
- When extracting structured fields, avoid storing unhashed PII in persistent recipe stores or local device storage.
- Respect site Terms of Service and copyright notices.
