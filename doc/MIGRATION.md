# Migration Guide: 1.1.0 to 2.0.0

`flutter_ai_scrapper` 2.0 is a ground-up architectural rebuild. While 1.1.0 relied on regular expressions for text matching and HTML extraction, 2.0 introduces an HTML5 spec-compliant DOM parser, zero-cost deterministic structured data harvesting (JSON-LD, Microdata), an on-device/cloud AI fallback tier, and site-level selector recipes.

---

## 1. Key Behavioral Differences & Bug Fixes

> [!WARNING]
> **Extracted Strings Will Differ from 1.1.0:**
> 1.1.0 suffered from fundamental regex parsing limitations. The 2.0 HTML parser resolves elements correctly, which means returned text content will be cleaner, more complete, and free from mismatched HTML tags.

### Nested Tag Pairing
- **1.1.0:** Regex matched the *first* closing tag it encountered. In nested structures like `<div><div>Inner</div></div>`, 1.1.0 stopped at the first `</div>`, truncating the outer container and corrupting sibling elements.
- **2.0.0:** The HTML5 parser builds a true DOM tree. Queries against an outer tag return the complete nested subtree.

### Class Name Matching
- **1.1.0:** Regex checked substring containment, meaning `class="btn"` matched `<div class="btn-primary">` and `<div class="subtle-btn">`.
- **2.0.0:** CSS selectors (`.select('.btn')`) evaluate exact class list membership according to W3C standards.

### HTML Entity Decoding
- **1.1.0:** Entities like `&amp;`, `&quot;`, and `&#39;` were returned raw in extracted strings.
- **2.0.0:** All text properties (`node.text`) automatically decode HTML5 entities.

---

## 2. API Migration Cheatsheet

### Quick Scrape & Loading

**Before (1.1.0):**
```dart
final scraper = MobileScraper(url: 'https://example.com');
await scraper.load();
final title = scraper.queryWithRegexFirst(r'<title>(.*?)</title>');
```

**After (2.0.0):**
```dart
final page = await AiScrapper.open('https://example.com');
final title = page.title;
final links = page.document.select('a');
```

---

### Structured Schema Extraction

**2.0.0 Introduces Typed Schemas:**
```dart
final schema = Schema.object({
  'name': const Field.string(),
  'price': const Field.money(),
});

// Deterministic Tier 1 extraction (free, zero-inference):
final result = page.extract(schema);

// Or with on-device Gemma / Cloud fallback:
final result = await page.extractWithAi(schema, provider: gemmaProvider);
```

---

### Natural Language Querying

**2.0.0 Introduces Natural Language Scraping:**
```dart
final result = await page.ask('extract book name and price in USD', provider: provider);
print(result.data);
```

---

## 3. Deprecation Compatibility Shim

To assist gradual migration, `MobileScraper` is retained as a `@Deprecated` facade in 2.0.0. Existing 1.1.0 methods will continue to compile with deprecation warnings pointing to their 2.0 replacements. The shim will be retired in 2.1.0.
