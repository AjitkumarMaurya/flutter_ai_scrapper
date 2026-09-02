# 🚀 Flutter AI Scrapper 2.0

On-device AI web scraping for Flutter. Parses real HTML with an HTML5 DOM parser, harvests JSON-LD, Microdata, and OpenGraph for free with zero AI calls, and falls back to an on-device Gemma model or any OpenAI/Claude-compatible endpoint for schema-typed extraction.

---

## ⚡ The Four-Tier Extraction Architecture

Web scraping on mobile must balance accuracy, battery life, token expenditure, and user privacy. `flutter_ai_scrapper` uses a four-tier pipeline that prioritizes deterministic execution and only invokes language models when necessary:

```
[Web Page]
    │
    ▼
┌─────────────────────────────────────────────────────────────┐
│ Tier 1 — Deterministic Foundation (0 AI Tokens, <2ms)       │
│ HTML5 DOM Parser • Readability Scoring • JSON-LD • Microdata│
└───────────────────────────┬─────────────────────────────────┘
                            │ (missing fields or unstructured)
                            ▼
┌─────────────────────────────────────────────────────────────┐
│ Tier 4 — Site Selector Recipes (0 AI Tokens, <0.05ms)       │
│ Cached CSS Selectors • Pure-CSS Runner • Drift Detection    │
└───────────────────────────┬─────────────────────────────────┘
                            │ (new domain or mutated layout)
                            ▼
┌─────────────────────────────────────────────────────────────┐
│ Tier 2 — Typed Schema Extraction (On-Device or Cloud)       │
│ Schema-as-Tool • BM25 Chunk Ranking • Map-Reduce Collections│
└───────────────────────────┬─────────────────────────────────┘
                            │ (free-form queries)
                            ▼
┌─────────────────────────────────────────────────────────────┐
│ Tier 3 — Natural-Language Planner (`page.ask`)              │
│ Prompt → Schema Inference • Auto-Recipe Lifecycle           │
└─────────────────────────────────────────────────────────────┘
```

---

## 📊 Measured Benchmarks

Measured on a standard mobile/desktop development machine using the included benchmark suite:

| Pipeline Stage | Measured Latency | Token Cost | Accuracy / Guarantees |
|---|---|---|---|
| **HTML5 DOM Parsing** | **1.13 ms** / page | 0 tokens | W3C spec compliant, decodes entities, pairs nested tags |
| **Readability Scoring** | **1.84 ms** / page | 0 tokens | Strips boilerplate chrome, extracts core prose |
| **JSON-LD / Metadata (Tier 1)** | **0.10 ms** / page | 0 tokens | 100% deterministic, schema-typed |
| **Recipe Pure-CSS (Tier 4)** | **0.02 ms** / page | **0 tokens** | Sub-millisecond execution, auto-drift detection |
| **Context Window Reduction** | — | **71.0% saved** | Reduces raw HTML to clean markdown before LLM |

---

## 📱 Platform Support

| Platform | Support | Requirement |
|---|---|---|
| **Android** | Full support | **minSdkVersion 24** (Android 7.0), compileSdkVersion 36 |
| **iOS** | Full support | **iOS 15.0+** |
| Web / Desktop | Unofficial | Out of scope for 2.0 on-device AI |

---

## 🚀 Quick Start

### 1. Installation

```yaml
dependencies:
  flutter_ai_scrapper: ^2.0.0
```

### 2. Tier 1: Zero-AI Deterministic Extraction

Scrape articles and extract metadata with zero tokens, zero model downloads, and zero platform weight:

```dart
import 'package:flutter_ai_scrapper/flutter_ai_scrapper.dart';

// Fetch and parse with full HTML5 DOM
final page = await AiScrapper.open('https://news.ycombinator.com');

print('Title: ${page.title}');
print('First link: ${page.document.selectFirst("a")?.attributes["href"]}');

// Automatic JSON-LD, OpenGraph, and Microdata harvesting
final productSchema = Schema.object({
  'name': const Field.string(),
  'price': const Field.money(),
});
final harvest = page.extract(productSchema);
if (harvest.isComplete) {
  print('Harvested deterministically: ${harvest.data}');
}
```

### 3. Tier 2: Typed Schema Extraction (Gemma & Cloud Providers)

When websites lack structured metadata, the schema extraction pipeline reduces the page via BM25 chunk ranking and uses local Gemma or cloud providers:

```dart
// Option A: On-Device Gemma (Zero Network, Zero Cost)
final gemmaProvider = GemmaProvider(manager: ModelManager());

// Option B: Resilient Fallback Chain with Cloud
final chain = ProviderChain(
  providers: [
    gemmaProvider,
    OpenAiProvider(baseUrl: 'http://localhost:11434/v1', model: 'llama3'), // Ollama
    AnthropicProvider(apiKey: 'sk-ant-...', model: 'claude-3-5-sonnet-latest'),
  ],
  allowCloudEgress: false, // Strict zero-egress privacy default!
);

final result = await page.extractWithAi(productSchema, provider: chain);
print('Extracted by: ${result.providerId}');
print('Data: ${result.data}');
```

### 4. Tier 3: Natural-Language Asking (`page.ask`)

Ask questions in plain English. The library plans a typed schema and executes the extraction:

```dart
final result = await page.ask(
  'extract all book titles and prices in USD',
  provider: chain,
);

print(result.data);
```

### 5. Tier 4: Site-Level Selector Recipes (AI Once, CSS Forever)

Synthesize CSS selector recipes with an AI model on page 1, and run with pure CSS for free on pages 2–N:

```dart
final recipeStore = RecipeStore();

// Page 1: Synthesizes recipe using AI
final res1 = await page1.ask('extract product name and price', provider: chain, recipeStore: recipeStore);

// Page 2+: Runs pure CSS with ZERO tokens and sub-millisecond execution!
final res2 = await page2.ask('extract product name and price', provider: chain, recipeStore: recipeStore);
```

---

## 🔒 Privacy & Secret Safety

1. **`allowCloudEgress: false` by default:** Remote cloud providers are skipped unless callers explicitly opt in.
2. **Secret Redaction:** `KeySanitizer` redacts API keys and bearer tokens from all logs and error messages.
3. **Local Ollama Support:** Connect to local desktop Ollama instances (`http://localhost:11434/v1`) without sending data to any cloud provider.

---

## 🎨 Built-In Material 3 UI Components

Zero external state-management dependencies (`ValueNotifier` only):

- **`ModelManagerSheet`**: Download, delete, and inspect on-device Hugging Face models.
- **`ProviderSettingsSheet`**: Configure fallback chains, test connections, and toggle cloud egress.
- **`ResultViewer`**: Tabbed viewer (Table, JSON, Markdown, Raw) with field-level **Provenance Badges** (`[JSON-LD]`, `[Recipe]`, `[AI]`).
- **`StreamingTextView`**: Live token streaming with collapsible reasoning/thinking blocks.
- **`ExtractionConsole`**: Interactive scraping console with real-time stage progress.

---

## 📚 Documentation Links

- [Migration Guide (1.1.0 to 2.0.0)](doc/MIGRATION.md)
- [On-Device Model Selection & Architecture](doc/MODELS.md)
- [Cloud Providers & Fallback Setup](doc/PROVIDERS.md)
- [Ethics & Responsible Scraping](doc/ETHICS.md)

---

## 📄 License

MIT License. See [LICENSE](LICENSE) for details.
