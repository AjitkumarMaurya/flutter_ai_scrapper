# AI Providers & Security Guide

`flutter_ai_scrapper` supports multi-provider extraction ranging from local, offline on-device models to cloud endpoints and self-hosted inference servers.

---

## 🔒 Security & Privacy First

### The Key Exposure Problem
**Never embed production API keys (OpenAI, Anthropic, etc.) directly into a mobile or web client application.**

Mobile application packages (`.apk`, `.ipa`, `.aab`) and compiled WebAssembly / JavaScript bundles are easily inspected using tools like `apktool`, `strings`, or web browser dev tools. Embedding an API key in client code gives any user or attacker unlimited access to charge your LLM billing account.

### Recommended Production Architecture: The Backend Proxy Pattern
For production applications requiring cloud LLMs, route requests through your own backend proxy server:

```
[Flutter App]
      │
      │ 1. POST /scrape-extract (User Auth Token)
      ▼
[Your Backend / Edge Gateway (e.g. Cloud Run, Supabase, Workers)]
      │ (Holds true OPENAI_API_KEY / ANTHROPIC_API_KEY in Secret Manager)
      │ 2. Calls OpenAI / Claude with rate limits & cost caps
      ▼
[LLM Provider]
```

To configure `flutter_ai_scrapper` to talk to your backend proxy, simply supply your proxy URL to `OpenAiProvider`:

```dart
final provider = OpenAiProvider(
  baseUrl: 'https://api.yourbackend.com/v1',
  model: 'gpt-4o-mini',
  apiKey: userAuthSessionToken, // Your user's session token, NOT your OpenAI key!
);
```

---

## Zero-Egress Privacy: `allowCloudEgress`

By default, `ProviderChain` sets `allowCloudEgress: false`. This guarantees that scraped data will **never leave the user's device** unless you explicitly opt in:

```dart
final chain = ProviderChain(
  providers: [
    OpenAiProvider(baseUrl: 'https://api.openai.com/v1', model: 'gpt-4o-mini', apiKey: key),
    GemmaProvider(),
  ],
  allowCloudEgress: false, // Default: skips OpenAiProvider and uses local GemmaProvider
);

// To allow cloud endpoints:
final cloudChain = ProviderChain(
  providers: [
    OpenAiProvider(baseUrl: 'https://api.openai.com/v1', model: 'gpt-4o-mini', apiKey: key),
    GemmaProvider(),
  ],
  allowCloudEgress: true, // Explicit opt-in required for cloud transmission
);
```

---

## Provider Setup Examples

### 1. Local On-Device Gemma (`GemmaProvider`)
- **Cost:** Free
- **Privacy:** 100% on-device, zero network traffic
- **Weights:** Downloaded once to app document storage (~550 MB for Gemma 3 1B)

```dart
final gemma = GemmaProvider();
await gemma.init();
```

---

### 2. Local Ollama (`OpenAiProvider` with local `baseUrl`)
Ideal for local testing and developer workstations without needing any cloud account or incurring any egress:

```bash
# Start Ollama locally
ollama run llama3
```

```dart
final ollama = OpenAiProvider(
  baseUrl: 'http://localhost:11434/v1', // Or 10.0.2.2 for Android Emulator
  model: 'llama3',
  // No apiKey needed for local Ollama
);
```

---

### 3. OpenAI & OpenAI-Compatible Clouds
Supports OpenAI, Groq, Together, Mistral, DeepSeek, OpenRouter, and Azure:

```dart
// Standard OpenAI
final openai = OpenAiProvider(
  baseUrl: 'https://api.openai.com/v1',
  model: 'gpt-4o-mini',
  apiKey: backendKeyOrProxyToken,
);

// Groq
final groq = OpenAiProvider(
  baseUrl: 'https://api.groq.com/openai/v1',
  model: 'llama-3.3-70b-versatile',
  apiKey: groqApiKey,
);

// DeepSeek
final deepseek = OpenAiProvider(
  baseUrl: 'https://api.deepseek.com/v1',
  model: 'deepseek-chat',
  apiKey: deepseekApiKey,
);
```

---

### 4. Anthropic Claude (`AnthropicProvider`)
Supports Claude 3.5 Sonnet and Haiku with native `tool_use`:

```dart
final anthropic = AnthropicProvider(
  apiKey: anthropicApiKey,
  model: 'claude-3-5-haiku-20241022',
);
```

---

### 5. Fallback Chains (`ProviderChain`)
Create self-healing pipelines that try cloud endpoints and automatically fall back to local Gemma if offline, rate-limited (429), or facing server errors (5xx):

```dart
final chain = ProviderChain(
  providers: [
    OpenAiProvider(baseUrl: 'https://api.yourproxy.com/v1', model: 'gpt-4o-mini'),
    AnthropicProvider(apiKey: claudeProxyToken),
    GemmaProvider(), // Local offline fallback floor
  ],
  allowCloudEgress: true,
);
```
